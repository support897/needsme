import SwiftUI
import FirebaseFirestore

/// The group room engine. It wakes AIs while the room is open. There is no always on
/// server wake in this build, and the app never says there is.
@MainActor
final class RoomEngine: ObservableObject {
    let roomId: String
    let title: String
    private let store: Store

    @Published private(set) var messages: [RoomMessage] = []
    @Published private(set) var pending: [String: RoomMessage] = [:]
    @Published private(set) var working: Set<String> = []
    @Published var fileNote = ""
    @Published private(set) var reading = false

    /// One engine per open room, so a posted prompt never wakes the same room twice.
    static var live: [String: RoomEngine] = [:]
    /// Agents whose current run was cancelled from the Workforce controls (HTML section 11).
    /// A cancelled agent drops the reply it was writing and stays out until the next message.
    static var cancelledAgents: Set<String> = []
    static func isWorking(_ id: String) -> Bool { live.values.contains { $0.working.contains(id) } }
    /// Cancels one agent's run wherever it is working. Returns true when a run was going.
    static func cancelAgent(_ a: AIAccount) -> Bool {
        cancelledAgents.insert(a.id)
        let was = isWorking(a.id)
        if was {
            for e in live.values where e.working.contains(a.id) { e.cancelNote(a.label) }
        }
        return was
    }
    func cancelNote(_ label: String) { note("\(label)'s run was cancelled.") }
    var isBackground = false
    static func retireBackground(_ roomId: String) {
        if let o = live[roomId], o.isBackground { o.close() }
    }

    private var listener: ListenerRegistration?
    private var seen: Set<String> = []
    private var firstSnapshot = true
    private let startedAt = Date()
    private var chain = 0
    private var paused = false
    private var stopped = false
    private var capNoted = false
    private var tasks: [Task<Void, Never>] = []

    init(store: Store, room: RoomItem) {
        self.store = store
        self.roomId = room.id
        self.title = room.title
    }

    /// The project this room filed, if any. Read live from the room record.
    var currentProject: String { store.rooms.first { $0.id == roomId }?.project ?? "" }

    var shown: [RoomMessage] {
        let ids = Set(messages.map { $0.id })
        let extra = pending.values.filter { !ids.contains($0.id) }
            .sorted { ($0.createdAt ?? Date()) < ($1.createdAt ?? Date()) }
        return messages + extra
    }

    func start() {
        if Store.demo {
            messages = Store.demoMessages.map { var x = $0; if x.author == "user" { x.author = store.user?.uid ?? "me" }; return x }
            return
        }
        guard listener == nil, let c = store.roomMessagesCollection(roomId) else { return }
        RoomEngine.live[roomId] = self
        listener = c.order(by: "createdAt").addSnapshotListener { [weak self] snap, err in
            if let err {
                let text = "Could not load the room: \(err.localizedDescription)"
                Task { @MainActor in self?.store.roomError = text }
            }
            guard let snap else { return }
            let items = snap.documents.map { RoomEngine.parse($0) }
            let added = snap.documentChanges.filter { $0.type == .added }.map { RoomEngine.parse($0.document) }
            Task { @MainActor in self?.apply(items, added) }
        }
    }

    func close() {
        if RoomEngine.live[roomId] === self { RoomEngine.live[roomId] = nil }
        listener?.remove(); listener = nil
        for t in tasks { t.cancel() }
        tasks = []
    }

    nonisolated private static func parse(_ d: QueryDocumentSnapshot) -> RoomMessage {
        let x = d.data()
        return RoomMessage(id: d.documentID,
                           author: x["author"] as? String ?? "",
                           text: x["text"] as? String ?? "",
                           needsYou: x["needsYou"] as? Bool ?? false,
                           createdAt: (x["createdAt"] as? Timestamp)?.dateValue())
    }

