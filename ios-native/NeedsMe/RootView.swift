import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @AppStorage("nm_tour_done") private var tourDone = false
    @State private var showTour = false
    @State private var tab = 0
    @State private var tabBeforeTour = 0
    @State private var askClosedNow = false
    @State private var nameDraft = ""
    static let launchId = UUID().uuidString
    @AppStorage("nm_motion") private var motion = "system"
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            p.bg.ignoresSafeArea()
            if store.user == nil {
                AuthView()
            } else {
                MainTabs(tab: $tab, replayTour: { tabBeforeTour = tab; showTour = true })
                    .onAppear { if !tourDone { tabBeforeTour = tab; showTour = true } }
                if showNameAsk { nameAsk }
                if showTour {
                    PipTour(onClose: { tourDone = true; showTour = false; tab = tabBeforeTour }, goTo: { tab = $0 })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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
                    PipImage(size: 44)
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
            .padding(18).background(p.card).clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(p.line))
            .padding(12).padding(.bottom, 56).shadow(radius: 12, y: 4)
            .accessibilityElement(children: .contain).accessibilityIdentifier("nameAsk")
        }
    }
}

/// The mobile shape of the HTML section 2 order: bottom tabs are Home, Needs Me, Projects,
/// Notes and More. More opens the remaining destinations in the same sidebar order.
struct MainTabs: View {
    @Binding var tab: Int
    var replayTour: () -> Void
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    var body: some View {
        TabView(selection: $tab) {
            HomeView().tabItem { Label("Home", systemImage: "house") }.tag(0)
            NeedsMeView().tabItem { Label("Needs Me", systemImage: "bell") }.tag(1)
                .badge(store.needs.filter { $0.status == "open" }.count)
            ProjectsView().tabItem { Label("Projects", systemImage: "folder") }.tag(2)
            NotesView().tabItem { Label("Notes", systemImage: "note.text") }.tag(3)
            MoreView(replayTour: replayTour).tabItem { Label("More", systemImage: "ellipsis") }.tag(4)
        }
        .tint(p.ink)
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
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(p.card).clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(p.line, lineWidth: 1))
    }
}
