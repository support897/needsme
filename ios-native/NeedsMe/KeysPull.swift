import Foundation
import SwiftUI
import FirebaseAuth

/// "Bring my keys in" (build 341, item 2, spec of 12 Nov). One tap: the app sends the signed in
/// user's own Firebase token to the keys endpoint on her own server; the server reads the uid
/// FROM THE TOKEN and returns only that user's vaulted accounts (provider, label, key).
/// Keys land in the device Keychain through the same AIKeys path pasted keys use. A key already
/// on this device is never overwritten. Each brought in account then runs its OWN test, and only
/// a passed test shows Connected. Keys are never shown, logged, or written anywhere else.
enum KeysPull {
    static let endpoint = URL(string: "https://keys.ilseplacencia.shop/keys/pull")!

    struct Pulled: Decodable {
        let provider: String
        let label: String
        let key: String
    }
    private struct Reply: Decodable { let accounts: [Pulled] }

    enum Outcome {
        case accounts([Pulled])
        case noKeys
        case tooMany
        case unreachable
    }

    /// Maps the server's provider words onto the app's providers. Unknown words are skipped.
    static func provider(_ raw: String) -> AIProvider? {
        switch raw.lowercased() {
        case "chatgpt", "openai": return .chatgpt
        case "claude", "anthropic": return .claude
        case "gemini", "google": return .gemini
        case "perplexity": return .perplexity
        case "grok", "xai": return .grok
        default: return AIProvider.named(raw)
        }
    }

    static func pull() async -> Outcome {
        guard let user = Auth.auth().currentUser else { return .unreachable }
        guard let token = try? await user.getIDToken() else { return .unreachable }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data("{}".utf8)
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return .unreachable }
        if http.statusCode == 429 { return .tooMany }
        guard http.statusCode == 200 else { return .unreachable }
        if let reply = try? JSONDecoder().decode(Reply.self, from: data) {
            return reply.accounts.isEmpty ? .noKeys : .accounts(reply.accounts)
        }
        if let list = try? JSONDecoder().decode([Pulled].self, from: data) {
            return list.isEmpty ? .noKeys : .accounts(list)
        }
        return .unreachable
    }
}

/// The card on the Connections screen. One button, one plain result line per account.
struct BringKeysCard: View {
    @Environment(\.palette) var p
    @ObservedObject private var conns = AIConnections.shared
    @State private var running = false
    @State private var lines: [String] = []

    var body: some View {
        Card {
            Text("BRING MY KEYS IN").font(.caption.monospaced().bold()).foregroundColor(p.soft)
            Text("Your keys, already saved for you").font(.title3.bold()).foregroundColor(p.ink)
            Text("If the team saved your AI keys for this account, bring them in with one tap. They land in this phone's Keychain, the same place pasted keys go. A key already on this phone is never replaced.")
                .font(.subheadline).foregroundColor(p.soft)
            Button(running ? "Bringing your keys in..." : "Bring my keys in") { Task { await run() } }
                .buttonStyle(PrimaryButton()).disabled(running)
                .accessibilityIdentifier("bringKeys")
            ForEach(lines, id: \.self) { line in
                Text(line).font(.subheadline).foregroundColor(p.ink)
            }
            if !lines.isEmpty {
                Text(lines.last ?? "").accessibilityIdentifier("bringKeysResult")
                    .font(.system(size: 0.1)).opacity(0.01).frame(height: 1)
            }
        }
    }

    private func run() async {
        running = true
        lines = []
        defer { running = false }
        switch await KeysPull.pull() {
        case .tooMany:
            lines = ["Too many tries just now. Give it a moment, then tap again."]
        case .unreachable:
            lines = ["Could not reach the server. Your keys stay where they are. Try again later."]
        case .noKeys:
            lines = ["No keys waiting for this account."]
        case .accounts(let pulled):
            var out: [String] = []
            for item in pulled {
                guard let prov = KeysPull.provider(item.provider) else { continue }
                out.append(await place(item, prov))
            }
            lines = out.isEmpty ? ["No keys waiting for this account."] : out
        }
    }

    /// Puts one pulled key where it belongs and runs that account's own test.
    /// Fill only empty: an account that already holds a key is reported and left exactly as it is.
    private func place(_ item: KeysPull.Pulled, _ prov: AIProvider) async -> String {
        let mine = conns.accounts(for: prov)
        if let named = mine.first(where: { $0.label.lowercased() == item.label.lowercased() }) {
            if conns.hasKey(named) { return "\(named.label): already here. Your saved key was not replaced." }
            return await fill(named, item.key)
        }
        if let empty = mine.first(where: { !conns.hasKey($0) }) {
            return await fill(empty, item.key)
        }
        if let added = conns.add(provider: prov, label: item.label, key: item.key) {
            return await testLine(added)
        }
        return "\(item.label): could not be saved on this phone."
    }

    private func fill(_ a: AIAccount, _ key: String) async -> String {
        guard conns.save(key, for: a) else { return "\(a.label): could not be saved on this phone." }
        return await testLine(a)
    }

    private func testLine(_ a: AIAccount) async -> String {
        await conns.test(a)
        if conns.isConnected(a) { return "\(a.label): brought in and connected." }
        return "\(a.label): brought in, but its test did not pass (\(conns.status(a)))."
    }
}
