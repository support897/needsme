import Foundation
import Security

/// The five AIs that connect with the user's own key.
enum AIProvider: String, CaseIterable, Identifiable {
    case chatgpt, claude, gemini, perplexity, grok
    var id: String { rawValue }
    /// Name shown in the app and used in @mentions.
    var name: String {
        switch self {
        case .chatgpt: return "ChatGPT"
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        case .perplexity: return "Perplexity"
        case .grok: return "Grok"
        }
    }
    var company: String {
        switch self {
        case .chatgpt: return "OpenAI"
        case .claude: return "Anthropic"
        case .gemini: return "Google"
        case .perplexity: return "Perplexity"
        case .grok: return "xAI"
        }
    }
    var keyPage: String {
        switch self {
        case .chatgpt: return "https://platform.openai.com/api-keys"
        case .claude: return "https://console.anthropic.com/settings/keys"
        case .gemini: return "https://aistudio.google.com/apikey"
        case .perplexity: return "https://www.perplexity.ai/settings/api"
        case .grok: return "https://console.x.ai"
        }
    }
    static func named(_ s: String) -> AIProvider? {
        AIProvider.allCases.first { $0.name.lowercased() == s.lowercased() }
    }
}

/// One connected member of the room: an account. Its own key plus its own label.
/// Two accounts of one provider are two members and two voices.
struct AIAccount: Codable, Identifiable, Equatable {
    var id: String        // the provider name for the first account, else provider plus a short slug
    var provider: String  // AIProvider raw value
    var label: String
    var kind: AIProvider { AIProvider(rawValue: provider) ?? .chatgpt }
}

/// Keys live in the device Keychain only. One item per ACCOUNT, keyed by the account id.
/// Never in Firestore, never in UserDefaults, never in a log, never in a file.
enum AIKeys {
    private static let service = "shop.ilseplacencia.needsme.aikeys"

