import SwiftUI

struct PipTour: View {
    var onClose: () -> Void
    /// Takes the user to the screen Pip is talking about (tab index: 0 Home, 1 Needs Me, 2 Projects, 3 Notes, 4 More).
    var goTo: (Int) -> Void = { _ in }
    private let tabs = [0, 0, 1, 2, 3, 4, 0]
    @Environment(\.palette) var p
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @AppStorage("nm_motion") private var motion = "system"
    @State private var step = 0
    @State private var bounce = false
    private let looks: [(String, Color)] = [
        ("hand.wave.fill", Color(hex: 0xF5A524)), ("house.fill", Color(hex: 0x4285F4)), ("bell.badge.fill", Color(hex: 0xD97757)),
        ("square.grid.2x2.fill", Color(hex: 0x10A37F)), ("note.text", Color(hex: 0x8B5CF6)), ("ellipsis.circle.fill", Color(hex: 0xF55036)),
        ("sparkles", Color(hex: 0xA8C256)),
    ]
    private let stops: [(String, String, String)] = [
        ("pip-welcome", "Hi, I'm Pip!", "I'll show you around in under a minute. You can skip any time."),
        ("pip-point-show", "Home", "Home shows what needs you first, then your projects."),
        ("pip-point-show", "Needs Me", "Anything that needs your decision waits here, grouped by project."),
        ("pip-point-show", "Projects", "Every project has its own colour and shows how much is done."),
        ("pip-point-show", "Notes & prompts", "Keep ideas and AI prompts in one place, sorted by project and AI."),
        ("pip-welcome", "More", "Tasks, your AIs, Changes and Settings live in More. Connect an AI in about 60 seconds, in Connections."),
        ("pip-celebrate", "You are ready!", "Next, I will help you connect your first AI. It takes about a minute."),
    ]
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    PipImage(name: stops[step].0, size: 72)
                        .offset(y: bounce ? -4 : 4)
                        .animation((reduceMotion || motion != "system") ? Animation?.none : Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: bounce)
                    IconTile(icon: looks[step].0, color: looks[step].1, size: 30).offset(x: 10, y: 4)
                }
                Text("Tour \(step + 1) of \(stops.count)").font(.caption.bold()).foregroundColor(p.soft)
                StepDots(count: stops.count, current: step, color: looks[step].1)
                Text(stops[step].1).font(.system(.title3, design: .rounded).weight(.heavy)).foregroundColor(p.ink)
                Text(stops[step].2).multilineTextAlignment(.center).foregroundColor(p.ink)
                HStack {
                    Button("Skip guide", action: onClose).foregroundColor(p.soft).font(.subheadline.bold())
                    Spacer()
                    if step > 0 { Button("Back") { go(-1) }.buttonStyle(SoftButton()).frame(maxWidth: 100) }
                    Button(step == stops.count - 1 ? "Finish tour" : "Next") { step == stops.count - 1 ? onClose() : go(1) }
                        .buttonStyle(PrimaryButton()).frame(maxWidth: 130)
                }
            }
            .padding(18).background(p.card).clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(p.line))
            .padding(12).shadow(radius: 12, y: 4)
            .onAppear { bounce = true }
            .accessibilityElement(children: .contain).accessibilityLabel("Pip's guide")
            // Sliding right goes back one step, like the back swipe everywhere else.
            .gesture(DragGesture(minimumDistance: 30).onEnded { v in
                if v.translation.width > 60, abs(v.translation.height) < 60, step > 0 { go(-1) }
            })
        }
    }
    func go(_ d: Int) {
        let next = min(max(step + d, 0), tabs.count - 1)
        if reduceMotion || motion != "system" { step = next } else { withAnimation { step = next } }
        goTo(tabs[next])
    }
}
