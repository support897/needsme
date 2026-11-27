import SwiftUI

/// Which AI accounts work on which project. Saved on this phone.
enum ProjectAIs {
    private static let k = "needsme.projectAIs"
    static func ids(_ project: String) -> [String] {
        ((UserDefaults.standard.dictionary(forKey: k) as? [String: [String]]) ?? [:])[project] ?? []
    }
    static func set(_ project: String, _ v: [String]) {
        var d = (UserDefaults.standard.dictionary(forKey: k) as? [String: [String]]) ?? [:]
        d[project] = v
        UserDefaults.standard.set(d, forKey: k)
    }
}

/// "AIs on this project": add or remove AIs with one tap.
struct ProjectAIPanel: View {
    let project: String
    @Environment(\.palette) var p
    @ObservedObject private var conns = AIConnections.shared
    @State private var ids: [String] = []
    var members: [AIAccount] { ids.compactMap { conns.account($0) } }
    var body: some View {
        Card {
            HStack {
                Text("AIs on this project").font(.headline).foregroundColor(p.ink)
                Spacer()
                Menu {
                    if conns.connected.isEmpty { Text("Sign in to an AI first, in the AIs tab") }
                    ForEach(conns.connected) { a in
                        Button { toggle(a) } label: { Label(a.label, systemImage: ids.contains(a.id) ? "checkmark" : "plus") }
                    }
                } label: { Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundColor(.loam)
                    .frame(width: 32, height: 32).background(Color.sprout).clipShape(Circle()) }
                    .accessibilityIdentifier("projectAddAI")
            }
            if members.isEmpty {
                Text("None yet. Tap plus to choose which AIs help here.").font(.subheadline).foregroundColor(p.soft)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(members) { a in
                            HStack(spacing: 6) {
                                AIFace(label: a.label, size: 24, state: .none)
                                Text(a.label).font(.system(size: 13, weight: .semibold)).foregroundColor(p.ink)
                            }.padding(.horizontal, 10).padding(.vertical, 6).background(p.chip).clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .onAppear { ids = ProjectAIs.ids(project) }
    }
    func toggle(_ a: AIAccount) {
        if let i = ids.firstIndex(of: a.id) { ids.remove(at: i) } else { ids.append(a.id) }
        ProjectAIs.set(project, ids)
    }
}

/// Hand one to-do to an AI. It does it, or asks a question. You can answer, or tick it yourself.
struct AskAISheet: View {
    let task: TaskItem
    let project: String
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var conns = AIConnections.shared
    @State private var pick: AIAccount?
    @State private var busy = false
    @State private var answer = ""
    @State private var question = ""
    @State private var reply = ""
    @State private var finished = false
    @State private var error = ""

    var choices: [AIAccount] {
        let mine = ProjectAIs.ids(project).compactMap { conns.account($0) }.filter { conns.isConnected($0) }
        return mine.isEmpty ? conns.connected : mine
    }

    func run(_ extra: String?) async {
        guard let a = pick ?? choices.first, let key = AIKeys.load(a.id) else { error = "Sign in to an AI first."; return }
        busy = true; error = ""
        let open = store.openTodos(project: project)
        var system = "You are \(a.label), working on the project \"\(project)\" for the user. Keep replies short and plain. If you need the user to decide something, end with one line: NEEDS-YOU: followed by your question. When the to-do is finished, end with one line: DONE: followed by the exact to-do words."
        if !open.isEmpty { system += " Open to-dos: " + open.map { $0.title }.joined(separator: "; ") + "." }
        var msgs = [ChatMsg(role: "user", text: "Please do this to-do: \(task.title)")]
        if let extra, !reply.isEmpty {
            msgs.append(ChatMsg(role: "assistant", text: reply))
            msgs.append(ChatMsg(role: "user", text: extra))
        }
        let r = await AIClient.chat(a, key: key, system: system, messages: msgs, maxTokens: 700)
        busy = false
        switch r {
        case .failure(let e): error = "Could not get an answer: " + e.reason
        case .success(let raw):
            reply = raw
            question = ""
            var shown: [String] = []
            for line in raw.components(separatedBy: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.uppercased().hasPrefix("NEEDS-YOU:") { question = String(t.dropFirst(10)).trimmingCharacters(in: .whitespaces) }
                else if t.uppercased().hasPrefix("DONE:") { finished = true }
                else { shown.append(line) }
            }
            if finished { store.markDone(task, by: a.label) }
            reply = shown.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Card {
                        Text(task.title).font(.headline).foregroundColor(p.ink)
                        Text("Project: \(project)").font(.subheadline).foregroundColor(p.soft)
                    }
                    if choices.isEmpty {
                        Text("No AI is signed in yet. Open the AIs tab and sign in to one.").foregroundColor(p.soft)
                    } else {
                        HStack {
                            Text("Ask").foregroundColor(p.soft)
                            Menu {
                                ForEach(choices) { a in Button(a.label) { pick = a } }
                            } label: {
                                Text((pick ?? choices.first)?.label ?? "").font(.system(size: 15, weight: .bold)).foregroundColor(p.ink)
                                    .padding(.horizontal, 14).padding(.vertical, 8).background(p.chip).clipShape(Capsule())
                            }
                        }
                        if reply.isEmpty && !busy {
                            Button { Task { await run(nil) } } label: { Text("Send to AI") }.buttonStyle(PrimaryButton()).accessibilityIdentifier("askSend")
                        }
                    }
                    if busy { HStack { ProgressView(); Text("Working. This can take a minute.").foregroundColor(p.soft) } }
                    if !error.isEmpty { Text(error).font(.footnote).foregroundColor(p.soft) }
                    if !reply.isEmpty {
                        Card { Text(reply).foregroundColor(p.ink).textSelection(.enabled) }
                    }
                    if finished { Text("Done. Ticked off for you.").font(.headline).foregroundColor(.sprout) }
                    if !question.isEmpty && !finished {
                        Card {
                            Text("The AI asks:").font(.subheadline.weight(.semibold)).foregroundColor(p.soft)
                            Text(question).foregroundColor(p.ink)
                            TextField("Your answer", text: $answer).textFieldStyle(.roundedBorder)
                            Button { let a = answer; answer = ""; Task { await run(a) } } label: { Text("Answer") }
                                .buttonStyle(PrimaryButton()).disabled(answer.isEmpty || busy)
                        }
                    }
                    if !task.isDone && !finished {
                        Button("Tick it off myself") { store.toggle(task); dismiss() }.buttonStyle(SoftButton())
                    }
                }.padding()
            }
            .lookBg().navigationTitle("Ask an AI").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}
