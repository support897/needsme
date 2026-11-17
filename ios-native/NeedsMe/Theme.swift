import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case white, dark, beige, brand, system
    var id: String { rawValue }
    var label: String {
        switch self { case .white: "Brand"; case .dark: "Loam"; case .beige: "Bone"; case .brand: "Brand"; case .system: "Device" }
    }
    var scheme: ColorScheme? {
        switch self { case .white, .beige, .brand: .light; case .dark: .dark; case .system: nil }
    }
    var palette: Palette {
        switch self { case .white: .white; case .dark: .dark; case .beige: .beige; case .brand: .brand; case .system: .white }
    }
    /// Reads a stored pick. The old Soft Green value ("green") moves to Brand. Unknown or empty is White.
    static func from(_ raw: String) -> AppTheme {
        if raw == "green" || raw == "brand" { return .white }
        return AppTheme(rawValue: raw) ?? .white
    }
}

struct Palette {
    var bg: Color, card: Color, ink: Color, soft: Color, accent: Color, accentInk: Color, chip: Color, line: Color
    var onInk: Color = Color(hex: 0xF0EAE0)
    var gradient: Bool = false
    var isDark: Bool { bg == Palette.dark.bg }
    // White (default): pure white page and card surfaces, soft neutral dividers and chips (HTML section 3).
    static let white = Palette(bg: .clear, card: Color(hex: 0xFBF8F2), ink: Color(hex: 0x16120E), soft: Color(hex: 0x6B6252), accent: Color(hex: 0xA8C256), accentInk: Color(hex: 0x16120E), chip: Color(hex: 0xEFE9DC), line: Color(hex: 0xE6DFCF), gradient: true)
    static let dark = Palette(bg: Color(hex: 0x16120E), card: Color(hex: 0x262019), ink: Color(hex: 0xF3ECDF), soft: Color(hex: 0xA79C8C), accent: Color(hex: 0xA8C256), accentInk: Color(hex: 0x16120E), chip: Color(hex: 0x353026), line: Color(hex: 0x40392D))
    // Beige: a real warm beige family. Ground, card, ink, accent and chip all sit in the same sand and brown hues.
    static let beige = Palette(bg: Color(hex: 0xF0EAE0), card: Color(hex: 0xFBF8F2), ink: Color(hex: 0x16120E), soft: Color(hex: 0x6B6252), accent: Color(hex: 0xA8C256), accentInk: Color(hex: 0x16120E), chip: Color(hex: 0xE6DFCF), line: Color(hex: 0xD9D0BC))
    // Brand: the Sprout tokens already in this file. Sprout green 0xA8C256 is the accent, warm black 0x16120E is the ink and the accent ink.
    static let brand = Palette(bg: Color(hex: 0xDCE8B4), card: Color(hex: 0xF6FAE8), ink: Color(hex: 0x16120E), soft: Color(hex: 0x44512A), accent: Color(hex: 0xA8C256), accentInk: Color(hex: 0x16120E), chip: Color(hex: 0xC4D88A), line: Color(hex: 0xA9BF6E))
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

private struct PaletteKey: EnvironmentKey { static let defaultValue = Palette.white }
extension EnvironmentValues {
    var palette: Palette { get { self[PaletteKey.self] } set { self[PaletteKey.self] = newValue } }
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.palette) var p
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.body, design: .rounded).weight(.bold))
            .padding(.vertical, 14).frame(maxWidth: .infinity)
            .background(p.accent.opacity(configuration.isPressed ? 0.8 : 1)).foregroundColor(p.accentInk)
            .clipShape(Capsule())
    }
}
struct SoftButton: ButtonStyle {
    @Environment(\.palette) var p
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.body, design: .rounded).weight(.semibold))
            .padding(.vertical, 12).padding(.horizontal, 16).frame(maxWidth: .infinity)
            .background(p.chip.opacity(configuration.isPressed ? 0.7 : 1)).foregroundColor(p.ink)
            .clipShape(Capsule())
    }
}

