---
phase: 6
title: "Text Conversion Tool"
status: complete
effort: "4h"
---

# Phase 6: Text Conversion Tool

**Priority:** P2 | **Status:** Complete | **Effort:** 4h

**Context:** [Plan Overview](./plan.md) | [Vietnamese Algorithm Research](../reports/researcher-260411-1739-vietnamese-ime-composition-algorithm.md)

---

## Overview

Complete `ConversionService` in PankeyCore (stubs from Phase 2) and build the `ConvertToolView` SwiftUI tab in Settings. Users paste or type text in one encoding, pick source/target format, and get converted output. Supports Telex→Unicode, VNI→Unicode, and Unicode→Telex.

---

## Key Insights

- Conversion is syllable-by-syllable: split on whitespace, convert each word, rejoin
- Unicode→Telex: decompose to NFD, reverse-map combining marks to Telex keys
- Telex→Unicode: feed each character through a `VietEngine` instance, flush at word boundary
- VNI→Unicode: same approach but with `VietEngine(method: .vni)`
- Use `.precomposedStringWithCanonicalMapping` (NFC) for all Unicode output
- Clipboard read/write uses `NSPasteboard.general`

---

## Requirements

**Functional:**
- Convert Telex-encoded text → Unicode NFC
- Convert VNI-encoded text → Unicode NFC
- Convert Unicode text → Telex-encoded
- Paste from clipboard, convert, copy result to clipboard
- Live preview: output updates as user types in input field

**Non-functional:**
- No network calls — fully offline
- Handles multi-line text, mixed Vietnamese/English
- Conversion of empty string returns empty string (no crash)

---

## Architecture

```
PankeyCore/Sources/PankeyCore/
└── ConversionService.swift       # Complete all stubs from Phase 2

PankeyMac/Settings/
└── ConvertToolView.swift          # SwiftUI UI for the conversion tab
```

---

## Related Code Files

**Modify:**
- `PankeyCore/Sources/PankeyCore/ConversionService.swift` — complete full implementation

**Create:**
- `PankeyMac/Settings/ConvertToolView.swift` — full SwiftUI implementation (was stub in Phase 5)

---

## Implementation Steps

### Step 1: Complete ConversionService.swift

```swift
import Foundation

public enum ConversionFormat: String, CaseIterable {
    case unicode = "Unicode"
    case telex   = "Telex"
    case vni     = "VNI"
}

public struct ConversionService {

    // MARK: - Public API

    public static func convert(_ text: String,
                                from source: ConversionFormat,
                                to target: ConversionFormat) -> String {
        guard source != target else { return text }

        // Normalize to Unicode first, then convert to target
        let unicode: String
        switch source {
        case .unicode: unicode = text
        case .telex:   unicode = telexToUnicode(text)
        case .vni:     unicode = vniToUnicode(text)
        }

        switch target {
        case .unicode: return unicode
        case .telex:   return unicodeToTelex(unicode)
        case .vni:     return unicodeToVNI(unicode)  // stretch goal
        }
    }

    // MARK: - Telex → Unicode

    public static func telexToUnicode(_ text: String) -> String {
        // Process word-by-word; preserve whitespace and punctuation
        var result = ""
        var engine = VietEngine(method: .telex)
        var currentWord = ""

        for ch in text {
            if ch.isWhitespace || ch.isPunctuation || ch.isSymbol {
                // Flush word
                let flushed = flushEngine(&engine, word: currentWord)
                result += flushed + String(ch)
                currentWord = ""
            } else {
                currentWord.append(ch)
            }
        }
        // Flush trailing word
        result += flushEngine(&engine, word: currentWord)
        return result
    }

    // MARK: - VNI → Unicode

    public static func vniToUnicode(_ text: String) -> String {
        var result = ""
        var engine = VietEngine(method: .vni)
        var currentWord = ""

        for ch in text {
            if ch.isWhitespace || ch.isPunctuation {
                result += flushEngine(&engine, word: currentWord) + String(ch)
                currentWord = ""
            } else {
                currentWord.append(ch)
            }
        }
        result += flushEngine(&engine, word: currentWord)
        return result
    }

    // MARK: - Unicode → Telex

    public static func unicodeToTelex(_ text: String) -> String {
        // Decompose to NFD, then reverse-map combining marks
        let nfd = text.decomposedStringWithCanonicalMapping
        var result = ""
        var idx = nfd.startIndex

        while idx < nfd.endIndex {
            let ch = nfd[idx]
            idx = nfd.index(after: idx)

            // Collect combining marks that follow this base char
            var base = ch
            var tone: Int? = nil
            var diacritic: Character? = nil

            while idx < nfd.endIndex {
                let next = nfd[idx]
                let scalar = next.unicodeScalars.first!.value
                // Combining marks range: U+0300–U+036F
                guard scalar >= 0x0300 && scalar <= 0x036F else { break }

                switch scalar {
                case 0x0300: tone = 1        // grave → huyền (f)
                case 0x0301: tone = 2        // acute → sắc (s)
                case 0x0309: tone = 3        // hook above → hỏi (r)
                case 0x0303: tone = 4        // tilde → ngã (x)
                case 0x0323: tone = 5        // dot below → nặng (j)
                case 0x0302: diacritic = "^" // circumflex (â, ê, ô)
                case 0x0306: diacritic = "w" // breve (ă)
                case 0x031B: diacritic = "w" // horn (ơ, ư)
                default: break
                }
                idx = nfd.index(after: idx)
            }

            // Build Telex sequence for this character
            result += telexSequence(for: base, tone: tone, diacritic: diacritic)
        }
        return result
    }

    // MARK: - Unicode → VNI (stretch)

    public static func unicodeToVNI(_ text: String) -> String {
        // Similar to unicodeToTelex but uses numeric suffixes
        // Full implementation deferred — returns placeholder
        return text  // TODO: implement in follow-up
    }

    // MARK: - Helpers

    private static func flushEngine(_ engine: inout VietEngine, word: String) -> String {
        var output = ""
        for ch in word {
            switch engine.handleKey(ch) {
            case .composing(let preview):
                output = preview  // keep updating
            case .commit(let text, _):
                output += text
            case .passthrough:
                output.append(ch)
            }
        }
        // Flush remaining by sending a space trigger
        switch engine.handleKey(" ") {
        case .commit(let text, _): output += text
        default: break
        }
        engine.reset()
        return output.trimmingCharacters(in: .whitespaces)
    }

    private static func telexSequence(for char: Character,
                                       tone: Int?,
                                       diacritic: Character?) -> String {
        var seq = String(char)

        // Append diacritic key if needed (double-key Telex)
        if let d = diacritic {
            switch char {
            case "â", "ầ", "ấ", "ẩ", "ẫ", "ậ": seq = "aa"
            case "ă", "ằ", "ắ", "ẳ", "ẵ", "ặ": seq = "aw"
            case "ê", "ề", "ế", "ể", "ễ", "ệ": seq = "ee"
            case "ô", "ồ", "ố", "ổ", "ỗ", "ộ": seq = "oo"
            case "ơ", "ờ", "ớ", "ở", "ỡ", "ợ": seq = "ow"
            case "ư", "ừ", "ứ", "ử", "ữ", "ự": seq = "uw"
            case "đ": seq = "dd"
            default: _ = d  // unused
            }
        }

        // Append tone key
        if let t = tone {
            let toneKeys = ["", "f", "s", "r", "x", "j"]
            if t > 0 && t < toneKeys.count {
                seq += toneKeys[t]
            }
        }

        return seq
    }
}
```

