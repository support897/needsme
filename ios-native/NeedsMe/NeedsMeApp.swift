import SwiftUI
import FirebaseCore

@main
struct NeedsMeApp: App {
    @StateObject private var store = Store()
    @AppStorage("nm_theme") private var themeRaw = AppTheme.white.rawValue

    init() {
        if FirebaseApp.app() != nil { return }
        let o = FirebaseOptions(googleAppID: "1:943521917653:ios:8b24fe223741acfb2c105c", gcmSenderID: "943521917653")
        o.apiKey = "AIzaSyD3pfsSI-NpEPZgZhk4jiqdIZjyfmbkTVs"
        o.projectID = "needs-me-480ea"
        FirebaseApp.configure(options: o)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.palette, (AppTheme(rawValue: themeRaw) ?? .white).palette)
                .preferredColorScheme((AppTheme(rawValue: themeRaw) ?? .white).scheme)
        }
    }
}
