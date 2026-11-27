import SwiftUI
import UIKit
import UserNotifications
import FirebaseAuth

/// Closed-app alerts. Apple gives this phone a device token. The bridge keeps it and sends one short
/// alert when an AI says it needs you or finished. No AI key and no chat text is ever stored for this.
@MainActor final class Push {
    static let shared = Push()
    private let k = "nm_push_token"
    var token: String? { UserDefaults.standard.string(forKey: k) }

    /// Asks once, then registers. Skipped inside UI tests so no system box gets in the way.
    func start() {
        if CommandLine.arguments.contains(where: { $0.hasPrefix("-uitest") }) { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
            guard ok else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }
    func got(_ data: Data) {
        let hex = data.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: k)
        Task { await upload() }
    }
    /// Sends the token to the bridge under this user. Safe to call again.
    func upload() async {
        guard let t = token, let u = Auth.auth().currentUser, let idt = try? await u.getIDToken(), let url = URL(string: BridgeCard.base + "/device") else { return }
        var r = URLRequest(url: url); r.httpMethod = "POST"; r.timeoutInterval = 20
        r.setValue("Bearer " + idt, forHTTPHeaderField: "Authorization"); r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["token": t])
        _ = try? await URLSession.shared.data(for: r)
    }
}

final class PushDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in Push.shared.got(deviceToken) }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let id = response.notification.request.content.userInfo["acct"] as? String { Task { @MainActor in AlertRouter.shared.go(id) } }
        completionHandler()
    }
}