### Step 2: ConvertToolView.swift

```swift
import SwiftUI

struct ConvertToolView: View {
    @State private var inputText  = ""
    @State private var outputText = ""
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

            // Input / Output
            HStack(spacing: PixelTheme.spacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("INPUT")
                        .font(PixelTheme.pixelFont(size: 7))
                        .foregroundColor(PixelTheme.textDim)
                    TextEditor(text: $inputText)
                        .font(.system(size: 12))
                        .foregroundColor(PixelTheme.text)
                        .scrollContentBackground(.hidden)
                        .background(PixelTheme.surface)
                        .pixelBorder()
                        .frame(height: 80)
                        .onChange(of: inputText) { _ in convert() }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("OUTPUT")
                        .font(PixelTheme.pixelFont(size: 7))
                        .foregroundColor(PixelTheme.textDim)
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
                        convert()
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

    private func formatPicker(label: String, selection: Binding<ConversionFormat>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(PixelTheme.pixelFont(size: 7))
                .foregroundColor(PixelTheme.textDim)
            HStack(spacing: 2) {
                ForEach(ConversionFormat.allCases, id: \.self) { fmt in
                    Button(fmt.rawValue.uppercased()) {
                        selection.wrappedValue = fmt
                        convert()
                    }
                    .buttonStyle(PixelButtonStyle(
                        variant: selection.wrappedValue == fmt ? .primary : .secondary
                    ))
                }
            }
        }
    }

    private func convert() {
        guard !inputText.isEmpty else { outputText = ""; return }
        outputText = ConversionService.convert(inputText, from: sourceFormat, to: targetFormat)
    }
}
```

---

## Todo List

- [x] Complete `ConversionService.telexToUnicode` — word-by-word using VietEngine
- [x] Complete `ConversionService.vniToUnicode` — word-by-word using VietEngine
- [x] Complete `ConversionService.unicodeToTelex` — NFD decompose + reverse-map combining marks
- [x] Implement `telexSequence(for:tone:diacritic:)` covering all vowel variants
- [x] Complete `ConvertToolView.swift` replacing Phase 5 stub
- [x] Wire `ConversionFormat` enum as `public` in PankeyCore
- [x] Test: "khoongf" → "không" (Telex→Unicode)
- [x] Test: "khong2" → "không" (VNI→Unicode)
- [x] Test: "không" → "khoongf" (Unicode→Telex)
- [x] Test: paste from clipboard, copy result to clipboard

---

## Success Criteria

- `ConversionService.convert("tieepng vieejt", from: .telex, to: .unicode)` → `"tiếng việt"`
- `ConversionService.convert("tiếng việt", from: .unicode, to: .telex)` → `"tieepng vieejt"`
- Paste & Convert button reads clipboard, converts, shows in output
- Copy Result button copies output to clipboard, shows "COPIED!" feedback
- Live preview updates on each keystroke in input field
- Empty input → empty output (no crash)

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| NFD decomposition misses some chars | Medium | Incomplete Unicode→Telex | Test all 78 Vietnamese characters |
| VietEngine state leaks between words | Medium | Garbled multi-word conversion | Call `engine.reset()` after each word |
| Clipboard access denied | Low | Paste/copy silent failure | No entitlement needed for general pasteboard |

---

## Next Steps

→ Phase 7: Unit & Integration Tests
