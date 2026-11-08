import Foundation
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

struct TaskItem: Identifiable { let id: String; var title: String; var status: String; var dueOn: String; var area: String
    var isDone: Bool { status == "done" }
    var isOverdue: Bool { !isDone && !dueOn.isEmpty && dueOn < Store.today }
}
struct NoteItem: Identifiable { let id: String; var title: String; var body: String; var project: String; var ai: String; var isPrompt: Bool }

@MainActor
final class Store: ObservableObject {
    @Published var user: User?
    @Published var tasks: [TaskItem] = []
    @Published var notes: [NoteItem] = []
    @Published var message = ""
    @Published var busy = false
    private var handles: [ListenerRegistration] = []
    private var authHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()

    nonisolated static var today: String { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date()) }

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, u in
            Task { @MainActor in self?.user = u; self?.listen() }
        }
    }

    var projects: [String] {
        Array(Set(tasks.map { $0.area }.filter { !$0.isEmpty } + notes.map { $0.project }.filter { !$0.isEmpty && $0 != "Unsorted" })).sorted()
    }
    func progress(_ p: String) -> (done: Int, total: Int) {
        let t = tasks.filter { $0.area == p }; return (t.filter { $0.isDone }.count, t.count)
    }

    private func col(_ n: String) -> CollectionReference? {
        guard let u = user else { return nil }
        return db.collection("users").document(u.uid).collection(n)
    }
    private func listen() {
        handles.forEach { $0.remove() }; handles = []; tasks = []; notes = []
        guard user != nil else { return }
        if let c = col("tasks") {
            handles.append(c.addSnapshotListener { [weak self] s, _ in
                guard let s else { return }
                let items = s.documents.map { d -> TaskItem in
                    let x = d.data()
                    return TaskItem(id: d.documentID, title: x["title"] as? String ?? "", status: x["status"] as? String ?? "", dueOn: x["due_on"] as? String ?? "", area: x["area"] as? String ?? "")
                }
                Task { @MainActor in self?.tasks = items }
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
                    return NoteItem(id: d.documentID, title: x["title"] as? String ?? "", body: x["body"] as? String ?? "", project: x["project"] as? String ?? "", ai: x["ai"] as? String ?? "", isPrompt: isPrompt)
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
    func googleDoor() { message = "Google sign-in is almost ready. Please use Apple or email for now." }
    static func randomNonce(_ n: Int = 32) -> String {
        let cs = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<n).map { _ in cs[Int.random(in: 0..<cs.count)] })
    }
    static func sha256(_ s: String) -> String { SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined() }
    func signOut() { try? Auth.auth().signOut() }
    private func run(_ f: @escaping () async throws -> Void) async {
        message = ""; busy = true; defer { busy = false }
        do { try await f() } catch { message = error.localizedDescription }
    }

    // MARK: data
    func addTask(_ title: String, area: String, due: String) {
        col("tasks")?.addDocument(data: ["title": title, "area": area, "due_on": due, "status": "waiting", "created": FieldValue.serverTimestamp()])
    }
    func toggle(_ t: TaskItem) {
        col("tasks")?.document(t.id).updateData(["status": t.isDone ? "waiting" : "done", "done_date": t.isDone ? "" : Store.today, "done_by": "user"])
    }
    func deleteTask(_ t: TaskItem) { col("tasks")?.document(t.id).delete() }
    func saveNote(id: String?, title: String, body: String, project: String, ai: String, isPrompt: Bool) {
        guard let c = col(isPrompt ? "prompts" : "notes") else { return }
        let now = FieldValue.serverTimestamp()
        var d: [String: Any] = ["title": title, "body": body, "project": project.isEmpty ? "Unsorted" : project, "ai": ai.isEmpty ? "Any AI" : ai, "updatedAt": now]
        if let id { c.document(id).setData(d, merge: true) } else { d["createdAt"] = now; d["version"] = 1; c.addDocument(data: d) }
    }
    func delete(_ n: NoteItem) { col(n.isPrompt ? "prompts" : "notes")?.document(n.id).delete() }
}
