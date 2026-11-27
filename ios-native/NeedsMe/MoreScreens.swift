import SwiftUI
import FirebaseAuth

/// The More menu. First the bug and feedback rows, then the profile, then the remaining
/// destinations in the HTML section 2 sidebar order, and Settings last with its gear icon.
/// No setting lives here or in Me: every setting stands in Settings (Settings law).
struct MoreView: View {
    var replayTour: () -> Void
    var goTab: (Int) -> Void = { _ in }
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p

    var initials: String {
        let parts = (store.savedName ?? "Me").split(separator: " ")
        return parts.prefix(2).map { String($0.prefix(1)) }.joined().uppercased()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    row("Report a bug", "ladybug.fill", "moreBug") { ReportView(kind: .bug) }
                    row("Send feedback", "text.bubble.fill", "moreFeedback") { ReportView(kind: .feedback) }
                    NavigationLink { MeView() } label: {
                        Card {
                            HStack(spacing: 12) {
                                ZStack { Circle().fill(p.chip); Text(initials).font(.headline).foregroundColor(p.ink) }
                                    .frame(width: 48, height: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.savedName ?? "Me").font(.headline).foregroundColor(p.ink)
                                    Text(store.user?.isAnonymous == true ? "Guest" : (store.user?.email ?? ""))
                                        .font(.subheadline).foregroundColor(p.soft)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(p.soft)
                            }
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("meRow")
                    Button { goTab(2) } label: { Card { HStack(spacing: 12) { Image(systemName: "rectangle.on.rectangle").foregroundColor(p.ink).frame(width: 24); Text("Projects").font(.headline).foregroundColor(p.ink); Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(p.soft) } } }.buttonStyle(.plain).accessibilityIdentifier("moreProjects")
                    Button { goTab(3) } label: { Card { HStack(spacing: 12) { Image(systemName: "doc.text").foregroundColor(p.ink).frame(width: 24); Text("Notes").font(.headline).foregroundColor(p.ink); Spacer(); Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(p.soft) } } }.buttonStyle(.plain).accessibilityIdentifier("moreNotes")
                    row("Tasks", "checkmark", "moreTasks") { TasksView() }
                    row("Changes", "list.bullet", "moreChanges") { ChangesView() }
                    row("AI Group Chat", "bubble.left.and.bubble.right", "moreGroupChat") { RoomsListView() }
                    row("Automations", "gearshape.2", "moreAutomations") { AutomationsView() }
                    row("Sessions", "clock.arrow.circlepath", "moreSessions") { SessionsView() }
                    row("Knowledge", "books.vertical", "moreKnowledge") { KnowledgeView() }
                    row("AIs", "sparkles", "moreConnections") { ConnectView() }
                    row("Operations", "waveform.path.ecg", "moreOperations") { OperationsView() }
                    Button("Replay Pip's guide", action: replayTour).buttonStyle(SoftButton())
                    row("Settings", "gearshape", "settingsRow") { SettingsView() }
                }.padding().padding(.bottom, 100)
            }
            .lookBg().navigationTitle("More")
        }
    }

    func row<D: View>(_ title: String, _ icon: String, _ id: String, @ViewBuilder _ dest: () -> D) -> some View {
        NavigationLink { dest() } label: {
            Card {
                HStack(spacing: 12) {
                    Image(systemName: icon).foregroundColor(p.ink).frame(width: 24)
                    Text(title).font(.headline).foregroundColor(p.ink)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(p.soft)
                }
            }
        }.buttonStyle(.plain).accessibilityIdentifier(id)
    }
}

