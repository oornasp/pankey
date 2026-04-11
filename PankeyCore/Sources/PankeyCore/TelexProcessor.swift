// TelexProcessor.swift — Decodes Telex keystrokes into composition events

// Shared result type for both Telex and VNI processors
public enum ProcessResult {
    case appended                           // Regular key appended to buffer
    case modified                           // Vowel substitution applied
    case toneApplied(Int)                   // Tone index set
    case tripleEscape(committed: String)    // Triple-key: commit pair as literal
}

public struct TelexProcessor {

    /// Process a single Telex keystroke against the current buffer state.
    /// - Parameters:
    ///   - key: The pressed character (lowercased by caller for composition logic)
    ///   - buffer: Keystroke buffer, mutated in place
    ///   - currentTone: Current tone index (0–5), mutated when a tone key is detected
    /// - Returns: A `ProcessResult` describing what happened
    public static func process(
        key: Character,
        buffer: inout String,
        currentTone: inout Int
    ) -> ProcessResult {

        // 1. Check vowel substitution (double-key: aa, aw, ee, oo, ow, uw, dd)
        if let lastChar = buffer.last {
            let pair = String(lastChar) + String(key)
            if let substituted = CharacterTable.telexVowelSubstitutions[pair] {
                buffer.removeLast()
                // Triple-key escape: if the character before the removed one is
                // the same base key (e.g. buffer was "a" before removeLast → still "a")
                // then the user typed a-a-a to get "â" + literal "a".
                if buffer.last.map(String.init) == String(lastChar) {
                    // Emit the committed pair as literal text
                    return .tripleEscape(committed: pair)
                }
                buffer.append(substituted)
                return .modified
            }
        }

        // 2. Check tone key — only apply if buffer already contains a vowel
        //    (false-positive prevention: "sofas" should not trigger tone on 'f')
        if let tone = CharacterTable.telexToneKeys[key] {
            let hasVowel = buffer.contains(where: { CharacterTable.toneMap.keys.contains($0) })
            if hasVowel {
                currentTone = tone
                return .toneApplied(tone)
            } else {
                // No vowel yet — treat tone key as a regular character
                buffer.append(key)
                return .appended
            }
        }

        // 3. Regular alphabetic/other key — append to buffer
        buffer.append(key)
        return .appended
    }
}
