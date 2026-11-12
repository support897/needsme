import SwiftUI

struct PipTour: View {
    var onClose: () -> Void
    /// Takes the user to the screen Pip is talking about (tab index: 0 Home, 1 Tasks, 2 Notes, 3 AI, 4 More).
    var goTo: (Int) -> Void = { _ in }
    private let tabs = [0, 0, 1, 2, 3, 4, 0]
    @Environment(\.palette) var p
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @AppStorage("nm_motion") private var motion = "system"
    @State private var step = 0
    private let stops: [(String, String, String)] = [
        ("pip-welcome", "Hi, I'm Pip!", "I'll show you around in under a minute. You can skip any time."),
        ("pip-point-show", "Home", "Home shows what needs you first, then your projects."),
        ("pip-point-show", "Tasks", "All open and finished to-dos live here."),
        ("pip-point-show", "Notes & prompts", "Keep ideas and AI prompts in one place, sorted by project and AI."),
        ("pip-welcome", "Connect an AI", "Set up an AI in about 60 seconds. Tap Copy setup prompt for help."),
        ("pip-point-show", "Colours", "In More, pick White, Dark, Beige, Brand or match your phone."),
        ("pip-celebrate", "You are ready!", "Pick one small step to begin."),
    ]
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                PipImage(name: stops[step].0, size: 72)
                Text("Tour \(step + 1) of \(stops.count)").font(.caption.bold()).foregroundColor(p.soft)
                ProgressView(value: Double(step + 1), total: Double(stops.count)).tint(p.accent)
                Text(stops[step].1).font(.headline).foregroundColor(p.ink)
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
