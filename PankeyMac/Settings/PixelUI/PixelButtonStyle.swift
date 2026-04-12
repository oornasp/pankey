// PixelButtonStyle.swift — custom ButtonStyle with primary/secondary/danger variants
import SwiftUI

struct PixelButtonStyle: ButtonStyle {
    var variant: Variant = .primary

    enum Variant { case primary, secondary, danger }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PixelTheme.pixelFont(size: 9))
            .foregroundColor(configuration.isPressed ? PixelTheme.background : labelColor)
            .padding(.horizontal, PixelTheme.spacing * 1.5)
            .padding(.vertical, PixelTheme.spacing)
            .background(configuration.isPressed ? labelColor : PixelTheme.surface)
            .overlay(
                Rectangle()
                    .stroke(labelColor, lineWidth: PixelTheme.borderWidth)
            )
            .animation(.none, value: configuration.isPressed)
    }

    private var labelColor: Color {
        switch variant {
        case .primary:   return PixelTheme.accent
        case .secondary: return PixelTheme.text
        case .danger:    return PixelTheme.danger
        }
    }
}
