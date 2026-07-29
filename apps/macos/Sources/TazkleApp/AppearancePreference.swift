import SwiftUI

enum AppearancePreference: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark
    case highContrast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automático"
        case .light: "Claro"
        case .dark: "Oscuro"
        case .highContrast: "Mayor contraste"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .automatic, .highContrast: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var usesHighContrastTokens: Bool { self == .highContrast }
}