    private func apply(_ items: [RoomMessage], _ added: [RoomMessage]) {
        messages = items
        for m in items { pending[m.id] = nil }
        if firstSnapshot {
            firstSnapshot = false
            for m in items { seen.insert(m.id) }
            return
        }
        for m in added where !seen.contains(m.id) {
            seen.insert(m.id)
            if m.author == "system" { continue }
            if let t = m.createdAt, t < startedAt { continue }
            handle(m)
        }
    }

    // MARK: sending

    func send(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let uid = store.user?.uid else { return }
        stopped = false; paused = false; chain = 0; capNoted = false
        RoomEngine.cancelledAgents = []
        let m = remember(author: uid, text: t, needsYou: false)
        if let m { handle(m) }
    }

    func stop() {
        stopped = true
        for t in tasks { t.cancel() }
        tasks = []
        working = []
        note("Stopped. Send a message when you want to go on.")
        autoRead()
    }

    /// Writes a message and shows it right away. Returns it, or nil if there is no signed in user.
    @discardableResult
    private func remember(author: String, text: String, needsYou: Bool) -> RoomMessage? {
        guard let id = store.addRoomMessage(roomId: roomId, author: author, text: text, needsYou: needsYou) else { return nil }
        seen.insert(id)
        let m = RoomMessage(id: id, author: author, text: text, needsYou: needsYou, createdAt: Date())
        pending[id] = m
        return m
    }

    private func note(_ text: String) {
        remember(author: "system", text: text, needsYou: false)
    }

    // MARK: waking AIs

    /// Accounts named in the text. A connected account matches by its label with or without the @.
    /// An account without a connection only matches with the @, so plain words raise no noise.
    static func mentions(in text: String, among accounts: [AIAccount], requireAt: Bool) -> [AIAccount] {
        var chars = Array(text.lowercased())
        var out: [AIAccount] = []
        // Longest label first, so "Claude 2" is taken before "Claude".
        for a in accounts.sorted(by: { $0.label.count > $1.label.count }) {
            let needle = Array(a.label.lowercased())
            if needle.isEmpty || needle.count > chars.count { continue }
            var found = false
            var i = 0
            while i + needle.count <= chars.count {
                if Array(chars[i..<(i + needle.count)]) == needle {
                    let before: Character? = i > 0 ? chars[i - 1] : nil
                    let after: Character? = (i + needle.count) < chars.count ? chars[i + needle.count] : nil
                    let hasAt = (before == "@")
                    var leftOK = hasAt || before == nil
                    if let b = before, !hasAt { leftOK = !(b.isLetter || b.isNumber) }
                    var rightOK = after == nil
                    if let f = after { rightOK = !(f.isLetter || f.isNumber) }
                    if leftOK && rightOK && (hasAt || !requireAt) {
                        found = true
                        for k in i..<(i + needle.count) { chars[k] = "#" }
                        if hasAt { chars[i - 1] = "#" }
                        i += needle.count
                        continue
                    }
                }
                i += 1
            }
            if found { out.append(a) }
        }
        return out
    }

    private func handle(_ m: RoomMessage) {
        if stopped || paused { return }
        let conns = AIConnections.shared
        // Per agent controls (section 11): a paused agent, an agent without the rooms tool,
        // or an agent whose run was cancelled does not answer.
        for a in RoomEngine.mentions(in: m.text, among: conns.connected, requireAt: true) where a.id != m.author {
            if store.agentPaused(a.id) { note("\(a.label) is paused, so it did not answer.") }
        }
        var targets: [AIAccount] = []
        for a in RoomEngine.mentions(in: m.text, among: conns.connected, requireAt: false) where a.id != m.author
            && !store.agentPaused(a.id) && store.agentMay(a.id, tool: AgentTool.rooms)
            && !RoomEngine.cancelledAgents.contains(a.id) {
            if chain >= 6 {
                if !capNoted { capNoted = true; note("Six AI turns in a row. The room waits for you now."); autoRead() }
                break
            }
            chain += 1
            targets.append(a)
        }
        let idle = conns.accounts.filter { !conns.isConnected($0) }
        for a in RoomEngine.mentions(in: m.text, among: idle, requireAt: true) where a.id != m.author {
            note("\(a.label) is not connected, so it did not answer.")
        }
        guard !targets.isEmpty else { return }
        let t = Task { [weak self] in
            for a in targets {
                guard let me = self, !Task.isCancelled, !me.stopped, !me.paused else { return }
                await me.turn(a)
            }
        }
        tasks.append(t)
    }

