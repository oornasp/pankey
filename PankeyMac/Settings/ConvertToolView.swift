// ConvertToolView.swift — stub for Phase 6 text conversion tool tab
import SwiftUI

struct ConvertToolView: View {
    var body: some View {
        VStack(spacing: PixelTheme.spacing * 2) {
            Text("CONVERT")
                .font(PixelTheme.pixelFont(size: 10))
                .foregroundColor(PixelTheme.accent)

            Divider().background(PixelTheme.border)

            Spacer()

            Text("COMING IN PHASE 6")
                .font(PixelTheme.pixelFont(size: 8))
                .foregroundColor(PixelTheme.textDim)

            Spacer()
        }
        .padding(PixelTheme.spacing * 2)
        .background(PixelTheme.background)
    }
}
