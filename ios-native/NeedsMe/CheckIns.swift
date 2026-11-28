import Foundation
import UserNotifications
import MetricKit

/// Three local check-in alerts a day (free, no server). Tapping one opens the app, which then syncs.
enum CheckIns {
    static let key = "nm.checkins.on"
    static var on: Bool { get { UserDefaults.standard.object(forKey: key) as? Bool ?? true } set { UserDefaults.standard.set(newValue, forKey: key); schedule() } }
    static func schedule() {
        let c = UNUserNotificationCenter.current()
        let ids = ["nm.ci.9", "nm.ci.13", "nm.ci.18"]
        c.removePendingNotificationRequests(withIdentifiers: ids)
        guard on else { return }
        let text = ["Good morning. Open NeedsMe to see your projects and what needs you.", "Midday check-in. Open NeedsMe to see what needs you.", "Evening check-in. Open NeedsMe to see today's updates."]
        for (i, h) in [9, 13, 18].enumerated() {
            let n = UNMutableNotificationContent(); n.title = "NeedsMe"; n.body = text[i]; n.sound = .default
            var d = DateComponents(); d.hour = h; d.minute = 0
            c.add(UNNotificationRequest(identifier: ids[i], content: n, trigger: UNCalendarNotificationTrigger(dateMatching: d, repeats: true)))
        }
    }
}

/// Item 1: Apple sends crash reports back to the app on the next launch; pass them to the bridge /report.
final class CrashReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashReporter()
    static func start() { MXMetricManager.shared.add(shared) }
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for p in payloads {
            guard let crashes = p.crashDiagnostics, !crashes.isEmpty else { continue }
            let t = crashes.prefix(3).map { String(data: $0.jsonRepresentation(), encoding: .utf8)?.prefix(1200) ?? "" }.joined(separator: "\n---\n")
            var r = URLRequest(url: URL(string: "https://billowing-lake-5abc.placenciailse.workers.dev/report")!)
            r.httpMethod = "POST"; r.setValue("application/json", forHTTPHeaderField: "content-type")
            r.httpBody = try? JSONSerialization.data(withJSONObject: ["kind": "bug", "text": "iPhone crash report (\(crashes.count))\n" + t, "info": "iOS app MetricKit"])
            URLSession.shared.dataTask(with: r).resume()
        }
    }
}
