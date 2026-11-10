import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @AppStorage("nm_tour_done") private var tourDone = false
    @State private var showTour = false
    @State private var tab = 0
    @AppStorage("nm_motion") private var motion = "system"
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            p.bg.ignoresSafeArea()
            if store.user == nil {
                AuthView()
            } else {
                MainTabs(tab: $tab, replayTour: { tab = 0; showTour = true })
                    .onAppear { if !tourDone { showTour = true } }
                if showTour {
                    PipTour(onClose: { tourDone = true; showTour = false; tab = 0 }, goTo: { tab = $0 })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation((motion != "system" || reduceMotion) ? nil : .easeInOut(duration: 0.25), value: showTour)
    }
}

struct MainTabs: View {
    @Binding var tab: Int
    var replayTour: () -> Void
    @Environment(\.palette) var p
    var body: some View {
        TabView(selection: $tab) {
            HomeView().tabItem { Label("Home", systemImage: "house") }.tag(0)
            TasksView().tabItem { Label("Tasks", systemImage: "checkmark") }.tag(1)
            NotesView().tabItem { Label("Notes", systemImage: "note.text") }.tag(2)
            ConnectView().tabItem { Label("AI", systemImage: "sparkles") }.tag(3)
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

struct MoreView: View {
    var replayTour: () -> Void
    @EnvironmentObject var store: Store
    @Environment(\.palette) var p
    @AppStorage("nm_theme") private var themeRaw = AppTheme.white.rawValue
    @AppStorage("nm_motion") private var motion = "system"
    @AppStorage("nm_digest") private var digest = "Daily"
    @AppStorage("nm_quiet") private var quiet = true
    @State private var confirmDelete = false
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
                        Text("Privacy and your data").font(.headline).foregroundColor(p.ink)
                        Text("What we keep: your sign-in email, and the tasks and notes you write. They are saved to your own account.").font(.subheadline).foregroundColor(p.ink)
                        Text("What we do not keep: no AI keys, no passwords for other services, no location, no contacts.").font(.subheadline).foregroundColor(p.ink)
                        Text("Nobody else can see your tasks and notes. Alert settings and colours stay on this phone.").font(.subheadline).foregroundColor(p.ink)
                        Text("You can delete everything below. It cannot be undone.").font(.footnote).foregroundColor(p.soft)
                        ShareLink(item: store.exportText.isEmpty ? "No notes yet." : store.exportText) { Text("Export my notes") }.buttonStyle(SoftButton()).accessibilityIdentifier("exportNotes")
                        Button("Delete my account") { confirmDelete = true }
                            .buttonStyle(SoftButton()).accessibilityIdentifier("deleteAccount")
                        if !store.deleteMessage.isEmpty { Text(store.deleteMessage).font(.footnote).foregroundColor(p.ink).accessibilityIdentifier("deleteMessage") }
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
            .alert("Delete your account?", isPresented: $confirmDelete) {
                Button("Delete everything", role: .destructive) { Task { await store.deleteAccount() } }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This removes your tasks, notes and sign-in. It cannot be undone.") }
        }
    }
}