/// The approved look (design round, Ilse's yes 17 Nov): soft Bone ground, rounded cards with weight,
/// Sprout used only for "can be done / was just done", Loam as ink. Brand colours and soft tints of them only.
extension Color {
    static let loam = Color(hex: 0x16120E)
    static let bone = Color(hex: 0xF0EAE0)
    static let sprout = Color(hex: 0xA8C256)
    static let sproutPale = Color(hex: 0xDDE7B6)   // Sprout tint
    static let sproutMid = Color(hex: 0xC9DA8E)    // Sprout tint
    static let sproutDeep = Color(hex: 0x44512A)   // Sprout shade, for small text
    static let cardTone = Color(hex: 0xFBF8F2)     // lighter Bone
    static let muted = Color(hex: 0x6B6252)
    static let faint = Color(hex: 0x8A8070)
}

/// The soft page ground of the default (Brand) look.
struct LookBackdrop: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: 0xF7F2E8), Color(hex: 0xF0EAE0), Color(hex: 0xE8EBCB)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// The door's own ground: a little more Sprout toward the bottom.
struct DoorBackdrop: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: 0xF7F2E8), Color(hex: 0xEEF0D2), Color(hex: 0xDDE7B6)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// Pip, from the repo's own art (never redrawn). Transparent-background copies of the same files.
enum PipPose: String { case welcome = "pip-clear", point = "pip-point-clear", celebrate = "pip-celebrate-clear" }

struct PipArt: View {
    var pose: PipPose = .welcome
    var height: CGFloat = 120
    var body: some View {
        Image(pose.rawValue).resizable().scaledToFit().frame(height: height).accessibilityHidden(true)
    }
}

/// The Sprout N mark (dark tile).
struct SproutMark: View {
    var size: CGFloat = 38
    var body: some View {
        Image("sprout-mark").resizable().scaledToFit().frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28)).accessibilityHidden(true)
    }
}

enum FaceState { case none, working, needs, done }

/// A face for each AI: a plain monogram disc in brand colours, with its state drawn round it.
struct AIFace: View {
    let label: String
    var size: CGFloat = 34
    var state: FaceState = .none
    var short: String {
        let l = label.lowercased()
        if l.hasPrefix("claude") { return "Cl" }
        if l.hasPrefix("chatgpt") { return "Ch" }
        if l.hasPrefix("gemini") { return "Ge" }
        return String(label.prefix(2))
    }
    var fill: Color {
        let l = label.lowercased()
        if l.hasPrefix("claude") { return .loam }
        if l.hasPrefix("gemini") { return .sprout }
        if l.hasPrefix("chatgpt") { return .bone }
        return .sproutPale
    }
    var textColor: Color { fill == .loam ? .bone : .loam }
    var body: some View {
        ZStack {
            Circle().fill(fill)
            Text(short).font(.system(size: size * 0.38, weight: .heavy)).foregroundColor(textColor)
            if state == .working { Circle().stroke(Color.sprout, style: StrokeStyle(lineWidth: 2.5, dash: [4, 3])).padding(-4) }
            if state == .needs { Circle().stroke(Color.sprout, lineWidth: 2.5).padding(-4) }
            if state == .done { Circle().stroke(Color.loam.opacity(0.5), lineWidth: 2.5).padding(-4) }
            if state == .needs {
                Circle().fill(Color.sprout).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.cardTone, lineWidth: 2.5))
                    .offset(x: size * 0.36, y: -size * 0.36)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: Color.cardTone, radius: 0, x: 0, y: 0)
        .accessibilityLabel(label)
    }
}

struct FaceStack: View {
    let labels: [String]
    var size: CGFloat = 34
    var states: [String: FaceState] = [:]
    var body: some View {
        HStack(spacing: -size * 0.26) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, l in
                AIFace(label: l, size: size, state: states[l] ?? .none)
                    .overlay(Circle().stroke(Color.cardTone, lineWidth: 2))
            }
        }
    }
}

