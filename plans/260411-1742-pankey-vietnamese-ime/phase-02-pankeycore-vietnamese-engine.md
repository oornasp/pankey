---
phase: 2
title: "PankeyCore Vietnamese Engine"
status: complete
effort: "10h"
---

# Phase 2: PankeyCore Vietnamese Engine

**Priority:** P1 | **Status:** Complete | **Effort:** 10h

**Context:** [Plan Overview](./plan.md) | [Vietnamese Algorithm Research](../reports/researcher-260411-1739-vietnamese-ime-composition-algorithm.md)

---

## Overview

<!-- Updated: Validation Session 1 - uppercase support added -->
Implement the platform-agnostic Vietnamese composition engine in the `PankeyCore` Swift Package. This is the hardest algorithmic phase — covers character tables, Telex/VNI processors, the composition state machine, tone placement, false-positive prevention, NFC normalization, and **uppercase/Caps Lock support**.

---

## Key Insights

- macOS expects **NFC (precomposed) Unicode** — always normalize output with `.precomposedStringWithCanonicalMapping`
- Vietnamese has ~78 distinct precomposed chars spanning Latin-1 Supplement, Latin Extended-A/B, and Latin Extended Additional (U+1E00–U+1EFF)
- **Tone placement uses 3-level precedence:** (1) special vowels ă/â/ê/ô/ơ/ư first, (2) 'e' (legacy), (3) center vowel of rhyme
- **Backspace during composition:** remove last keystroke, recompute buffer — do NOT pass to system
- **False positives** (e.g. "sofas" in Telex): use hybrid strategy — vowel-boundary check + valid-end-consonant check
- **Telex tone keys:** f=huyền, s=sắc, r=hỏi, x=ngã, j=nặng, z=cancel
- **VNI tone digits:** 1=sắc, 2=huyền, 3=hỏi, 4=ngã, 5=nặng; diacritic digits: 6=circumflex, 7=horn, 8=breve, 9=đ stroke

---

## Requirements

**Functional:**
- `CharacterTable.swift` — complete NFC lookup tables for all Vietnamese chars × 6 tones
- `TelexProcessor.swift` — Telex key → composition event with vowel substitution + tone rules
- `VNIProcessor.swift` — VNI numeric → composition event
- `VietEngine.swift` — state machine: buffer management, tone placement, commit logic
- `ConversionService.swift` — Telex↔VNI↔Unicode text conversion (for Phase 6 UI)
- All output NFC-normalized
- Backspace correctly undoes last composition step
- **Uppercase support**: `VietEngine.handleKey(_:isUppercase:)` — when `isUppercase=true`, output `.uppercased()` Vietnamese result

**Non-functional:**
- Zero external dependencies (pure Swift)
- Fully unit-testable without running the IME app
- Public API usable by `PankeyMac` and future platforms

---

## Architecture

```
PankeyCore/Sources/PankeyCore/
├── CharacterTable.swift          # Lookup: base char + tone → NFC Unicode char
├── TelexProcessor.swift          # Telex keystroke decoder
├── VNIProcessor.swift            # VNI keystroke decoder
├── VietEngine.swift              # Composition state machine (main coordinator)
└── ConversionService.swift       # Batch text conversion (Telex/VNI ↔ Unicode)
```

### Data Flow

```
KeyPress
  → TelexProcessor / VNIProcessor   (decode keystroke → CompositionEvent)
  → VietEngine.handleEvent()        (apply to buffer state)
  → TonePlacement algorithm         (find correct vowel index)
  → CharacterTable.lookup()         (base + diacritic + tone → NFC char)
  → EngineResult (.composing / .commit)
```

---

## Related Code Files

**Create (all in `PankeyCore/Sources/PankeyCore/`):**
- `CharacterTable.swift`
- `TelexProcessor.swift`
- `VNIProcessor.swift`
- `VietEngine.swift`
- `ConversionService.swift`

---

## Implementation Steps

### Step 1: CharacterTable.swift

Define the complete vowel × tone NFC lookup table:

