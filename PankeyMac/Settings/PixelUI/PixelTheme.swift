// PixelTheme.swift — 8-bit color palette, typography, and spacing constants
import SwiftUI

enum PixelTheme {
    // MARK: - Color palette (8-bit inspired)
    static let background = Color(hex: "#1a1a2e")   // Deep navy
    static let surface    = Color(hex: "#16213e")   // Slightly lighter
    static let accent     = Color(hex: "#00ff9f")   // Neon green
    static let accentDim  = Color(hex: "#00cc7a")
    static let text       = Color(hex: "#e0e0e0")
    static let textDim    = Color(hex: "#888888")
    static let danger     = Color(hex: "#ff4444")
    static let border     = Color(hex: "#00ff9f")   // Same as accent

    // MARK: - Typography
    static func pixelFont(size: CGFloat) -> Font {
        .custom("Press Start 2P", size: size)
    }

    // MARK: - Spacing grid (8px base)
    static let spacing: CGFloat = 8
    static let borderWidth: CGFloat = 2
}

// MARK: - Color hex initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xff) / 255
        let g = Double((int >> 8) & 0xff) / 255
        let b = Double(int & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }
}
