import SwiftUI
import FirebaseCore
import FirebaseAuth

/// Crash fix (build 121): Firebase must be configured exactly once, from code,
/// before anything touches Auth or Firestore. No GoogleService-Info.plist needed.
enum FirebaseBoot {
    static func ensure() {
        if FirebaseApp.app() != nil { return }
        let o = FirebaseOptions(googleAppID: "1:943521917653:ios:729a230157baf5a02c105c", gcmSenderID: "943521917653")
        o.apiKey = "AIzaSyD3pfsSI-NpEPZgZhk4jiqdIZjyfmbkTVs"
        o.projectID = "needs-me-480ea"
        o.clientID = "943521917653-k7cggtl36k7fn64mvhtv2qbbp3kkmg32.apps.googleusercontent.com"
        o.bundleID = "shop.ilseplacencia.needsme"
        FirebaseApp.configure(options: o)
    }
}

@main
struct NeedsMeApp: App {
    @StateObject private var store = Store()
    @AppStorage("nm_theme") private var themeRaw = AppTheme.white.rawValue

    init() {
        FirebaseBoot.ensure()
        if CommandLine.arguments.contains("-uitest-reset") {
            try? Auth.auth().signOut()
            UserDefaults.standard.removeObject(forKey: "nm_tour_done")
        }
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
