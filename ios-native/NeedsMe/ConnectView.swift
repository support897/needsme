import SwiftUI
import WebKit
import CryptoKit

let setupPrompt = "You are my friendly setup helper for the NeedsMe Ai app. Help me connect my own AI in under 60 seconds. Ask me ONE question at a time: 1) Which AI do I want to connect (OpenAI, Claude or Gemini)? 2) Give me the exact key page link and the 3 clicks to create an API key. 3) Tell me to copy the key and paste it ONLY into the NeedsMe app Connect page, never into this chat. 4) Tell me which model name to type. 5) Ask me to press Test connection and tell you the result. Use short plain words. If something fails, give the single next fix."


// MARK: Real AI websites inside the app. One private saved login per account (iOS 17+).
@MainActor
enum WebHub {
    private static var views: [String: WKWebView] = [:]
    private static var busy: Set<String> = []
    static let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

    static func uuid(_ id: String) -> UUID {
        var b = Array(SHA256.hash(data: Data(("needsme-web-" + id).utf8)).prefix(16))
        b[6] = (b[6] & 0x0F) | 0x50; b[8] = (b[8] & 0x3F) | 0x80
        return b.withUnsafeBytes { UUID(uuid: $0.load(as: uuid_t.self)) }
    }

    static func existing(_ id: String) -> WKWebView? { views[id] }

