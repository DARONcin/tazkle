import AppKit
import SwiftUI

public enum TazkleSpacing {
    public static let xSmall: CGFloat = 4
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
    public static let xLarge: CGFloat = 24
    public static let xxLarge: CGFloat = 32
}

public enum TazkleRadius {
    public static let control: CGFloat = 8
    public static let card: CGFloat = 12
    public static let panel: CGFloat = 16
}

/// Colores físicos de la marca. Las vistas de producto deben preferir
/// `TazkleColors`, que expresa la intención semántica del color.
public enum TazkleBrandColors {
    public static let blue = Color(hex: 0x4F7CFF)
    public static let violet = Color(hex: 0x8C6BFF)
    public static let cyan = Color(hex: 0x6DD6E7)
    public static let amber = Color(hex: 0xF1B84B)
    public static let green = Color(hex: 0x75C66B)
}

public enum TazkleColors {
    /// Derivados semánticos de los pigmentos aprobados. Mantienen la familia
    /// cromática de la marca y elevan el contraste cuando aparecen sobre las
    /// superficies claras u oscuras del producto.
    public static let actionPrimary = Color(
        light: 0x315CCB,
        dark: 0x668CFF
    )
    public static let relationship = Color(
        light: 0x6546CC,
        dark: 0x9A7CFF
    )
    public static let assistantProposal = Color(
        light: 0x08788A,
        dark: 0x6DD6E7
    )
    public static let warning = Color(
        light: 0x825600,
        dark: 0xF1B84B
    )
    public static let success = Color(
        light: 0x2F762A,
        dark: 0x75C66B
    )

    /// Los riesgos críticos usan ámbar con icono, texto y patrón explícitos.
    /// No se introduce un sexto pigmento fuera de la paleta aprobada.
    public static let critical = warning

    public static func canvas(for scheme: ColorScheme, highContrast: Bool = false) -> Color {
        switch (scheme, highContrast) {
        case (.dark, true): Color(hex: 0x02070B)
        case (.dark, false): Color(hex: 0x08131D)
        case (.light, true): Color.white
        case (.light, false): Color(hex: 0xF3F6F8)
        @unknown default: Color(hex: 0x08131D)
        }
    }

    public static func panel(for scheme: ColorScheme, highContrast: Bool = false) -> Color {
        switch (scheme, highContrast) {
        case (.dark, true): Color(hex: 0x0B1720)
        case (.dark, false): Color(hex: 0x132430)
        case (.light, true): Color(hex: 0xF8FAFC)
        case (.light, false): Color.white
        @unknown default: Color(hex: 0x132430)
        }
    }

    public static func elevated(for scheme: ColorScheme, highContrast: Bool = false) -> Color {
        switch (scheme, highContrast) {
        case (.dark, true): Color(hex: 0x162A37)
        case (.dark, false): Color(hex: 0x1A303E)
        case (.light, true): Color(hex: 0xE1E8EE)
        case (.light, false): Color(hex: 0xE8EEF3)
        @unknown default: Color(hex: 0x1A303E)
        }
    }

    public static func primaryContent(for scheme: ColorScheme, highContrast: Bool = false) -> Color {
        switch (scheme, highContrast) {
        case (.dark, true): Color.white
        case (.dark, false): Color(hex: 0xEDF2F6)
        case (.light, true): Color(hex: 0x071118)
        case (.light, false): Color(hex: 0x14212A)
        @unknown default: Color(hex: 0xEDF2F6)
        }
    }

    public static func secondaryContent(for scheme: ColorScheme, highContrast: Bool = false) -> Color {
        switch (scheme, highContrast) {
        case (.dark, true): Color(hex: 0xD5DEE4)
        case (.dark, false): Color(hex: 0xA9B7C0)
        case (.light, true): Color(hex: 0x253743)
        case (.light, false): Color(hex: 0x50616D)
        @unknown default: Color(hex: 0xA9B7C0)
        }
    }

    public static func separator(for scheme: ColorScheme, highContrast: Bool = false) -> Color {
        if highContrast {
            return scheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.45)
        }
        return scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.12)
    }
}

private struct TazkleHighContrastKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var tazkleHighContrast: Bool {
        get { self[TazkleHighContrastKey.self] }
        set { self[TazkleHighContrastKey.self] = newValue }
    }
}

private extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(
            nsColor: NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [.darkAqua, .aqua])
                return NSColor(hex: match == .darkAqua ? dark : light)
            }
        )
    }
}

private extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