/// Pill tabs: the picked one is filled with Loam.
struct PillTabs: View {
    let items: [String]
    @Binding var selection: Int
    var idPrefix = "pill-"
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, t in
                Button { selection = i } label: {
                    Text(t).font(.system(size: 13.5, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(selection == i ? Color.loam : Color.clear)
                        .foregroundColor(selection == i ? Color.bone : Color.muted)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: selection == i ? Color.loam.opacity(0.25) : .clear, radius: 7, y: 3)
                }.buttonStyle(.plain).accessibilityIdentifier(idPrefix + t)
            }
        }
        .padding(5).background(Color.loam.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

/// A ring that fills. Progress is drawn, not just written.
struct RingGauge<Inner: View>: View {
    var progress: Double
    var size: CGFloat = 92
    var line: CGFloat = 11
    @ViewBuilder var inner: Inner
    var body: some View {
        ZStack {
            Circle().stroke(Color.sproutPale, lineWidth: line)
            Circle().trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(Color.sprout, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            inner
        }.frame(width: size, height: size)
    }
}

/// A flat progress bar.
struct LookBar: View {
    var progress: Double
    var tone: Color = .loam
    var height: CGFloat = 9
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.loam.opacity(0.1))
                Capsule().fill(tone).frame(width: max(g.size.width * CGFloat(min(max(progress, 0), 1)), progress > 0 ? height : 0))
                    .animation(.easeOut(duration: 0.6), value: progress)
            }
        }.frame(height: height)
    }
}

/// The round check circle for task rows.
struct CheckCircle: View {
    var on: Bool
    var working = false
    var size: CGFloat = 26
    var body: some View {
        ZStack {
            if on {
                Circle().fill(Color.loam)
                Image(systemName: "checkmark").font(.system(size: size * 0.5, weight: .heavy)).foregroundColor(.sprout)
            } else {
                Circle().stroke(working ? Color.sprout : Color(hex: 0xC9C2B2), lineWidth: 2.5)
            }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct CountPill: View {
    let text: String
    var light = false
    var body: some View {
        Text(text).font(.system(size: 12, weight: .heavy)).padding(.horizontal, 10).padding(.vertical, 4)
            .background(light ? Color.sproutPale : Color.loam)
            .foregroundColor(light ? Color.loam : Color.sprout)
            .clipShape(Capsule())
    }
}

struct SectionLabel: View {
    let text: String
    var trailing: String = ""
    var body: some View {
        HStack {
            Text(text.uppercased()).font(.system(size: 13, weight: .bold)).tracking(0.7).foregroundColor(.muted)
            Spacer()
            if !trailing.isEmpty { Text(trailing.uppercased()).font(.system(size: 13, weight: .bold)).tracking(0.7).foregroundColor(.muted) }
        }.padding(.horizontal, 4).padding(.top, 6)
    }
}

/// A row on a soft card, optionally lifted with Sprout when it needs the person.
struct LookRow<Lead: View, Trail: View>: View {
    var needs = false
    @ViewBuilder var lead: Lead
    let title: String
    var sub: String = ""
    @ViewBuilder var trail: Trail
    var body: some View {
        HStack(spacing: 12) {
            lead
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.loam).multilineTextAlignment(.leading)
                if !sub.isEmpty { Text(sub).font(.system(size: 11.5)).foregroundColor(.muted).multilineTextAlignment(.leading) }
            }
            Spacer(minLength: 4)
            trail
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            Group {
                if needs { LinearGradient(colors: [.sproutMid, Color(hex: 0xE8EDCB), Color(hex: 0xF4F0E4)], startPoint: .leading, endPoint: .trailing) }
                else { Color.cardTone }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.loam.opacity(0.05), radius: 8, y: 4)
    }
}

/// Large screen title with a quiet line under it, drawn the same on every tab screen.
struct LookTitle: View {
    let title: String
    var sub: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(sub).font(.system(size: 12.5)).foregroundColor(.muted).opacity(sub.isEmpty ? 0 : 1)
        }
    }
}

struct SearchIconButton: View {
    @Binding var on: Bool
    var body: some View {
        Button { on.toggle() } label: {
            Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .semibold)).foregroundColor(.loam)
                .frame(width: 38, height: 38).background(Color.cardTone).clipShape(RoundedRectangle(cornerRadius: 13))
                .shadow(color: Color.loam.opacity(0.07), radius: 6, y: 3)
        }.accessibilityLabel("Search").accessibilityIdentifier("searchButton")
    }
}

// MARK: the bottom bar: Home, Needs Me, big round plus, Projects, Notes