/// Me: the profile only (HTML section 15). Name, email, sign-in methods, language, time zone.
/// No settings stand here.
struct MeView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var editingName = false
    @State private var nameText = ""

    var methods: [String] {
        let ids = store.user?.providerData.map { $0.providerID } ?? []
        let words = ids.map { id -> String in
            switch id {
            case "google.com": return "Google"
            case "apple.com": return "Apple"
            case "password": return "Email and password"
            default: return id
            }
        }
        return words.isEmpty ? ["Not listed on this phone"] : words
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Card {
                    Text("Your name").font(.headline).foregroundColor(p.ink)
                    if editingName {
                        TextField("Your name", text: $nameText).textFieldStyle(.roundedBorder).accessibilityIdentifier("nameEditField")
                        HStack {
                            Button("Cancel") { editingName = false }.buttonStyle(SoftButton())
                            Button("Save") { store.saveName(nameText); editingName = false }
                                .buttonStyle(PrimaryButton()).accessibilityIdentifier("nameEditSave")
                                .disabled(nameText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } else {
                        Button { nameText = store.savedName ?? ""; editingName = true } label: {
                            HStack { Text(store.savedName ?? "Add your name"); Spacer(); Text("Edit").font(.subheadline.bold()) }
                                .padding(.vertical, 6)
                        }.foregroundColor(p.ink).accessibilityIdentifier("nameRow")
                    }
                    Text("This is the name greetings and Pip use.").font(.caption).foregroundColor(p.soft)
                }
                Card {
                    Text("Sign-in").font(.headline).foregroundColor(p.ink)
                    Text(store.user?.isAnonymous == true ? "Guest (not saved to an email yet)" : (store.user?.email ?? ""))
                        .foregroundColor(p.ink)
                    ForEach(methods, id: \.self) { m in
                        HStack { Text("Signed in with"); Spacer(); Text(m).bold() }.foregroundColor(p.ink)
                    }
                }
                Card {
                    Text("Language and time").font(.headline).foregroundColor(p.ink)
                    HStack { Text("Language"); Spacer(); Text("English (Australia)").bold() }.foregroundColor(p.ink)
                    HStack { Text("Time zone"); Spacer(); Text(TimeZone.current.identifier).bold() }.foregroundColor(p.ink)
                }
            }.padding()
        }
        .hidesTabBar().lookBg().navigationTitle("Me").navigationBarTitleDisplayMode(.inline)
    }
}

