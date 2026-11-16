import SwiftUI
import FirebaseAuth

/// The More menu. First row is the kindness revolution (her word, 14 Nov 15:19: it stands
/// at the very top of the menu, above everything else). Then the profile, then the remaining
/// destinations in the HTML section 2 sidebar order, and Settings last with its gear icon.
/// No setting lives here or in Me: every setting stands in Settings (Settings law).
struct MoreView: View {
    var replayTour: () -> Void
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
                    row("Join the AI kindness revolution", "heart.fill", "kindnessItem") { KindnessView() }
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
                    row("Tasks", "checkmark", "moreTasks") { TasksView() }
                    row("Changes", "list.bullet", "moreChanges") { ChangesView() }
                    row("AI Workforce", "person.2", "moreWorkforce") { WorkforceView() }
                    row("AI Group Chat", "bubble.left.and.bubble.right", "moreGroupChat") { RoomsListView() }
                    row("Automations", "gearshape.2", "moreAutomations") { AutomationsView() }
                    row("Sessions", "clock.arrow.circlepath", "moreSessions") { SessionsView() }
                    row("Knowledge", "books.vertical", "moreKnowledge") { KnowledgeView() }
                    row("Connections", "link", "moreConnections") { ConnectView() }
                    row("Operations", "waveform.path.ecg", "moreOperations") { OperationsView() }
                    Button("Replay Pip's guide", action: replayTour).buttonStyle(SoftButton())
                    row("Settings", "gearshape", "settingsRow") { SettingsView() }
                }.padding()
            }
            .background(p.bg).navigationTitle("More")
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
        .background(p.bg).navigationTitle("Me").navigationBarTitleDisplayMode(.inline)
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Card {
                    Text("Colours").font(.headline).foregroundColor(p.ink)
                    ForEach(AppTheme.allCases) { t in
                        Button { themeRaw = t.rawValue; store.saveTheme(t.rawValue) } label: {
                            HStack { Text(t.label); Spacer(); if AppTheme.from(themeRaw) == t { SproutBox(on: true, size: 22) } }
                                .padding(.vertical, 6)
                        }.foregroundColor(p.ink).accessibilityIdentifier("theme-" + t.rawValue)
                    }
                }
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
                    NavigationLink { WorkforceView() } label: {
                        Text("See your AI workers").font(.system(.body, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(p.chip).foregroundColor(p.ink).clipShape(Capsule())
                    }.accessibilityIdentifier("settingsWorkforce")
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
                    Button("Sign out") { store.signOut() }.buttonStyle(SoftButton()).accessibilityIdentifier("signOut")
                }
            }.padding()
        }
        .background(p.bg).navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        .alert("Delete your account?", isPresented: $confirmDelete) {
            Button("Delete everything", role: .destructive) { Task { await store.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes your tasks, notes and sign-in. It cannot be undone.") }
    }
}

/// Join the AI kindness revolution (build 341, item 8), in NeedsMe's own skin: Pip, Sprout
/// colours, the rainbow filling with people, message clouds, and the warm line. Giving itself
/// happens on the Safari giving page, never in the app: the app takes no card details and
/// shows no payment form, and nothing unlocks for giving.
struct KindnessView: View {
    @Environment(\.palette) var p

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 8) {
                    PipImage(size: 72)
                    Text("Join the AI kindness revolution").font(.title2.bold()).foregroundColor(p.ink)
                        .multilineTextAlignment(.center)
                    Text("NeedsMe Ai is free to use. Kind people help keep it that way, so the next person who needs a hand can have one too.")
                        .font(.subheadline).foregroundColor(p.soft).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity)
                RainbowView()
                Text("Be one of the first kind humans")
                    .font(.headline).foregroundColor(p.ink)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("kindHumans")
                Text("Your gift keeps the AI help free for the next person who needs a hand.")
                    .font(.subheadline).foregroundColor(p.ink).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Card {
                    Text("The kindness wall").font(.headline).foregroundColor(p.ink)
                    Text("Names and kind words from people who gave stand here, and stay here.")
                        .font(.subheadline).foregroundColor(p.soft)
                    Text("No messages yet. Yours could be the first.")
                        .font(.subheadline).foregroundColor(p.ink)
                        .accessibilityIdentifier("kindnessWall")
                }
                Card {
                    Text("Your gifts").font(.headline).foregroundColor(p.ink)
                    Text("What you give is private to you. NeedsMe never shows your own total to anyone else.")
                        .font(.subheadline).foregroundColor(p.soft)
                }
                Button("Give to keep it free") {}
                    .buttonStyle(PrimaryButton()).disabled(true)
                    .accessibilityIdentifier("giveButton")
                Text("Giving opens in Safari, on the kindness giving page. The page is being finished, and this button opens it the moment it is live. NeedsMe never takes card details in the app.")
                    .font(.caption).foregroundColor(p.soft)
                    .accessibilityIdentifier("giveNote")
            }.padding()
        }
        .background(p.bg).navigationTitle("AI Kindness").navigationBarTitleDisplayMode(.inline)
    }
}