final class TabRouter: ObservableObject {
    @Published var hideCount = 0
    var hideBar: Bool { hideCount > 0 }
    @Published var adding = false
    @Published var noteTick = 0
}

struct LookTabBar: View {
    @Binding var tab: Int
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: TabRouter

    func item(_ idx: Int, _ icon: String, _ name: String) -> some View {
        Button { tab = idx } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon).font(.system(size: 20, weight: .medium))
                    if idx == 1 && needsCount > 0 {
                        Circle().fill(Color.sprout).frame(width: 9, height: 9).overlay(Circle().stroke(Color.cardTone, lineWidth: 2)).offset(x: 5, y: -2)
                    }
                }
                Text(name).font(.system(size: 10.5, weight: .semibold))
                Circle().fill(tab == idx ? Color.sprout : Color.clear).frame(width: 5, height: 5)
            }
            .foregroundColor(tab == idx ? Color.loam : Color.faint).frame(width: 58)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name).accessibilityIdentifier("tab-" + name)
        .accessibilityAddTraits(tab == idx ? .isSelected : [])
    }
    var needsCount: Int { store.needs.filter { $0.status == "open" }.count }

    var body: some View {
        HStack {
            item(0, "house", "Home")
            item(1, "exclamationmark.circle", "Needs Me")
            Button { if tab == 3 { router.noteTick += 1 } else { router.adding = true } } label: {
                Image(systemName: "plus").font(.system(size: 26, weight: .heavy)).foregroundColor(.loam)
                    .frame(width: 62, height: 62).background(Color.sprout).clipShape(Circle())
                    .overlay(Circle().stroke(Color(hex: 0xF7F2E8), lineWidth: 6))
                    .shadow(color: Color.sprout.opacity(0.5), radius: 12, y: 8)
            }
            .offset(y: -22).frame(width: 66)
            .accessibilityLabel(tab == 3 ? "New" : "Add a task").accessibilityIdentifier(tab == 3 ? "newItem" : "addButton")
            item(2, "rectangle.on.rectangle", "Projects")
            item(3, "doc.text", "Notes")
        }
        .padding(.horizontal, 10).frame(height: 66)
        .background(Color.cardTone).clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: Color.loam.opacity(0.14), radius: 14, y: 8)
        .padding(.horizontal, 14).padding(.bottom, 6)
    }
}

/// Hides the bottom bar on a pushed screen (a room, Settings) the way the approved pictures show them.
struct HideBarModifier: ViewModifier {
    @EnvironmentObject var router: TabRouter
    func body(content: Content) -> some View {
        content.onAppear { router.hideCount += 1 }.onDisappear { router.hideCount = max(0, router.hideCount - 1) }
    }
}
extension View { func hidesTabBar() -> some View { modifier(HideBarModifier()) } }

/// A card-shaped icon button for headers.
struct HeaderIcon: View {
    let system: String
    var dot = false
    var body: some View {
        Image(systemName: system).font(.system(size: 18, weight: .medium)).foregroundColor(.loam)
            .frame(width: 38, height: 38).background(Color.cardTone).clipShape(RoundedRectangle(cornerRadius: 13))
            .shadow(color: Color.loam.opacity(0.07), radius: 6, y: 3)
            .overlay(alignment: .topTrailing) {
                if dot { Circle().fill(Color.sprout).frame(width: 10, height: 10).overlay(Circle().stroke(Color.cardTone, lineWidth: 2)).offset(x: -8, y: 8) }
            }
    }
}


/// Chat bubble with one small corner (works on iOS 16.0).
struct BubbleShape: Shape {
    var tl: CGFloat, tr: CGFloat, bl: CGFloat, br: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + tl, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - tr, y: r.minY))
        p.addArc(center: CGPoint(x: r.maxX - tr, y: r.minY + tr), radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - br))
        p.addArc(center: CGPoint(x: r.maxX - br, y: r.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX + bl, y: r.maxY))
        p.addArc(center: CGPoint(x: r.minX + bl, y: r.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + tl))
        p.addArc(center: CGPoint(x: r.minX + tl, y: r.minY + tl), radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}