/// Settings (Settings law): the entry is the gear icon in More; inside stand the theme, motion,
/// alerts, language, keys and accounts, AI permissions, Needs Me rules, privacy, log out and
/// delete account. Nothing here lives in Me.
struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @AppStorage("nm_theme") private var themeRaw = AppTheme.white.rawValue
    @AppStorage("nm_motion") private var motion = "system"
    @AppStorage("nm_digest") private var digest = "Daily"
    @AppStorage("nm_quiet") private var quiet = true
    @State private var confirmDelete = false
    private var firstLaunch: Double { UserDefaults.standard.double(forKey: "nm_first_launch") }
    @ObservedObject private var conns = AIConnections.shared
    var pipDays: Int { firstLaunch == 0 ? 1 : max(1, Int(Date().timeIntervalSince1970 - firstLaunch) / 86400 + 1) }
    var aiDays: Int { Set(store.tasks.filter { $0.isDone && !$0.doneBy.isEmpty && $0.doneBy != "user" }.map { $0.doneDate }).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    PipArt(pose: .welcome, height: 76)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.savedName ?? "You").font(.system(size: 20, weight: .bold)).foregroundColor(.loam)
                        Text("Pip has been with you \(pipDays) days").font(.system(size: 12.5)).foregroundColor(.muted)
                        Text("\(aiDays) days your AIs worked for you").font(.system(size: 12.5, weight: .bold)).foregroundColor(.sproutDeep)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.sproutMid, .sproutPale, .bone], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .accessibilityIdentifier("settingsProfile")
                HStack {
                    Text("YOUR AIS").font(.system(size: 13, weight: .bold)).tracking(0.7).foregroundColor(.muted)
                    Spacer()
                    NavigationLink { ConnectView() } label: { Text("+ ADD").font(.system(size: 13, weight: .bold)).tracking(0.7).foregroundColor(.sproutDeep) }
                        .accessibilityIdentifier("settingsAddAI")
                }.padding(.horizontal, 4).padding(.top, 4)
                if conns.connected.isEmpty {
                    Card { Text("No AI is connected yet.").font(.subheadline).foregroundColor(.muted) }
                }
                ForEach(conns.connected) { a in
                    HStack(spacing: 12) {
                        AIFace(label: a.label, size: 42)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(a.label).font(.system(size: 16, weight: .bold)).foregroundColor(.loam)
                            Text("Connected · in \(store.rooms.count) rooms").font(.system(size: 12)).foregroundColor(.muted)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(get: { !store.agentPaused(a.id) }, set: { on in var c = store.agentControl(a.id); c.paused = !on; store.setAgentControl(a.id, c) }))
                            .labelsHidden().tint(.sprout).accessibilityLabel("\(a.label) on")
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(p.card).clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.loam.opacity(0.06), radius: 8, y: 4)
                }
                SectionLabel(text: "Look")
                Card {
                    HStack(spacing: 12) {
                        ForEach([AppTheme.white, .beige, .dark]) { t in
                            Button { themeRaw = t.rawValue; store.saveTheme(t.rawValue) } label: {
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(t == .dark ? Color.loam : (t == .beige ? Color.bone : Color.sproutPale))
                                        .frame(height: 54)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.from(themeRaw) == t ? Color.sprout : Color.loam.opacity(0.1), lineWidth: AppTheme.from(themeRaw) == t ? 3 : 1))
                                    Text(t.label).font(.system(size: 12, weight: .semibold)).foregroundColor(.loam)
                                }
                            }.buttonStyle(.plain).accessibilityIdentifier("theme-" + t.rawValue)
                        }
                    }
                }
                SectionLabel(text: "Privacy")
                HStack(spacing: 12) {
                    Image(systemName: "lock").font(.system(size: 18)).foregroundColor(.loam)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your AIs are yours alone").font(.system(size: 15.5, weight: .bold)).foregroundColor(.loam)
                        Text("Never shared. Never mixed. Never seen by anyone else.").font(.system(size: 12)).foregroundColor(.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(p.card).clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.loam.opacity(0.06), radius: 8, y: 4)
                Button { store.signOut() } label: {
                    Text("Sign out").font(.system(size: 16, weight: .bold)).foregroundColor(.muted).frame(maxWidth: .infinity).padding(.vertical, 8)
                }.accessibilityIdentifier("signOut")
                SectionLabel(text: "More settings")
                Card {
                    Text("Motion").font(.headline).foregroundColor(p.ink)
                    Picker("Motion", selection: $motion) {
                        Text("System").tag("system"); Text("Reduced").tag("reduced"); Text("Off").tag("off")
                    }.pickerStyle(.segmented).accessibilityIdentifier("motionPicker")
                    Text("System follows your phone's Reduce Motion setting.").font(.caption).foregroundColor(p.soft)
                }
                Card {
                    Text("Alerts").font(.headline).foregroundColor(p.ink)
                    Toggle("Quiet hours (10pm to 7am)", isOn: $quiet).tint(p.accent).foregroundColor(p.ink)
                    Picker("Digest", selection: $digest) {
                        Text("Instant").tag("Instant"); Text("Daily").tag("Daily"); Text("Weekly").tag("Weekly")
                    }.pickerStyle(.segmented).accessibilityIdentifier("digestPicker")
                    Text("Saved on this phone. Push alerts are not switched on yet.").font(.caption).foregroundColor(p.soft)
                }
                Card {
                    Text("Language").font(.headline).foregroundColor(p.ink)
                    HStack { Text("App language"); Spacer(); Text("English (Australia)").bold() }.foregroundColor(p.ink)
                    Text("NeedsMe speaks English today.").font(.caption).foregroundColor(p.soft)
                }
                Card {
                    Text("Keys and accounts").font(.headline).foregroundColor(p.ink)
                    Text("Your AI keys and the accounts they belong to live in Connections.")
                        .font(.subheadline).foregroundColor(p.soft)
                    NavigationLink { ConnectView() } label: {
                        Text("Open Connections").font(.system(.body, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(p.chip).foregroundColor(p.ink).clipShape(Capsule())
                    }.accessibilityIdentifier("settingsKeys")
                }
                Card {
                    Text("AI permissions").font(.headline).foregroundColor(p.ink)
                    HStack { Text("Autonomy level"); Spacer(); Text("Draft").bold() }.foregroundColor(p.ink)
                    Text("Your AIs can read what you allow and prepare drafts. You approve before anything is sent or shared.")
                        .font(.subheadline).foregroundColor(p.soft)
                }
                Card {
                    Text("Needs Me rules").font(.headline).foregroundColor(p.ink)
                    Text("A Needs Me item is filed when an AI needs a login, an approval, an answer or a file, or when a run stops and cannot go on safely.")
                        .font(.subheadline).foregroundColor(p.ink)
                    Text("Progress-only updates never file a Needs Me item. They live in the room and in Sessions.")
                        .font(.subheadline).foregroundColor(p.soft)
                }
                Card {
                    Text("Privacy and your data").font(.headline).foregroundColor(p.ink)
                    Text("What we keep: your sign-in email, and the tasks and notes you write. They are saved to your own account.").font(.subheadline).foregroundColor(p.ink)
                    Text("What we do not keep: no AI keys, no passwords for other services, no location, no contacts.").font(.subheadline).foregroundColor(p.ink)
                    Text("Nobody else can see your tasks and notes. Your name and colour pick are saved to your account. Alert settings stay on this phone.").font(.subheadline).foregroundColor(p.ink)
                    Text("You can delete everything below. It cannot be undone.").font(.footnote).foregroundColor(p.soft)
                    ShareLink(item: store.exportText.isEmpty ? "No notes yet." : store.exportText) { Text("Export my notes") }.buttonStyle(SoftButton()).accessibilityIdentifier("exportNotes")
                    Button("Delete my account") { confirmDelete = true }
                        .buttonStyle(SoftButton()).accessibilityIdentifier("deleteAccount")
                    if !store.deleteMessage.isEmpty { Text(store.deleteMessage).font(.footnote).foregroundColor(p.ink).accessibilityIdentifier("deleteMessage") }
                }
                Card { LegalCard() }
                Card {
                    Text("Your devices").font(.headline).foregroundColor(p.ink)
                    Text("Devices that have signed in to your account.").font(.caption).foregroundColor(p.soft)
                    if store.devices.isEmpty {
                        Text("No device is recorded yet.").font(.subheadline).foregroundColor(p.soft)
                    }
                    ForEach(store.devices) { d in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(d.name.isEmpty ? d.model : d.name).font(.subheadline.bold()).foregroundColor(p.ink)
                                if d.id == Store.thisDeviceDocId {
                                    Text("This device").font(.caption.bold()).foregroundColor(p.ink)
                                        .accessibilityIdentifier("thisDevice")
                                }
                                Spacer()
                                Text(d.model).font(.caption).foregroundColor(p.soft)
                            }
                            Text("First seen \(d.firstSeen.map { Store.niceTime($0) } ?? "not recorded") · Last seen \(d.lastSeen.map { Store.niceTime($0) } ?? "not recorded")")
                                .font(.caption).foregroundColor(p.soft)
                        }.padding(.vertical, 4)
                    }
                }
                Card {
                    Text("Workspace").font(.headline).foregroundColor(p.ink)
                    Text("Your workspace holds one person: you.").font(.subheadline).foregroundColor(p.ink)
                    HStack { Text("You"); Spacer(); Text("Owner").bold() }.foregroundColor(p.ink)
                    Text("Your AIs, keys and data are never shared with anyone, and there are no invitations — sharing is off for good.")
                        .font(.subheadline).foregroundColor(p.soft)
                }.accessibilityIdentifier("workspaceCard")
                Card {
                    Text("Account").font(.headline).foregroundColor(p.ink)
                    Text(store.user?.isAnonymous == true ? "Guest (not saved to an email yet)" : (store.user?.email ?? "")).foregroundColor(p.soft)
                }
            }.padding()
        }
        .hidesTabBar()
        .lookBg().navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        .alert("Delete your account?", isPresented: $confirmDelete) {
            Button("Delete everything", role: .destructive) { Task { await store.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes your tasks, notes and sign-in. It cannot be undone.") }
    }
}

/// AI Workforce (HTML section 11): every connected AI as a worker, with its provider, model,
/// status, autonomy level and last test. A hand-off AI is never shown as a live worker.
struct WorkforceView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @ObservedObject private var conns = AIConnections.shared
    @State private var cancelNotes: [String: String] = [:]

    @State private var openWorker: String? = nil

    func worker(_ a: AIAccount) -> some View {
        let prov = a.kind
        let open = openWorker == a.id
        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .trailing) {
                Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { openWorker = open ? nil : a.id } } label: {
                    HStack(spacing: 12) {
                        IconTile(icon: prov.icon, color: prov.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.label).font(.system(.headline, design: .rounded)).foregroundColor(p.ink)
                            Text(conns.isConnected(a) ? "Awake. Say @\(a.label) to call it." : "Asleep. Connect it to wake it.").font(.caption).foregroundColor(p.soft)
                        }
                        Spacer(minLength: 110)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(p.card).clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(open ? prov.tint : Color.clear, lineWidth: 2))
                    .shadow(color: Color.loam.opacity(p.isDark ? 0 : 0.07), radius: 10, y: 5)
                }.buttonStyle(.plain).accessibilityIdentifier("worker-" + a.id)
                HStack(spacing: 8) {
                    Text(conns.status(a)).font(.system(size: 11, weight: .bold, design: .rounded)).lineLimit(1)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(conns.isConnected(a) ? Color.sprout : p.chip).foregroundColor(conns.isConnected(a) ? .loam : p.ink)
                        .clipShape(Capsule()).frame(maxWidth: 100)
                        .accessibilityIdentifier("workerStatus-" + a.id)
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .bold)).foregroundColor(prov.tint)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }.padding(.trailing, 14).allowsHitTesting(false)
            }
            if open {
                Card {
                    Text("\(a.kind.name) (\(a.kind.company)) · Model: \(AIClient.model(a.kind))")
                        .font(.subheadline).foregroundColor(p.soft)
                    Text("Autonomy: Draft. It can prepare work; you approve before anything is sent.")
                        .font(.subheadline).foregroundColor(p.ink)
                    Text("Can do: answer in rooms · read talks · file to-dos")
                        .font(.caption).foregroundColor(p.soft)
                    if let r = conns.results[a.id] {
                        Text("Last tested: \(Store.niceTime(r.at))").font(.caption).foregroundColor(p.soft)
                    } else {
                        Text("Not tested yet. Test it in Connections.").font(.caption).foregroundColor(p.soft)
                    }
                    if AIKeys.has(a.id) || AIConsent.testMode {
                        agentControls(a)
                    } else {
                        Text("Nothing to pause yet. This AI has no key or link.").font(.subheadline).foregroundColor(p.ink)
                        NavigationLink { ConnectView() } label: { Text("Set it up in Connections").font(.subheadline.bold()) }
                            .accessibilityIdentifier("workerSetup-" + a.id)
                    }
                }.transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PipSays(text: "Every AI you connect is a worker. Tap one to see what it may do.")
                Card {
                    Text("Connections is where you set an AI up: a key or a link. AI Workforce is where you decide what each connected AI may do: pause it, pick its projects, stop a run.").font(.subheadline).foregroundColor(p.ink)
                }
                FoldSection(id: "wake", icon: "bell.badge.fill", color: Color(hex: 0xF5A524), title: "How AIs wake each other", sub: "Tap to watch it happen") { WakeStory().padding(14).background(p.card).clipShape(RoundedRectangle(cornerRadius: 22)) }
                ForEach(conns.accounts) { a in worker(a) }
                FoldSection(id: "handoffs", icon: "arrow.left.arrow.right.circle.fill", color: Color(hex: 0xF55036), title: "Copy and paste only", sub: "Not live workers. You carry the answer back.") {
                    VStack(spacing: 8) {
                        ForEach(aiRoutes.filter { $0.kind == "Hand-off" }) { r in
                            Card {
                                Text(r.name).font(.headline).foregroundColor(p.ink)
                                Text("Hand-off only").font(.caption.bold()).foregroundColor(p.soft)
                            }
                        }
                    }
                }
            }.padding()
        }
        .hidesTabBar().lookBg().navigationTitle("AI Workforce")
    }

    /// Per agent controls (HTML section 11). Every control acts on the real machinery:
    /// pause and the tool switches bind room answers, talk reading and Loop filing in
    /// RoomEngine and Store; the project pick binds what the agent may file into; cancel
    /// drops a run that is going right now. Saved per owner in her settings space.
    @ViewBuilder func agentControls(_ a: AIAccount) -> some View {
        let ctrl = store.agentControl(a.id)
        VStack(alignment: .leading, spacing: 8) {
            if ctrl.paused {
                Text("\(a.label) is paused. It does not answer in rooms, read talks or file to-dos.")
                    .font(.subheadline.bold()).foregroundColor(p.ink)
                    .accessibilityIdentifier("agentPaused-" + a.id)
            }
            HStack(spacing: 8) {
                Button(ctrl.paused ? "Resume" : "Pause") {
                    var c = ctrl; c.paused.toggle(); store.setAgentControl(a.id, c)
                }.buttonStyle(SoftButton()).accessibilityIdentifier("agentPause-" + a.id)
                Button("Cancel run") {
                    let was = RoomEngine.cancelAgent(a)
                    cancelNotes[a.id] = was ? "Its run was cancelled. It will not post that reply."
                        : "\(a.label) has no run going right now."
                }.buttonStyle(SoftButton()).accessibilityIdentifier("agentCancel-" + a.id)
            }
            if let n = cancelNotes[a.id] {
                Text(n).font(.caption).foregroundColor(p.soft).accessibilityIdentifier("agentCancelNote-" + a.id)
            }
            Menu {
                Button("All projects") { var c = ctrl; c.projects = []; store.setAgentControl(a.id, c) }
                ForEach(store.projects, id: \.self) { name in
                    Button(name) {
                        var c = ctrl
                        if c.projects.isEmpty { c.projects = [name] }
                        else if c.projects.contains(name) { c.projects.removeAll { $0 == name } }
                        else { c.projects.append(name) }
                        store.setAgentControl(a.id, c)
                    }
                }
            } label: {
                Text(ctrl.projects.isEmpty ? "Projects it may file into: all" : "Projects it may file into: \(ctrl.projects.count) picked")
                    .font(.subheadline.bold()).foregroundColor(p.ink)
                    .padding(.horizontal, 12).padding(.vertical, 8).background(p.chip).clipShape(Capsule())
            }.accessibilityIdentifier("agentProjects-" + a.id)
            ForEach(AgentTool.all, id: \.id) { tool in
                HStack {
                    Text(tool.name).foregroundColor(p.ink)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { store.agentMay(a.id, tool: tool.id) },
                        set: { on in
                            var c = store.agentControl(a.id)
                            var tools = c.tools.isEmpty ? AgentTool.all.map { $0.id } : c.tools
                            if on { if !tools.contains(tool.id) { tools.append(tool.id) } }
                            else { tools.removeAll { $0 == tool.id } }
                            c.tools = tools.count == AgentTool.all.count ? [] : tools
                            store.setAgentControl(a.id, c)
                        }))
                        .labelsHidden()
                        .tint(p.accent)
                        .accessibilityIdentifier("agentTool-" + a.id + "-" + tool.id)
                }
            }
            Text("To remove this worker for good, remove its key in Connections.")
                .font(.caption).foregroundColor(p.soft)
        }
    }
}

