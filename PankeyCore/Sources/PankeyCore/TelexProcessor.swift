// TelexProcessor.swift — Decodes Telex keystrokes into composition events
//
// Key design: 'w' is a RETROACTIVE vowel modifier (like OpenKey's insertW),
// not a simple pair substitution. It scans the entire vowel cluster to apply
// horn/breve diacritics (ư, ơ, ă), and can be typed at ANY position in the
// word — before, within, or after the vowel cluster.

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

        // 1. Handle 'w' as retroactive vowel modifier (horn/breve)
        //    Must be checked BEFORE pair substitution to take priority.
        //    Scans the entire vowel cluster, not just the last character.
        if key == "w" {
            return handleW(buffer: &buffer)
        }

        // 2. Check vowel substitution (double-key: aa, ee, oo, dd)
        if let lastChar = buffer.last {
            let pair = String(lastChar) + String(key)
            if let substituted = CharacterTable.telexVowelSubstitutions[pair] {
                buffer.removeLast()
                // Triple-key escape: if the character before the removed one is
                // the same base key (e.g. buffer was "a" before removeLast → still "a")
                // then the user typed a-a-a to get "â" + literal "a".
                if buffer.last.map(String.init) == String(lastChar) {
                    return .tripleEscape(committed: pair)
                }
                buffer.append(substituted)
                return .modified
            }
        }

        // 3. Check tone key — only apply if buffer already contains a vowel
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

        // 4. Regular alphabetic/other key — append to buffer
        buffer.append(key)
        return .appended
    }

    // MARK: - Retroactive W handler (port of OpenKey's insertW concept)

    /// Handle 'w' pressed at any position — retroactively modify the vowel cluster.
    ///
    /// Scans the buffer for the vowel nucleus, respecting Vietnamese consonant
    /// rules (qu, gi are onset clusters). Applies horn (ơ, ư) or breve (ă)
    /// based on the vowel pattern, following OpenKey's insertW logic:
    ///
    /// Multi-vowel patterns:
    ///   uo → ươ   |   ua → ưa   |   ui → ưi   |   uu → ưu
    ///   oi → ơi   |   io → iơ   |   oa → oă
    ///
    /// Single vowel: a→ă, u→ư, o→ơ
    ///
    /// Toggle: pressing 'w' again undoes the modification when the pattern
    /// is already fully applied.
    private static func handleW(buffer: inout String) -> ProcessResult {
        var chars = Array(buffer)
        guard !chars.isEmpty else {
            buffer.append("w")
            return .appended
        }

        let vowelKeys = Set(CharacterTable.toneMap.keys)

        // --- Locate the vowel cluster, skipping onset consonants ---
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if vowelKeys.contains(ch) {
                // qu: 'u' after 'q' is part of onset, NOT a vowel
                if ch == "u" && i > 0 && chars[i - 1] == "q" {
                    i += 1; continue
                }
                // gi: 'i' after 'g' is part of onset when followed by another vowel
                if ch == "i" && i > 0 && chars[i - 1] == "g"
                    && i + 1 < chars.count && vowelKeys.contains(chars[i + 1]) {
                    i += 1; continue
                }
                break
            }
            i += 1
        }

        // Collect contiguous vowel indices (stop at first consonant/coda)
        var vowelIndices: [Int] = []
        while i < chars.count && vowelKeys.contains(chars[i]) {
            vowelIndices.append(i)
            i += 1
        }

        guard !vowelIndices.isEmpty else {
            buffer.append("w")
            return .appended
        }

        // Reverse map: horn/breve vowel → base vowel
        let baseMap: [Character: Character] = ["ư": "u", "ơ": "o", "ă": "a"]

        // Determine base vowels (strip horn/breve to identify the pattern)
        let vowelChars = vowelIndices.map { chars[$0] }
        let baseVowels = vowelChars.map { baseMap[$0] ?? $0 }

        var applied = false

        // --- Multi-vowel patterns (2+ vowels) ---
        if baseVowels.count >= 2 {
            let b0 = baseVowels[0], b1 = baseVowels[1]

            // Define target modifications for each pair pattern:
            // (index into vowelIndices, target character)
            var targets: [(Int, Character)]? = nil

            switch (b0, b1) {
            case ("u", "o"): targets = [(0, "ư"), (1, "ơ")]   // uo → ươ
            case ("u", "a"): targets = [(0, "ư")]              // ua → ưa
            case ("u", "i"): targets = [(0, "ư")]              // ui → ưi
            case ("u", "u"): targets = [(0, "ư")]              // uu → ưu
            case ("o", "i"): targets = [(0, "ơ")]              // oi → ơi
            case ("i", "o"): targets = [(1, "ơ")]              // io → iơ
            case ("o", "a"): targets = [(1, "ă")]              // oa → oă
            default: break
            }

            if let targets = targets {
                // Toggle: undo if ALL targets are already applied
                let fullyApplied = targets.allSatisfy { vi, target in
                    chars[vowelIndices[vi]] == target
                }

                if fullyApplied {
                    // Undo — restore to base vowels
                    for (vi, _) in targets {
                        chars[vowelIndices[vi]] = baseVowels[vi]
                    }
                } else {
                    // Apply — set target characters
                    for (vi, target) in targets {
                        chars[vowelIndices[vi]] = target
                    }
                }
                applied = true
            }
        }

        // --- Single vowel fallback (only when exactly 1 vowel in cluster) ---
        if !applied && vowelIndices.count == 1 {
            let ch = chars[vowelIndices[0]]
            let base = baseMap[ch] ?? ch

            switch base {
            case "a", "u", "o":
                if ch != base {
                    // Already has horn/breve → undo (toggle off)
                    chars[vowelIndices[0]] = base
                } else {
                    // Apply horn/breve
                    let wTarget: [Character: Character] = ["a": "ă", "u": "ư", "o": "ơ"]
                    chars[vowelIndices[0]] = wTarget[base]!
                }
                applied = true
            default:
                break  // e, i, y cannot take w modifier
            }
        }

        if applied {
            buffer = String(chars)
            return .modified
        }

        // w doesn't apply to any vowel in this context — append as literal
        buffer.append("w")
        return .appended
    }
}
