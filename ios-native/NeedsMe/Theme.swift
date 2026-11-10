import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case white, dark, beige, brand, system
    var id: String { rawValue }
    var label: String {
        switch self { case .white: "White"; case .dark: "Dark"; case .beige: "Beige"; case .brand: "Brand"; case .system: "Device" }
    }
    var scheme: ColorScheme? {
        switch self { case .white, .beige, .brand: .light; case .dark: .dark; case .system: nil }
    }
    var palette: Palette {
        switch self { case .white: .white; case .dark: .dark; case .beige: .beige; case .brand: .brand; case .system: .white }
    }
    /// Reads a stored pick. The old Soft Green value ("green") moves to Brand. Unknown or empty is White.
    static func from(_ raw: String) -> AppTheme {
        if raw == "green" { return .brand }
        return AppTheme(rawValue: raw) ?? .white
    }
}

struct Palette {
    var bg: Color, card: Color, ink: Color, soft: Color, accent: Color, accentInk: Color, chip: Color, line: Color
    var isDark: Bool { bg == Palette.dark.bg }
    static let white = Palette(bg: Color(hex: 0xF4EFE7), card: Color(hex: 0xFFFEFA), ink: Color(hex: 0x16120E), soft: Color(hex: 0x6B6252), accent: Color(hex: 0xA8C256), accentInk: Color(hex: 0x16120E), chip: Color(hex: 0xEFE8DA), line: Color(hex: 0xD8D0C0))
    static let dark = Palette(bg: Color(hex: 0x1A1612), card: Color(hex: 0x262019), ink: Color(hex: 0xF3ECDF), soft: Color(hex: 0xA79C8C), accent: Color(hex: 0xA8C256), accentInk: Color(hex: 0x16120E), chip: Color(hex: 0x353026), line: Color(hex: 0x40392D))
    // Beige: a real warm beige family. Ground, card, ink, accent and chip all sit in the same sand and brown hues.
    static let beige = Palette(bg: Color(hex: 0xE6D8BC), card: Color(hex: 0xF3EAD6), ink: Color(hex: 0x2A1F10), soft: Color(hex: 0x57472E), accent: Color(hex: 0x7A4E1D), accentInk: Color(hex: 0xFFF8EA), chip: Color(hex: 0xD6C4A0), line: Color(hex: 0xBCA77D))
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