/// Sessions (HTML sections 9 and 14): the durable record of rooms and sent prompts.
struct SessionsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p

    var sentPrompts: [NoteItem] {
        store.notes.filter { $0.isPrompt && $0.state == "sent" }
            .sorted { ($0.sentAt ?? .distantPast) > ($1.sentAt ?? .distantPast) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Rooms").font(.title3.bold()).foregroundColor(p.ink)
                if store.rooms.isEmpty { Text("No rooms yet.").foregroundColor(p.soft) }
                ForEach(store.rooms) { r in
                    NavigationLink { RoomView(room: r, store: store) } label: {
                        Card {
                            Text(r.title).font(.headline).foregroundColor(p.ink)
                            Text(r.project.isEmpty ? "Group chat room" : "Group chat room · \(r.project)")
                                .font(.caption).foregroundColor(p.soft)
                        }
                    }.buttonStyle(.plain)
                }
                Text("Prompts sent").font(.title3.bold()).foregroundColor(p.ink)
                if sentPrompts.isEmpty { Text("No prompts sent yet.").foregroundColor(p.soft) }
                ForEach(sentPrompts) { n in
                    Card {
                        Text(n.title).font(.headline).foregroundColor(p.ink)
                        Text("Sent to \(n.roomTitle.isEmpty ? "a room" : n.roomTitle) at \(n.sentAt.map { Store.niceTime($0) } ?? "an unknown time")")
                            .font(.caption).foregroundColor(p.soft)
                    }
                }
            }.padding()
        }
        .hidesTabBar().lookBg().navigationTitle("Sessions")
    }
}