    private func displayName(_ author: String) -> String {
        if author == store.user?.uid { return store.user?.displayName ?? "The user" }
        return AIConnections.shared.displayName(author)
    }

    private func turn(_ a: AIAccount) async {
        if RoomEngine.cancelledAgents.contains(a.id) { return }
        guard let key = AIKeys.load(a.id) else { note("\(a.label) could not answer: no key saved"); return }
        working.insert(a.id)
        defer { working.remove(a.id) }

        let history = Array(shown.filter { $0.author != "system" }.suffix(20))
        let transcript = history.map { "\(displayName($0.author)): \($0.text)" }.joined(separator: "\n")
        var others = [store.user?.displayName ?? "the user"]
        others += AIConnections.shared.connected.filter { $0.id != a.id }.map { $0.label }
        var system = "You are \(a.label), one member of a shared room called \"\(title)\". The other members are: \(others.joined(separator: ", ")). Members can use the same AI maker as you. They are separate voices. Keep replies short and plain. If your reply needs the user's decision, end it with one line of the form NEEDS-YOU: followed by the short decision text."
        let proj = currentProject
        let open = store.openTodos(project: proj)
        if !open.isEmpty {
            let list = open.enumerated().map { "\($0.offset + 1). \($0.element.title)" }.joined(separator: " ")
            system += " Open to dos for the project \"\(proj)\": \(list). When you have finished a to-do from the list, end your reply with one line of the form DONE: followed by the exact to-do words."
        }
        let ask = "Room so far:\n\(transcript)\n\nWrite your next reply as \(a.label)."

        let result = await AIClient.chat(a, key: key, system: system, messages: [ChatMsg(role: "user", text: ask)])
        if stopped || Task.isCancelled { return }
        // Cancelled while it was writing: its reply is dropped, never posted (section 11).
        if RoomEngine.cancelledAgents.contains(a.id) { return }
        switch result {
        case .failure(let e):
            note("\(a.label) could not answer: \(e.reason)")
        case .success(let raw):
            // Cross off: only a DONE line that names an open to do of this room's project is acted on,
            // and only when this agent may file to-dos into that project (its section 11 controls).
            let mayCross = store.agentMay(a.id, tool: AgentTool.file)
                && (proj.isEmpty || store.agentMayFile(a.id, project: proj))
            let (afterDone, crossed) = mayCross ? RoomEngine.splitDone(raw, open: open) : (raw, [])
            for t in crossed { store.markDone(t, by: a.label) }
            let (body, need) = RoomEngine.splitNeed(afterDone)
            let text = body.isEmpty ? (need ?? "") : body
            guard !text.isEmpty, let m = remember(author: a.id, text: text, needsYou: need != nil) else { return }
            if let need {
                // An AI never finalises its own proposal. File it and wait for the user.
                store.addNeed(text: need, ai: a.label, roomId: roomId, messageId: m.id)
                paused = true
                autoRead()
                return
            }
            handle(m)
        }
    }

    // MARK: the loop: detect, file, sync

    /// Connected accounts in label order. The first is asked first. If its read fails, the next is asked.
    /// Paused agents, and agents without the read tool, never read (section 11).
    private func readerAccounts() -> [AIAccount] {
        AIConnections.shared.connected
            .filter { !store.agentPaused($0.id) && store.agentMay($0.id, tool: AgentTool.read) }
            .sorted { $0.label.lowercased() < $1.label.lowercased() }
    }

    /// One read each time a chain settles (cap reached, Needs You pause, Stop). Never two reads at once.
    private func autoRead() { Task { await readTalk(manual: false) } }