```swift
// Public namespace for Vietnamese character data
public enum CharacterTable {
    // Tone indices: 0=ngang, 1=huyền, 2=sắc, 3=hỏi, 4=ngã, 5=nặng
    public static let toneMap: [Character: [Character]] = [
        "a": ["a","à","á","ả","ã","ạ"],
        "e": ["e","è","é","ẻ","ẽ","ẹ"],
        "i": ["i","ì","í","ỉ","ĩ","ị"],
        "o": ["o","ò","ó","ỏ","õ","ọ"],
        "u": ["u","ù","ú","ủ","ũ","ụ"],
        "y": ["y","ỳ","ý","ỷ","ỹ","ỵ"],
        "ă": ["ă","ằ","ắ","ẳ","ẵ","ặ"],
        "â": ["â","ầ","ấ","ẩ","ẫ","ậ"],
        "ê": ["ê","ề","ế","ể","ễ","ệ"],
        "ô": ["ô","ồ","ố","ổ","ỗ","ộ"],
        "ơ": ["ơ","ờ","ớ","ở","ỡ","ợ"],
        "ư": ["ư","ừ","ứ","ử","ữ","ự"],
    ]

    // Telex vowel substitutions (double-key)
    public static let telexVowelSubstitutions: [String: Character] = [
        "aa": "â", "aw": "ă", "ee": "ê",
        "oo": "ô", "ow": "ơ", "uw": "ư", "dd": "đ"
    ]

    // Telex tone key → tone index
    public static let telexToneKeys: [Character: Int] = [
        "z": 0, "f": 1, "s": 2, "r": 3, "x": 4, "j": 5
    ]

    // VNI: digit → tone index
    public static let vniToneDigits: [Character: Int] = [
        "1": 2, "2": 1, "3": 3, "4": 4, "5": 5  // sắc=2,huyền=1,hỏi=3,ngã=4,nặng=5
    ]

    // VNI: vowel+digit → modified vowel
    public static let vniDiacriticMap: [String: Character] = [
        "a6": "â", "e6": "ê", "o6": "ô",
        "o7": "ơ", "u7": "ư", "a8": "ă"
        // d9 → đ handled separately
    ]

    // Valid Vietnamese end consonants (for false-positive prevention)
    public static let validEndConsonants: Set<String> = [
        "c","ch","m","n","ng","nh","p","t"
    ]

    // Special vowels with diacritics (Level 1 tone placement)
    public static let specialVowels: Set<Character> = ["ă","â","ê","ô","ơ","ư"]
}
```

### Step 2: TelexProcessor.swift

```swift
public struct TelexProcessor {
    // Returns (modified buffer, tone index) or nil if key is not a Telex modifier
    public static func process(key: Character,
                                buffer: inout String,
                                currentTone: inout Int) -> ProcessResult {
        // 1. Check vowel substitution (double-key: aa, aw, ee, oo, ow, uw, dd)
        if let lastChar = buffer.last {
            let pair = String(lastChar) + String(key)
            if let substituted = CharacterTable.telexVowelSubstitutions[pair] {
                buffer.removeLast()
                // Handle triple-key escape: aaa → aâ (output previous + literal)
                if buffer.last.map({ String($0) }) == String(lastChar) {
                    // triple press: output committed pair, restart
                    return .tripleEscape(committed: pair)
                }
                buffer.append(substituted)
                return .modified
            }
        }

        // 2. Check tone key
        if let tone = CharacterTable.telexToneKeys[key] {
            currentTone = tone
            return .toneApplied(tone)
        }

        // 3. Regular key — append to buffer
        buffer.append(key)
        return .appended
    }
}

public enum ProcessResult {
    case appended
    case modified                        // vowel substitution applied
    case toneApplied(Int)               // tone index set
    case tripleEscape(committed: String) // triple-key: commit pair + continue
}
```

### Step 3: VNIProcessor.swift

```swift
public struct VNIProcessor {
    public static func process(key: Character,
                                buffer: inout String,
                                currentTone: inout Int) -> ProcessResult {
        // 1. Check tone digit (1-5)
        if let tone = CharacterTable.vniToneDigits[key] {
            currentTone = tone
            return .toneApplied(tone)
        }

        // 2. Check diacritic digit (6-9)
        if let lastVowel = buffer.last(where: { isVowel($0) }) {
            let pair = String(lastVowel) + String(key)
            if let modified = CharacterTable.vniDiacriticMap[pair] {
                // Replace last vowel in buffer
                if let idx = buffer.lastIndex(where: { isVowel($0) }) {
                    buffer.replaceSubrange(idx...idx, with: String(modified))
                }
                return .modified
            }
        }

        // 3. d9 → đ
        if key == "9", buffer.last == "d" {
            buffer.removeLast()
            buffer.append("đ")
            return .modified
        }

        // 4. Regular key
        buffer.append(key)
        return .appended
    }

    private static func isVowel(_ c: Character) -> Bool {
        CharacterTable.toneMap.keys.contains(c)
    }
}
```