/// Automations (HTML section 14): what already runs on its own, from real records.
/// A rules builder is not in this build, and the screen says so plainly.
struct AutomationsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p

    var waiting: [NoteItem] {
        store.notes.filter { $0.isPrompt && $0.state == "scheduled" }
            .sorted { ($0.scheduledFor ?? .distantFuture) < ($1.scheduledFor ?? .distantFuture) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Card {
                    Text("Scheduled prompts").font(.headline).foregroundColor(p.ink)
                    Text("These send on their own while NeedsMe is open.")
                        .font(.subheadline).foregroundColor(p.soft)
                    if waiting.isEmpty { Text("None scheduled right now.").font(.subheadline).foregroundColor(p.ink) }
                    ForEach(waiting) { n in
                        Text("\(n.title) · to \(n.roomTitle.isEmpty ? "a room" : n.roomTitle) at \(n.scheduledFor.map { Store.niceTime($0) } ?? "a set time")")
                            .font(.subheadline).foregroundColor(p.ink)
                    }
                }
                Card {
                    Text("Always on, in the app").font(.headline).foregroundColor(p.ink)
                    Text("When a room talk settles, the Loop reads it and files the work into Projects and Tasks.")
                        .font(.subheadline).foregroundColor(p.ink)
                    Text("When you open the app, anything an AI flagged for you while you were away is filed into Needs Me.")
                        .font(.subheadline).foregroundColor(p.ink)
                }
                Card {
                    Text("Rules you write yourself").font(.headline).foregroundColor(p.ink)
                    Text("A rule builder is not in this build yet. Nothing here pretends to be one.")
                        .font(.subheadline).foregroundColor(p.soft)
                }
            }.padding()
        }
        .hidesTabBar().lookBg().navigationTitle("Automations")
    }
}

