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

        // Stream the archive to a temporary file, reporting progress.
        let (bytes, response) = try await URLSession.shared.bytes(from: Self.archiveURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            logger.error("Sheet download: unexpected HTTP status \(statusCode, privacy: .public)")
            throw SheetStoreError.badResponse
        }
        let expected = response.expectedContentLength // may be -1 if unknown

        let tempZip = fm.temporaryDirectory.appendingPathComponent("sheets-\(UUID().uuidString).zip")
        fm.createFile(atPath: tempZip.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempZip)
        defer { try? handle.close() }

        var buffer = Data()
        buffer.reserveCapacity(1 << 16)
        var received: Int64 = 0
        for try await byte in bytes {
            buffer.append(byte)
            received += 1
            if buffer.count >= (1 << 16) {
                try handle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
                if expected > 0 {
                    let p = Double(received) / Double(expected)
                    state = .downloading(progress: min(p, 1))
                }
                try Task.checkCancellation()
            }
        }
        if !buffer.isEmpty { try handle.write(contentsOf: buffer) }
        try handle.close()
        try Task.checkCancellation()

        // Unzip into a fresh directory, then swap into place atomically.
        let staging = fm.temporaryDirectory.appendingPathComponent("sheets-unzip-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        try fm.unzipItem(at: tempZip, to: staging)
        try? fm.removeItem(at: tempZip)

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