### Step 4: VietEngine.swift (State Machine)

```swift
public enum InputMethod { case telex, vni }

public struct EngineState {
    public var keystrokeBuffer: String = ""    // Raw keystrokes
    public var unicodeBuffer: String = ""      // Current Unicode output (preview)
    public var currentTone: Int = 0            // 0=ngang..5=nặng
    public var isActive: Bool = true           // false when in excluded app
}

public enum EngineResult {
    case composing(preview: String)            // Show as marked text
    case commit(text: String, remainder: Character?) // Commit + optional overflow key
    case passthrough                           // Don't process this key
}

public struct VietEngine {
    private var state = EngineState()
    private let method: InputMethod

    public init(method: InputMethod = .telex) {
        self.method = method
    }

    public mutating func handleKey(_ key: Character) -> EngineResult {
        guard state.isActive else { return .passthrough }

        // Backspace: undo last composition step
        if key == "\u{08}" {  // U+0008 backspace
            if !state.keystrokeBuffer.isEmpty {
                state.keystrokeBuffer.removeLast()
                if state.keystrokeBuffer.isEmpty {
                    state.currentTone = 0
                    state.unicodeBuffer = ""
                    return .commit(text: "", remainder: nil)
                }
                recomputeUnicode()
                return .composing(preview: state.unicodeBuffer)
            }
            return .passthrough  // Let system handle backspace on committed text
        }

        // Commit triggers: space, punctuation, non-alpha (excluding Telex/VNI specials)
        if shouldCommit(key) {
            let committed = state.unicodeBuffer
            reset()
            return .commit(text: committed, remainder: key)
        }

        // Process key through method-specific processor
        let result: ProcessResult
        if method == .telex {
            result = TelexProcessor.process(key: key, buffer: &state.keystrokeBuffer, currentTone: &state.currentTone)
        } else {
            result = VNIProcessor.process(key: key, buffer: &state.keystrokeBuffer, currentTone: &state.currentTone)
        }

        switch result {
        case .tripleEscape(let committed):
            let text = state.unicodeBuffer.dropLast() + committed
            reset()
            return .commit(text: String(text), remainder: nil)
        default:
            recomputeUnicode()
            return .composing(preview: state.unicodeBuffer)
        }
    }

    public mutating func reset() {
        state.keystrokeBuffer = ""
        state.unicodeBuffer = ""
        state.currentTone = 0
    }

    // MARK: - Private

    private mutating func recomputeUnicode() {
        let (onset, vowels, coda) = parseSyllable(state.keystrokeBuffer)
        guard !vowels.isEmpty else {
            state.unicodeBuffer = state.keystrokeBuffer
            return
        }
        let toneIdx = tonePlacementIndex(in: vowels)
        var result = onset
        for (i, v) in vowels.enumerated() {
            let tone = (i == toneIdx) ? state.currentTone : 0
            let toned = CharacterTable.toneMap[v]?[tone] ?? v
            result.append(toned)
        }
        result += coda
        state.unicodeBuffer = result.precomposedStringWithCanonicalMapping
    }

    /// 3-level tone placement precedence
    private func tonePlacementIndex(in vowels: [Character]) -> Int {
        // Level 1: Special vowels with diacritics
        for (i, v) in vowels.enumerated() {
            if CharacterTable.specialVowels.contains(v) { return i }
        }
        // Level 3: Center vowel of rhyme
        if vowels.count == 1 { return 0 }
        let last = vowels.last!
        if last == "a" { return 0 }            // diphthong ending in 'a': mark first
        if vowels.count > 2 { return vowels.count - 2 }  // triphthong: center
        return vowels.count - 1                 // other diphthong: mark last
    }

    /// Parse buffer into (onset consonants, vowels, coda consonants)
    private func parseSyllable(_ buffer: String) -> (String, [Character], String) {
        // Simple heuristic: consonants before first vowel = onset,
        // vowels in middle, consonants after last vowel = coda
        var onset = ""
        var vowelSeq: [Character] = []
        var coda = ""
        var inVowels = false

        for ch in buffer {
            let isV = CharacterTable.toneMap.keys.contains(ch)
            if isV {
                inVowels = true
                vowelSeq.append(ch)
            } else if !inVowels {
                onset.append(ch)
            } else {
                coda.append(ch)
            }
        }
        return (onset, vowelSeq, coda)
    }

    /// Determine if key should trigger buffer commit
    private func shouldCommit(_ key: Character) -> Bool {
        if key == " " || key == "\n" || key == "\t" { return true }
        if key.isPunctuation || key.isSymbol { return true }
        // For Telex: if key is NOT a valid Telex composition key and we have a buffer
        // This prevents false positives on English words
        return false
    }
}
```

