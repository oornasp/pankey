// ExclusionListView.swift — settings tab: view and manage per-app exclusion list
import SwiftUI

struct ExclusionListView: View {
    @State private var excludedApps: [String] = []
    @State private var selectedApp: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: PixelTheme.spacing * 2) {
            Text("EXCLUDED APPS")
                .font(PixelTheme.pixelFont(size: 10))
                .foregroundColor(PixelTheme.accent)

            Divider().background(PixelTheme.border)

            // Bundle ID list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(excludedApps, id: \.self) { bundleID in
                        HStack {
                            Text(bundleID)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(
                                    selectedApp == bundleID ? PixelTheme.background : PixelTheme.text
                                )
                            Spacer()
                        }
                        .padding(.horizontal, PixelTheme.spacing)
                        .padding(.vertical, 6)
                        .background(selectedApp == bundleID ? PixelTheme.accent : PixelTheme.surface)
                        .onTapGesture { selectedApp = bundleID }
                    }
                }
            }
            .pixelBorder()
            .frame(minHeight: 130)

            // Action buttons
            HStack(spacing: PixelTheme.spacing) {
                Button("+ ADD CURRENT APP") {
                    if let bundleID = AppExclusionManager.shared.addFrontmostApp() {
                        reload()
                        selectedApp = bundleID
                    }
                }
                .buttonStyle(PixelButtonStyle(variant: .primary))

                Button("− REMOVE") {
                    if let selected = selectedApp {
                        AppExclusionManager.shared.remove(bundleID: selected)
                        selectedApp = nil
                        reload()
                    }
                }
                .buttonStyle(PixelButtonStyle(variant: .danger))
                .disabled(selectedApp == nil)
            }
        }
        .padding(PixelTheme.spacing * 2)
        .background(PixelTheme.background)
        .onAppear { reload() }
    }

    private func reload() {
        excludedApps = AppExclusionManager.shared.excludedBundleIDs()
    }
}