    static func view(for a: AIAccount) -> WKWebView {
        if let v = views[a.id] { return v }
        let c = WKWebViewConfiguration()
        c.websiteDataStore = WKWebsiteDataStore(forIdentifier: uuid(a.id))
        c.allowsInlineMediaPlayback = true
        c.defaultWebpagePreferences.preferredContentMode = .mobile
        let vp = "var m=document.querySelector('meta[name=viewport]');if(!m){m=document.createElement('meta');m.name='viewport';(document.head||document.documentElement).appendChild(m)}m.content='width=device-width,initial-scale=1,viewport-fit=cover';"
        c.userContentController.addUserScript(WKUserScript(source: vp, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let sz = UIScreen.main.bounds.size
        let v = WKWebView(frame: CGRect(x: 0, y: 0, width: sz.width, height: sz.height), configuration: c)
        v.customUserAgent = ua
        v.allowsBackForwardNavigationGestures = true
        views[a.id] = v
        park(v)
        if let u = URL(string: a.site) { v.load(URLRequest(url: u)) }
        return v
    }

    /// Keeps a page alive out of sight, so it can still be asked things.
    static func park(_ v: WKWebView) {
        guard let w = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) else { return }
        v.removeFromSuperview()
        v.frame = CGRect(x: -3000, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        w.addSubview(v)
    }

    static func blurAll() { for v in views.values { v.evaluateJavaScript("document.activeElement&&document.activeElement.blur()", completionHandler: nil) } }

    static func forget(_ a: AIAccount) {
        if let v = views[a.id] { v.removeFromSuperview() }
        views[a.id] = nil
        let id = uuid(a.id)
        Task { try? await WKWebsiteDataStore.remove(forIdentifier: id) }
    }

    static func js(_ v: WKWebView, _ code: String) async -> String {
        await withCheckedContinuation { (c: CheckedContinuation<String, Never>) in
            v.evaluateJavaScript(code) { r, _ in
                if let s = r as? String { c.resume(returning: s) }
                else if let r { c.resume(returning: "\(r)") }
                else { c.resume(returning: "") }
            }
        }
    }

    static func settle(_ v: WKWebView) async {
        let t0 = Date()
        while Date().timeIntervalSince(t0) < 20 {
            if !v.isLoading, await js(v, "document.readyState") == "complete" { break }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        try? await Task.sleep(nanoseconds: 2_500_000_000)
    }

    static let findBox = #"(()=>{const el=[...document.querySelectorAll('textarea,[contenteditable="true"],[role="textbox"]')].filter(e=>e.offsetParent).pop();return el?'1':'0'})()"#
    static let typeJS = #"(()=>{const el=[...document.querySelectorAll('textarea,[contenteditable="true"],[role="textbox"]')].filter(e=>e.offsetParent).pop();if(!el)return '0';el.focus();const t=__T__;if(el.tagName==='TEXTAREA'||el.tagName==='INPUT'){const s=Object.getOwnPropertyDescriptor(Object.getPrototypeOf(el),'value').set;s.call(el,t);el.dispatchEvent(new Event('input',{bubbles:true}));}else{document.execCommand('selectAll',false,null);document.execCommand('insertText',false,t);if(!(el.innerText||'').trim()){el.textContent=t;el.dispatchEvent(new InputEvent('input',{bubbles:true,data:t,inputType:'insertText'}));}}return '1'})()"#
    static let sendJS = #"(()=>{const el=[...document.querySelectorAll('textarea,[contenteditable="true"],[role="textbox"]')].filter(e=>e.offsetParent).pop();const root=(el&&el.closest('form'))||document;const b=[...root.querySelectorAll('button,[role=button]')].filter(x=>x.offsetParent&&!x.disabled&&x.getAttribute('aria-disabled')!=='true').find(x=>/send|submit|enviar/i.test((x.getAttribute('aria-label')||'')+' '+(x.getAttribute('data-testid')||'')+' '+(x.innerText||'')))||root.querySelector('button[type=submit]');if(b){b.click();return 'click'}if(el){for(const t of ['keydown','keypress','keyup'])el.dispatchEvent(new KeyboardEvent(t,{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true}));return 'enter'}return 'none'})()"#

    /// Checks that the page shows a message box, which means the user is signed in.
    static func test(_ a: AIAccount) async -> Result<Void, AIError> {
        let v = view(for: a)
        if await js(v, findBox) == "1" { return .success(()) }
        return .failure(AIError(reason: "no message box yet. Sign in on the page first"))
    }

    /// Types into the real page and reads the answer, one job at a time per account.
    static func ask(_ a: AIAccount, _ text: String) async -> Result<String, AIError> {
        while busy.contains(a.id) { try? await Task.sleep(nanoseconds: 700_000_000) }
        busy.insert(a.id); defer { busy.remove(a.id) }
        let v = view(for: a)
        if let u = URL(string: a.site) { v.load(URLRequest(url: u)) }
        await settle(v)
        let before = await js(v, "document.body.innerText")
        guard let d = try? JSONEncoder().encode(text), let lit = String(data: d, encoding: .utf8) else { return .failure(AIError(reason: "bad text")) }
        if await js(v, typeJS.replacingOccurrences(of: "__T__", with: lit)) != "1" {
            return .failure(AIError(reason: "cannot find the message box. Open \(a.label) in AIs and sign in first"))
        }
        try? await Task.sleep(nanoseconds: 900_000_000)
        _ = await js(v, sendJS)
        var last = "", stable = 0
        let t0 = Date()
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        while Date().timeIntervalSince(t0) < 180 {
            let now = await js(v, "document.body.innerText")
            if now == last && now != before { stable += 1 } else { stable = 0 }
            last = now
            if stable >= 4 { break }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        let tail = String(text.suffix(40))
        var out = last
        if let r = last.range(of: tail, options: .backwards) { out = String(last[r.upperBound...]) }
        else if last.count > before.count { out = String(last.dropFirst(before.count)) }
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return out.isEmpty ? .failure(AIError(reason: "no answer came back")) : .success(out)
    }
}

struct WebBrowser: UIViewRepresentable {
    let account: AIAccount
    func makeUIView(context: Context) -> WKWebView { WebHub.view(for: account) }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    static func dismantleUIView(_ uiView: WKWebView, coordinator: ()) {
        MainActor.assumeIsolated { WebHub.park(uiView) }
    }
}

// MARK: AIs: every platform, with its accounts, and the real site inside the app.
struct ConnectView: View {
    @Environment(\.palette) var p
    @ObservedObject private var conns = AIConnections.shared
    @State private var opened: AIAccount?
    @State private var newFor: String?
    @State private var newLabel = ""

    var signedCount: Int { conns.mine.count }
    @State private var showAll = false
    @State private var otherLink = ""
    @State private var otherOpen = false
    @State private var query = ""
    @State private var editing: AIAccount?

    func chip(_ a: AIAccount) -> some View {
        let on = conns.isConnected(a)
        return Button { opened = a } label: {
            HStack(spacing: 6) {
                Circle().fill(on ? Color.sprout : Color.faint.opacity(0.5)).frame(width: 8, height: 8)
                Text(a.label).font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(p.chip).clipShape(Capsule()).foregroundColor(p.ink)
        }.buttonStyle(.plain).accessibilityIdentifier("ai-" + a.label)
        .contextMenu { Button { editing = a } label: { Label("Edit name and icon", systemImage: "pencil") } }
    }

    func platform(_ w: WebAI) -> some View {
        let accts = conns.accounts(forId: w.id)
        let signed = accts.filter { conns.isConnected($0) }
        return Card {
            HStack(spacing: 12) {
                AIFace(label: w.name, size: 40, state: .none)
                VStack(alignment: .leading, spacing: 2) {
                    Text(w.name).font(.headline).foregroundColor(p.ink)
                    Text(signed.isEmpty ? w.group : (signed.count == 1 ? "1 account signed in" : "\(signed.count) accounts signed in"))
                        .font(.subheadline).foregroundColor(p.soft)
                }
                Spacer()
            }
            if signed.isEmpty {
                Button { detail = nil; opened = accts.first ?? conns.addWeb(id: w.id, label: "") } label: { Text("Sign in") }
                    .buttonStyle(PrimaryButton()).accessibilityIdentifier("signin-" + w.name)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(signed) { chip($0) }
                        Button { newLabel = ""; newFor = w.id } label: {
                            Label("Account", systemImage: "plus").font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .overlay(Capsule().stroke(Color.faint.opacity(0.6), lineWidth: 1)).foregroundColor(p.soft)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @State private var group = "All"
    @State private var detail: WebAI?
    var groups: [String] { ["All"] + webCatalog.map { $0.group }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } } }
    var shown: [WebAI] {
        webCatalog.filter { (group == "All" || $0.group == group) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }
    }
    func tile(_ w: WebAI) -> some View {
        let n = conns.accounts(forId: w.id).filter { conns.isConnected($0) }.count
        return Button { if w.url.isEmpty { return }; detail = w } label: {
            VStack(spacing: 8) {
                AIFace(label: w.name, size: 44, state: .none)
                Text(w.name).font(.system(size: 13, weight: .bold)).foregroundColor(p.ink).multilineTextAlignment(.center).lineLimit(2)
                Text(w.url.isEmpty ? "Terminal, on your computer" : (n > 0 ? "\(n) signed in" : w.group)).font(.system(size: 11)).foregroundColor(n > 0 ? .sprout : p.soft)
            }
            .frame(maxWidth: .infinity, minHeight: 112).padding(8)
            .background(p.card).clipShape(RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).accessibilityIdentifier("tile-" + w.name)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Card {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your AIs").font(.system(.title2, design: .rounded).weight(.heavy))
                            Text(signedCount == 0 ? "Sign in once. Stay signed in." : "\(signedCount) signed in. Tap one to open it.")
                                .font(.subheadline.weight(.semibold)).foregroundColor(p.soft)
                        }
                        Spacer(); PipArt(pose: .welcome, height: 64)
                    }.foregroundColor(p.ink)
                }
                ConsentCard()
                if !conns.mine.isEmpty {
                    Text("Switch").font(.headline).foregroundColor(p.ink)
                    AccountSwitcher(accounts: conns.mine, onPick: { opened = $0 }).padding(.horizontal, -14)
                }
                Button { withAnimation { showAll.toggle() } } label: {
                    HStack { Text(conns.mine.isEmpty ? "Pick an AI" : "Add another AI").font(.headline); Spacer()
                        Image(systemName: "chevron.down").rotationEffect(.degrees(showAll || conns.mine.isEmpty ? 180 : 0)) }
                        .foregroundColor(p.ink).padding(14).background(p.card).clipShape(RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain).accessibilityIdentifier("addAnotherAI")
                if showAll || conns.mine.isEmpty || !query.isEmpty {
                TextField("Search \(webCatalog.count) AIs", text: $query).textFieldStyle(.roundedBorder).accessibilityIdentifier("aiSearch")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(groups, id: \.self) { g in
                            Button { group = g } label: {
                                Text(g).font(.system(size: 13, weight: .semibold)).padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(group == g ? Color.loam : p.chip).foregroundColor(group == g ? .sprout : p.ink).clipShape(Capsule())
                            }.buttonStyle(.plain)
                        }
                    }
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(shown) { tile($0) }
                    if group == "All" || query.isEmpty && group == "Any" {
                        Button { otherLink = ""; newLabel = ""; otherOpen = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus").font(.system(size: 20, weight: .bold)).foregroundColor(.loam).frame(width: 44, height: 44).background(Color.sprout).clipShape(Circle())
                                Text("Any other AI").font(.system(size: 13, weight: .bold)).foregroundColor(p.ink)
                                Text("Paste a link").font(.system(size: 11)).foregroundColor(p.soft)
                            }.frame(maxWidth: .infinity, minHeight: 112).padding(8).background(p.card).clipShape(RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain).accessibilityIdentifier("tile-other")
                    }
                }
                }
                let extra = conns.accounts(forId: "custom").filter { $0.url != nil }
                if !extra.isEmpty {
                    Text("Added by link").font(.headline).foregroundColor(p.ink)
                    ForEach(extra) { chip($0) }
                }
                Text("You sign in on each AI's own page, inside this app. Your logins stay on this phone and are never mixed between accounts.")
                    .font(.footnote).foregroundColor(p.soft)
            }.padding().padding(.bottom, 100)
        }
        .lookBg().navigationTitle("AIs")
        .sheet(item: $detail) { w in ScrollView { platform(w).padding() }.background(p.bg).presentationDetents([.medium]).environment(\.palette, p) }
        .fullScreenCover(item: $opened) { WebAIScreen(account: $0).environment(\.palette, p) }
        .sheet(item: $editing) { AccountEditor(account: $0).environment(\.palette, p) }
        .scrollDismissesKeyboard(.interactively)
        .alert("Add another \(webAI(newFor ?? "")?.name ?? "") account", isPresented: Binding(get: { newFor != nil }, set: { if !$0 { newFor = nil } })) {
            TextField("Name, like Work", text: $newLabel)
            Button("Add") { if let id = newFor { detail = nil; opened = conns.addWeb(id: id, label: newLabel) }; newFor = nil }
            Button("Cancel", role: .cancel) { newFor = nil }
        } message: { Text("It gets its own private login.") }
        .alert("Add any AI", isPresented: $otherOpen) {
            TextField("Name", text: $newLabel)
            TextField("https://...", text: $otherLink).textInputAutocapitalization(.never).keyboardType(.URL)
            Button("Add") {
                var u = otherLink.trimmingCharacters(in: .whitespacesAndNewlines)
                if !u.isEmpty && !u.hasPrefix("http") { u = "https://" + u }
                if URL(string: u)?.host != nil { opened = conns.addWeb(id: "custom", label: newLabel.isEmpty ? "Other AI" : newLabel, url: u) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Type a name and the AI's web address.") }
    }
}

struct WebAIScreen: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.palette) var p
    @ObservedObject private var conns = AIConnections.shared
    @ObservedObject private var tabs = OpenTabs.shared
    @State var current: AIAccount
    @State private var msg = ""
    @State private var checking = false
    @State private var picking = false
    @State private var editing: AIAccount?
    init(account: AIAccount) { _current = State(initialValue: account) }

    func done() async {
        checking = true
        let r = await WebHub.test(current)
        checking = false
        switch r {
        case .success: conns.connectWeb(current); msg = ""; if AvatarStore.shared.shouldPrompt(current.id) { editing = current }
        case .failure(let e): msg = "Not ready: " + e.reason + "."
        }
    }
    func show(_ a: AIAccount) { tabs.open(a); current = a; msg = "" }
    func close(_ a: AIAccount) {
        tabs.close(a.id)
        if a.id == current.id {
            if let n = tabs.accounts.first { current = n; msg = "" } else { dismiss() }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { dismiss() } label: { Image(systemName: "chevron.down").font(.system(size: 14, weight: .bold)).foregroundColor(p.ink)
                    .frame(width: 34, height: 34).background(p.chip).clipShape(Circle()) }.accessibilityIdentifier("webClose")
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(tabs.accounts) { a in
                                TabChip(account: a, selected: a.id == current.id, onTap: { show(a) }, onClose: { close(a) }).id(a.id)
                            }
                        }
                    }.onChange(of: current.id) { id in withAnimation { proxy.scrollTo(id, anchor: .center) } }
                }
                Menu {
                    ForEach(conns.mine.map { $0.platformName }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }, id: \.self) { plat in
                        Section(plat) {
                            ForEach(conns.mine.filter { $0.platformName == plat }) { a in
                                Button { show(a) } label: { Label(a.label, systemImage: a.id == current.id ? "checkmark.circle.fill" : (conns.isConnected(a) ? "person.crop.circle.badge.checkmark" : "person.crop.circle")) }
                            }
                        }
                    }
                } label: { Image(systemName: "person.2.circle").font(.system(size: 17, weight: .semibold)).foregroundColor(p.ink)
                    .frame(width: 34, height: 34).background(p.chip).clipShape(Circle()) }.accessibilityIdentifier("switchMenu")
                Button { picking = true } label: { Image(systemName: "plus").font(.system(size: 15, weight: .bold)).foregroundColor(.loam)
                    .frame(width: 34, height: 34).background(Color.sprout).clipShape(Circle()) }.accessibilityIdentifier("addTab")
            }.padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 6).background(p.bg)
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(current.platformName).font(.system(size: 12, weight: .semibold)).foregroundColor(p.soft).lineLimit(1)
                    if !AvatarStore.shared.desc(current.id).isEmpty { Text(AvatarStore.shared.desc(current.id)).font(.system(size: 11)).foregroundColor(p.soft).lineLimit(1) }
                }
                Spacer()
                Menu {
                    Button { editing = current } label: { Label("Edit name and icon", systemImage: "pencil") }
                    Button { show(conns.addWeb(id: current.provider, label: "", url: current.url)) } label: { Label("Add another \(current.platformName) account", systemImage: "person.badge.plus") }
                } label: { Image(systemName: "ellipsis").font(.system(size: 14, weight: .bold)).foregroundColor(p.ink).frame(width: 30, height: 28).background(p.chip).clipShape(Capsule()) }
                    .accessibilityIdentifier("webMore")
                Button { Task { await done() } } label: { Text(checking ? "Checking" : "I'm signed in").font(.system(size: 12, weight: .bold))
                    .foregroundColor(.loam).padding(.horizontal, 12).padding(.vertical, 6).background(Color.sprout).clipShape(Capsule()) }
                    .disabled(checking).accessibilityIdentifier("webDone")
            }.padding(.horizontal, 14).padding(.bottom, 6).background(p.bg)
            if !msg.isEmpty { Text(msg).font(.footnote).foregroundColor(p.soft).padding(.horizontal, 16).padding(.bottom, 6) }
            WebBrowser(account: current).id(current.id)
        }
        .background(p.bg.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) { KeyboardDownButton() }
        .onAppear { tabs.open(current); AlertRouter.shared.screenUp = true; AlertRouter.shared.viewing = current.id }
        .onDisappear { AlertRouter.shared.screenUp = false }
        .onChange(of: current.id) { AlertRouter.shared.viewing = $0 }
        .onReceive(AlertRouter.shared.$open) { if let a = $0 { show(a); AlertRouter.shared.open = nil } }
        .sheet(isPresented: $picking) { AddTabSheet(onPick: { show($0) }).environment(\.palette, p) }
        .sheet(item: $editing) { AccountEditor(account: $0, onRemoved: { if let n = tabs.accounts.first(where: { conns.account($0.id) != nil }) { current = n } else { dismiss() } }).environment(\.palette, p) }
    }
}

