// PixelBorderModifier.swift — ViewModifier for 2px pixel-style border
import SwiftUI

struct PixelBorder: ViewModifier {
    var color: Color = PixelTheme.border
    var width: CGFloat = PixelTheme.borderWidth

    func body(content: Content) -> some View {
        content
            .overlay(Rectangle().stroke(color, lineWidth: width))
    }
}

extension View {
    func pixelBorder(color: Color = PixelTheme.border) -> some View {
        modifier(PixelBorder(color: color))
    }
}
