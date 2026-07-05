import Foundation
import Observation
import os
import ZIPFoundation

private let logger = Logger(subsystem: Bundle.main.identifier, category: "SheetStore")

/// Manages the optional download of song sheet-music images.
///
/// Sheets are not bundled with the app. The user can download a single zip
/// archive (~45 MB) from a GitHub release; it is unzipped into Application
/// Support and served locally afterwards.
@Observable
@MainActor
final class SheetStore {

    static let archiveURL = URL(string: "https://github.com/MilanNosal/spevnik-casd/releases/download/sheets_v1/sheets.zip")!

    private static let installedFlagKey = "org.valesoft.casd.sheetsInstalled"

    enum State: Equatable {
        case notDownloaded
        case downloading(progress: Double)
        case downloaded
        case failed(String)
    }

    private(set) var state: State

    private var downloadTask: Task<Void, Never>?

    init() {
        let installed = UserDefaults.standard.bool(forKey: Self.installedFlagKey)
        // Trust the flag only if the directory actually still exists.
        state = (installed && FileManager.default.fileExists(atPath: Self.sheetsDirectory.path))
            ? .downloaded
            : .notDownloaded
    }

    // MARK: - Locations

    private static var sheetsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("sheets", isDirectory: true)
    }

    /// Local file URL for a sheet name (as stored on `Song.sheets`), or nil if
    /// it is not present on disk.
    func imageURL(for name: String) -> URL? {
        guard case .downloaded = state else { return nil }
        let url = Self.sheetsDirectory.appendingPathComponent("\(name).png")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    var isDownloaded: Bool {
        if case .downloaded = state { return true }
        return false
    }

    var isDownloading: Bool {
        if case .downloading = state { return true }
        return false
    }

    // MARK: - Download

    func download() {
        guard !isDownloading, !isDownloaded else { return }
        state = .downloading(progress: 0)

        downloadTask = Task {
            do {
                try await performDownload()
                UserDefaults.standard.set(true, forKey: Self.installedFlagKey)
                state = .downloaded
            } catch is CancellationError {
                cleanupPartial()
                state = .notDownloaded
            } catch {
                logger.error("Sheet download failed: \(String(describing: error), privacy: .public)")
                cleanupPartial()
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
    }

    func delete() {
        cancel()
        try? FileManager.default.removeItem(at: Self.sheetsDirectory)
        UserDefaults.standard.set(false, forKey: Self.installedFlagKey)
        state = .notDownloaded
    }

    // MARK: - Implementation

    private func performDownload() async throws {
        let fm = FileManager.default

        // Download the archive to a temp file via a download task, which writes
        // straight to disk. (Streaming `URLSession.bytes` would iterate the ~45 MB
        // one `UInt8` at a time — tens of millions of awaits.)
        let downloader = ArchiveDownloader { [weak self] fraction in
            Task { @MainActor in
                guard let self, self.isDownloading else { return }
                self.state = .downloading(progress: fraction)
            }
        }
        let tempZip = try await downloader.download(Self.archiveURL)
        defer { try? fm.removeItem(at: tempZip) }

        try Task.checkCancellation()

        // Unzip into a fresh directory, then swap into place atomically.
        let staging = fm.temporaryDirectory.appendingPathComponent("sheets-unzip-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        try fm.unzipItem(at: tempZip, to: staging)

        // The zip may contain a top-level `sheets/` folder or the PNGs directly.
        let source = try resolvedContentRoot(in: staging)

        let dest = Self.sheetsDirectory
        try? fm.removeItem(at: dest)
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.moveItem(at: source, to: dest)
        try? fm.removeItem(at: staging)
    }

    /// If the archive unzipped to a single wrapper folder, descend into it so
    /// the PNGs sit directly under `sheets/`.
    private func resolvedContentRoot(in staging: URL) throws -> URL {
        let fm = FileManager.default
        let entries = try fm.contentsOfDirectory(at: staging, includingPropertiesForKeys: [.isDirectoryKey])
        let pngs = entries.filter { $0.pathExtension.lowercased() == "png" }
        if !pngs.isEmpty { return staging }
        let dirs = entries.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        if dirs.count == 1 { return dirs[0] }
        return staging
    }

    private func cleanupPartial() {
        try? FileManager.default.removeItem(at: Self.sheetsDirectory)
        UserDefaults.standard.set(false, forKey: Self.installedFlagKey)
    }
}

enum SheetStoreError: LocalizedError {
    case badResponse

    var errorDescription: String? {
        switch self {
        case .badResponse: return "Server neodpovedal správne."
        }
    }
}

/// Downloads a file to a temporary location via a `URLSessionDownloadTask`,
/// reporting fractional progress. The task writes straight to disk, avoiding the
/// per-byte iteration cost of streaming `URLSession.bytes`.
///
/// We drive an explicit `downloadTask(with:)` rather than the async
/// `session.download(from:)` convenience method: the latter installs its own
/// internal task delegate, so our `didWriteData` progress callback never fires.
private final class ArchiveDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {

    private let onProgress: (Double) -> Void

    // Assigned by `download(_:)` before `task.resume()`, so it is set before any
    // delegate callback can fire; the callbacks then read and clear it on the
    // serial delegate queue. This ordering — not a lock — is what keeps access
    // safe under `@unchecked Sendable`.
    private var continuation: CheckedContinuation<URL, Error>?

    // Last fraction handed to `onProgress`. Read and written only on the serial
    // delegate queue (from `didWriteData`), so it needs no synchronization. Used
    // to throttle updates: `didWriteData` fires very frequently for a ~45 MB
    // download, and each report otherwise spawns a MainActor Task.
    private var lastReportedFraction = 0.0

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
    }

    /// Downloads `url` and returns a temp file URL the caller owns (and must
    /// remove). Throws `CancellationError` if the surrounding task is cancelled,
    /// or `SheetStoreError.badResponse` on a non-2xx status.
    func download(_ url: URL) async throws -> URL {
        lastReportedFraction = 0
        // Serial delegate queue so `continuation` and the callbacks don't race.
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: queue)
        defer { session.finishTasksAndInvalidate() }

        let task = session.downloadTask(with: url)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return } // unknown length
        let fraction = min(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 1)
        // Report only on a ≥2.5% advance (always report completion). This keeps the
        // progress bar smooth while avoiding a MainActor Task per callback, and —
        // since it only moves forward — the bar can't jump backward.
        guard fraction - lastReportedFraction >= 0.015 || fraction >= 1 else { return }
        lastReportedFraction = fraction
        onProgress(fraction)
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let response = downloadTask.response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            let statusCode = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? -1
            logger.error("Sheet download: unexpected HTTP status \(statusCode, privacy: .public)")
            continuation?.resume(throwing: SheetStoreError.badResponse)
            continuation = nil
            return
        }

        // `location` is deleted the moment this callback returns, so move it to a
        // stable spot the caller can hand off to unzip — synchronously, here.
        let fm = FileManager.default
        let dest = fm.temporaryDirectory.appendingPathComponent("sheets-\(UUID().uuidString).zip")
        do {
            try fm.moveItem(at: location, to: dest)
            continuation?.resume(returning: dest)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        // A successful finish already resumed via `didFinishDownloadingTo`, which
        // clears the continuation; only an error path remains to handle here.
        guard let continuation else { return }
        self.continuation = nil
        if let urlError = error as? URLError, urlError.code == .cancelled {
            // Map URLSession's cancellation to the cooperative-cancellation error
            // the caller already handles as a user-initiated cancel.
            continuation.resume(throwing: CancellationError())
        } else if let error {
            continuation.resume(throwing: error)
        } else {
            // No error and no file — shouldn't happen, but don't leak the await.
            continuation.resume(throwing: SheetStoreError.badResponse)
        }
    }
}
