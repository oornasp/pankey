// ConvertToolView.swift — Text conversion tool tab in Settings
import SwiftUI
import PankeyCore

struct ConvertToolView: View {
    @State private var inputText    = ""
    @State private var outputText   = ""
    @State private var sourceFormat: ConversionFormat = .telex
    @State private var targetFormat: ConversionFormat = .unicode
    @State private var copyFeedback = false

    var body: some View {
        VStack(alignment: .leading, spacing: PixelTheme.spacing * 2) {
            Text("CONVERT TEXT")
                .font(PixelTheme.pixelFont(size: 10))
                .foregroundColor(PixelTheme.accent)

            Divider().background(PixelTheme.border)

            // Format selectors
            HStack(spacing: PixelTheme.spacing * 2) {
                formatPicker(label: "FROM", selection: $sourceFormat)
                Text("→")
                    .font(PixelTheme.pixelFont(size: 10))
                    .foregroundColor(PixelTheme.accent)
                formatPicker(label: "TO", selection: $targetFormat)
            }

            // Input / Output side-by-side
            HStack(alignment: .top, spacing: PixelTheme.spacing) {
                textPanel(label: "INPUT") {
                    TextEditor(text: $inputText)
                        .font(.system(size: 12))
                        .foregroundColor(PixelTheme.text)
                        .scrollContentBackground(.hidden)
                        .background(PixelTheme.surface)
                        .pixelBorder()
                        .frame(height: 80)
                        .onChange(of: inputText)  { _ in runConversion() }
                        .onChange(of: sourceFormat) { _ in runConversion() }
                        .onChange(of: targetFormat) { _ in runConversion() }
                }

                textPanel(label: "OUTPUT") {
                    TextEditor(text: .constant(outputText))
                        .font(.system(size: 12))
                        .foregroundColor(PixelTheme.accent)
                        .scrollContentBackground(.hidden)
                        .background(PixelTheme.surface)
                        .pixelBorder()
                        .frame(height: 80)
                }
            }

            // Action buttons
            HStack(spacing: PixelTheme.spacing) {
                Button("PASTE & CONVERT") {
                    if let clip = NSPasteboard.general.string(forType: .string) {
                        inputText = clip
                        runConversion()
                    }
                }
                .buttonStyle(PixelButtonStyle(variant: .secondary))

                Button(copyFeedback ? "COPIED!" : "COPY RESULT") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(outputText, forType: .string)
                    copyFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copyFeedback = false
                    }
                }
                .buttonStyle(PixelButtonStyle(variant: .primary))
                .disabled(outputText.isEmpty)
            }
        }
        .padding(PixelTheme.spacing * 2)
        .background(PixelTheme.background)
    }

    // MARK: - Sub-views

    private func formatPicker(label: String, selection: Binding<ConversionFormat>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(PixelTheme.pixelFont(size: 7))
                .foregroundColor(PixelTheme.textDim)
            HStack(spacing: 2) {
                ForEach(ConversionFormat.allCases, id: \.self) { fmt in
                    Button(fmt.rawValue.uppercased()) {
                        selection.wrappedValue = fmt
                        runConversion()
                    }
                    .buttonStyle(PixelButtonStyle(
                        variant: selection.wrappedValue == fmt ? .primary : .secondary
                    ))
                }
            }
        }
    }

    @ViewBuilder
    private func textPanel<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(PixelTheme.pixelFont(size: 7))
                .foregroundColor(PixelTheme.textDim)
            content()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Conversion

    private func runConversion() {
        guard !inputText.isEmpty else { outputText = ""; return }
        outputText = ConversionService.convert(inputText, from: sourceFormat, to: targetFormat)
    }
}