    private static func base(_ accountId: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: accountId]
    }

    @discardableResult
    static func save(_ key: String, account accountId: String) -> Bool {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let data = clean.data(using: .utf8) else { return false }
        SecItemDelete(base(accountId) as CFDictionary)
        var q = base(accountId)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    static func load(_ accountId: String) -> String? {
        var q = base(accountId)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func has(_ accountId: String) -> Bool { load(accountId) != nil }

    static func remove(_ accountId: String) {
        SecItemDelete(base(accountId) as CFDictionary)
    }
}

/// Last test result per account. Holds the result, a plain reason and the time. Never the key.
struct AITestResult: Codable {
    var ok: Bool
    var reason: String
    var at: Date
}

/// What the Connect screen and the rooms read. An account is Connected only after
/// its own test call returned success on this device.
@MainActor
final class AIConnections: ObservableObject {
    static let shared = AIConnections()
    private static let resultsKey = "nm_ai_test_results_v2"
    private static let accountsKey = "nm_ai_accounts"

    @Published private(set) var accounts: [AIAccount] = []
    @Published private(set) var results: [String: AITestResult] = [:]
    @Published private(set) var keyTick = 0
    @Published var testing: Set<String> = []

    private init() {
        if let d = UserDefaults.standard.data(forKey: AIConnections.accountsKey),
           let a = try? JSONDecoder().decode([AIAccount].self, from: d) { accounts = a }
        if let d = UserDefaults.standard.data(forKey: AIConnections.resultsKey),
           let r = try? JSONDecoder().decode([String: AITestResult].self, from: d) { results = r }
        // Every provider always has a first account. Its label defaults to the provider name.
        for p in AIProvider.allCases where !accounts.contains(where: { $0.id == p.rawValue }) {
            accounts.append(AIAccount(id: p.rawValue, provider: p.rawValue, label: p.name))
        }
        // A result without a key in the Keychain is not a connection.
        for a in accounts where !AIKeys.has(a.id) { results[a.id] = nil }
        persist()
    }

    private func persist() {
        if let d = try? JSONEncoder().encode(accounts) { UserDefaults.standard.set(d, forKey: AIConnections.accountsKey) }
        if let d = try? JSONEncoder().encode(results) { UserDefaults.standard.set(d, forKey: AIConnections.resultsKey) }
    }

    func accounts(for p: AIProvider) -> [AIAccount] {
        accounts.filter { $0.provider == p.rawValue }
    }
    func account(_ id: String) -> AIAccount? { accounts.first { $0.id == id } }

    func hasKey(_ a: AIAccount) -> Bool { _ = keyTick; return AIKeys.has(a.id) }

    func isConnected(_ a: AIAccount) -> Bool {
        _ = keyTick
        return AIKeys.has(a.id) && results[a.id]?.ok == true
    }

    var connected: [AIAccount] { accounts.filter { isConnected($0) } }

    /// The name to show for an author id: the account label, else the provider name, else the id.
    func displayName(_ authorId: String) -> String {
        if let a = account(authorId) { return a.label }
        let prefix = authorId.split(separator: "-").first.map(String.init) ?? authorId
        return AIProvider(rawValue: prefix)?.name ?? authorId
    }

    /// Plain words for one account: Not tested, Connected, or Failed with the reason.
    func status(_ a: AIAccount) -> String {
        _ = keyTick
        if testing.contains(a.id) { return "Testing" }
        guard AIKeys.has(a.id), let r = results[a.id] else { return "Not tested" }
        return r.ok ? "Connected" : "Failed: \(r.reason)"
    }

    // MARK: labels

    private func taken(_ label: String, except id: String?) -> Bool {
        accounts.contains { $0.id != id && $0.label.lowercased() == label.lowercased() }
    }
    /// Labels must be different so a mention points at one account.
    func uniqueLabel(_ wanted: String, provider p: AIProvider, except id: String?) -> String {
        let base = wanted.trimmingCharacters(in: .whitespacesAndNewlines)
        let start = base.isEmpty ? p.name : base
        if !taken(start, except: id) { return start }
        var n = 2
        while taken("\(start) \(n)", except: id) { n += 1 }
        return "\(start) \(n)"
    }
    /// Default label for another account: the provider name plus a number (Claude 2, Gemini 2).
    func nextDefaultLabel(_ p: AIProvider) -> String {
        var n = 2
        while taken("\(p.name) \(n)", except: nil) { n += 1 }
        return "\(p.name) \(n)"
    }

    func rename(_ a: AIAccount, to label: String) {
        guard let i = accounts.firstIndex(where: { $0.id == a.id }) else { return }
        accounts[i].label = uniqueLabel(label, provider: a.kind, except: a.id)
        persist(); keyTick += 1
    }

    // MARK: keys and accounts

    func save(_ key: String, for a: AIAccount) -> Bool {
        let ok = AIKeys.save(key, account: a.id)
        results[a.id] = nil          // a new key has never been tested
        persist(); keyTick += 1
        return ok
    }

    /// Adds another account under a provider, with its own label and key. Returns it, or nil if the key was empty.
    @discardableResult
    func add(provider p: AIProvider, label: String, key: String) -> AIAccount? {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let slug = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).lowercased()
        let acc = AIAccount(id: p.rawValue + "-" + slug, provider: p.rawValue,
                            label: uniqueLabel(label.isEmpty ? nextDefaultLabel(p) : label, provider: p, except: nil))
        guard AIKeys.save(clean, account: acc.id) else { return nil }
        accounts.append(acc)
        persist(); keyTick += 1
        return acc
    }

    /// The first account of a provider only loses its key. Any other account is removed whole.
    func remove(_ a: AIAccount) {
        AIKeys.remove(a.id)
        results[a.id] = nil
        if a.id != a.provider { accounts.removeAll { $0.id == a.id } }
        persist(); keyTick += 1
    }

    func test(_ a: AIAccount) async {
        guard let key = AIKeys.load(a.id) else {
            results[a.id] = nil
            persist(); keyTick += 1
            return
        }
        testing.insert(a.id)
        let outcome = await AIClient.test(a, key: key)
        testing.remove(a.id)
        switch outcome {
        case .success:
            results[a.id] = AITestResult(ok: true, reason: "", at: Date())
        case .failure(let e):
            results[a.id] = AITestResult(ok: false, reason: e.reason, at: Date())
        }
        persist(); keyTick += 1
    }
}
