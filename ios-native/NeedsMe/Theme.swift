import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case white, dark, green, system
    var id: String { rawValue }
    var label: String {
        switch self { case .white: "Soft White"; case .dark: "Dark"; case .green: "Soft Green"; case .system: "Device" }
    }
    var scheme: ColorScheme? {
        switch self { case .white, .green: .light; case .dark: .dark; case .system: nil }
    }
    var palette: Palette {
        switch self { case .white: .white; case .dark: .dark; case .green: .green; case .system: .white }
    }
}

struct Palette {
    var bg: Color, card: Color, ink: Color, soft: Color, accent: Color, accentInk: Color, chip: Color, line: Color
    var isDark: Bool { bg == Palette.dark.bg }
    static let white = Palette(bg: Color(hex: 0xF4EFE7), card: Color(hex: 0xFFFEFA), ink: Color(hex: 0x16120E), soft: Color(hex: 0x6B6252), accent: Color(hex: 0xA8C256), accentInk: Color(hex: 0x16120E), chip: Color(hex: 0xEFE8DA), line: Color(hex: 0xD8D0C0))
    static let dark = Palette(bg: Color(hex: 0x1A1612), card: Color(hex: 0x262019), ink: Color(hex: 0xF3ECDF), soft: Color(hex: 0xA79C8C), accent: Color(hex: 0xA8C256), accentInk: Color(hex: 0x16120E), chip: Color(hex: 0x353026), line: Color(hex: 0x40392D))
    static let green = Palette(bg: Color(hex: 0xE4F0DD), card: Color(hex: 0xF7FBF3), ink: Color(hex: 0x14201A), soft: Color(hex: 0x3F5545), accent: Color(hex: 0xA8C256), accentInk: Color(hex: 0x14201A), chip: Color(hex: 0xD3E6C9), line: Color(hex: 0xB9D0AE))
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
