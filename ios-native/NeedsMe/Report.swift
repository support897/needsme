import SwiftUI
import FirebaseAuth

enum ReportKind {
    case bug, feedback
    var title: String { self == .bug ? "Report a bug" : "Send feedback" }
    var icon: String { self == .bug ? "ladybug.fill" : "text.bubble.fill" }
    var tint: UInt32 { self == .bug ? 0xFF6B6B : 0x4D96FF }
    var prompt: String {
        self == .bug ? "What went wrong? What did you tap, and what did you expect?" : "What do you love? What should be better? What is missing?"
    }
    var key: String { self == .bug ? "bug" : "feedback" }
}

/// One screen, one tap to send. Goes to the link service, which emails the owner and sends the
/// sender a "we got it" email. Connected to the account and its email, or anonymous for feedback.
struct ReportView: View {
    let kind: ReportKind
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var text = ""
    @State private var anon = false
    @State private var includeInfo = true
    @State private var guestEmail = ""
    @State private var sending = false
    @State private var sent = false
    @State private var emailedYou = false
    @State private var error = ""
    @FocusState private var focus: Bool

    var account: String { store.user?.email ?? "" }
    var isGuest: Bool { account.isEmpty }
    var ready: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 && !sending }

    var info: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "NeedsMe \(v) (\(b)), iOS \(UIDevice.current.systemVersion), \(UIDevice.current.model)"
    }

    var body: some View {
        ScrollView {
            if sent { thanks } else { form }
        }
        .hidesTabBar().lookBg().navigationTitle(kind.title).navigationBarTitleDisplayMode(.inline)
        .onAppear { if !sent { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focus = true } } }
    }

    var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: kind.icon).font(.system(size: 22)).foregroundColor(.white)
                    .frame(width: 48, height: 48).background(Color(hex: kind.tint)).clipShape(RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind == .bug ? "Something broke?" : "We read every message").font(.system(.headline, design: .rounded)).foregroundColor(p.ink)
                    Text("We reply within 24 hours.").font(.subheadline).foregroundColor(p.soft)
                }
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text).focused($focus).frame(minHeight: 190).padding(8)
                    .scrollContentBackground(.hidden).background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("reportText")
                if text.isEmpty {
                    Text(kind.prompt).foregroundColor(.secondary).padding(.horizontal, 14).padding(.vertical, 16).allowsHitTesting(false)
                }
            }
            if kind == .feedback {
                Toggle("Send anonymously", isOn: $anon).tint(.sprout).accessibilityIdentifier("reportAnon")
            }
            if isGuest && !anon {
                TextField("Your email (so we can reply)", text: $guestEmail).textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress).textContentType(.emailAddress).textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("reportEmail")
            }
            if kind == .bug {
                Toggle("Include app version and phone model", isOn: $includeInfo).tint(.sprout)
            }
            Text(anon ? "Anonymous. No account and no email is sent with this."
                 : (isGuest ? "Add an email if you want a reply."
                    : "Sent with your account email, \(account). We email you back there."))
                .font(.footnote).foregroundColor(p.soft)
            if !error.isEmpty { Text(error).font(.footnote).foregroundColor(.red) }
            Button(sending ? "Sending..." : "Send") { Task { await send() } }
                .buttonStyle(PrimaryButton()).disabled(!ready).accessibilityIdentifier("reportSend")
        }.padding()
    }

    var thanks: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundColor(.sprout).padding(.top, 40)
            Text("Got it. Thank you.").font(.system(.title2, design: .rounded).bold()).foregroundColor(p.ink)
            Text(anon ? "We will read it. Because it is anonymous, we cannot reply."
                 : (emailedYou ? "We emailed you to say we have it. We will reply within 24 hours."
                    : "We will reply within 24 hours."))
                .font(.subheadline).foregroundColor(p.soft).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding().accessibilityIdentifier("reportDone")
    }

    func send() async {
        sending = true; error = ""; defer { sending = false }
        if AIConsent.testMode { sent = true; return }
        guard let url = URL(string: BridgeCard.base + "/report") else { return }
        var r = URLRequest(url: url); r.httpMethod = "POST"; r.timeoutInterval = 25
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !anon, let u = Auth.auth().currentUser, let t = try? await u.getIDToken() { r.setValue("Bearer " + t, forHTTPHeaderField: "Authorization") }
        let body: [String: Any] = ["kind": kind.key, "text": text, "anon": anon, "email": (isGuest && !anon) ? guestEmail : "",
                                   "info": (kind == .bug && !includeInfo) ? "" : info]
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (d, resp) = try? await URLSession.shared.data(for: r) else { error = "No connection. Try again."; return }
        let obj = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
        if (resp as? HTTPURLResponse)?.statusCode == 200 {
            emailedYou = (obj?["emailedYou"] as? Bool) ?? false
            sent = true
        } else {
            error = (obj?["error"] as? String) ?? "Could not send. Try again."
        }
    }
}
