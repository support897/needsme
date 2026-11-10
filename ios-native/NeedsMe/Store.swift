import Foundation
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

struct TaskItem: Identifiable {
    let id: String; var title: String; var status: String; var dueOn: String; var area: String
    // Source and cross off stamps. Filled when the app filed the task from a room, or an AI crossed it off.
    var sourceRoom = ""; var sourceDate = ""; var sourceBy = ""; var doneBy = ""; var doneDate = ""
    var isDone: Bool { status == "done" }
    var isOverdue: Bool { !isDone && !dueOn.isEmpty && dueOn < Store.today }
    /// Small plain words under the task. Empty for hand filed tasks.
    var stamp: String {
        var parts: [String] = []
        if !sourceRoom.isEmpty {
            parts.append("From the room \(sourceRoom) on \(Store.niceDate(sourceDate)), read by \(sourceBy)")
        }
        if isDone, !doneBy.isEmpty, doneBy != "user" {
            parts.append("Done by \(doneBy) on \(Store.niceDate(doneDate))")
        }
        return parts.joined(separator: ". ")
    }
}
struct RoomItem: Identifiable { let id: String; var title: String; var project: String = "" }
struct RoomMessage: Identifiable { let id: String; var author: String; var text: String; var needsYou: Bool; var createdAt: Date? }
struct NeedItem: Identifiable { let id: String; var text: String; var ai: String; var roomId: String; var status: String }
struct NoteItem: Identifiable {
    let id: String; var title: String; var body: String; var project: String; var ai: String; var isPrompt: Bool
    /// Project names (a project is its name in this app). A note can hold several, a prompt holds at most one.
    var projects: [String] = []
    var archived = false
    var autoProject = ""; var autoBy = ""; var autoWords = ""; var projectFixed = false
    // Prompts only: target room, state ("scheduled" or "sent"; older prompts have none), and times.
    var room = ""; var roomTitle = ""; var state = ""
    var scheduledFor: Date? = nil; var sentAt: Date? = nil
    /// Small plain words saying what decided the project.
    var stamp: String {
        if projectFixed { return "Project set by you." }
        if !autoBy.isEmpty && !autoProject.isEmpty { return "Matched to \(autoProject) by \(autoBy). Words used: \(autoWords)" }
        return ""
    }
}

@MainActor
final class Store: ObservableObject {
    @Published var user: User?
    @Published var tasks: [TaskItem] = []
    @Published var notes: [NoteItem] = []
    @Published var rooms: [RoomItem] = []
    @Published var needs: [NeedItem] = []
    @Published var roomError = ""
    /// Her saved colour pick, from users/{uid}/settings/app. Nil until one is saved.
    @Published var cloudTheme: String?
    @Published var cloudThemeLoaded = false
    /// Her saved name, from the same settings record (users/{uid}/settings/app, field name).
    @Published var cloudName: String?
    /// The name every greeting uses: her saved name, then the sign in name, then nobody (nil).
    var savedName: String? {
        let c = (cloudName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !c.isEmpty { return c }
        let a = (user?.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return a.isEmpty ? nil : a
    }
    var greetingName: String { savedName ?? "friend" }
    @Published var message = ""
    @Published var busy = false
    private var handles: [ListenerRegistration] = []
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var ticker: Timer?
    private var firing: Set<String> = []
    private lazy var db: Firestore = { FirebaseBoot.ensure(); return Firestore.firestore() }()

    nonisolated static var today: String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date()) }

