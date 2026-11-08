import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @AppStorage("nm_tour_done") private var tourDone = false
    @State private var showTour = false
    @AppStorage("nm_motion") private var motion = "system"
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            p.bg.ignoresSafeArea()
            if store.user == nil {
                AuthView()
            } else {
                MainTabs(replayTour: { showTour = true })
                    .onAppear { if !tourDone { showTour = true } }
                if showTour {
                    PipTour(onClose: { tourDone = true; showTour = false })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation((motion != "system" || reduceMotion) ? nil : .easeInOut(duration: 0.25), value: showTour)
    }
}

struct MainTabs: View {
    var replayTour: () -> Void
    @Environment(\.palette) var p
    var body: some View {
        TabView {
            HomeView().tabItem { Label("Home", systemImage: "house") }
            TasksView().tabItem { Label("Tasks", systemImage: "checkmark") }
            NotesView().tabItem { Label("Notes", systemImage: "note.text") }
            ConnectView().tabItem { Label("AI", systemImage: "sparkles") }
            MoreView(replayTour: replayTour).tabItem { Label("More", systemImage: "ellipsis") }
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

struct MoreView: View {
    var replayTour: () -> Void
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @AppStorage("nm_theme") private var themeRaw = AppTheme.white.rawValue
    @AppStorage("nm_motion") private var motion = "system"
    @AppStorage("nm_digest") private var digest = "Daily"
    @AppStorage("nm_quiet") private var quiet = true
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Card {
                        Text("Colours").font(.headline).foregroundColor(p.ink)
                        ForEach(AppTheme.allCases) { t in
                            Button { themeRaw = t.rawValue } label: {
                                HStack { Text(t.label); Spacer(); if themeRaw == t.rawValue { Image(systemName: "checkmark.circle.fill") } }
                                    .padding(.vertical, 6)
                            }.foregroundColor(p.ink)
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
                        Text("Account").font(.headline).foregroundColor(p.ink)
                        Text(store.user?.isAnonymous == true ? "Guest (not saved to an email yet)" : (store.user?.email ?? "")).foregroundColor(p.soft)
                        Button("Replay Pip's guide", action: replayTour).buttonStyle(SoftButton())
                        Button("Sign out") { store.signOut() }.buttonStyle(SoftButton())
                    }
                }.padding()
            }
            .background(p.bg).navigationTitle("More")
        }
    }
}
