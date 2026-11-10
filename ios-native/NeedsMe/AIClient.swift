import Foundation

struct AIError: Error {
    var reason: String
    var modelRejected = false
}

struct ChatMsg {
    var role: String   // "user" or "assistant"
    var text: String
}

/// One chat call per provider, using the user's own saved key.
/// Returns the reply text or a short plain reason. No raw status dumps reach the screen.
enum AIClient {
    static let timeout: TimeInterval = 30

    // MARK: models

    static func defaultModel(_ p: AIProvider) -> String {
        switch p {
        case .chatgpt: return "gpt-4o-mini"
        case .claude: return "claude-haiku-4-5"
        case .gemini: return "gemini-2.5-flash"
        case .perplexity: return "sonar"
        case .grok: return "grok-4-1-fast-non-reasoning"
        }
    }
    private static func pickKey(_ p: AIProvider) -> String { "nm_ai_model_" + p.rawValue }
    static func model(_ p: AIProvider) -> String {
        UserDefaults.standard.string(forKey: pickKey(p)) ?? defaultModel(p)
    }

    // MARK: test connection (one real call)

    /// Calls take the account: its provider, its key and its label.
    static func test(_ a: AIAccount, key: String) async -> Result<Void, AIError> {
        await test(a.kind, key: key)
    }

    static func chat(_ a: AIAccount, key: String, system: String, messages: [ChatMsg], maxTokens: Int = 400) async -> Result<String, AIError> {
        await chat(a.kind, key: key, system: system, messages: messages, maxTokens: maxTokens)
    }

    static func test(_ p: AIProvider, key: String) async -> Result<Void, AIError> {
        switch p {
        case .perplexity:
            let r = await send(p, key: key, model: model(p), system: "", messages: [ChatMsg(role: "user", text: "Hi")], maxTokens: 1)
            if case .failure(let e) = r, e.modelRejected {
                return .failure(AIError(reason: "model not found"))
            }
            return r.map { _ in Void() }
        default:
            guard let req = listRequest(p, key: key) else { return .failure(AIError(reason: "could not start")) }
            switch await run(req) {
            case .failure(let e): return .failure(AIError(reason: e.reason))
            case .success: return .success(Void())
            }
        }
    }

    private static func listRequest(_ p: AIProvider, key: String) -> URLRequest? {
        var url: String
        switch p {
        case .chatgpt: url = "https://api.openai.com/v1/models"
        case .claude: url = "https://api.anthropic.com/v1/models"
        case .gemini: url = "https://generativelanguage.googleapis.com/v1beta/models"
        case .grok: url = "https://api.x.ai/v1/models"
        case .perplexity: return nil
        }
        guard let u = URL(string: url) else { return nil }
        var r = URLRequest(url: u)
        r.httpMethod = "GET"
        r.timeoutInterval = timeout
        switch p {
        case .chatgpt, .grok: r.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        case .claude:
            r.setValue(key, forHTTPHeaderField: "x-api-key")
            r.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .gemini: r.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        case .perplexity: break
        }
        return r
    }

    // MARK: chat

    /// Sends the messages and returns the reply text. Retries once with the cheapest
    /// listed chat model if the model name is not accepted. Never loops.
    static func chat(_ p: AIProvider, key: String, system: String, messages: [ChatMsg], maxTokens: Int = 400) async -> Result<String, AIError> {
        let msgs = normalise(messages)
        let first = await send(p, key: key, model: model(p), system: system, messages: msgs, maxTokens: maxTokens)
        guard case .failure(let e) = first, e.modelRejected else { return first }
        guard let pick = await cheapestModel(p, key: key), pick != model(p) else {
            return .failure(AIError(reason: "model not found"))
        }
        UserDefaults.standard.set(pick, forKey: pickKey(p))
        return await send(p, key: key, model: pick, system: system, messages: msgs, maxTokens: maxTokens)
    }

    /// Roles must start with user and alternate. Merge runs of the same role.
    private static func normalise(_ m: [ChatMsg]) -> [ChatMsg] {
        var out: [ChatMsg] = []
        for x in m where !x.text.isEmpty {
            if let last = out.last, last.role == x.role {
                out[out.count - 1].text += "\n\n" + x.text
            } else { out.append(x) }
        }
        while let f = out.first, f.role != "user" { out.removeFirst() }
        return out
    }

