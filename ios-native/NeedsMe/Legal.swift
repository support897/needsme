import SwiftUI
import FirebaseAuth

/// Where the app tells people what it shares, and asks first (App Review Guideline 5.1.2(i)).
enum AIConsent {
    static let key = "nm_ai_share_ok"
    /// UI tests skip the ask, like they skip the push prompt.
    static var testMode: Bool { CommandLine.arguments.contains { $0.hasPrefix("-uitest") } }
    static var granted: Bool { testMode || UserDefaults.standard.bool(forKey: key) }
    static let needed = "Allow sharing first. Open the Connect tab and tap Allow in the box at the top."
}

enum LegalLinks {
    static let privacy = "https://support897.github.io/needsme/privacy.html"
    static let terms = "https://support897.github.io/needsme/terms.html"
    static let support = "https://support897.github.io/needsme/support.html"
    static let email = "needsmeai@proton.me"
}

/// A plain box: who gets what, and an Allow button. Shown at the top of Connect.
struct ConsentCard: View {
    @Environment(\.palette) var p
    @AppStorage(AIConsent.key) var ok = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Before you connect an AI").font(.headline).foregroundColor(p.ink)
            Text("When you chat with an AI here, your messages and your project and to-do names go to that AI company, the one you picked, using your own key or link. They are not sent to anyone else. That company's own privacy policy then applies. Your keys stay in this phone's Keychain.")
                .font(.subheadline).foregroundColor(p.ink)
            Text("Links to Claude, ChatGPT and other tools also keep a copy of your project and to-do names on our bridge (Cloudflare) so the AI can read them. You can cut every link any time.")
                .font(.footnote).foregroundColor(p.soft)
            if ok {
                Label("Sharing is allowed", systemImage: "checkmark.seal.fill").font(.subheadline.bold()).foregroundColor(.sprout)
                    .accessibilityIdentifier("aiConsentOn")
                Button("Turn sharing off") { ok = false }.buttonStyle(SoftButton()).accessibilityIdentifier("aiConsentOff")
            } else {
                Button("Allow sharing with the AIs I connect") { ok = true }.buttonStyle(PrimaryButton()).accessibilityIdentifier("aiConsentAllow")
            }
            Link("Read the privacy policy", destination: URL(string: LegalLinks.privacy)!).font(.footnote)
        }
        .padding(14).background(p.card).clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

/// Privacy policy, terms and help, one tap away (Guidelines 5.1.1(i) and 1.5).
struct LegalCard: View {
    @Environment(\.palette) var p
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About and help").font(.headline).foregroundColor(p.ink)
            Link("Privacy policy", destination: URL(string: LegalLinks.privacy)!).accessibilityIdentifier("linkPrivacy")
            Link("Terms of use", destination: URL(string: LegalLinks.terms)!).accessibilityIdentifier("linkTerms")
            Link("Help and support", destination: URL(string: LegalLinks.support)!).accessibilityIdentifier("linkSupport")
            Link("Report a problem: " + LegalLinks.email, destination: URL(string: "mailto:" + LegalLinks.email + "?subject=NeedsMe%20Ai%20problem")!).accessibilityIdentifier("linkReport")
        }
        .font(.subheadline)
    }
}

extension BridgeSync {
    /// Deleting the account also erases what the link holds (tokens, project names, queued messages, device token).
    func eraseAll() async {
        guard let u = Auth.auth().currentUser, let idt = try? await u.getIDToken(), let url = URL(string: BridgeCard.base + "/me") else { return }
        var r = URLRequest(url: url); r.httpMethod = "DELETE"; r.timeoutInterval = 20
        r.setValue("Bearer " + idt, forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: r)
        clearToken()
    }
}
