import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @AppStorage("nm_tour_done") private var tourDone = false
    @State private var showTour = false
    @State private var tab = 0
    @State private var tabBeforeTour = 0
    @State private var askClosedNow = false
    @State private var showWizard = false
    @State private var nameDraft = ""
    static let launchId = UUID().uuidString
    @AppStorage("nm_motion") private var motion = "system"
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            p.bg.ignoresSafeArea()
            if p.gradient { LookBackdrop().ignoresSafeArea() }
            if store.user == nil {
                AuthView()
            } else {
                MainTabs(tab: $tab, replayTour: { tabBeforeTour = tab; showTour = true })
                    .onAppear { if !tourDone { tabBeforeTour = tab; showTour = true } }
                if showNameAsk { nameAsk }
                if showTour {
                    PipTour(onClose: {
                        tourDone = true; showTour = false; tab = tabBeforeTour
                        let testing = CommandLine.arguments.contains("-uitest-reset") && !CommandLine.arguments.contains("-uitest-wizard")
                        if !testing && AIConnections.shared.connected.isEmpty { showWizard = true }
                    }, goTo: { tab = $0 })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .fullScreenCover(isPresented: $showWizard) { SetupWizard(onClose: { showWizard = false }).environment(\.palette, p) }
        .task(id: store.user?.uid) {
            while !Task.isCancelled {
                if store.user != nil { await BridgeSync.shared.poll(store: store) }
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
        .onChange(of: store.user?.email) { email in if email != nil { tab = 0 } }
        .onChange(of: store.user?.uid) { _ in askClosedNow = false; nameDraft = "" }
        .animation((motion != "system" || reduceMotion) ? nil : .easeInOut(duration: 0.25), value: showTour)
    }
}

extension RootView {
    private var askKey: String { "nm_nameask_" + (store.user?.uid ?? "none") }

    /// Pip asks once the guide is out of the way and nothing is saved. If it is closed unanswered it is offered
    /// once more on the next launch only (never the same session), then never again.
    var showNameAsk: Bool {
        guard store.user != nil, store.cloudThemeLoaded, store.savedName == nil, !showTour, !askClosedNow else { return false }
        if CommandLine.arguments.contains("-uitest-noask") { return false }
        let v = UserDefaults.standard.string(forKey: askKey) ?? ""
        if v == "done" { return false }
        if v.hasPrefix("closed1:") { return v != "closed1:" + RootView.launchId }
        return true
    }

    func closeAsk() {
        let v = UserDefaults.standard.string(forKey: askKey) ?? ""
        UserDefaults.standard.set(v.hasPrefix("closed1:") ? "done" : "closed1:" + RootView.launchId, forKey: askKey)
        askClosedNow = true
    }

    var nameAsk: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    PipArt(pose: .welcome, height: 52)
                    Text("What's your name?").font(.headline).foregroundColor(p.ink)
                }
                TextField("Your name", text: $nameDraft).textFieldStyle(.roundedBorder).textContentType(.givenName)
                    .accessibilityIdentifier("nameField")
                HStack {
                    Button("Not now") { closeAsk() }.foregroundColor(p.soft).font(.subheadline.bold()).accessibilityIdentifier("nameClose")
                    Spacer()
                    Button("Save") {
                        store.saveName(nameDraft)
                        UserDefaults.standard.set("done", forKey: askKey)
                        askClosedNow = true
                    }
                    .buttonStyle(PrimaryButton()).frame(maxWidth: 130).accessibilityIdentifier("nameSave")
                    .disabled(nameDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(18).background(p.card).clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(12).padding(.bottom, 56).shadow(color: Color.loam.opacity(0.18), radius: 16, y: 6)
            .accessibilityElement(children: .contain).accessibilityIdentifier("nameAsk")
        }
    }
}

/// The approved bottom bar: Home, Needs Me, one big round plus, Projects, Notes. Everything else
/// (Tasks, Rooms, Settings and the rest) opens from the Sprout N on Home, the same More list as before.
struct MainTabs: View {
    @Binding var tab: Int
    var replayTour: () -> Void
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @StateObject private var router = TabRouter()
    @State private var title = ""
    @State private var area = ""

    func layer<V: View>(_ i: Int, @ViewBuilder _ v: () -> V) -> some View {
        v().opacity(tab == i ? 1 : 0).allowsHitTesting(tab == i).accessibilityHidden(tab != i)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                layer(0) { HomeView(goMore: { tab = 4 }) }
                layer(1) { NeedsMeView() }
                layer(2) { ProjectsView() }
                layer(3) { NotesView() }
                layer(4) { MoreView(replayTour: replayTour) }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: router.hideBar ? 0 : 84) }
            if !router.hideBar { LookTabBar(tab: $tab) }
        }
        .environmentObject(router)
        .sheet(isPresented: $router.adding) {
            NavigationStack {
                Form {
                    TextField("What needs doing?", text: $title)
                    Picker("Project", selection: $area) { Text("None").tag(""); ForEach(store.projects, id: \.self) { Text($0).tag($0) } }
                    TextField("Or a new project name", text: $area)
                }
                .navigationTitle("New task")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { router.adding = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { store.addTask(title, area: area, due: ""); title = ""; area = ""; router.adding = false }
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }.presentationDetents([.medium])
        }
    }
}

struct PipImage: View {
    var name = "pip-welcome"
    var size: CGFloat = 64
    var body: some View {
        Image(name).resizable().scaledToFit().frame(width: size, height: size)
            .clipShape(Circle()).accessibilityHidden(true)
    }
}

struct Card<Content: View>: View {
    @Environment(\.palette) var p
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(p.card).clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.loam.opacity(p.isDark ? 0 : 0.07), radius: 12, y: 6)
    }
}