/// Knowledge (HTML section 14): search across notes and prompts, and a context pack
/// for one project that can be shared as plain text.
struct KnowledgeView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @State private var query = ""
    @State private var packProject = ""

    var results: [NoteItem] {
        store.notes.filter { !$0.archived && (query.isEmpty || ($0.title + $0.body).localizedCaseInsensitiveContains(query)) }
    }
    var packText: String {
        let items = store.notes.filter { $0.projects.contains(packProject) && !$0.archived }
        if items.isEmpty { return "No notes or prompts in \(packProject) yet." }
        return "# Context pack: \(packProject)\n\n" + items.map { "## \($0.title)\n\n\($0.body)" }.joined(separator: "\n\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Search notes and prompts", text: $query)
                    .padding().background(p.card).clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.line, lineWidth: 1))
                    .accessibilityIdentifier("knowledgeSearch")
                ForEach(results) { n in
                    Card {
                        Text(n.title).font(.headline).foregroundColor(p.ink)
                        Text(n.isPrompt ? "Prompt" : "Note").font(.caption.bold()).foregroundColor(p.soft)
                        if !n.projects.isEmpty {
                            Text(n.projects.joined(separator: ", ")).font(.caption).foregroundColor(p.soft)
                        }
                        if !n.body.isEmpty { Text(NoteText.preview(n.body)).font(.subheadline).foregroundColor(p.soft).lineLimit(2) }
                    }
                }
                if results.isEmpty { Text("Nothing matches.").foregroundColor(p.soft) }
                Card {
                    Text("Context pack").font(.headline).foregroundColor(p.ink)
                    Text("One project's notes and prompts as one plain text pack, to hand to any AI.")
                        .font(.subheadline).foregroundColor(p.soft)
                    Picker("Project", selection: $packProject) {
                        Text("Pick a project").tag("")
                        ForEach(store.projects, id: \.self) { Text($0).tag($0) }
                    }.accessibilityIdentifier("knowledgeProject")
                    if !packProject.isEmpty {
                        ShareLink(item: packText) { Text("Share context pack") }.buttonStyle(SoftButton())
                            .accessibilityIdentifier("packShare")
                    }
                }
            }.padding()
        }
        .hidesTabBar().lookBg().navigationTitle("Knowledge")
    }
}