    func fileThisTalk() { Task { await readTalk(manual: true) } }

    func showList() {
        let proj = currentProject
        if proj.isEmpty { fileNote = "No project is filed from this room yet."; return }
        postList(project: proj, extraTodo: [], done: [])
    }

    private func postList(project: String, extraTodo: [String], done: [String]) {
        func key(_ t: String) -> String { t.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let doneKeys = Set(done.map { key($0) })
        var titles: [String] = []
        var seenKeys: Set<String> = []
        for t in store.openTodos(project: project).map({ $0.title }) + extraTodo {
            let k = key(t)
            if k.isEmpty || seenKeys.contains(k) || doneKeys.contains(k) { continue }
            seenKeys.insert(k); titles.append(t.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if titles.isEmpty { note("The project \(project) has no open to dos."); return }
        note("Open to dos for \(project):\n" + titles.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
    }

    private func readTalk(manual: Bool) async {
        if reading { return }
        let readers = readerAccounts().filter { AIKeys.load($0.id) != nil }
        guard !readers.isEmpty else {
            if manual { fileNote = "No AI is connected yet, so nothing can be filed. Connect one in the Connect screen." }
            return
        }
        let history = Array(shown.filter { $0.author != "system" }.suffix(50))
        guard !history.isEmpty else {
            if manual { fileNote = ""; note("Nothing clear to file from this talk yet.") }
            return
        }
        reading = true
        defer { reading = false }
        fileNote = manual ? "Reading this talk." : ""
        let transcript = history.map { "\(displayName($0.author)): \($0.text)" }.joined(separator: "\n")
        let system = "You read a room conversation and report only what it clearly states. Never invent. Never guess. Answer with JSON only, no other words, in exactly this shape: {\"project\": string or null, \"done\": [strings], \"todo\": [strings]}. project is the name of the project the talk is about, or null if no project is clearly named. done lists work the talk clearly says is finished. todo lists work the talk clearly says is still to do. Use short plain words taken from the talk."
        let ask = "Room: \(title)\n\nTalk:\n\(transcript)"
        // Fall through: ask each connected account in turn. Only a failed call moves on to the next one.
        var firstFailure: (label: String, reason: String)? = nil
        var answer: (reader: AIAccount, raw: String)? = nil
        for r in readers {
            guard let key = AIKeys.load(r.id) else { continue }
            let result = await AIClient.chat(r, key: key, system: system, messages: [ChatMsg(role: "user", text: ask)], maxTokens: 800)
            switch result {
            case .failure(let e):
                if firstFailure == nil { firstFailure = (r.label, e.reason) }
            case .success(let raw):
                answer = (r, raw)
            }
            if answer != nil { break }
        }
        guard let got = answer else {
            fileNote = ""
            let f = firstFailure
            note("\(f?.label ?? "An AI") could not read the talk: \(f?.reason ?? "no answer"). No other connected AI could read it either.")
            return
        }
        let reader = got.reader
        guard let found = RoomEngine.parseReader(got.raw) else {
            fileNote = ""
            note("Nothing clear to file from this talk yet.")
            return
        }
        // The reader's own controls bind what it may file (section 11): no file tool, no filing;
        // a project outside its scope, no filing into it. Both say so in the room, plainly.
        guard store.agentMay(reader.id, tool: AgentTool.file) else {
            fileNote = ""
            note("\(reader.label) read the talk, but filing to-dos is switched off for it, so nothing was filed.")
            return
        }
        guard store.agentMayFile(reader.id, project: found.project) else {
            fileNote = ""
            note("\(reader.label) is not allowed to file into \(found.project), so nothing was filed.")
            return
        }
        let name = store.fileFromTalk(project: found.project, done: found.done, todo: found.todo, room: title, by: reader.label)
        store.setRoomProject(roomId: roomId, project: name)
        fileNote = "Filed under \(name)."
        postList(project: name, extraTodo: found.todo, done: found.done)
    }

    /// Strict: the reply must be one JSON object. A null or empty project, or two empty lists, files nothing.
    static func parseReader(_ raw: String) -> (project: String, done: [String], todo: [String])? {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            var lines = t.components(separatedBy: "\n")
            if !lines.isEmpty { lines.removeFirst() }
            if let last = lines.last, last.trimmingCharacters(in: .whitespaces).hasPrefix("```") { lines.removeLast() }
            t = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard t.hasPrefix("{"), t.hasSuffix("}"), let data = t.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let project = (obj["project"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        func list(_ k: String) -> [String] {
            ((obj[k] as? [Any]) ?? []).compactMap { $0 as? String }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        let done = list("done"), todo = list("todo")
        if project.isEmpty || (done.isEmpty && todo.isEmpty) { return nil }
        return (project, done, todo)
    }

    /// Strips a DONE line only when it names an open to do exactly (trimmed, any letter case).
    /// Any other DONE line stays as ordinary text.
    static func splitDone(_ raw: String, open: [TaskItem]) -> (String, [TaskItem]) {
        var kept: [String] = []
        var matched: [TaskItem] = []
        for line in raw.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.lowercased().hasPrefix("done:") {
                let words = String(t.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if let task = open.first(where: { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == words }),
                   !matched.contains(where: { $0.id == task.id }) {
                    matched.append(task)
                    continue
                }
            }
            kept.append(line)
        }
        return (kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines), matched)
    }

    /// Strips every NEEDS-YOU line from a reply and returns the decision text, if any.
    static func splitNeed(_ raw: String) -> (String, String?) {
        let token = "needs-you:"
        var kept: [String] = []
        var need: String?
        for line in raw.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.lowercased().hasPrefix(token) {
                need = String(t.dropFirst(token.count)).trimmingCharacters(in: .whitespaces)
            } else { kept.append(line) }
        }
        if let n = need, n.isEmpty { need = nil }
        return (kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines), need)
    }
}

// MARK: screens

struct RoomsListView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @ObservedObject private var conns = AIConnections.shared
    @State private var asking = false
    @State private var title = ""
    @State private var projectFilter = ""
    @State private var roomToDelete: RoomItem?
    @State private var searching = false
    @State private var query = ""

    var shownRooms: [RoomItem] {
        let byProject = projectFilter.isEmpty ? store.rooms : store.rooms.filter { $0.project == projectFilter }
        return query.isEmpty ? byProject : byProject.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
    func openNeed(_ r: RoomItem) -> NeedItem? { store.needs.first { $0.roomId == r.id && $0.status == "open" } }
    var needRooms: Int { Set(store.needs.filter { $0.status == "open" }.map { $0.roomId }).count }

    func faceState(_ a: AIAccount, _ r: RoomItem) -> FaceState {
        if let n = openNeed(r), n.ai == a.label { return .needs }
        if RoomEngine.isWorking(a.id) { return .working }
        return .none
    }

    func roomCard(_ r: RoomItem) -> some View {
        let n = openNeed(r)
        let accts = conns.connected
        let working = accts.first { RoomEngine.isWorking($0.id) }
        let state = n != nil ? "needs" : (working != nil ? "work" : "done")
        let line: String = {
            if let n { return "\(n.ai) asks: \(n.text)" }
            if let w = working { return "\(w.label) is working now." }
            if accts.isEmpty { return "No AI is connected yet." }
            return "Everything handled. Pip is pleased."
        }()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                NavigationLink { RoomView(room: r, store: store) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.title).font(.system(size: 16, weight: .bold)).foregroundColor(.loam)
                        if !r.project.isEmpty { Text(r.project).font(.system(size: 11.5)).foregroundColor(.muted) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).accessibilityIdentifier("room-" + r.title)
                if state == "needs" { CountPill(text: "needs you") }
                if state == "work" { CountPill(text: "working", light: true) }
                if state == "done" { Text("all clear").font(.system(size: 12, weight: .heavy)).padding(.horizontal, 10).padding(.vertical, 4).background(Color(hex: 0xE6DFCF)).foregroundColor(.muted).clipShape(Capsule()) }
                Button { roomToDelete = r } label: {
                    Image(systemName: "trash").font(.system(size: 14)).foregroundColor(.faint).frame(width: 36, height: 36).contentShape(Rectangle())
                }.accessibilityLabel("Delete room \(r.title)").accessibilityIdentifier("deleteRoom-" + r.title)
            }
            HStack(spacing: 14) {
                if !accts.isEmpty {
                    HStack(spacing: -9) {
                        ForEach(accts) { a in AIFace(label: a.label, size: 34, state: faceState(a, r)).overlay(Circle().stroke(Color.cardTone, lineWidth: 2)) }
                    }
                }
                Text(line).font(.system(size: 13)).foregroundColor(Color(hex: 0x4A4235)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14).background(Color.cardTone).clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.loam.opacity(0.07), radius: 12, y: 6)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(conns.connected.count) of your AIs talking, \(store.rooms.count) rooms").font(.system(size: 12.5)).foregroundColor(.muted)
                HStack(spacing: 12) {
                    PipArt(pose: .welcome, height: 54)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(needRooms > 0 ? (needRooms == 1 ? "1 room needs you" : "\(needRooms) rooms need you") : "All your rooms are calm").font(.system(size: 14.5, weight: .bold)).foregroundColor(.loam)
                        Text("One room for all your AIs. Mention an AI with its name to ask it.").font(.system(size: 12)).foregroundColor(.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(LinearGradient(colors: [.sproutPale, .bone], startPoint: .leading, endPoint: .trailing)).clipShape(RoundedRectangle(cornerRadius: 24))
                Text("An AI that is not connected never takes part.").font(.system(size: 12)).foregroundColor(.muted)
                Button("New group chat") { title = ""; asking = true }
                    .buttonStyle(PrimaryButton()).accessibilityIdentifier("newRoom")
                if searching { TextField("Search rooms", text: $query).textFieldStyle(.roundedBorder).accessibilityIdentifier("roomSearch") }
                if !store.projects.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            filterChip("All projects", projectFilter.isEmpty) { projectFilter = "" }
                            ForEach(store.projects, id: \.self) { name in
                                filterChip(name, projectFilter == name) { projectFilter = name }
                            }
                        }
                    }
                }
                if shownRooms.isEmpty {
                    Text(store.rooms.isEmpty ? "No rooms yet." : "No rooms for this project yet.").foregroundColor(.muted).accessibilityIdentifier("noRooms")
                }
                ForEach(shownRooms) { r in roomCard(r) }
                if !store.roomError.isEmpty {
                    Text(store.roomError).font(.footnote).foregroundColor(.muted).accessibilityIdentifier("roomError")
                }
            }.padding(.horizontal, 18).padding(.bottom, 12)
        }
        .lookBg().navigationTitle("Rooms")
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { SearchIconButton(on: $searching) } }
        .alert("Name your room", isPresented: $asking) {
            TextField("Room name", text: $title)
            Button("Create") {
                let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                _ = store.createRoom(t.isEmpty ? "My room" : t)
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete this room?", isPresented: Binding(get: { roomToDelete != nil }, set: { if !$0 { roomToDelete = nil } })) {
            Button("Delete the room", role: .destructive) {
                if let r = roomToDelete { store.deleteRoom(r) }
                roomToDelete = nil
            }
            Button("Keep it", role: .cancel) { roomToDelete = nil }
        } message: {
            Text("The room and its messages are removed. This cannot be undone.")
        }
    }

