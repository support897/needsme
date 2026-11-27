import SwiftUI
import WebKit
import UniformTypeIdentifiers

/// "Sign in and bring my chats". One door for every AI that has a website.
/// The person signs in to the AI's own page inside the app (their own login, their own session).
/// For ChatGPT and Claude the app then reads that person's own projects and chat titles through the
/// same page session, on this phone only, and files them. For the other AIs the page opens to the
/// export page and the person picks the downloaded file. Nothing is sent to any server of ours.
struct AIDoor: Identifiable {
    let id: String, name: String, login: String, exportPage: String, reads: Bool
}

let aiDoors: [AIDoor] = [
    AIDoor(id: "chatgpt", name: "ChatGPT", login: "https://chatgpt.com/auth/login", exportPage: "https://chatgpt.com/#settings/DataControls", reads: true),
    AIDoor(id: "claude", name: "Claude", login: "https://claude.ai/login", exportPage: "https://claude.ai/settings/data-privacy-controls", reads: true),
    AIDoor(id: "gemini", name: "Gemini", login: "https://gemini.google.com/app", exportPage: "https://takeout.google.com/settings/takeout/custom/gemini_gems", reads: false),
    AIDoor(id: "perplexity", name: "Perplexity", login: "https://www.perplexity.ai/", exportPage: "https://www.perplexity.ai/settings/account", reads: false),
    AIDoor(id: "grok", name: "Grok", login: "https://grok.com/", exportPage: "https://accounts.x.ai/account", reads: false),
    AIDoor(id: "muse", name: "Muse", login: "https://muse.ai/", exportPage: "https://accountscenter.meta.com/info_and_permissions/dyi", reads: false),
    AIDoor(id: "copilot", name: "Copilot", login: "https://copilot.microsoft.com/", exportPage: "https://account.microsoft.com/privacy", reads: false),
    AIDoor(id: "polar", name: "Polar", login: "https://polarbrowser.com/", exportPage: "https://polarbrowser.com/", reads: false),
]

enum DoorReader {
    struct Proj: Decodable { let name: String?; let about: String? }
    struct Reply: Decodable { let projects: [Proj]?; let chats: [String]?; let err: String? }

