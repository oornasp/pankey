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

    /// Read-only access to current composing buffer — used by InputController.deactivateServer
    public var currentPreview: String { state.unicodeBuffer }

    // MARK: - Unicode recomputation

    /// Rebuild `state.unicodeBuffer` from the current keystroke buffer + tone.
    private mutating func recomputeUnicode() {
        let (onset, rawVowels, coda) = parseSyllable(state.keystrokeBuffer)
        guard !rawVowels.isEmpty else {
            // No vowel yet — preview the raw buffer
            state.unicodeBuffer = state.keystrokeBuffer
            return
        }

        // Safety normalisation: "u" before "ơ" → "ư" (ươ diphthong fallback)
        var vowels = rawVowels
        for i in 0..<vowels.count - 1 where vowels[i] == "u" && vowels[i + 1] == "ơ" {
            vowels[i] = "ư"
        }

        let toneIdx = tonePlacementIndex(in: vowels, onset: onset, coda: coda)
        var result = onset
        for (i, vowel) in vowels.enumerated() {
            let tone = (i == toneIdx) ? state.currentTone : 0
            let toned = CharacterTable.toneMap[vowel]?[tone] ?? vowel
            result.append(toned)
        }
        result += coda
        state.unicodeBuffer = result.precomposedStringWithCanonicalMapping
    }

    // MARK: - Tone placement (modern Vietnamese orthography)

    /// Returns the index into `vowels` array where the tone mark goes.
    ///
    /// Implements modern Vietnamese orthography rules, matching OpenKey's
    /// `handleModernMark()` / `insertMark()` logic:
    ///
    /// 1. Special diphthongs (iê, yê, uô, ươ): if followed by more elements
    ///    (coda consonant or more vowels), tone on the special vowel (2nd element);
    ///    otherwise tone on the 1st element.
    /// 2. Special diacritic vowel (ă, â, ê, ô, ơ, ư): always receives the tone.
    /// 3. Single vowel: always index 0.
    /// 4. Diphthongs without coda:
    ///    - ai, ao, au, ay, eo, iu, oi, ui → tone on 1st vowel
    ///    - ia/ya (without 'g' onset) → 1st; with 'g' → 2nd
    ///    - ua (without 'q' onset) → 1st; with 'q' → 2nd
    ///    - oa, oe, ue → tone on 2nd vowel
    /// 5. Diphthongs with coda: tone on 2nd vowel (closer to nucleus+coda).
    /// 6. Triphthongs: tone on middle vowel.
    private func tonePlacementIndex(
        in vowels: [Character], onset: String, coda: String
    ) -> Int {
        let count = vowels.count
        if count <= 1 { return 0 }

        let hasCoda = !coda.isEmpty

        // --- Rule 1: Special diphthongs iê, yê, uô, ươ ---
        // These have unique behaviour: with following elements → tone on 2nd (ê/ô/ơ);
        // without → tone on 1st (i/y/u/ư).
        if count >= 2 {
            let v0 = vowels[0], v1 = vowels[1]
            let hasFollowing = count > 2 || hasCoda

            if v0 == "ư" && v1 == "ơ" {
                return hasFollowing ? 1 : 0
            }
            if (v0 == "i" || v0 == "y") && v1 == "ê" {
                return hasFollowing ? 1 : 0
            }
            if v0 == "u" && v1 == "ô" {
                return hasFollowing ? 1 : 0
            }
        }

        // --- Rule 2: Special diacritic vowel takes the tone ---
        for (i, v) in vowels.enumerated() {
            if CharacterTable.specialVowels.contains(v) { return i }
        }

        // --- Rule 3: Single vowel ---
        if count == 1 { return 0 }

        // --- Rule 4–5: Diphthong rules ---
        if count == 2 {
            let v0 = vowels[0], v1 = vowels[1]

            if hasCoda {
                // With coda consonant: tone on 2nd vowel (closer to coda)
                // This covers: oán, oét, oan, oen, uất, etc.
                return 1
            }

            // Without coda (open syllable):

            // Tone on FIRST vowel for these patterns:
            // ai, ao, au, ay, eo, iu, oi, ui
            if v0 == "a" && (v1 == "i" || v1 == "o" || v1 == "u" || v1 == "y") { return 0 }
            if v0 == "e" && v1 == "o" { return 0 }
            if v0 == "i" && v1 == "u" { return 0 }
            if v0 == "o" && v1 == "i" { return 0 }
            if v0 == "u" && v1 == "i" { return 0 }

            // ia / ya: depends on onset (gi cluster)
            if (v0 == "i" || v0 == "y") && v1 == "a" {
                return onset.last == "g" ? 1 : 0
            }
            // io: depends on onset (gi cluster)
            if v0 == "i" && v1 == "o" {
                return onset.last == "g" ? 1 : 0
            }
            // ua: depends on onset (qu cluster)
            if v0 == "u" && v1 == "a" {
                return onset.last == "q" ? 1 : 0
            }

            // Tone on SECOND vowel for these patterns:
            // oa, oe, ue
            if v0 == "o" && (v1 == "a" || v1 == "e") { return 1 }
            if v0 == "u" && v1 == "e" { return 1 }

            // Default diphthong: last vowel
            return count - 1
        }

        // --- Rule 6: Triphthong → middle vowel ---
        if count >= 3 {
            return 1
        }

        return count - 1
    }

    // MARK: - Syllable parsing

    /// Split `buffer` into (onset consonants, vowel sequence, coda consonants).
    ///
    /// Handles Vietnamese-specific consonant clusters:
    ///   - `qu`: 'u' after 'q' is part of onset (not a vowel)
    ///   - `gi`: 'i' after 'g' is part of onset when followed by another vowel
    ///
    /// IMPORTANT: Once coda mode is entered (first consonant after vowels),
    /// all subsequent characters go to coda — we do NOT re-enter vowel
    /// collection. This prevents "hehe" from being parsed as h+[e,e]+h.
    private func parseSyllable(_ buffer: String) -> (String, [Character], String) {
        let chars = Array(buffer)
        let vowelKeys = Set(CharacterTable.toneMap.keys)

        var onset = ""
        var vowels: [Character] = []
        var coda = ""

        var i = 0

        // Phase 1: Onset consonants
        while i < chars.count {
            let ch = chars[i]
            if vowelKeys.contains(ch) {
                // qu cluster: 'u' after 'q' stays in onset
                if ch == "u" && onset.hasSuffix("q") {
                    onset.append(ch)
                    i += 1
                    continue
                }
                // gi cluster: 'i' after 'g' stays in onset when followed by another vowel
                if ch == "i" && onset.hasSuffix("g")
                    && i + 1 < chars.count && vowelKeys.contains(chars[i + 1]) {
                    onset.append(ch)
                    i += 1
                    continue
                }
                break  // First real vowel found → exit onset phase
            }
            onset.append(ch)
            i += 1
        }

        // Phase 2: Vowel nucleus (contiguous vowels)
        while i < chars.count && vowelKeys.contains(chars[i]) {
            vowels.append(chars[i])
            i += 1
        }

        // Phase 3: Coda (everything remaining — NO re-entering vowel mode)
        while i < chars.count {
            coda.append(chars[i])
            i += 1
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