/// The rainbow of record: seven bands in the kindness colours, filling with people
/// (people, never money), and plain clouds over the top. Still by design, so reduced
/// motion changes nothing.
struct RainbowView: View {
    @Environment(\.palette) var p
    static let bands: [UInt32] = [0xFF6B6B, 0xFF9F43, 0xFFD93D, 0x6BCB77, 0x4D96FF, 0x9B5DE5, 0xFF6BAE]
    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { i in
                Circle().trim(from: 0.5, to: 1.0)
                    .stroke(Color(hex: RainbowView.bands[i]), lineWidth: 12)
                    .frame(width: 252 - CGFloat(i) * 26, height: 252 - CGFloat(i) * 26)
                    .offset(y: 62)
            }
            ForEach(0..<7, id: \.self) { i in
                let a = Double(i) / 6.0 * Double.pi
                ZStack {
                    Circle().fill(Color(hex: RainbowView.bands[i])).frame(width: 15, height: 15)
                    Circle().fill(Color(hex: RainbowView.bands[i])).frame(width: 7, height: 7).offset(y: -11)
                }
                .offset(x: -cos(a) * 104, y: 62 - sin(a) * 104)
            }
            Capsule().fill(p.card).overlay(Capsule().stroke(p.line, lineWidth: 1))
                .frame(width: 74, height: 26).offset(x: -86, y: -18)
            Capsule().fill(p.card).overlay(Capsule().stroke(p.line, lineWidth: 1))
                .frame(width: 62, height: 22).offset(x: 88, y: -34)
            Capsule().fill(p.card).overlay(Capsule().stroke(p.line, lineWidth: 1))
                .frame(width: 54, height: 20).offset(x: 10, y: -52)
        }
        .frame(maxWidth: .infinity).frame(height: 150)
        .accessibilityHidden(true)
    }
}

/// AI Workforce (HTML section 11): every connected AI as a worker, with its provider, model,
/// status, autonomy level and last test. A hand-off AI is never shown as a live worker.
struct WorkforceView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @ObservedObject private var conns = AIConnections.shared
    @State private var cancelNotes: [String: String] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Every AI you connect becomes a worker here. A worker answers in rooms, reads talks and files to-dos, at the level you allow.")
                    .font(.subheadline).foregroundColor(p.soft)
                ForEach(conns.accounts) { a in
                    Card {
                        HStack {
                            Text(a.label).font(.headline).foregroundColor(p.ink)
                            Spacer()
                            Text(conns.status(a)).font(.caption.bold()).foregroundColor(p.ink)
                                .accessibilityIdentifier("workerStatus-" + a.id)
                        }
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
                        agentControls(a)
                    }
                }
                Text("Hand-off only").font(.title3.bold()).foregroundColor(p.ink)
                Text("These are not live workers. You carry a question out and paste the answer back, in Connections.")
                    .font(.subheadline).foregroundColor(p.soft)
                ForEach(aiRoutes.filter { $0.kind == "Hand-off" }) { r in
                    Card {
                        Text(r.name).font(.headline).foregroundColor(p.ink)
                        Text("Hand-off only").font(.caption.bold()).foregroundColor(p.soft)
                    }
                }
            }.padding()
        }
        .background(p.bg).navigationTitle("AI Workforce")
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
        .background(p.bg).navigationTitle("Sessions")
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
        .background(p.bg).navigationTitle("Automations")
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
        .background(p.bg).navigationTitle("Knowledge")
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
        .background(p.bg).navigationTitle("Operations")
    }
}