    static let chatgptJS = #"""
    try{const s=await (await fetch('/api/auth/session',{credentials:'include'})).json();
    if(!s||!s.accessToken) return JSON.stringify({err:'signin'});
    const h={Authorization:'Bearer '+s.accessToken};
    let chats=[];
    for(let o=0;o<2000;o+=100){const r=await fetch('/backend-api/conversations?offset='+o+'&limit=100&order=updated',{headers:h});if(!r.ok)break;const j=await r.json();const it=j.items||[];chats=chats.concat(it.map(x=>x.title||''));if(it.length<100)break;}
    let projects=[];
    try{const r=await fetch('/backend-api/gizmos/snorlax/sidebar?conversations_per_gizmo=0',{headers:h});if(r.ok){const j=await r.json();projects=(j.items||[]).map(x=>{const d=((x.gizmo||{}).gizmo||{}).display||{};return {name:d.name||'',about:d.description||''}});}}catch(e){}
    return JSON.stringify({projects:projects,chats:chats});}catch(e){return JSON.stringify({err:String(e)})}
    """#

    static let claudeJS = #"""
    try{const o=await fetch('/api/organizations',{credentials:'include'});if(!o.ok) return JSON.stringify({err:'signin'});
    const orgs=await o.json();let projects=[],chats=[];
    for(const g of orgs){
      const p=await fetch('/api/organizations/'+g.uuid+'/projects',{credentials:'include'});
      if(p.ok){const j=await p.json();projects=projects.concat((Array.isArray(j)?j:[]).map(x=>({name:x.name||'',about:x.description||''})));}
      const c=await fetch('/api/organizations/'+g.uuid+'/chat_conversations',{credentials:'include'});
      if(c.ok){const j=await c.json();chats=chats.concat((Array.isArray(j)?j:[]).map(x=>x.name||''));}
    }
    return JSON.stringify({projects:projects,chats:chats});}catch(e){return JSON.stringify({err:String(e)})}
    """#

    static func js(_ id: String) -> String? { id == "chatgpt" ? chatgptJS : id == "claude" ? claudeJS : nil }

    static func decode(_ s: String) -> Reply? { try? JSONDecoder().decode(Reply.self, from: Data(s.utf8)) }
}

/// Files what was found. Shared by the sign in door and the export file picker.
enum DoorFiler {
    @MainActor
    static func file(_ store: Store, source: String, projects: [ProjectImport.Found], chats: [String]) -> String {
        let have = Set(store.projects.map { $0.lowercased() })
        var added: [String] = []; var already = 0
        for f in projects {
            if have.contains(f.name.lowercased()) { already += 1; continue }
            _ = store.saveNote(id: nil, title: f.name, body: f.about.isEmpty ? "Brought in from \(source)." : f.about, isPrompt: false,
                               extra: ["projects": [f.name], "project": f.name, "projectFixed": true])
            added.append(f.name)
        }
        var seen = Set<String>(); var chatsAdded = 0
        let room = "Chats from \(source)"
        for t in chats {
            let title = t.trimmingCharacters(in: .whitespacesAndNewlines)
            if title.isEmpty || seen.contains(title.lowercased()) { continue }
            seen.insert(title.lowercased())
            _ = store.saveNote(id: nil, title: title, body: "A chat you had in \(source).", isPrompt: false,
                               extra: ["projects": [room], "project": room, "projectFixed": true])
            chatsAdded += 1
        }
        var line = "Found \(projects.count) projects and \(seen.count) chats. Brought in \(added.count) projects and \(chatsAdded) chats"
        if already > 0 { line += ", \(already) projects already here" }
        return line + "."
    }
}

final class DoorWeb: NSObject, ObservableObject {
    let web: WKWebView
    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        web = WKWebView(frame: .zero, configuration: cfg)
        // Many sign in pages refuse a bare web view. Present the normal mobile Safari identity.
        web.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1"
        super.init()
    }
}

struct DoorWebView: UIViewRepresentable {
    let box: DoorWeb
    let url: String
    func makeUIView(context: Context) -> WKWebView {
        if let u = URL(string: url) { box.web.load(URLRequest(url: u)) }
        return box.web
    }
    func updateUIView(_ v: WKWebView, context: Context) {}
}

struct AIDoorSheet: View {
    let door: AIDoor
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @Environment(\.dismiss) var dismiss
    @StateObject private var box = DoorWeb()
    @State private var began = Date()
    @State private var line = ""
    @State private var working = false
    @State private var picking = false

    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                Text(door.reads
                     ? "Step 1: sign in to \(door.name) below. Step 2: tap Bring my chats."
                     : "Step 1: sign in to \(door.name) below. Step 2: ask it for your data export. Step 3: pick the file here.")
                    .font(.subheadline).foregroundColor(p.soft).padding(.horizontal)
                DoorWebView(box: box, url: door.login)
                    .clipShape(RoundedRectangle(cornerRadius: 14)).padding(.horizontal)
                if !line.isEmpty {
                    Text(line).font(.footnote.weight(.semibold)).foregroundColor(p.ink).padding(.horizontal)
                        .accessibilityIdentifier("doorResult")
                }
                if door.reads {
                    Button(working ? "Reading your chats..." : "Bring my chats") { Task { await read() } }
                        .buttonStyle(PrimaryButton()).disabled(working).accessibilityIdentifier("doorBring")
                        .padding(.horizontal)
                }
                HStack {
                    Button("Open its export page") { if let u = URL(string: door.exportPage) { box.web.load(URLRequest(url: u)) } }
                        .buttonStyle(SoftButton()).accessibilityIdentifier("doorExportPage")
                    Button("Pick the export file") { picking = true }
                        .buttonStyle(SoftButton()).accessibilityIdentifier("doorPick")
                }.padding(.horizontal).padding(.bottom, 8)
            }
            .navigationTitle(door.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Close") { dismiss() }.accessibilityIdentifier("doorClose") } }
            .onAppear { began = Date() }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.json, .plainText]) { r in
                guard case .success(let url) = r else { return }
                let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
                guard let d = try? Data(contentsOf: url) else { line = "Could not read that file."; return }
                let projects = ProjectImport.parse(d), chats = ProjectImport.parseChats(d)
                if projects.isEmpty && chats.isEmpty { line = "Nothing found in that file. Pick conversations.json or projects.json."; return }
                line = DoorFiler.file(store, source: door.name, projects: projects, chats: chats)
            }
        }
    }

    private func read() async {
        guard let js = DoorReader.js(door.id) else { return }
        working = true; defer { working = false }
        let t0 = Date()
        do {
            let res = try await box.web.callAsyncJavaScript(js, arguments: [:], in: nil, contentWorld: .page)
            guard let s = res as? String, let r = DoorReader.decode(s) else { line = "Could not read the page. Try again."; return }
            if let e = r.err {
                line = e == "signin" ? "Not signed in yet. Sign in above, then tap again." : "Could not read your chats (\(e.prefix(60)))."
                return
            }
            let projects = (r.projects ?? []).compactMap { x -> ProjectImport.Found? in
                let n = (x.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return n.isEmpty ? nil : ProjectImport.Found(name: n, about: x.about ?? "")
            }
            let secs = Date().timeIntervalSince(t0)
            line = DoorFiler.file(store, source: door.name, projects: projects, chats: r.chats ?? [])
                + String(format: " Read in %.1f s. Sign in to done: %.0f s.", secs, Date().timeIntervalSince(began))
        } catch {
            line = "Could not read the page. Try again."
        }
    }
}

struct SignInDoorCard: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var open: AIDoor?
    var body: some View {
        Card {
            Text("SIGN IN, BRING MY CHATS").font(.caption.monospaced().bold()).foregroundColor(p.soft)
            Text("Connect any AI by signing in").font(.title3.bold()).foregroundColor(p.ink)
            Text("No key needed. Sign in to the AI's own page here, with your own login. NeedsMe reads your projects and chat titles on this phone only. If the AI hides them, ask it for your export and pick the file.")
                .font(.subheadline).foregroundColor(p.soft)
            ForEach(aiDoors) { d in
                Button("Sign in to \(d.name)") { open = d }
                    .buttonStyle(SoftButton()).accessibilityIdentifier("door-\(d.id)")
            }
        }
        .sheet(item: $open) { d in AIDoorSheet(door: d).environmentObject(store) }
    }
}
