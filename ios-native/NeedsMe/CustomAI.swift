import SwiftUI

/// A model the user adds by hand: any service with an OpenAI-style API (Together, Fireworks, Cerebras, Ollama behind https, and so on).
struct CustomAI: Codable, Identifiable {
    var id: String      // the account id, for example custom-a1b2c3
    var base: String    // for example https://api.together.xyz/v1
    var model: String
}

enum CustomAIStore {
    private static let k = "nm_custom_ais"
    static func all() -> [CustomAI] {
        guard let d = UserDefaults.standard.data(forKey: k), let a = try? JSONDecoder().decode([CustomAI].self, from: d) else { return [] }
        return a
    }
    static func get(_ id: String) -> CustomAI? { all().first { $0.id == id } }
    static func put(_ c: CustomAI) {
        var a = all().filter { $0.id != c.id }; a.append(c)
        if let d = try? JSONEncoder().encode(a) { UserDefaults.standard.set(d, forKey: k) }
    }
    static func drop(_ id: String) {
        if let d = try? JSONEncoder().encode(all().filter { $0.id != id }) { UserDefaults.standard.set(d, forKey: k) }
    }
    /// Only https. Strips a pasted /chat/completions end and trailing slashes. Returns nil when it is not a usable address.
    static func cleanBase(_ s: String) -> String? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.lowercased().hasPrefix("https://"), URL(string: t)?.host != nil else { return nil }
        if t.lowercased().hasSuffix("/chat/completions") { t = String(t.dropLast("/chat/completions".count)) }
        while t.hasSuffix("/") { t.removeLast() }
        return t
    }
}

struct CustomPreset: Identifiable {
    var id: String { name }
    let name: String, base: String, model: String, keyPage: String
}

/// Any other model: name, address, model name and key. Same room voice as the built-in AIs.
struct CustomModelCard: View {
    @Environment(\.palette) var p
    @Environment(\.openURL) var openURL
    @ObservedObject private var conns = AIConnections.shared
    @State private var name = ""
    @State private var base = ""
    @State private var model = ""
    @State private var key = ""
    @State private var note = ""
    @State private var picked: CustomPreset? = nil

    static let presets: [CustomPreset] = [
        CustomPreset(name: "Together", base: "https://api.together.xyz/v1", model: "meta-llama/Llama-3.3-70B-Instruct-Turbo", keyPage: "https://api.together.ai/settings/api-keys"),
        CustomPreset(name: "Fireworks", base: "https://api.fireworks.ai/inference/v1", model: "accounts/fireworks/models/llama-v3p3-70b-instruct", keyPage: "https://fireworks.ai/account/api-keys"),
        CustomPreset(name: "Cerebras", base: "https://api.cerebras.ai/v1", model: "llama3.1-8b", keyPage: "https://cloud.cerebras.ai"),
        CustomPreset(name: "Ollama", base: "https://YOUR-ADDRESS/v1", model: "llama3.2", keyPage: "https://ollama.com/blog/openai-compatibility"),
    ]
    var mine: [AIAccount] { conns.accounts.filter { $0.provider == "custom" } }

    func field(_ ph: String, _ t: Binding<String>, secure: Bool = false) -> some View {
        Group { if secure { SecureField(ph, text: t) } else { TextField(ph, text: t) } }
            .autocorrectionDisabled().textInputAutocapitalization(.never)
            .padding(10).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.line, lineWidth: 1))
            .foregroundColor(p.ink)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PipSays(text: "Any service that talks like OpenAI can join. You need 4 things: a name, its address, its model name and your key.")
            Text("1. Tap your service to fill the address.").font(.subheadline.bold()).foregroundColor(p.ink)
            HStack(spacing: 8) {
                ForEach(CustomModelCard.presets) { pr in
                    Button(pr.name) { picked = pr; base = pr.base; model = pr.model; if name.isEmpty { name = pr.name } }
                        .buttonStyle(SoftButton()).accessibilityIdentifier("customPreset-" + pr.name)
                }
            }
            if let pr = picked {
                Button { if let u = URL(string: pr.keyPage) { openURL(u) } } label: { Label("Get a \(pr.name) key", systemImage: "key.fill") }
                    .buttonStyle(SoftButton()).accessibilityIdentifier("customGetKey")
            }
            Text("2. Check the four boxes.").font(.subheadline.bold()).foregroundColor(p.ink)
            field("Name in rooms (for example Llama)", $name).accessibilityIdentifier("customName")
            field("Address, starts with https://", $base).accessibilityIdentifier("customBase")
            field("Model name (copy it from the service)", $model).accessibilityIdentifier("customModel")
            field("Your key (any word if it has none)", $key, secure: true).accessibilityIdentifier("customKey")
            Text("The address is the part before /chat/completions. Only https works on iPhone. Ollama on your own computer needs an https address, for example from a tunnel.")
                .font(.caption).foregroundColor(p.soft)
            Button {
                if CustomAIStore.cleanBase(base) == nil { note = "The address must start with https://"; return }
                if model.trimmingCharacters(in: .whitespaces).isEmpty { note = "Add the model name."; return }
                if key.trimmingCharacters(in: .whitespaces).isEmpty { note = "Paste your key."; return }
                if let a = conns.addCustom(label: name, base: base, model: model, key: key) {
                    note = "Saved. Testing..."; name = ""; base = ""; model = ""; key = ""; picked = nil
                    Task { await conns.test(a); note = conns.status(a) == "Connected" ? "Connected. Use @\(a.label) in a room." : "Not connected yet: " + conns.status(a) }
                } else { note = "Could not save. Check the boxes." }
            } label: { Label("Save and test", systemImage: "checkmark.seal.fill") }
                .buttonStyle(PrimaryButton()).accessibilityIdentifier("customSave")
            if !note.isEmpty { Text(note).font(.footnote.weight(.semibold)).foregroundColor(p.ink).accessibilityIdentifier("customNote") }
            ForEach(mine) { a in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.label).font(.headline).foregroundColor(p.ink)
                        Text((CustomAIStore.get(a.id)?.model ?? "") + " at " + (URL(string: CustomAIStore.get(a.id)?.base ?? "")?.host ?? "")).font(.caption).foregroundColor(p.soft)
                    }
                    Spacer()
                    Text(conns.status(a)).font(.caption.bold()).foregroundColor(p.ink).accessibilityIdentifier("status-" + a.id)
                }
                HStack(spacing: 8) {
                    Button("Test") { Task { await conns.test(a) } }.buttonStyle(SoftButton()).accessibilityIdentifier("testKey-" + a.id)
                    Button("Remove") { CustomAIStore.drop(a.id); conns.remove(a) }.buttonStyle(SoftButton()).accessibilityIdentifier("removeKey-" + a.id)
                }
            }
        }
    }
}
