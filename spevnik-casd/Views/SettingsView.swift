import SwiftUI

struct SettingsView: View {
    
    @AppStorage("org.valesoft.casd.breakingLines") private var showLineBreaks = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Toggle("Zalomenie riadkov", isOn: $showLineBreaks)
            
            VStack(alignment: .center, spacing: 2) {
                Text("milan.nosal@gmail.com").font(.footnote).bold()
                Text(Bundle.main.appName).font(.footnote).bold()
                Text("\(Bundle.main.appVersionLong) (\(Bundle.main.appBuild))").font(.footnote)
            }
            .opacity(0.8)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 24)
            
            Spacer()
        }
        .padding()
        .tint(.green)
    }
}
