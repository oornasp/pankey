// VNIProcessor.swift — Decodes VNI numeric keystrokes into composition events

public struct VNIProcessor {

    /// Process a single VNI keystroke against the current buffer state.
    /// - Parameters:
    ///   - key: The pressed character
    ///   - buffer: Keystroke/vowel buffer, mutated in place
    ///   - currentTone: Current tone index (0–5), mutated when a tone digit is detected
    /// - Returns: A `ProcessResult` describing what happened
    public static func process(
        key: Character,
        buffer: inout String,
        currentTone: inout Int
    ) -> ProcessResult {

        // 1. Tone digit (1–5)
        if let tone = CharacterTable.vniToneDigits[key] {
            currentTone = tone
            return .toneApplied(tone)
        }

        // 2. Diacritic digit (6–8): vowelChar + digit → modified vowel
        if ["6", "7", "8"].contains(key) {
            if let lastVowel = buffer.last(where: { isVowel($0) }) {
                let pair = String(lastVowel) + String(key)
                if let modified = CharacterTable.vniDiacriticMap[pair] {
                    // Replace the last vowel in the buffer with the diacritical form
                    if let idx = buffer.lastIndex(where: { isVowel($0) }) {
                        buffer.replaceSubrange(idx ... idx, with: String(modified))
                    }
                    return .modified
                }
            }
        }

        // 3. d + 9 → đ
        if key == "9", buffer.last == "d" {
            buffer.removeLast()
            buffer.append("đ")
            return .modified
        }

        // 4. Regular key
        buffer.append(key)
        return .appended
    }

    // MARK: - Helpers

    /// Returns true for any vowel base or diacritical vowel tracked in the tone table
    private static func isVowel(_ c: Character) -> Bool {
        CharacterTable.toneMap.keys.contains(c)
    }
}
