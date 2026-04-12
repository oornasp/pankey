// PixelToggleStyle.swift — custom ToggleStyle rendering a pixel on/off block
import SwiftUI

struct PixelToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: PixelTheme.spacing) {
            configuration.label
                .font(PixelTheme.pixelFont(size: 8))
                .foregroundColor(PixelTheme.text)
            Spacer()
            // Pixel on/off block: filled rect with a sliding indicator
            Rectangle()
                .fill(configuration.isOn ? PixelTheme.accent : PixelTheme.textDim)
                .frame(width: 32, height: 16)
                .overlay(Rectangle().stroke(PixelTheme.border, lineWidth: PixelTheme.borderWidth))
                .overlay(
                    Rectangle()
                        .fill(PixelTheme.background)
                        .frame(width: 14, height: 12)
                        .offset(x: configuration.isOn ? 8 : -8),
                    alignment: .center
                )
                .onTapGesture { configuration.isOn.toggle() }
        }
    }
}