    func filterChip(_ t: String, _ on: Bool, _ a: @escaping () -> Void) -> some View {
        Button(t, action: a).font(.subheadline.bold()).padding(.horizontal, 14).padding(.vertical, 8).frame(minHeight: 44)
            .background(on ? Color.loam : Color.cardTone).foregroundColor(on ? Color.bone : Color.loam).clipShape(Capsule())
    }
}

struct RoomView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @ObservedObject private var conns = AIConnections.shared
    @StateObject private var engine: RoomEngine
    @State private var draft = ""

    init(room: RoomItem, store: Store) {
        _engine = StateObject(wrappedValue: RoomEngine(store: store, room: room))
    }

    /// Who is in this room, and its project when one is filed. Only connected AIs are named:
    /// a disconnected AI is never shown as taking part (HTML section 12).
    var participantsLine: String {
        var s = "In this room: " + (["You"] + conns.connected.map { $0.label + (store.agentPaused($0.id) ? " (paused)" : "") }).joined(separator: ", ")
        let proj = store.rooms.first { $0.id == engine.roomId }?.project ?? ""
        if !proj.isEmpty { s += " · Project: " + proj }
        return s
    }
    var tasksMade: Int { store.tasks.filter { $0.sourceRoom == engine.title }.count }

    func faceInfo(_ a: AIAccount) -> (FaceState, String) {
        if engine.working.contains(a.id) { return (.working, "writing now") }
        if store.agentPaused(a.id) { return (.none, "paused") }
        if store.needs.contains(where: { $0.roomId == engine.roomId && $0.status == "open" && $0.ai == a.label }) { return (.needs, "needs you") }
        return (.none, "listening")
    }

    var facesCard: some View {
        HStack {
            if conns.connected.isEmpty {
                Text("No AI is connected yet.").font(.system(size: 13)).foregroundColor(.muted).padding(.vertical, 8)
            }
            ForEach(conns.connected) { a in
                let info = faceInfo(a)
                VStack(spacing: 6) {
                    AIFace(label: a.label, size: 46, state: info.0)
                    Text(a.label).font(.system(size: 12, weight: .bold)).foregroundColor(.loam)
                    Text(info.1).font(.system(size: 11)).foregroundColor(.muted)
                }.frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 12).background(Color.cardTone).clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.loam.opacity(0.07), radius: 10, y: 5)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                facesCard
            }.padding(.horizontal, 18).padding(.top, 4)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(engine.shown) { m in bubble(m).id(m.id) }
                        ForEach(Array(engine.working).sorted(), id: \.self) { id in
                            Text("\(conns.displayName(id)) is writing").font(.footnote).foregroundColor(.muted)
                        }
                        Text("AIs answer while this room is open.")
                            .font(.footnote).foregroundColor(.muted).accessibilityIdentifier("roomNote")
                        Text(participantsLine)
                            .font(.footnote).foregroundColor(.muted).accessibilityIdentifier("roomParticipants")
                        loopBar
                        chipsBar
                    }.padding(.horizontal, 18).padding(.vertical, 12)
                }
                .onChange(of: engine.shown.count) { _ in
                    if let last = engine.shown.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            if !store.roomError.isEmpty {
                Text(store.roomError).font(.footnote).foregroundColor(.muted).padding(.horizontal)
                    .accessibilityIdentifier("roomError")
            }
            composer
        }
        .lookBg().navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(engine.title).font(.system(size: 17, weight: .bold)).foregroundColor(.loam)
                    Text("\(conns.connected.count) AIs here · \(tasksMade) tasks made").font(.system(size: 12)).foregroundColor(.muted)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) { PipArt(pose: .welcome, height: 34) }
        }
        .onAppear { RoomEngine.retireBackground(engine.roomId); engine.start() }
        .onDisappear { engine.close() }
        .hidesTabBar()
    }

    @ViewBuilder func bubble(_ m: RoomMessage) -> some View {
        if m.author == "system" {
            systemCard(m.text)
        } else {
            let mine = m.author == store.user?.uid
            if mine {
                HStack { Spacer(minLength: 60)
                    Text(m.text).font(.system(size: 14)).foregroundColor(.bone).padding(.horizontal, 14).padding(.vertical, 11)
                        .background(Color.loam).clipShape(BubbleShape(tl: 20, tr: 6, bl: 20, br: 20))
                }
            } else {
                HStack(alignment: .bottom, spacing: 10) {
                    AIFace(label: conns.displayName(m.author), size: 34)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(conns.displayName(m.author)).font(.system(size: 11, weight: .bold)).foregroundColor(.muted)
                        Text(m.text).font(.system(size: 14)).foregroundColor(.loam)
                        if m.needsYou {
                            Text("Needs you").font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.sproutPale).clipShape(Capsule()).foregroundColor(.loam)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(Color.cardTone).clipShape(BubbleShape(tl: 6, tr: 20, bl: 20, br: 20))
                    .shadow(color: Color.loam.opacity(0.06), radius: 6, y: 3)
                    Spacer(minLength: 40)
                }
            }
        }
    }

    @ViewBuilder func systemCard(_ text: String) -> some View {
        let parts = text.split(separator: "\n", maxSplits: 1).map(String.init)
        let made = parts.count == 2 && (parts[0].hasPrefix("Task made") || parts[0].hasPrefix("Note made"))
        if made {
            HStack(spacing: 10) {
                Image(systemName: parts[0].hasPrefix("Task") ? "sparkle" : "doc.text").foregroundColor(.loam)
                VStack(alignment: .leading, spacing: 1) {
                    Text(parts[0]).font(.system(size: 12.5, weight: .bold)).foregroundColor(.loam)
                    Text(parts[1]).font(.system(size: 12.5)).foregroundColor(.muted)
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(LinearGradient(colors: [.sproutPale, .bone], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sprout, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            .padding(.leading, 44)
        } else {
            Text(text).font(.footnote).foregroundColor(.muted).frame(maxWidth: .infinity, alignment: .center)
        }
    }

    var loopBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button { engine.fileThisTalk() } label: {
                    Label("File this talk", systemImage: "sparkle").font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.bordered).tint(.loam).disabled(engine.reading)
                .accessibilityIdentifier("fileTalk")
                Button("Show the list") { engine.showList() }
                    .font(.system(size: 13, weight: .semibold))
                    .buttonStyle(.bordered).tint(.loam)
                    .accessibilityIdentifier("showList")
            }
            if !engine.fileNote.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "sparkle").foregroundColor(.loam)
                    Text(engine.fileNote).font(.system(size: 12.5, weight: .semibold)).foregroundColor(.loam).accessibilityIdentifier("fileNote")
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(LinearGradient(colors: [.sproutPale, .bone], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.sprout, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.vertical, 6)
    }

    var chipsBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if conns.connected.isEmpty {
                Text("No AI is connected yet. Add a key in the Connect screen, then mention it here.")
                    .font(.footnote).foregroundColor(.muted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(conns.connected) { a in
                            Button("@" + a.label) { draft += (draft.isEmpty || draft.hasSuffix(" ") ? "" : " ") + "@" + a.label + " " }
                                .buttonStyle(.bordered).tint(.loam).accessibilityIdentifier("chip-" + a.id)
                        }
                    }
                }
            }
        }
    }

    var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Say something to your AIs", text: $draft, axis: .vertical)
                    .lineLimit(1...4).padding(.leading, 12)
                    .accessibilityIdentifier("roomComposer")
                if !engine.working.isEmpty {
                    Button("Stop") { engine.stop() }.buttonStyle(.bordered).tint(.loam).accessibilityIdentifier("roomStop")
                }
                Button {
                    let t = draft; draft = ""; engine.send(t)
                } label: {
                    Image(systemName: "paperplane").font(.system(size: 18, weight: .semibold)).foregroundColor(.loam)
                        .frame(width: 42, height: 42).background(Color.sprout).clipShape(Circle())
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                .accessibilityLabel("Send")
                .accessibilityIdentifier("roomSend")
            }
            .padding(.horizontal, 8).padding(.vertical, 7).background(Color.cardTone).clipShape(RoundedRectangle(cornerRadius: 30))
            .shadow(color: Color.loam.opacity(0.14), radius: 14, y: 8)
        }
        .padding(.horizontal, 14).padding(.top, 6).padding(.bottom, 8)
    }
}
