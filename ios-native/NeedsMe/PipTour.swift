import SwiftUI

struct PipTour: View {
    var onClose: () -> Void
    @Environment(\.palette) var p
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var step = 0
    private let stops: [(String, String, String)] = [
        ("pip-welcome", "Hi, I'm Pip!", "I'll show you around in under a minute. You can skip any time."),
        ("pip-point-show", "Home", "Home shows what needs you first, then your projects."),
        ("pip-point-show", "Tasks", "All open and finished to-dos live here."),
        ("pip-point-show", "Notes & prompts", "Keep ideas and AI prompts in one place, sorted by project and AI."),
        ("pip-welcome", "Connect an AI", "Set up an AI in about 60 seconds. Tap Copy setup prompt for help."),
        ("pip-point-show", "Colours", "In More, pick Soft White, Dark, Soft Green or match your phone."),
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
        }
    }
    func go(_ d: Int) { if reduceMotion { step += d } else { withAnimation { step += d } } }
}
