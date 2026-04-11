// VietEngine.swift — Vietnamese composition state machine
import Foundation

// MARK: - Public types

public enum InputMethod {
    case telex
    case vni
}

public struct EngineState {
    public var keystrokeBuffer: String = ""  // Vowel/substitution buffer
    public var unicodeBuffer: String = ""    // Current NFC preview shown to user
    public var currentTone: Int = 0          // 0=ngang .. 5=nặng
    public var isActive: Bool = true         // false when IME bypassed (excluded app)

    public init() {}
}

public enum EngineResult {
    case composing(preview: String)                    // Marked/candidate text
    case commit(text: String, remainder: Character?)   // Finalized text + overflow key
    case passthrough                                   // Let system handle the key
}

// MARK: - VietEngine

public struct VietEngine {

    private var state = EngineState()
    private let method: InputMethod

    public init(method: InputMethod = .telex) {
        self.method = method
    }

    // MARK: - Public API

    /// Handle a single keypress from the IMK controller.
    /// - Parameters:
    ///   - key: The character for this keypress (lowercased for Telex/VNI logic)
    ///   - isUppercase: True when Shift or Caps Lock is active; output is uppercased
    public mutating func handleKey(_ key: Character, isUppercase: Bool = false) -> EngineResult {
        guard state.isActive else { return .passthrough }

        // --- Backspace: undo last composition step, NOT a system backspace ---
        if key == "\u{08}" {
            guard !state.keystrokeBuffer.isEmpty else {
                return .passthrough  // Let system handle backspace on committed text
            }
            state.keystrokeBuffer.removeLast()
            if state.keystrokeBuffer.isEmpty {
                state.currentTone = 0
                state.unicodeBuffer = ""
                return .commit(text: "", remainder: nil)
            }
            recomputeUnicode()
            return .composing(preview: cased(state.unicodeBuffer, isUppercase))
        }

        // --- Commit triggers: space, newline, tab, punctuation, symbols ---
        if shouldCommit(key) {
            guard !state.unicodeBuffer.isEmpty else {
                return .passthrough
            }
            let committed = state.unicodeBuffer
            reset()
            return .commit(text: cased(committed, isUppercase), remainder: key)
        }

        // --- Route to method-specific processor ---
        let result: ProcessResult
        if method == .telex {
            result = TelexProcessor.process(
                key: key,
                buffer: &state.keystrokeBuffer,
                currentTone: &state.currentTone
            )
        } else {
            result = VNIProcessor.process(
                key: key,
                buffer: &state.keystrokeBuffer,
                currentTone: &state.currentTone
            )
        }

        switch result {
        case .tripleEscape(let committed):
            // e.g. "aaa" → commit "â" + literal "a"
            let text = String(state.unicodeBuffer.dropLast()) + committed
            reset()
            return .commit(text: cased(text, isUppercase), remainder: nil)
        default:
            recomputeUnicode()
            return .composing(preview: cased(state.unicodeBuffer, isUppercase))
        }
    }

    /// Clear composition state (called on commit or explicit cancel)
    public mutating func reset() {
        state.keystrokeBuffer = ""
        state.unicodeBuffer = ""
        state.currentTone = 0
    }

    /// Bypass IME for excluded apps
    public mutating func setActive(_ active: Bool) {
        state.isActive = active
        if !active { reset() }
    }

    // MARK: - Unicode recomputation

    /// Rebuild `state.unicodeBuffer` from the current keystroke buffer + tone.
    private mutating func recomputeUnicode() {
        let (onset, vowels, coda) = parseSyllable(state.keystrokeBuffer)
        guard !vowels.isEmpty else {
            // No vowel yet — preview the raw buffer
            state.unicodeBuffer = state.keystrokeBuffer
            return
        }

        let toneIdx = tonePlacementIndex(in: vowels)
        var result = onset
        for (i, vowel) in vowels.enumerated() {
            let tone = (i == toneIdx) ? state.currentTone : 0
            let toned = CharacterTable.toneMap[vowel]?[tone] ?? vowel
            result.append(toned)
        }
        result += coda
        state.unicodeBuffer = result.precomposedStringWithCanonicalMapping
    }

    // MARK: - Tone placement (3-level precedence)

    /// Returns the index into `vowels` array where the tone mark should go.
    ///
    /// Precedence:
    /// 1. Special diacritic vowels: ă â ê ô ơ ư
    /// 2. Single vowel: always index 0
    /// 3. Diphthong/triphthong: center vowel (last for diphthong, middle for triphthong)
    private func tonePlacementIndex(in vowels: [Character]) -> Int {
        // Level 1: diacritic vowel takes the mark
        for (i, v) in vowels.enumerated() {
            if CharacterTable.specialVowels.contains(v) { return i }
        }
        // Level 2: single vowel
        if vowels.count == 1 { return 0 }
        // Level 3: diphthong/triphthong center
        //   diphthong ending in 'a' (e.g. "ia", "ua"): mark the first vowel
        if vowels.last == "a" { return 0 }
        //   triphthong: mark center (index count-2)
        if vowels.count > 2 { return vowels.count - 2 }
        //   other diphthong: mark the last vowel
        return vowels.count - 1
    }

    // MARK: - Syllable parsing

    /// Split `buffer` into (onset consonants, vowel sequence, coda consonants).
    ///
    /// Algorithm: scan left-to-right; consonants before first vowel → onset,
    /// contiguous vowels → vowel cluster, consonants after last vowel → coda.
    private func parseSyllable(_ buffer: String) -> (String, [Character], String) {
        var onset = ""
        var vowels: [Character] = []
        var coda = ""
        var inVowels = false

        for ch in buffer {
            let isV = CharacterTable.toneMap.keys.contains(ch)
            if isV {
                inVowels = true
                vowels.append(ch)
            } else if !inVowels {
                onset.append(ch)
            } else {
                coda.append(ch)
            }
        }
        return (onset, vowels, coda)
    }

    // MARK: - Commit decision

    /// Returns true when the key should flush the composition buffer.
    private func shouldCommit(_ key: Character) -> Bool {
        if key == " " || key == "\n" || key == "\t" { return true }
        if key.isPunctuation || key.isSymbol { return true }
        // Number keys trigger commit in Telex (VNI handles its own digits internally)
        if method == .telex && key.isNumber && !state.keystrokeBuffer.isEmpty { return true }
        return false
    }

    // MARK: - Case helper

    private func cased(_ text: String, _ upper: Bool) -> String {
        upper ? text.uppercased() : text
    }
}