    private static func send(_ p: AIProvider, key: String, model: String, system: String, messages: [ChatMsg], maxTokens: Int) async -> Result<String, AIError> {
        var urlString: String
        var body: [String: Any]
        switch p {
        case .chatgpt, .grok, .perplexity:
            urlString = p == .chatgpt ? "https://api.openai.com/v1/chat/completions"
                : p == .grok ? "https://api.x.ai/v1/chat/completions"
                : "https://api.perplexity.ai/chat/completions"
            var list: [[String: String]] = []
            if !system.isEmpty { list.append(["role": "system", "content": system]) }
            for m in messages { list.append(["role": m.role, "content": m.text]) }
            body = ["model": model, "messages": list]
            if p == .perplexity { body["max_tokens"] = maxTokens }
        case .claude:
            urlString = "https://api.anthropic.com/v1/messages"
            var list: [[String: String]] = []
            for m in messages { list.append(["role": m.role, "content": m.text]) }
            body = ["model": model, "max_tokens": maxTokens, "messages": list]
            if !system.isEmpty { body["system"] = system }
        case .gemini:
            urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
            var contents: [[String: Any]] = []
            for m in messages {
                let role: String = m.role == "assistant" ? "model" : "user"
                let parts: [[String: String]] = [["text": m.text]]
                contents.append(["role": role, "parts": parts])
            }
            body = ["contents": contents]
            if !system.isEmpty {
                let sysParts: [[String: String]] = [["text": system]]
                body["systemInstruction"] = ["parts": sysParts]
            }
        }
        guard let url = URL(string: urlString),
              let data = try? JSONSerialization.data(withJSONObject: body) else {
            return .failure(AIError(reason: "could not start"))
        }
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.httpBody = data
        r.timeoutInterval = timeout
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        switch p {
        case .chatgpt, .grok, .perplexity: r.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        case .claude:
            r.setValue(key, forHTTPHeaderField: "x-api-key")
            r.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .gemini: r.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        }
        switch await run(r) {
        case .failure(let e): return .failure(e)
        case .success(let d):
            if let t = extractText(p, d), !t.isEmpty { return .success(t) }
            return .failure(AIError(reason: "empty answer"))
        }
    }

    private static func extractText(_ p: AIProvider, _ d: Data) -> String? {
        guard let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        switch p {
        case .chatgpt, .grok, .perplexity:
            let c = (j["choices"] as? [[String: Any]])?.first
            return ((c?["message"] as? [String: Any])?["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        case .claude:
            let parts = (j["content"] as? [[String: Any]]) ?? []
            return parts.compactMap { $0["text"] as? String }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        case .gemini:
            let c = (j["candidates"] as? [[String: Any]])?.first
            let parts = ((c?["content"] as? [String: Any])?["parts"] as? [[String: Any]]) ?? []
            return parts.compactMap { $0["text"] as? String }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: model fallback

    private static func cheapestModel(_ p: AIProvider, key: String) async -> String? {
        guard let req = listRequest(p, key: key) else { return nil }
        guard case .success(let d) = await run(req),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        var ids: [String] = []
        if p == .gemini {
            for m in (j["models"] as? [[String: Any]]) ?? [] {
                let methods = (m["supportedGenerationMethods"] as? [String]) ?? []
                if methods.contains("generateContent"), let n = m["name"] as? String {
                    ids.append(n.replacingOccurrences(of: "models/", with: ""))
                }
            }
        } else {
            ids = ((j["data"] as? [[String: Any]]) ?? []).compactMap { $0["id"] as? String }
        }
        let chatty = ids.filter { id in
            let l = id.lowercased()
            return !["embedding", "embed", "image", "audio", "tts", "whisper", "moderation", "realtime", "transcribe", "vision", "imagen", "veo", "aqa"].contains { l.contains($0) }
        }
        let prefs: [String]
        switch p {
        case .chatgpt: prefs = ["nano", "mini"]
        case .claude: prefs = ["haiku"]
        case .gemini: prefs = ["flash-lite", "flash"]
        case .grok: prefs = ["mini", "fast"]
        case .perplexity: prefs = ["sonar"]
        }
        for w in prefs {
            if let hit = chatty.filter({ $0.lowercased().contains(w) }).sorted().first { return hit }
        }
        return chatty.sorted().first
    }

    // MARK: transport and plain errors

    private static func run(_ r: URLRequest) async -> Result<Data, AIError> {
        do {
            let (data, resp) = try await URLSession.shared.data(for: r)
            guard let h = resp as? HTTPURLResponse else { return .failure(AIError(reason: "no answer")) }
            if (200..<300).contains(h.statusCode) { return .success(data) }
            return .failure(plain(h.statusCode, data))
        } catch let e as URLError {
            switch e.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return .failure(AIError(reason: "no network"))
            case .timedOut:
                return .failure(AIError(reason: "timed out after 30 seconds"))
            default:
                return .failure(AIError(reason: "could not reach the service"))
            }
        } catch {
            return .failure(AIError(reason: "could not reach the service"))
        }
    }

    private static func plain(_ code: Int, _ data: Data) -> AIError {
        let body = (String(data: data, encoding: .utf8) ?? "").lowercased()
        if body.contains("insufficient_quota") || body.contains("billing") || body.contains("credit balance") || body.contains("exceeded your current quota") || body.contains("out of credits") {
            return AIError(reason: "account needs billing")
        }
        if code == 402 { return AIError(reason: "account needs billing") }
        if code == 401 || code == 403 || body.contains("api key not valid") || body.contains("api_key_invalid") || body.contains("invalid x-api-key") || body.contains("incorrect api key") {
            return AIError(reason: "key not accepted")
        }
        let modelWords = ["model_not_found", "does not exist", "not found", "not supported", "invalid model", "decommissioned", "deprecated", "unknown model", "not a valid model"]
        if (code == 404 || code == 400) && body.contains("model") && modelWords.contains(where: { body.contains($0) }) {
            return AIError(reason: "model not accepted", modelRejected: true)
        }
        if code == 404 { return AIError(reason: "model not accepted", modelRejected: true) }
        if code == 429 { return AIError(reason: "too many calls, try again soon") }
        if code >= 500 { return AIError(reason: "the service is busy, try again") }
        return AIError(reason: "the service said no")
    }
}
