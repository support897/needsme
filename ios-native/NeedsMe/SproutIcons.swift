import SwiftUI

/// The Sprout icon family, drawn from the Pip art: warm black rounded forms with the sprout leaf pair in brand green.
/// Used in place of stock glyphs on every new surface.
enum SproutColor {
    static let green = Color(hex: 0xA8C256)
}

/// The two leaves and stem from the Pip sprout, in the same curves as the Pip art (a 204 by 108 drawing box).
struct SproutLeaves: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 102 - 9, y: 50, width: 18, height: 58), cornerSize: CGSize(width: 9, height: 9))
        p.move(to: CGPoint(x: 102, y: 56))
        p.addCurve(to: CGPoint(x: 0, y: 18), control1: CGPoint(x: 67, y: 7), control2: CGPoint(x: 22, y: 0))
        p.addCurve(to: CGPoint(x: 102, y: 56), control1: CGPoint(x: 14, y: 60), control2: CGPoint(x: 64, y: 74))
        p.move(to: CGPoint(x: 102, y: 56))
        p.addCurve(to: CGPoint(x: 204, y: 18), control1: CGPoint(x: 137, y: 7), control2: CGPoint(x: 182, y: 0))
        p.addCurve(to: CGPoint(x: 102, y: 56), control1: CGPoint(x: 190, y: 60), control2: CGPoint(x: 140, y: 74))
        let s = min(r.width / 204, r.height / 108)
        let t = CGAffineTransform(translationX: r.midX - 102 * s, y: r.midY - 54 * s).scaledBy(x: s, y: s)
        return p.applying(t)
    }
}

/// Checklist box. Off: an ink rounded outline. On: a filled ink box with the green sprout inside.
struct SproutBox: View {
    var on: Bool
    var size: CGFloat = 24
    @Environment(\.palette) var p
    var body: some View {
        ZStack {
            if on {
                RoundedRectangle(cornerRadius: size * 0.32).fill(p.ink)
                SproutLeaves().fill(SproutColor.green).frame(width: size * 0.66, height: size * 0.66)
            } else {
                RoundedRectangle(cornerRadius: size * 0.32).stroke(p.ink, lineWidth: size * 0.09)
            }
        }
        .frame(width: size, height: size).accessibilityHidden(true)
    }
}

/// The "new" mark: a green rounded square with an ink plus, in the Pip button shape.
struct SproutPlus: View {
    var size: CGFloat = 30
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.34).fill(SproutColor.green)
            Capsule().fill(Color(hex: 0x16120E)).frame(width: size * 0.5, height: size * 0.12)
            Capsule().fill(Color(hex: 0x16120E)).frame(width: size * 0.12, height: size * 0.5)
        }
        .frame(width: size, height: size).accessibilityHidden(true)
    }
}