/// Every AI gets a real, honestly named route. No "coming soon" bucket.
/// Own key = you make a key at the AI's own page. Hand-off = the app copies your question,
/// opens that AI's own app or page, and you paste the answer back into a note. Nothing here
/// pretends to be a live link between the AI and this app. (HTML section 13 catalogue:
/// method, capabilities, permissions, setup and limitations stand on every entry.)
struct AIRoute: Identifiable {
    let id: String; let name: String; let kind: String; let how: String; let url: String
    let category: String; let caps: String; let perms: String; let limits: String
}
let aiRoutes: [AIRoute] = [
    AIRoute(id: "chatgpt", name: "ChatGPT / OpenAI", kind: "Own key", how: "Make a key, then use it in your AI app. Or hand off a question to ChatGPT.", url: "https://platform.openai.com/api-keys", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Needs credit on your OpenAI account to answer"),
    AIRoute(id: "claude", name: "Claude", kind: "Own key", how: "Make a key at Anthropic, or hand off a question to Claude.", url: "https://console.anthropic.com/settings/keys", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Needs credit on your Anthropic account to answer"),
    AIRoute(id: "gemini", name: "Gemini", kind: "Own key", how: "Make a key at Google AI Studio, or hand off a question to Gemini.", url: "https://aistudio.google.com/apikey", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Free keys have daily limits"),
    AIRoute(id: "perplexity", name: "Perplexity", kind: "Own key", how: "Make a key at Perplexity, paste it above, then test it.", url: "https://www.perplexity.ai", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Needs credit on your Perplexity account to answer"),
    AIRoute(id: "grok", name: "Grok", kind: "Own key", how: "Make a key at xAI, paste it above, then test it.", url: "https://grok.com", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Needs credit on your xAI account to answer"),
    AIRoute(id: "copilot", name: "Microsoft Copilot", kind: "Hand-off", how: "Copy your question, open Copilot, paste the answer back into a note.", url: "https://copilot.microsoft.com", category: "AI assistants and models", caps: "Hand-off questions and answers", perms: "Nothing is shared until you paste it", limits: "No live link. A carry, not a connection"),
    AIRoute(id: "claudecode", name: "Claude Code", kind: "Hand-off", how: "Copy a project prompt, paste it in Claude Code on your computer, bring the result back.", url: "https://claude.com/product/claude-code", category: "AI coding", caps: "Hand-off project prompts", perms: "Nothing is shared until you paste it", limits: "No live link in this build. The connection design is in the build notes"),
    AIRoute(id: "codex", name: "Codex", kind: "Hand-off", how: "Copy a project prompt, open Codex, bring the result back.", url: "https://chatgpt.com/codex", category: "AI coding", caps: "Hand-off project prompts", perms: "Nothing is shared until you paste it", limits: "No live link. A carry, not a connection"),
    AIRoute(id: "cursor", name: "Cursor", kind: "Hand-off", how: "Copy a project prompt, paste it in Cursor, bring the result back.", url: "https://cursor.com", category: "AI coding", caps: "Hand-off project prompts", perms: "Nothing is shared until you paste it", limits: "No live link. A carry, not a connection"),
    AIRoute(id: "polar", name: "Polar", kind: "Hand-off", how: "Copy a task prompt, open Polar, bring the result back.", url: "https://polarbrowser.com", category: "AI browsers and research", caps: "Hand-off task prompts", perms: "Nothing is shared until you paste it", limits: "No live link. A carry, not a connection"),
    AIRoute(id: "muse", name: "Muse", kind: "Own key", how: "Make a key at dev.meta.ai (Model API), paste it above, then test it.", url: "https://dev.meta.ai", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Meta Model API is pay as you go; public preview, US developers first"),
    AIRoute(id: "deepseek", name: "DeepSeek", kind: "Own key", how: "Make a key at platform.deepseek.com, paste it above, then test it.", url: "https://platform.deepseek.com", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Pay as you go at the provider"),
    AIRoute(id: "mistral", name: "Mistral", kind: "Own key", how: "Make a key at console.mistral.ai, paste it above, then test it.", url: "https://console.mistral.ai", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Pay as you go at the provider"),
    AIRoute(id: "groq", name: "Groq (Llama and more)", kind: "Own key", how: "Make a key at console.groq.com, paste it above, then test it.", url: "https://console.groq.com", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Pay as you go at the provider"),
    AIRoute(id: "openrouter", name: "OpenRouter (hundreds of models)", kind: "Own key", how: "Make a key at openrouter.ai, paste it above, then test it.", url: "https://openrouter.ai", category: "AI assistants and models", caps: "Answers in rooms · reads talks · files to-dos", perms: "Your key is used only for calls you start", limits: "Pay as you go at the provider"),
]
let aiCategories = ["AI assistants and models", "AI coding", "AI browsers and research"]

struct AIRoutesCard: View {
    @Environment(\.palette) var p
    @Environment(\.openURL) var openURL
    @ObservedObject private var conns = AIConnections.shared
    @State private var copiedId = ""
    var body: some View {
        Card {
            Text("EVERY AI HAS A WAY IN").font(.caption.monospaced().bold()).foregroundColor(p.soft)
            Text("Pick your AI").font(.title3.bold()).foregroundColor(p.ink)
            Text("Own key: you make a key at that AI. Hand-off: the app copies your question, opens that AI, and you paste the answer back. Hand-off is a carry, not a live link, and we say so.")
                .font(.subheadline).foregroundColor(p.soft)
            ForEach(aiCategories, id: \.self) { cat in
                Text(cat).font(.headline).foregroundColor(p.ink).padding(.top, 8)
                ForEach(aiRoutes.filter { $0.category == cat }) { r in routeRow(r) }
            }
        }
    }

    func routeRow(_ r: AIRoute) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(r.name).font(.body.weight(.semibold)).foregroundColor(p.ink); Spacer()
                Text(r.kind).font(.caption.bold()).foregroundColor(p.soft) }
            Text(r.how).font(.footnote).foregroundColor(p.soft)
            Text("Can do: " + r.caps).font(.footnote).foregroundColor(p.soft)
            Text("Permissions: " + r.perms).font(.footnote).foregroundColor(p.soft)
            Text("Limits: " + r.limits).font(.footnote).foregroundColor(p.soft)
            if let acc = conns.account(r.id), let res = conns.results[acc.id] {
                Text("Last tested: " + Store.niceTime(res.at)).font(.footnote).foregroundColor(p.soft)
            }
            Button(copiedId == r.id ? "Copied. Opening..." : (r.url.isEmpty ? "Copy question" : "Copy question and open")) {
                UIPasteboard.general.string = "Question from my NeedsMe Ai project:\n\n"
                copiedId = r.id
                if let u = URL(string: r.url), !r.url.isEmpty { openURL(u) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { copiedId = "" }
            }.buttonStyle(SoftButton()).accessibilityIdentifier("route-" + r.id)
        }.padding(.vertical, 6)
    }
}

/// Work tools (HTML section 13): named in the catalogue, with the truth about their path.
/// None has a supported way into this app yet, so none carries a Connect button.
struct WorkToolsCard: View {
    @Environment(\.palette) var p
    let tools = ["GitHub", "Notion", "Google Drive", "Slack", "Discord", "Email", "Calendar"]
    var body: some View {
        Card {
            Text("WORK TOOLS").font(.caption.monospaced().bold()).foregroundColor(p.soft)
            Text("Work and project tools").font(.title3.bold()).foregroundColor(p.ink)
            ForEach(tools, id: \.self) { t in
                VStack(alignment: .leading, spacing: 2) {
                    Text(t).font(.body.weight(.semibold)).foregroundColor(p.ink)
                    Text("No supported path into this app yet. Nothing here pretends to connect it.")
                        .font(.footnote).foregroundColor(p.soft)
                }.padding(.vertical, 4)
            }
        }
    }
}

/// Custom connections (HTML section 13): a user can write down an MCP server they own.
/// Saving a server never shows it as connected: it stands as saved on this phone only,
/// until a real connection test exists and passes.
struct CustomMCPCard: View {
    @Environment(\.palette) var p
    @State private var name = ""
    @State private var address = ""
    @State private var saved: [[String: String]] = CustomMCPCard.load()
    static let storeKey = "nm_custom_mcp"
    static func load() -> [[String: String]] {
        (UserDefaults.standard.array(forKey: storeKey) as? [[String: String]]) ?? []
    }
    func persist() { UserDefaults.standard.set(saved, forKey: CustomMCPCard.storeKey) }

    var body: some View {
        Card {
            Text("CUSTOM CONNECTION").font(.caption.monospaced().bold()).foregroundColor(p.soft)
            Text("Add your own MCP server").font(.title3.bold()).foregroundColor(p.ink)
            Text("Write down a server you own. It is saved on this phone only. Saved is not connected: a server here never shows as a live worker until a real test passes.")
                .font(.subheadline).foregroundColor(p.soft)
            ForEach(saved.indices, id: \.self) { i in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(saved[i]["name"] ?? "").font(.body.weight(.semibold)).foregroundColor(p.ink)
                        Text(saved[i]["address"] ?? "").font(.caption).foregroundColor(p.soft)
                        Text("Saved on this phone. Not connected.").font(.caption.bold()).foregroundColor(p.soft)
                    }
                    Spacer()
                    Button("Remove") { saved.remove(at: i); persist() }.buttonStyle(SoftButton())
                }.padding(.vertical, 4)
            }
            TextField("Server name", text: $name)
                .autocorrectionDisabled()
                .padding(10).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.line, lineWidth: 1))
                .foregroundColor(p.ink).accessibilityIdentifier("mcpName")
            TextField("Server address", text: $address)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .padding(10).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.line, lineWidth: 1))
                .foregroundColor(p.ink).accessibilityIdentifier("mcpAddress")
            Button("Save server") {
                let n = name.trimmingCharacters(in: .whitespaces)
                let a = address.trimmingCharacters(in: .whitespaces)
                guard !n.isEmpty, !a.isEmpty else { return }
                saved.append(["name": n, "address": a]); persist(); name = ""; address = ""
            }.buttonStyle(SoftButton()).accessibilityIdentifier("mcpSave")
        }
    }
}

/// Each own key provider holds a list of accounts. An account is its own key plus its own label.
/// Keys go to the Keychain only. The screen never shows a key again.
struct KeysCard: View {
    @Environment(\.palette) var p
    @Environment(\.openURL) var openURL
    @ObservedObject private var conns = AIConnections.shared
    @State private var drafts: [String: String] = [:]
    @State private var labels: [String: String] = [:]
    @State private var notes: [String: String] = [:]
    @State private var adding: String? = nil
    @State private var newLabel = ""
    @State private var newKey = ""

    var body: some View {
        Card {
            Text("YOUR OWN KEYS").font(.caption.monospaced().bold()).foregroundColor(p.soft)
            Text("Connect with your key").font(.title3.bold()).foregroundColor(p.ink)
            Text("Each key is one account with its own name. Two keys from one AI are two voices in a room. Your key stays on this phone, in the Keychain. It is never sent to our servers.")
                .font(.subheadline).foregroundColor(p.soft)
            ForEach(AIProvider.allCases) { prov in
                VStack(alignment: .leading, spacing: 10) {
                    Text(prov.name + " (" + prov.company + ")").font(.headline).foregroundColor(p.ink)
                    ForEach(conns.accounts(for: prov)) { a in row(a) }
                    if adding == prov.rawValue { addForm(prov) } else {
                        Button("Add another account") {
                            adding = prov.rawValue; newLabel = conns.nextDefaultLabel(prov); newKey = ""
                        }.buttonStyle(SoftButton()).accessibilityIdentifier("addAccount-" + prov.rawValue)
                    }
                    Button("Get a key") { if let u = URL(string: prov.keyPage) { openURL(u) } }
                        .buttonStyle(SoftButton()).accessibilityIdentifier("getKey-" + prov.rawValue)
                }.padding(.vertical, 8)
            }
        }
    }

    func field(_ placeholder: String, _ text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .autocorrectionDisabled()
            .padding(10).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.line, lineWidth: 1))
            .foregroundColor(p.ink)
    }
    func secure(_ placeholder: String, _ text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .autocorrectionDisabled().textInputAutocapitalization(.never)
            .padding(10).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.line, lineWidth: 1))
            .foregroundColor(p.ink)
    }

    func row(_ a: AIAccount) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(a.label).font(.body.weight(.semibold)).foregroundColor(p.ink)
                Spacer()
                Text(conns.status(a)).font(.caption.bold()).foregroundColor(p.ink)
                    .accessibilityIdentifier("status-" + a.id)
            }
            field("Name in rooms", Binding(get: { labels[a.id] ?? a.label }, set: { labels[a.id] = $0 }))
                .onSubmit { commitLabel(a) }
                .accessibilityIdentifier("label-" + a.id)
            secure(conns.hasKey(a) ? "A key is saved. Paste a new one to replace it." : "Paste your key",
                   Binding(get: { drafts[a.id] ?? "" }, set: { drafts[a.id] = $0 }))
                .accessibilityIdentifier("keyField-" + a.id)
            HStack(spacing: 8) {
                Button("Save") {
                    commitLabel(a)
                    let k = drafts[a.id] ?? ""
                    if k.isEmpty { notes[a.id] = conns.hasKey(a) ? "Name saved." : "Paste a key first." }
                    else { notes[a.id] = conns.save(k, for: a) ? "Saved on this phone." : "Could not save the key." }
                    drafts[a.id] = ""
                }.buttonStyle(SoftButton()).accessibilityIdentifier("saveKey-" + a.id)
                Button("Test connection") {
                    Task { await conns.test(a) }
                }.buttonStyle(SoftButton()).accessibilityIdentifier("testKey-" + a.id)
            }
            if conns.hasKey(a) || a.id != a.provider {
                Button(a.id == a.provider ? "Remove key" : "Remove account") {
                    conns.remove(a); notes[a.id] = "Removed."
                }.buttonStyle(SoftButton()).accessibilityIdentifier("removeKey-" + a.id)
            }
            if let n = notes[a.id], !n.isEmpty { Text(n).font(.footnote).foregroundColor(p.soft) }
        }
        .padding(12).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func commitLabel(_ a: AIAccount) {
        if let l = labels[a.id], !l.trimmingCharacters(in: .whitespaces).isEmpty { conns.rename(a, to: l) }
        labels[a.id] = nil
    }

    func addForm(_ prov: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New " + prov.name + " account").font(.subheadline.weight(.semibold)).foregroundColor(p.ink)
            field("Name in rooms", $newLabel).accessibilityIdentifier("newLabel-" + prov.rawValue)
            secure("Paste the key", $newKey).accessibilityIdentifier("newKey-" + prov.rawValue)
            HStack(spacing: 8) {
                Button("Save account") {
                    if conns.add(provider: prov, label: newLabel, key: newKey) != nil { adding = nil; newKey = ""; newLabel = "" }
                }.buttonStyle(SoftButton()).accessibilityIdentifier("saveNew-" + prov.rawValue)
                Button("Cancel") { adding = nil; newKey = "" }
                    .buttonStyle(SoftButton()).accessibilityIdentifier("cancelNew-" + prov.rawValue)
            }
        }
        .padding(12).background(p.chip).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
