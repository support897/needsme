import Foundation
import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

/// One line of a task's checklist (HTML section 9). Stored on the task record itself.
struct CheckItem: Equatable {
    var text: String; var done: Bool
}

struct TaskItem: Identifiable {
    let id: String; var title: String; var status: String; var dueOn: String; var area: String
    /// When the record was written (the "created" stamp every task write already carries). Read only.
    var createdAt: Date? = nil
    /// The task detail's own records (HTML section 9): its checklist lines, and the ids of
    /// the tasks it waits on. Both ride on the task document; empty until someone writes them.
    var checklist: [CheckItem] = []
    var dependsOn: [String] = []
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
/// A picture kept with a note (HTML section 10). The bytes ride a document under the note,
/// in her own space — the same store as every other record she holds.
struct NoteAttachment: Identifiable {
    let id: String; var name: String; var data: Data; var createdAt: Date?
}

/// One AI worker's controls (HTML section 11): paused, the projects it may file into and the
/// tools it may use. An empty projects list means every project; an empty tools list means
/// every tool — the shape the app has always run with until she changes it.
struct AgentControl: Equatable {
    var paused = false; var projects: [String] = []; var tools: [String] = []
}

/// The tools an agent's controls switch (HTML sections 11 and 13 capabilities).
enum AgentTool {
    static let rooms = "rooms", read = "read", file = "file"
    static let all: [(id: String, name: String)] = [(rooms, "Answer in rooms"), (read, "Read talks and notes"), (file, "File to-dos")]
}

/// A device that has signed in to her account (HTML section 15). Lives in her settings space.
struct DeviceRecord: Identifiable {
    let id: String; var name: String; var model: String; var system: String
    var firstSeen: Date?; var lastSeen: Date?
}

struct RoomItem: Identifiable { let id: String; var title: String; var project: String = "" }
struct RoomMessage: Identifiable { let id: String; var author: String; var text: String; var needsYou: Bool; var createdAt: Date? }
struct NeedItem: Identifiable { let id: String; var text: String; var ai: String; var roomId: String; var status: String; var messageId: String = "" }
struct NoteItem: Identifiable {
    let id: String; var title: String; var body: String; var project: String; var ai: String; var isPrompt: Bool
    /// Project names (a project is its name in this app). A note can hold several, a prompt holds at most one.
    var projects: [String] = []
    var archived = false
    /// When the record was first written and last changed (stamps saveNote already writes). Read only.
    var createdAt: Date? = nil; var updatedAt: Date? = nil
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
    /// The kindness offer (main-round item 8): stands after a task is finished,
    /// on whichever task surface the person is standing on. It belongs to the
    /// act of finishing, not to one screen, so it lives here and not in a view.
    @Published var kindnessOffer = false
    @Published var notes: [NoteItem] = []
    @Published var rooms: [RoomItem] = []
    @Published var needs: [NeedItem] = []
    /// Pictures kept with notes, by note id (HTML section 10).
    @Published var noteImages: [String: [NoteAttachment]] = [:]
    private var attHandles: [String: ListenerRegistration] = [:]
    /// Per agent controls, by account id (HTML section 11), from users/{uid}/settings/agents.
    @Published var agentControls: [String: AgentControl] = [:]
    /// Devices that have signed in (HTML section 15), newest seen first.
    @Published var devices: [DeviceRecord] = []
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
    // Relay registry: one sync write per sign in, once both lists have arrived from the server.
    private var roomsFresh = false
    private var promptsFresh = false
    private var registrySynced = false
    private var firing: Set<String> = []
    private lazy var db: Firestore = { FirebaseBoot.ensure(); return Firestore.firestore() }()