/// Operations (HTML section 14): health read from the app's own real state.
struct OperationsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @ObservedObject private var conns = AIConnections.shared

    var buildText: String {
        let d = Bundle.main.infoDictionary
        let v = d?["CFBundleShortVersionString"] as? String ?? "?"
        let b = d?["CFBundleVersion"] as? String ?? "?"
        return "Version \(v), build \(b)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Card {
                    Text("Connections health").font(.headline).foregroundColor(p.ink)
                    Text(conns.accounts.map { "\($0.label): \(conns.status($0))" }.joined(separator: "\n"))
                        .font(.subheadline).foregroundColor(p.ink)
                        .accessibilityIdentifier("operationsStatus")
                }
                Card {
                    Text("Your data").font(.headline).foregroundColor(p.ink)
                    Text("\(store.tasks.count) tasks · \(store.notes.filter { !$0.isPrompt }.count) notes · \(store.notes.filter { $0.isPrompt }.count) prompts · \(store.rooms.count) rooms")
                        .font(.subheadline).foregroundColor(p.ink)
                    Text("Your records live in your own account space. Export a copy any time from Settings, under Privacy and your data.")
                        .font(.subheadline).foregroundColor(p.soft)
                }
                Card {
                    Text("App").font(.headline).foregroundColor(p.ink)
                    Text(buildText).font(.subheadline).foregroundColor(p.ink)
                }
            }.padding()
        }
        .hidesTabBar().lookBg().navigationTitle("Operations")
    }
}