    init() {
        FirebaseBoot.ensure()
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, u in
            Task { @MainActor in self?.user = u; self?.listen() }
        }
        startScheduler()
    }

    var projects: [String] {
        Array(Set(tasks.map { $0.area }.filter { !$0.isEmpty } + notes.flatMap { $0.projects })).sorted()
    }
    func progress(_ p: String) -> (done: Int, total: Int) {
        let t = tasks.filter { $0.area == p }; return (t.filter { $0.isDone }.count, t.count)
    }

    private func col(_ n: String) -> CollectionReference? {
        guard let u = user else { return nil }
        return db.collection("users").document(u.uid).collection(n)
    }
    private func listen() {
        handles.forEach { $0.remove() }; handles = []; tasks = []; notes = []; rooms = []; needs = []
        cloudTheme = nil; cloudThemeLoaded = false; cloudName = nil
        guard user != nil else { return }
        if let c = col("settings") {
            handles.append(c.document("app").addSnapshotListener { [weak self] snap, _ in
                guard let snap else { return }
                let raw = snap.data()?["theme"] as? String
                Task { @MainActor in
                    guard let me = self else { return }
                    me.cloudName = snap.data()?["name"] as? String
                    me.cloudTheme = raw.map { AppTheme.from($0).rawValue }
                    me.cloudThemeLoaded = true
                    // An old Soft Green value moves to Brand in her space too.
                    if raw == "green" { me.saveTheme(AppTheme.brand.rawValue) }
                }
            })
        }
        if let c = col("tasks") {
            handles.append(c.addSnapshotListener { [weak self] s, e in
                if let e { Task { @MainActor in self?.message = "Could not load your tasks: \(e.localizedDescription)" } }
                guard let s else { return }
                let items = s.documents.map { d -> TaskItem in
                    let x = d.data()
                    return TaskItem(id: d.documentID, title: x["title"] as? String ?? "", status: x["status"] as? String ?? "", dueOn: x["due_on"] as? String ?? "", area: x["area"] as? String ?? "",
                                    sourceRoom: x["source_room"] as? String ?? "", sourceDate: x["source_date"] as? String ?? "", sourceBy: x["source_by"] as? String ?? "",
                                    doneBy: x["done_by"] as? String ?? "", doneDate: x["done_date"] as? String ?? "")
                }
                Task { @MainActor in self?.tasks = items }
            })
        }
        if let c = col("rooms") {
            handles.append(c.order(by: "createdAt").addSnapshotListener { [weak self] s, e in
                if let e { Task { @MainActor in self?.roomError = "Could not load rooms: \(e.localizedDescription)" } }
                guard let s else { return }
                let items = s.documents.map { d in RoomItem(id: d.documentID, title: d.data()["title"] as? String ?? "Room", project: d.data()["project"] as? String ?? "") }
                Task { @MainActor in self?.rooms = items }
            })
        }
        if let c = col("needs") {
            handles.append(c.addSnapshotListener { [weak self] s, e in
                if let e { Task { @MainActor in self?.roomError = "Could not load needs: \(e.localizedDescription)" } }
                guard let s else { return }
                let items = s.documents.map { d -> NeedItem in
                    let x = d.data()
                    return NeedItem(id: d.documentID, text: x["text"] as? String ?? "", ai: x["ai"] as? String ?? "", roomId: x["roomId"] as? String ?? "", status: x["status"] as? String ?? "open")
                }
                Task { @MainActor in self?.needs = items }
            })
        }
        var prompts: [NoteItem] = [], plain: [NoteItem] = []
        func merge(_ me: Store?) { me?.notes = (plain + prompts).sorted { $0.title.lowercased() < $1.title.lowercased() } }
        for (name, isPrompt) in [("notes", false), ("prompts", true)] {
            guard let c = col(name) else { continue }
            handles.append(c.addSnapshotListener { [weak self] s, _ in
                guard let s else { return }
                let items = s.documents.map { d -> NoteItem in
                    let x = d.data()
                    let proj = x["project"] as? String ?? ""
                    let fallback: [String] = (proj.isEmpty || proj == "Unsorted") ? [] : [proj]
                    let plist: [String] = (x["projects"] as? [String]) ?? fallback
                    return NoteItem(id: d.documentID, title: x["title"] as? String ?? "", body: x["body"] as? String ?? "",
                                    project: plist.first ?? "Unsorted", ai: x["ai"] as? String ?? "", isPrompt: isPrompt,
                                    projects: plist, archived: x["archived"] as? Bool ?? false,
                                    autoProject: x["autoProject"] as? String ?? "", autoBy: x["autoBy"] as? String ?? "",
                                    autoWords: x["autoWords"] as? String ?? "", projectFixed: x["projectFixed"] as? Bool ?? false,
                                    room: x["room"] as? String ?? "", roomTitle: x["roomTitle"] as? String ?? "", state: x["state"] as? String ?? "",
                                    scheduledFor: (x["scheduledFor"] as? Timestamp)?.dateValue(), sentAt: (x["sentAt"] as? Timestamp)?.dateValue())
                }
                Task { @MainActor in
                    if isPrompt { prompts = items } else { plain = items }
                    merge(self)
                }
            })
        }
    }

    // MARK: auth
    func signIn(_ e: String, _ p: String) async { await run { _ = try await Auth.auth().signIn(withEmail: e, password: p) } }
    func signUp(_ e: String, _ p: String) async { await run { _ = try await Auth.auth().createUser(withEmail: e, password: p) } }
    func reset(_ e: String) async { await run { try await Auth.auth().sendPasswordReset(withEmail: e); self.message = "Reset email sent." } }
    func guest() async { await run { _ = try await Auth.auth().signInAnonymously() } }
    // Apple door: real flow. Finishes only when Apple is enabled in Firebase (parked).
    private var nonce = ""
    func prepareApple(_ r: ASAuthorizationAppleIDRequest) {
        nonce = Store.randomNonce()
        r.requestedScopes = [.fullName, .email]
        r.nonce = Store.sha256(nonce)
    }
    func finishApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let e):
            if (e as NSError).code == ASAuthorizationError.canceled.rawValue { message = "Apple sign-in was cancelled."; return }
            message = "Apple sign-in did not finish. Try email for now."
        case .success(let auth):
            guard let c = auth.credential as? ASAuthorizationAppleIDCredential, let t = c.identityToken, let id = String(data: t, encoding: .utf8) else { message = "Apple sent nothing back. Try again."; return }
            let cred = OAuthProvider.appleCredential(withIDToken: id, rawNonce: nonce, fullName: c.fullName)
            await run { _ = try await Auth.auth().signIn(with: cred) }
        }
    }
    private var googleProvider: OAuthProvider?
    func googleDoor() async {
        let prov = OAuthProvider(providerID: "google.com")
        prov.scopes = ["email", "profile"]
        googleProvider = prov
        await run {
            let cred: AuthCredential = try await withCheckedThrowingContinuation { cont in
                prov.getCredentialWith(nil) { c, e in
                    if let c = c { cont.resume(returning: c) } else { cont.resume(throwing: e ?? NSError(domain: "nm", code: 1)) }
                }
            }
            _ = try await Auth.auth().signIn(with: cred)
        }
    }
    static func randomNonce(_ n: Int = 32) -> String {
        let cs = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<n).map { _ in cs[Int.random(in: 0..<cs.count)] })
    }
    static func sha256(_ s: String) -> String { SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined() }
    func signOut() { try? Auth.auth().signOut() }
    @Published var deleteMessage = ""
    func deleteAccount() async {
        guard let u = Auth.auth().currentUser else { return }
        deleteMessage = "Deleting..."
        do {
            if let rc = col("rooms") {
                for r in try await rc.getDocuments().documents {
                    for m in try await r.reference.collection("messages").getDocuments().documents { try await m.reference.delete() }
                    try await r.reference.delete()
                }
            }
            for name in ["tasks", "notes", "prompts", "needs", "settings"] {
                if let c = col(name) {
                    let snap = try await c.getDocuments()
                    for d in snap.documents { try await d.reference.delete() }
                }
            }
            try await u.delete()
            deleteMessage = ""
            try? Auth.auth().signOut()
        } catch {
            let code = (error as NSError).code
            deleteMessage = code == AuthErrorCode.requiresRecentLogin.rawValue
                ? "For safety, please sign out, sign in again, then delete your account right away. Your tasks and notes were removed."
                : "Could not delete: \(error.localizedDescription)"
        }
    }
    private func run(_ f: @escaping () async throws -> Void) async {
        message = ""; busy = true; defer { busy = false }
        do { try await f() } catch { message = error.localizedDescription }
    }

    // MARK: colour pick, saved on the device (AppStorage) and in her own space
    func saveTheme(_ raw: String) {
        col("settings")?.document("app").setData(["theme": raw, "updatedAt": FieldValue.serverTimestamp()], merge: true)
    }

    /// Saves her name in both places: the sign in profile (displayName) and her own space.
    func saveName(_ raw: String) {
        let n = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, let u = user else { return }
        cloudName = n
        col("settings")?.document("app").setData(["name": n, "updatedAt": FieldValue.serverTimestamp()], merge: true)
        Task {
            do {
                let change = u.createProfileChangeRequest()
                change.displayName = n
                try await change.commitChanges()
                self.user = Auth.auth().currentUser
            } catch {
                self.message = "Your name is saved in your space, but not on your sign in: \(error.localizedDescription)"
            }
        }
    }

    // MARK: data
    func addTask(_ title: String, area: String, due: String) {
        col("tasks")?.addDocument(data: ["title": title, "area": area, "due_on": due, "status": "waiting", "created": FieldValue.serverTimestamp()]) { [weak self] err in
            if let err { Task { @MainActor in self?.message = "Could not save your task: \(err.localizedDescription)" } }
        }
    }
    func toggle(_ t: TaskItem) {
        col("tasks")?.document(t.id).updateData(["status": t.isDone ? "waiting" : "done", "done_date": t.isDone ? "" : Store.today, "done_by": "user"])
    }
    func deleteTask(_ t: TaskItem) { col("tasks")?.document(t.id).delete() }
    /// Notes and prompts are one shape in Firestore under users/{uid}/notes and users/{uid}/prompts.
    /// There is no delete for a note anywhere in the app. Archive is the only way out of sight.
    @discardableResult
    func saveNote(id: String?, title: String, body: String, isPrompt: Bool, extra: [String: Any] = [:]) -> String? {
        guard let c = col(isPrompt ? "prompts" : "notes") else { return nil }
        let now = FieldValue.serverTimestamp()
        var d: [String: Any] = ["title": title, "body": body, "updatedAt": now]
        for (k, v) in extra { d[k] = v }
        if let id { c.document(id).setData(d, merge: true); return id }
        let ref = c.document()
        d["createdAt"] = now; d["version"] = 1; d["archived"] = false
        if d["project"] == nil { d["project"] = "Unsorted" }
        if d["projects"] == nil { d["projects"] = [String]() }
        if d["ai"] == nil { d["ai"] = "Any AI" }
        ref.setData(d) { [weak self] err in
            if let err { Task { @MainActor in self?.message = "Could not save: \(err.localizedDescription)" } }
        }
        return ref.documentID
    }

    func setArchived(_ n: NoteItem, _ on: Bool) {
        col(n.isPrompt ? "prompts" : "notes")?.document(n.id).updateData(["archived": on])
    }

    // MARK: project for notes and prompts: her pick always wins

    func setProjects(_ n: NoteItem, _ list: [String]) {
        col(n.isPrompt ? "prompts" : "notes")?.document(n.id).updateData([
            "projects": list, "project": list.first ?? "Unsorted", "projectFixed": true,
            "autoProject": "", "autoBy": "", "autoWords": ""])
    }
    func toggleProject(_ n: NoteItem, _ name: String) {
        if n.isPrompt { setProjects(n, n.projects.contains(name) ? [] : [name]); return }
        setProjects(n, n.projects.contains(name) ? n.projects.filter { $0 != name } : n.projects + [name])
    }

    /// The app finds the project itself. The first connected account reads the item and may only pick one of her
    /// existing projects. Nothing clear means no project. Her own pick is never overwritten.
    func autoMatch(id: String, isPrompt: Bool, title: String, body: String) {
        let names = projects
        guard !names.isEmpty,
              let reader = AIConnections.shared.connected.sorted(by: { $0.label.lowercased() < $1.label.lowercased() }).first,
              let key = AIKeys.load(reader.id) else { return }
        let system = "You file one note or prompt into the user's existing projects. Use only what is clearly stated. Never invent. Never guess. Answer with JSON only, no other words, in exactly this shape: {\"project\": string or null, \"words\": string}. project must be exactly one name from this list, or null: " + names.joined(separator: " | ") + ". words is the few words from the item that made you choose it."
        let ask = "Title: \(title)\n\nText: \(String(body.prefix(2000)))"
        Task {
            let result = await AIClient.chat(reader, key: key, system: system, messages: [ChatMsg(role: "user", text: ask)], maxTokens: 150)
            guard case .success(let raw) = result, let hit = Store.parseMatch(raw, names: names) else { return }
            guard let cur = self.notes.first(where: { $0.id == id && $0.isPrompt == isPrompt }), !cur.projectFixed,
                  cur.projects.isEmpty || !cur.autoBy.isEmpty else { return }
            var list = cur.projects.filter { $0 != cur.autoProject }
            if isPrompt { list = [] }
            if !list.contains(hit.project) { list.append(hit.project) }
            self.col(isPrompt ? "prompts" : "notes")?.document(id).updateData([
                "projects": list, "project": list.first ?? "Unsorted",
                "autoProject": hit.project, "autoBy": reader.label, "autoWords": hit.words])
        }
    }

    /// Strict: one JSON object, the project must be one of her projects, and the words must be there.
    nonisolated static func parseMatch(_ raw: String, names: [String]) -> (project: String, words: String)? {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            var lines = t.components(separatedBy: "\n")
            if !lines.isEmpty { lines.removeFirst() }
            if let last = lines.last, last.trimmingCharacters(in: .whitespaces).hasPrefix("```") { lines.removeLast() }
            t = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard t.hasPrefix("{"), t.hasSuffix("}"), let data = t.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let p = (obj["project"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty,
              let name = names.first(where: { $0.lowercased() == p.lowercased() }) else { return nil }
        let words = (obj["words"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if words.isEmpty { return nil }
        return (name, String(words.prefix(80)))
    }

    // MARK: prompts: send now, or schedule for an exact time while the app is open

    /// Saves a prompt. Send now posts it to its room at once and marks it Sent. Otherwise it is Scheduled for the time.
    func savePrompt(id: String?, title: String, body: String, room: RoomItem?, sendNow: Bool, at: Date) {
        var extra: [String: Any] = ["room": room?.id ?? "", "roomTitle": room?.title ?? ""]
        if sendNow { extra["state"] = "sent"; extra["sentAt"] = Timestamp(date: Date()) }
        else { extra["state"] = "scheduled"; extra["scheduledFor"] = Timestamp(date: at) }
        let newId = saveNote(id: id, title: title, body: body, isPrompt: true, extra: extra)
        if sendNow, let room { PromptSender.post(store: self, roomId: room.id, text: body) }
        if let newId { autoMatch(id: newId, isPrompt: true, title: title, body: body) }
    }

    /// One tap on a saved prompt that has a room.
    func sendPromptNow(_ n: NoteItem) {
        guard n.isPrompt, !n.room.isEmpty, n.state != "sent" else { return }
        col("prompts")?.document(n.id).updateData(["state": "sent", "sentAt": Timestamp(date: Date())])
        PromptSender.post(store: self, roomId: n.room, text: n.body)
    }

    nonisolated static func niceTime(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy HH:mm"; return f.string(from: d)
    }

    private func startScheduler() {
        guard ticker == nil else { return }
        ticker = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickScheduler() }
        }
    }
    /// Fires every due prompt once. It only runs while the app is open.
    private func tickScheduler() {
        guard user != nil else { return }
        let now = Date()
        for n in notes where n.isPrompt && n.state == "scheduled" && !firing.contains(n.id) {
            guard let at = n.scheduledFor, at <= now, !n.room.isEmpty, rooms.contains(where: { $0.id == n.room }) else { continue }
            firing.insert(n.id)
            let sent = Date()
            col("prompts")?.document(n.id).updateData(["state": "sent", "sentAt": Timestamp(date: sent)])
            PromptSender.post(store: self, roomId: n.room, text: n.body)
            _ = addRoomMessage(roomId: n.room, author: "system",
                               text: "Scheduled prompt \(n.title). Set for \(Store.niceTime(at)). Sent at \(Store.niceTime(sent)).")
        }
    }

    // MARK: the loop (detect, file, sync, cross off). One task store: the tasks collection.
    nonisolated static func niceDate(_ s: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: s) else { return s }
        let o = DateFormatter(); o.dateFormat = "d MMM yyyy"
        return o.string(from: d)
    }

    /// An existing project of that name (any letter case) wins. Otherwise the name is new.
    func canonicalProject(_ name: String) -> String {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return projects.first { $0.lowercased() == n.lowercased() } ?? n
    }

    func openTodos(project: String) -> [TaskItem] {
        let k = project.lowercased()
        return tasks.filter { !$0.isDone && !project.isEmpty && $0.area.lowercased() == k }
    }

    /// Files what the reader found. Done lines become completed tasks, to do lines become open tasks,
    /// all under the project, in the one tasks collection. A line that already exists is not filed twice.
    /// Returns the project name used.
    @discardableResult
    func fileFromTalk(project: String, done: [String], todo: [String], room: String, by: String) -> String {
        let name = canonicalProject(project)
        guard let c = col("tasks") else { return name }
        let inProject = tasks.filter { $0.area.lowercased() == name.lowercased() }
        func key(_ t: String) -> String { t.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        var seenNew: Set<String> = []
        for line in done {
            let k = key(line); if k.isEmpty || seenNew.contains(k) { continue }
            seenNew.insert(k)
            if let open = inProject.first(where: { !$0.isDone && key($0.title) == k }) {
                markDone(open, by: by); continue
            }
            if inProject.contains(where: { $0.isDone && key($0.title) == k }) { continue }
            c.addDocument(data: stampedTask(line, area: name, status: "done", room: room, by: by)) { [weak self] err in
                if let err { Task { @MainActor in self?.message = "Could not save your task: \(err.localizedDescription)" } }
            }
        }
        for line in todo {
            let k = key(line); if k.isEmpty || seenNew.contains(k) { continue }
            seenNew.insert(k)
            if inProject.contains(where: { key($0.title) == k }) { continue }
            c.addDocument(data: stampedTask(line, area: name, status: "waiting", room: room, by: by)) { [weak self] err in
                if let err { Task { @MainActor in self?.message = "Could not save your task: \(err.localizedDescription)" } }
            }
        }
        return name
    }

    private func stampedTask(_ title: String, area: String, status: String, room: String, by: String) -> [String: Any] {
        var d: [String: Any] = ["title": title.trimmingCharacters(in: .whitespacesAndNewlines), "area": area, "due_on": "", "status": status,
                                "created": FieldValue.serverTimestamp(),
                                "source_room": room, "source_date": Store.today, "source_by": by]
        if status == "done" { d["done_date"] = Store.today; d["done_by"] = by }
        return d
    }

    /// An AI crosses a task off. Same record the Tasks list and the project list read.
    func markDone(_ t: TaskItem, by label: String) {
        col("tasks")?.document(t.id).updateData(["status": "done", "done_date": Store.today, "done_by": label])
    }

    func setRoomProject(roomId: String, project: String) {
        col("rooms")?.document(roomId).updateData(["project": project])
    }

    // MARK: rooms (every write stays inside users/{uid}/)
    func roomMessagesCollection(_ roomId: String) -> CollectionReference? {
        col("rooms")?.document(roomId).collection("messages")
    }
    func createRoom(_ title: String) -> String? {
        guard let c = col("rooms") else { return nil }
        let ref = c.document()
        ref.setData(["title": title, "createdAt": FieldValue.serverTimestamp()]) { [weak self] err in
            if let err { Task { @MainActor in self?.roomError = "Could not save the room: \(err.localizedDescription)" } }
        }
        return ref.documentID
    }
    /// Writes one message and returns its id right away. Author is the uid, an AI id, or "system".
    func addRoomMessage(roomId: String, author: String, text: String, needsYou: Bool = false) -> String? {
        guard let c = roomMessagesCollection(roomId) else { return nil }
        let ref = c.document()
        ref.setData(["author": author, "text": text, "needsYou": needsYou, "createdAt": FieldValue.serverTimestamp()]) { [weak self] err in
            if let err { Task { @MainActor in self?.roomError = "Could not save to the room: \(err.localizedDescription)" } }
        }
        return ref.documentID
    }
    func addNeed(text: String, ai: String, roomId: String) {
        col("needs")?.addDocument(data: ["text": text, "ai": ai, "roomId": roomId, "source": "room", "status": "open", "createdAt": FieldValue.serverTimestamp()]) { [weak self] err in
            if let err { Task { @MainActor in self?.roomError = "Could not save the need: \(err.localizedDescription)" } }
        }
    }
    func resolveNeed(_ n: NeedItem) { col("needs")?.document(n.id).updateData(["status": "done"]) }

    /// Plain-text copy of every note and prompt, for the Privacy and data screen.
    var exportText: String {
        notes.map { "# \($0.title)\n(\($0.isPrompt ? "Prompt" : "Note") · \($0.project) · \($0.ai))\n\n\($0.body)\n" }.joined(separator: "\n---\n\n")
    }
}