    nonisolated static var today: String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date()) }

    init() {
        FirebaseBoot.ensure()
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, u in
            Task { @MainActor in
                self?.user = u; self?.listen()
                if u != nil { Task { await self?.fileUnfiledNeeds() } }
            }
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
        attHandles.values.forEach { $0.remove() }; attHandles = [:]; noteImages = [:]
        agentControls = [:]; devices = []
        cloudTheme = nil; cloudThemeLoaded = false; cloudName = nil
        roomsFresh = false; promptsFresh = false; registrySynced = false
        guard user != nil else { return }
        registerDevice()
        if let c = col("settings") {
            handles.append(c.addSnapshotListener { [weak self] s, _ in
                guard let s else { return }
                var controls: [String: AgentControl] = [:]
                var devs: [DeviceRecord] = []
                for d in s.documents {
                    let x = d.data()
                    if d.documentID == "agents" {
                        for (k, v) in x {
                            guard let m = v as? [String: Any] else { continue }
                            controls[k] = AgentControl(paused: m["paused"] as? Bool ?? false,
                                                       projects: m["projects"] as? [String] ?? [],
                                                       tools: m["tools"] as? [String] ?? [])
                        }
                    } else if d.documentID.hasPrefix("device-") {
                        devs.append(DeviceRecord(id: d.documentID, name: x["name"] as? String ?? "",
                                                 model: x["model"] as? String ?? "", system: x["system"] as? String ?? "",
                                                 firstSeen: (x["firstSeen"] as? Timestamp)?.dateValue(),
                                                 lastSeen: (x["lastSeen"] as? Timestamp)?.dateValue()))
                    }
                }
                devs.sort { ($0.lastSeen ?? .distantPast) > ($1.lastSeen ?? .distantPast) }
                Task { @MainActor in self?.agentControls = controls; self?.devices = devs }
            })
        }
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
                    let checks = ((x["checklist"] as? [[String: Any]]) ?? []).map {
                        CheckItem(text: $0["text"] as? String ?? "", done: $0["done"] as? Bool ?? false)
                    }
                    return TaskItem(id: d.documentID, title: x["title"] as? String ?? "", status: x["status"] as? String ?? "", dueOn: x["due_on"] as? String ?? "", area: x["area"] as? String ?? "",
                                    createdAt: (x["created"] as? Timestamp)?.dateValue(),
                                    checklist: checks, dependsOn: x["dependsOn"] as? [String] ?? [],
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
                let fresh = !s.metadata.isFromCache
                Task { @MainActor in
                    self?.rooms = items
                    if fresh { self?.roomsFresh = true; self?.syncRegistryOnce() }
                }
            })
        }
        if let c = col("needs") {
            handles.append(c.addSnapshotListener { [weak self] s, e in
                if let e { Task { @MainActor in self?.roomError = "Could not load needs: \(e.localizedDescription)" } }
                guard let s else { return }
                let items = s.documents.map { d -> NeedItem in
                    let x = d.data()
                    return NeedItem(id: d.documentID, text: x["text"] as? String ?? "", ai: x["ai"] as? String ?? "", roomId: x["roomId"] as? String ?? "", status: x["status"] as? String ?? "open", messageId: x["messageId"] as? String ?? "")
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
                                    createdAt: (x["createdAt"] as? Timestamp)?.dateValue(), updatedAt: (x["updatedAt"] as? Timestamp)?.dateValue(),
                                    autoProject: x["autoProject"] as? String ?? "", autoBy: x["autoBy"] as? String ?? "",
                                    autoWords: x["autoWords"] as? String ?? "", projectFixed: x["projectFixed"] as? Bool ?? false,
                                    room: x["room"] as? String ?? "", roomTitle: x["roomTitle"] as? String ?? "", state: x["state"] as? String ?? "",
                                    scheduledFor: (x["scheduledFor"] as? Timestamp)?.dateValue(), sentAt: (x["sentAt"] as? Timestamp)?.dateValue())
                }
                let fresh = !s.metadata.isFromCache
                Task { @MainActor in
                    if isPrompt { prompts = items } else { plain = items }
                    merge(self)
                    if isPrompt && fresh { self?.promptsFresh = true; self?.syncRegistryOnce() }
                }
            })
        }
    }

    // MARK: auth
    func signIn(_ e: String, _ p: String) async { await run { _ = try await Auth.auth().signIn(withEmail: e, password: p) } }
    /// Sign up. On a network error only, try once more with the same values. If that retry says the address is
    /// already in use, the first try landed, so go on to sign in with the same credentials. Any other retry
    /// outcome is the same as a single try. No retry anywhere else.
    func signUp(_ e: String, _ p: String) async {
        await run {
            do {
                _ = try await Auth.auth().createUser(withEmail: e, password: p)
            } catch let first as NSError where first.code == AuthErrorCode.networkError.rawValue {
                do {
                    _ = try await Auth.auth().createUser(withEmail: e, password: p)
                } catch let second as NSError where second.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                    _ = try await Auth.auth().signIn(withEmail: e, password: p)
                }
            }
        }
    }
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
    /// True when an error is the person closing the sign in page themselves. A cancel on any door
    /// is a quiet return to the door: no error line, nothing red, nothing painted (build 341, item 4).
    nonisolated static func isDoorCancel(_ e: Error) -> Bool {
        let n = e as NSError
        if n.domain == "com.apple.AuthenticationServices.WebAuthenticationSession" && n.code == 1 { return true }
        if n.domain == "com.apple.AuthenticationServices.AuthorizationError" && n.code == 1000 { return true }
        return n.localizedDescription.lowercased().contains("cancel")
    }
    func googleDoor() async {
        let prov = OAuthProvider(providerID: "google.com")
        prov.scopes = ["email", "profile"]
        googleProvider = prov
        message = ""; busy = true
        defer { busy = false }
        do {
            let cred: AuthCredential = try await withCheckedThrowingContinuation { cont in
                prov.getCredentialWith(nil) { c, e in
                    if let c = c { cont.resume(returning: c) } else { cont.resume(throwing: e ?? NSError(domain: "nm", code: 1)) }
                }
            }
            _ = try await Auth.auth().signIn(with: cred)
        } catch {
            // Her own cancel is never an error. Anything else keeps the words it had before.
            message = Store.isDoorCancel(error) ? "" : error.localizedDescription
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
            // The sweeps do not depend on each other, so they run together. Each one deletes in batches.
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await self.sweepRooms() }
                group.addTask { try await self.sweepNoteAttachments() }
                for name in ["tasks", "notes", "prompts", "needs", "settings"] {
                    group.addTask { try await self.sweep(name) }
                }
                try await group.waitForAll()
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
    /// Deletes every document in one collection of her space, in batches.
    private func sweep(_ name: String) async throws {
        guard let c = col(name) else { return }
        let snap = try await c.getDocuments()
        try await wipe(snap.documents.map { $0.reference })
    }
    /// Each room and its messages. The rooms are swept together.
    private func sweepRooms() async throws {
        guard let rc = col("rooms") else { return }
        let ids = try await rc.getDocuments().documents.map { $0.documentID }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for id in ids { group.addTask { try await self.sweepRoom(id) } }
            try await group.waitForAll()
        }
    }
    private func sweepRoom(_ id: String) async throws {
        guard let r = col("rooms")?.document(id) else { return }
        let msgs = try await r.collection("messages").getDocuments().documents.map { $0.reference }
        try await wipe(msgs + [r])
    }
    /// Batch delete, 400 at a time (a batch holds at most 500).
    private func wipe(_ refs: [DocumentReference]) async throws {
        var i = 0
        while i < refs.count {
            let batch = db.batch()
            for ref in refs[i..<min(i + 400, refs.count)] { batch.deleteDocument(ref) }
            try await batch.commit()
            i += 400
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
        if !t.isDone { kindnessOffer = true }
        col("tasks")?.document(t.id).updateData(["status": t.isDone ? "waiting" : "done", "done_date": t.isDone ? "" : Store.today, "done_by": "user"])
    }
    func deleteTask(_ t: TaskItem) { col("tasks")?.document(t.id).delete() }

    // MARK: task detail records (HTML section 9): checklist and dependencies ride on the task document
    func saveChecklist(_ t: TaskItem, _ list: [CheckItem]) {
        col("tasks")?.document(t.id).updateData(["checklist": list.map { ["text": $0.text, "done": $0.done] }])
    }
    func saveDependsOn(_ t: TaskItem, _ ids: [String]) {
        col("tasks")?.document(t.id).updateData(["dependsOn": ids])
    }

    // MARK: note attachments (HTML section 10): pictures under the note, in her own space
    func listenAttachments(_ noteId: String) {
        guard attHandles[noteId] == nil, let c = col("notes")?.document(noteId).collection("attachments") else { return }
        attHandles[noteId] = c.order(by: "createdAt").addSnapshotListener { [weak self] s, _ in
            guard let s else { return }
            let items = s.documents.map { d -> NoteAttachment in
                let x = d.data()
                return NoteAttachment(id: d.documentID, name: x["name"] as? String ?? "Picture",
                                      data: x["data"] as? Data ?? Data(),
                                      createdAt: (x["createdAt"] as? Timestamp)?.dateValue())
            }
            Task { @MainActor in self?.noteImages[noteId] = items }
        }
    }
    /// Shrinks a picked picture so it fits one Firestore document. Nil when even the smallest
    /// try is still too large — the screen then says so plainly instead of pretending.
    static func shrink(_ raw: Data) -> Data? {
        guard let img = UIImage(data: raw) else { return nil }
        let maxSide: CGFloat = 1000
        let scale = min(1, maxSide / max(img.size.width, img.size.height))
        var out = img
        if scale < 1 {
            let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
            out = UIGraphicsImageRenderer(size: size).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        }
        for q in [0.6, 0.4, 0.25, 0.15] {
            if let d = out.jpegData(compressionQuality: q), d.count <= 700_000 { return d }
        }
        return nil
    }
    /// Returns false when the picture could not be kept (too large). The write itself is the
    /// same shape as every other record: one document in her own space.
    @discardableResult
    func addAttachment(noteId: String, raw: Data) -> Bool {
        guard let data = Store.shrink(raw), let c = col("notes")?.document(noteId).collection("attachments") else { return false }
        c.addDocument(data: ["name": "Picture", "data": data, "createdAt": FieldValue.serverTimestamp()]) { [weak self] err in
            if let err { Task { @MainActor in self?.message = "Could not keep that picture: \(err.localizedDescription)" } }
        }
        return true
    }
    func removeAttachment(noteId: String, _ a: NoteAttachment) {
        col("notes")?.document(noteId).collection("attachments").document(a.id).delete()
    }
    /// Every note's attachments go when the account goes.
    private func sweepNoteAttachments() async throws {
        guard let c = col("notes") else { return }
        let docs = try await c.getDocuments().documents
        for d in docs {
            let atts = try await d.reference.collection("attachments").getDocuments().documents.map { $0.reference }
            try await wipe(atts)
        }
    }

    // MARK: per agent controls (HTML section 11), persisted per owner in settings/agents
    func agentControl(_ id: String) -> AgentControl { agentControls[id] ?? AgentControl() }
    func agentPaused(_ id: String) -> Bool { agentControl(id).paused }
    func agentMay(_ id: String, tool: String) -> Bool {
        let t = agentControl(id).tools
        return t.isEmpty || t.contains(tool)
    }
    func agentMayFile(_ id: String, project: String) -> Bool {
        let ps = agentControl(id).projects
        return ps.isEmpty || ps.contains { $0.lowercased() == project.lowercased() }
    }
    func setAgentControl(_ id: String, _ ctrl: AgentControl) {
        agentControls[id] = ctrl
        var map: [String: Any] = [:]
        for (k, v) in agentControls { map[k] = ["paused": v.paused, "projects": v.projects, "tools": v.tools] }
        col("settings")?.document("agents").setData(map)
    }

    // MARK: devices (HTML section 15): this device registers itself at sign-in, in her settings space
    static var deviceId: String {
        if let s = UserDefaults.standard.string(forKey: "nm_device_id"), !s.isEmpty { return s }
        let s = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(s, forKey: "nm_device_id")
        return s
    }
    static var thisDeviceDocId: String { "device-" + deviceId }
    private func registerDevice() {
        guard let ref = col("settings")?.document(Store.thisDeviceDocId) else { return }
        Task {
            let snap = try? await ref.getDocument()
            var d: [String: Any] = ["name": UIDevice.current.name, "model": UIDevice.current.model,
                                    "system": "iOS " + UIDevice.current.systemVersion,
                                    "lastSeen": FieldValue.serverTimestamp()]
            if snap?.exists != true || (snap?.data()?["firstSeen"] as? Timestamp) == nil {
                d["firstSeen"] = FieldValue.serverTimestamp()
            }
            ref.setData(d, merge: true) { _ in }
        }
    }
    /// Notes and prompts are one shape in Firestore under users/{uid}/notes and users/{uid}/prompts.
    /// There is no delete for a note anywhere in the app. Archive is the only way out of sight.
    @discardableResult
    func saveNote(id: String?, title: String, body: String, isPrompt: Bool, extra: [String: Any] = [:], landed: ((String) -> Void)? = nil) -> String? {
        guard let c = col(isPrompt ? "prompts" : "notes") else { return nil }
        let now = FieldValue.serverTimestamp()
        var d: [String: Any] = ["title": title, "body": body, "updatedAt": now]
        for (k, v) in extra { d[k] = v }
        if let id {
            c.document(id).setData(d, merge: true) { err in if err == nil { landed?(id) } }
            return id
        }
        let ref = c.document()
        d["createdAt"] = now; d["version"] = 1; d["archived"] = false
        if d["project"] == nil { d["project"] = "Unsorted" }
        if d["projects"] == nil { d["projects"] = [String]() }
        if d["ai"] == nil { d["ai"] = "Any AI" }
        ref.setData(d) { [weak self] err in
            if let err { Task { @MainActor in self?.message = "Could not save: \(err.localizedDescription)" } }
            else { landed?(ref.documentID) }
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
              let reader = AIConnections.shared.connected
                .filter({ !agentPaused($0.id) && agentMay($0.id, tool: AgentTool.read) })
                .sorted(by: { $0.label.lowercased() < $1.label.lowercased() }).first,
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
                "autoProject": hit.project, "autoBy": reader.label, "autoWords": hit.words]) { [weak self] err in
                if let err { Task { @MainActor in self?.message = "Could not save the project match: \(err.localizedDescription)" } }
            }
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
        // After the prompt lands, the relay registry hears about it: scheduled adds it, sent takes it off.
        let newId = saveNote(id: id, title: title, body: body, isPrompt: true, extra: extra) { [weak self] landedId in
            Task { @MainActor in
                if sendNow || room == nil { self?.registryPrompts(removing: landedId) } else { self?.registryPrompts(adding: landedId) }
            }
        }
        if sendNow, let room { PromptSender.post(store: self, roomId: room.id, text: body) }
        if let newId { autoMatch(id: newId, isPrompt: true, title: title, body: body) }
    }

    /// One tap on a saved prompt that has a room.
    func sendPromptNow(_ n: NoteItem) {
        guard n.isPrompt, !n.room.isEmpty, n.state != "sent" else { return }
        col("prompts")?.document(n.id).updateData(["state": "sent", "sentAt": Timestamp(date: Date())]) { [weak self] err in
            if err == nil { Task { @MainActor in self?.registryPrompts(removing: n.id) } }
        }
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
            col("prompts")?.document(n.id).updateData(["state": "sent", "sentAt": Timestamp(date: sent)]) { [weak self] err in
                if err == nil { Task { @MainActor in self?.registryPrompts(removing: n.id) } }
            }
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

    // MARK: relay registry. One document per user: _relayRegistry/{uid} = { rooms: [roomId], prompts: [promptId], updatedAt }.
    // Ids and updatedAt only. Never keys, titles or bodies. These writes never block the action they ride on,
    // run only after the main write lands, and swallow their errors. The sign in sync repairs any miss.
    private var registryDoc: DocumentReference? {
        guard let u = user else { return nil }
        return db.collection("_relayRegistry").document(u.uid)
    }
    private func scheduledPromptIds() -> [String] {
        notes.filter { $0.isPrompt && $0.state == "scheduled" && !$0.room.isEmpty }.map { $0.id }
    }
    /// Rewrites rooms[]. The change just made is passed in, because the local list may not show it yet.
    func registryRooms(adding: String? = nil, removing: String? = nil) {
        var ids = rooms.map { $0.id }.filter { $0 != removing }
        if let a = adding, !ids.contains(a) { ids.append(a) }
        registryDoc?.setData(["rooms": ids, "updatedAt": FieldValue.serverTimestamp()], merge: true) { _ in }
    }
    /// Rewrites prompts[] (the scheduled prompts).
    func registryPrompts(adding: String? = nil, removing: String? = nil) {
        var ids = scheduledPromptIds().filter { $0 != removing }
        if let a = adding, !ids.contains(a) { ids.append(a) }
        registryDoc?.setData(["prompts": ids, "updatedAt": FieldValue.serverTimestamp()], merge: true) { _ in }
    }
    /// On every sign in: one write of both arrays from the app's own lists.
    private func syncRegistryOnce() {
        guard roomsFresh, promptsFresh, !registrySynced else { return }
        registrySynced = true
        registryDoc?.setData(["rooms": rooms.map { $0.id }, "prompts": scheduledPromptIds(), "updatedAt": FieldValue.serverTimestamp()], merge: true) { _ in }
    }

    // MARK: on open filing pass for NEEDS-YOU messages the relay posted while the app was closed
    /// For each room, any message flagged needsYou that is not filed yet files its needs item (same shape as the
    /// live turn filing, through addNeed) and is marked filed. Quiet: errors are swallowed, nothing is shown.
    func fileUnfiledNeeds() async {
        guard let rc = col("rooms"), let nc = col("needs") else { return }
        guard let roomDocs = try? await rc.getDocuments().documents else { return }
        guard let needDocs = try? await nc.getDocuments().documents else { return }
        var filedFor: Set<String> = Set(needDocs.compactMap { $0.data()["messageId"] as? String })
        for r in roomDocs {
            guard let flagged = try? await r.reference.collection("messages").whereField("needsYou", isEqualTo: true).getDocuments().documents else { continue }
            for m in flagged {
                let x = m.data()
                if (x["filed"] as? Bool) == true { continue }
                if filedFor.contains(m.documentID) { m.reference.updateData(["filed": true]) { _ in }; continue }
                let raw = x["text"] as? String ?? ""
                let (body, line) = RoomEngine.splitNeed(raw)
                let need = line ?? body
                if need.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
                let author = x["author"] as? String ?? ""
                addNeed(text: need, ai: AIConnections.shared.displayName(author), roomId: r.documentID, messageId: m.documentID)
                filedFor.insert(m.documentID)
            }
        }
    }

    // MARK: rooms (every write stays inside users/{uid}/)
    func roomMessagesCollection(_ roomId: String) -> CollectionReference? {
        col("rooms")?.document(roomId).collection("messages")
    }
    func createRoom(_ title: String) -> String? {
        guard let c = col("rooms") else { return nil }
        let ref = c.document()
        let newId = ref.documentID
        ref.setData(["title": title, "createdAt": FieldValue.serverTimestamp()]) { [weak self] err in
            if let err { Task { @MainActor in self?.roomError = "Could not save the room: \(err.localizedDescription)" } }
            else { Task { @MainActor in self?.registryRooms(adding: newId) } }
        }
        return newId
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
    /// Files one needs item. When it comes from a message, the message id rides on the item and the
    /// message is marked filed, so the same message never files twice.
    func addNeed(text: String, ai: String, roomId: String, messageId: String = "") {
        var d: [String: Any] = ["text": text, "ai": ai, "roomId": roomId, "source": "room", "status": "open", "createdAt": FieldValue.serverTimestamp()]
        if !messageId.isEmpty { d["messageId"] = messageId }
        col("needs")?.addDocument(data: d) { [weak self] err in
            if let err { Task { @MainActor in self?.roomError = "Could not save the need: \(err.localizedDescription)" } }
            else if !messageId.isEmpty {
                Task { @MainActor in self?.col("rooms")?.document(roomId).collection("messages").document(messageId).updateData(["filed": true]) { _ in } }
            }
        }
    }
    func resolveNeed(_ n: NeedItem) { col("needs")?.document(n.id).updateData(["status": "done"]) }

    // MARK: build 341 item 6: room delete and scheduled prompt cancel, wired to the relay registry

    /// Deletes one of her own rooms and its messages, then takes the room off the relay registry.
    /// The confirm step lives on the screen; this runs only after she has confirmed.
    func deleteRoom(_ room: RoomItem) {
        Task {
            try? await sweepRoom(room.id)
            registryRooms(removing: room.id)
        }
    }

    /// Cancels a scheduled prompt that has not sent yet. The state change alone stops the scheduler
    /// (it only fires state "scheduled"), and the registry rewrite takes the id off prompts[].
    func cancelScheduledPrompt(_ n: NoteItem) {
        guard n.isPrompt, n.state == "scheduled" else { return }
        col("prompts")?.document(n.id).updateData(["state": "cancelled"]) { [weak self] err in
            if err == nil { Task { @MainActor in self?.registryPrompts(removing: n.id) } }
        }
    }

    /// Plain-text copy of every note and prompt, for the Privacy and data screen.
    var exportText: String {
        notes.map { "# \($0.title)\n(\($0.isPrompt ? "Prompt" : "Note") · \($0.project) · \($0.ai))\n\n\($0.body)\n" }.joined(separator: "\n---\n\n")
    }
}

/// One calm colour per project (build 341, her word 22:50). The same name always gets the same
/// colour, drawn from a quiet set in the app's own family. Views stay visually quiet: the colour
/// is a small dot or a thin bar, never a loud surface.
enum ProjectColor {
    static let hexes: [UInt32] = [0xA8C256, 0x7FA6A3, 0xB08968, 0x9B8EA6, 0xC2A878, 0xC08A7E, 0x7E8FA6, 0x8A9A5B]
    static func hex(_ name: String) -> UInt32 {
        var h = 0
        for u in name.lowercased().unicodeScalars { h = (h &* 31 &+ Int(u.value)) & 0x7fffffff }
        return hexes[h % hexes.count]
    }
    static func color(_ name: String) -> Color { Color(hex: hex(name)) }
}

extension Store {
    /// Percentage done for one project, only where the records give an honest basis:
    /// the project must hold at least one task. Otherwise nil, and screens show the
    /// "not yet measurable" words instead of a number (HTML section 7).
    func percentDone(_ name: String) -> Int? {
        let pr = progress(name)
        guard pr.total > 0 else { return nil }
        return Int((Double(pr.done) / Double(pr.total) * 100).rounded())
    }
    /// The dependencies of a task that are still open (HTML section 9). A task whose
    /// dependencies are all done, or that has none, is not blocked.
    func openDependencies(_ t: TaskItem) -> [TaskItem] {
        t.dependsOn.compactMap { id in tasks.first { $0.id == id && !$0.isDone } }
    }
    func dependencyTasks(_ t: TaskItem) -> [TaskItem] {
        t.dependsOn.compactMap { id in tasks.first { $0.id == id } }
    }
}
