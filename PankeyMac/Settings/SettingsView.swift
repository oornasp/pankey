// SettingsView.swift — root tab container with pixel-style custom tab bar
import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = 0
    private let tabs = ["GENERAL", "EXCLUDED", "CONVERT"]

    var body: some View {
        VStack(spacing: 0) {
            // Pixel tab bar
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { i, label in
                    Button(label) { selectedTab = i }
                        .font(PixelTheme.pixelFont(size: 8))
                        .foregroundColor(selectedTab == i ? PixelTheme.background : PixelTheme.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PixelTheme.spacing)
                        .background(selectedTab == i ? PixelTheme.accent : PixelTheme.surface)
                        .overlay(Rectangle().stroke(PixelTheme.border, lineWidth: 1))
                }
            }

            // Tab content
            Group {
                switch selectedTab {
                case 0: GeneralSettingsView()
                case 1: ExclusionListView()
                case 2: ConvertToolView()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(PixelTheme.background)
        .frame(width: 420, height: 340)
    }
}
