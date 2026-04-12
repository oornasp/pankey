// ConversionService.swift — Batch text conversion between Telex / VNI / Unicode
import Foundation

/// Supported encoding formats for text conversion.
public enum ConversionFormat: String, CaseIterable {
    case unicode = "Unicode"
    case telex   = "Telex"
    case vni     = "VNI"
}

/// Converts full paragraphs or clipboard content between encoding schemes.
public struct ConversionService {

    // MARK: - Public API

    /// Convert `text` from `source` encoding to `target` encoding.
    public static func convert(
        _ text: String,
        from source: ConversionFormat,
        to target: ConversionFormat
    ) -> String {
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
        case .vni:     return unicodeToVNI(unicode)
        }
    }

    // MARK: - Telex → Unicode

    /// Convert a Telex-encoded string to NFC Unicode Vietnamese.
    public static func telexToUnicode(_ text: String) -> String {
        processWordByWord(text, method: .telex)
    }

    // MARK: - VNI → Unicode

    /// Convert a VNI-encoded string to NFC Unicode Vietnamese.
    public static func vniToUnicode(_ text: String) -> String {
        processWordByWord(text, method: .vni)
    }

    // MARK: - Unicode → Telex

    /// Convert NFC Unicode Vietnamese to its Telex-encoded representation.
    public static func unicodeToTelex(_ text: String) -> String {
        let nfd = text.decomposedStringWithCanonicalMapping
        var result = ""
        var idx = nfd.startIndex

        while idx < nfd.endIndex {
            let ch = nfd[idx]
            idx = nfd.index(after: idx)

            // Collect combining marks following this base character
            var tone: Int? = nil
            var diacriticKind: DiacriticKind? = nil

            while idx < nfd.endIndex {
                let scalar = nfd[idx].unicodeScalars.first!.value
                // Combining diacritical marks: U+0300–U+036F
                guard scalar >= 0x0300 && scalar <= 0x036F else { break }
                switch scalar {
                case 0x0300: tone = 1           // grave  → huyền (f)
                case 0x0301: tone = 2           // acute  → sắc   (s)
                case 0x0309: tone = 3           // hook   → hỏi   (r)
                case 0x0303: tone = 4           // tilde  → ngã   (x)
                case 0x0323: tone = 5           // dot    → nặng  (j)
                case 0x0302: diacriticKind = .circumflex  // â ê ô
                case 0x0306: diacriticKind = .breve       // ă
                case 0x031B: diacriticKind = .horn        // ơ ư
                default: break
                }
                idx = nfd.index(after: idx)
            }

            result += telexSequence(for: ch, tone: tone, diacriticKind: diacriticKind)
        }
        return result
    }

    // MARK: - Unicode → VNI (stretch goal — returns input unchanged)

    public static func unicodeToVNI(_ text: String) -> String {
        // Full VNI reverse-mapping deferred; returns text unchanged
        return text
    }

    // MARK: - Private helpers

    /// Feed characters of a single word through VietEngine, return composed Unicode.
    private static func flushWord(_ word: String, method: InputMethod) -> String {
        var engine = VietEngine(method: method)
        var output = ""

        for ch in word {
            switch engine.handleKey(ch) {
            case .composing(let preview):
                output = preview          // keep updating candidate
            case .commit(let text, _):
                output += text
            case .passthrough:
                output.append(ch)
            }
        }

        // Flush residual buffer with a space trigger
        switch engine.handleKey(" ") {
        case .commit(let text, _): output += text
        default: break
        }
        engine.reset()
        return output
    }

    /// Split `text` on whitespace, convert each token, rejoin preserving separators.
    private static func processWordByWord(_ text: String, method: InputMethod) -> String {
        guard !text.isEmpty else { return "" }

        var result = ""
        var currentWord = ""

        for ch in text {
            if ch.isWhitespace || ch.isPunctuation || ch.isSymbol || ch.isNumber {
                if !currentWord.isEmpty {
                    result += flushWord(currentWord, method: method)
                    currentWord = ""
                }
                result.append(ch)
            } else {
                currentWord.append(ch)
            }
        }
        if !currentWord.isEmpty {
            result += flushWord(currentWord, method: method)
        }
        return result
    }

    // MARK: - Telex reverse-mapping helpers

    private enum DiacriticKind {
        case circumflex  // ^ used in â, ê, ô
        case breve       // w used in ă
        case horn        // w used in ơ, ư
    }

    /// Build the Telex keystroke sequence that would reproduce a given base character + marks.
    private static func telexSequence(
        for char: Character,
        tone: Int?,
        diacriticKind: DiacriticKind?
    ) -> String {
        var seq: String

        // Map base character (NFD base, i.e. bare a/e/o/u/d) to Telex double-key
        switch char {
        case "a", "A":
            switch diacriticKind {
            case .circumflex: seq = char.isUppercase ? "AA" : "aa"
            case .breve:      seq = char.isUppercase ? "AW" : "aw"
            default:          seq = String(char)
            }
        case "e", "E":
            seq = diacriticKind == .circumflex ? (char.isUppercase ? "EE" : "ee") : String(char)
        case "o", "O":
            switch diacriticKind {
            case .circumflex: seq = char.isUppercase ? "OO" : "oo"
            case .horn:       seq = char.isUppercase ? "OW" : "ow"
            default:          seq = String(char)
            }
        case "u", "U":
            seq = diacriticKind == .horn ? (char.isUppercase ? "UW" : "uw") : String(char)
        case "d", "D":
            // đ in NFD is "d" + U+0335 (combining short stroke), but macOS may emit bare "đ"
            // We handle it by the diacriticKind path; bare "d"/"D" falls through here
            seq = String(char)
        default:
            seq = String(char)
        }

        // Append tone suffix
        if let t = tone {
            let toneKeys = ["", "f", "s", "r", "x", "j"]
            if t > 0 && t < toneKeys.count {
                seq += toneKeys[t]
            }
        }

        return seq
    }
}