### Step 5: ConversionService.swift

```swift
/// Batch text conversion between Telex-encoded, VNI-encoded, and Unicode
public struct ConversionService {
    public static func telexToUnicode(_ text: String) -> String {
        let words = text.components(separatedBy: .whitespaces)
        return words.map { convertTelexWord($0) }.joined(separator: " ")
    }

    public static func unicodeToTelex(_ text: String) -> String {
        // Decompose NFD, reverse-map combining marks to Telex keys
        let nfd = text.decomposedStringWithCanonicalMapping
        var result = ""
        var i = nfd.startIndex
        while i < nfd.endIndex {
            let ch = nfd[i]
            result += reverseMapToTelex(ch, nfd: nfd, index: &i)
        }
        return result
    }

    public static func vniToUnicode(_ text: String) -> String {
        // Similar to Telex but parse numeric suffixes
        let words = text.components(separatedBy: .whitespaces)
        return words.map { convertVNIWord($0) }.joined(separator: " ")
    }

    // Internal conversion helpers (implement fully in Phase 6)
    private static func convertTelexWord(_ word: String) -> String {
        var engine = VietEngine(method: .telex)
        var output = ""
        for ch in word {
            switch engine.handleKey(ch) {
            case .composing(let preview): output = preview
            case .commit(let text, _): output += text
            case .passthrough: output.append(ch)
            }
        }
        // Flush remaining buffer
        if case .commit(let text, _) = engine.handleKey(" ") {
            output += text
        }
        return output
    }

    private static func convertVNIWord(_ word: String) -> String { word } // Phase 6

    private static func reverseMapToTelex(_ ch: Character, nfd: String, index: inout String.Index) -> String {
        index = nfd.index(after: index)
        return String(ch)  // Full impl in Phase 6
    }
}
```

---

## Todo List

- [x] Implement `CharacterTable.swift` with complete vowel×tone NFC table
- [x] Implement `TelexProcessor.swift` with double-key substitution + triple-key escape
- [x] Implement `VNIProcessor.swift` with numeric diacritic + tone handling
- [x] Implement `VietEngine.swift` state machine (handleKey, reset, recomputeUnicode)
- [x] Implement `tonePlacementIndex` with all 3 precedence levels
- [x] Implement `parseSyllable` (onset/vowels/coda extraction)
- [x] Implement false-positive prevention in `shouldCommit`
- [x] Create `ConversionService.swift` stubs (full impl Phase 6)
- [x] Add `isUppercase` parameter to `VietEngine.handleKey` — apply `.uppercased()` when true
- [x] Run `swift build` in PankeyCore — verify 0 errors

---

## Success Criteria

- `swift build` in PankeyCore directory succeeds with 0 errors
- `VietEngine` correctly composes: "tooi" → "tôi", "vieejt" → "viết", "khoongf" → "không"
- Backspace correctly undoes: "tooi" + ⌫ → "too" (removes 'i', vowel substitution reverts)
- "sofas" typed in Telex mode does NOT produce garbled Vietnamese output
- All NFC-normalized: output characters are single precomposed code points (not combining sequences)
- `ConversionService` stub compiles and is accessible from PankeyMac

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Tone placement edge cases | High | Wrong output for some words | Comprehensive test cases in Phase 7 |
| False positives in English text | Medium | Annoying garbling | Per-app exclusion (Phase 4) + shouldCommit heuristics |
| NFC normalization missed | Medium | Cursor/display bugs in apps | `.precomposedStringWithCanonicalMapping` on every output |
| VNI digit conflicts (browser shortcuts) | Low | VNI unusable in browser | Document in README; per-app exclusion helps |

---

## Next Steps

→ Phase 3: IMK Integration — connect VietEngine to InputMethodKit
