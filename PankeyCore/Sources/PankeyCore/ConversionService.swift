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
    ///
    /// Uses Unicode scalar iteration over the NFD form so combining diacritical marks
    /// (U+0300–U+036F) appear as separate scalars and can be mapped to Telex keys.
    /// Swift's Character/grapheme-cluster iteration would bundle the marks with their
    /// base character and prevent this mapping.
    public static func unicodeToTelex(_ text: String) -> String {
        let nfd = text.decomposedStringWithCanonicalMapping
        let scalars = Array(nfd.unicodeScalars)
        var result = ""
        var i = 0

        while i < scalars.count {
            let baseScalar = scalars[i]
            i += 1
            let baseChar = Character(baseScalar)

            // Collect combining diacritical marks (U+0300–U+036F) that follow
            var tone: Int? = nil
            var diacriticKind: DiacriticKind? = nil

            while i < scalars.count {
                let val = scalars[i].value
                guard val >= 0x0300 && val <= 0x036F else { break }
                switch val {
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
                i += 1
            }

            result += telexSequence(for: baseChar, tone: tone, diacriticKind: diacriticKind)
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
            case .composing:
                break  // discard preview; committed text arrives via .commit
            case .commit(let text, _):
                output += text
            case .passthrough:
                output.append(ch)
            }
        }

        // Flush residual composition buffer with a space trigger
        switch engine.handleKey(" ") {
        case .commit(let text, _): output += text
        default: break
        }
        engine.reset()
        return output
    }

    /// Split `text` on whitespace/punctuation, convert each word token, rejoin preserving separators.
    ///
    /// In VNI mode, digits 1–9 are part of the encoding (diacritics and tones) and must
    /// NOT be treated as word delimiters — they are passed through to the engine.
    /// In Telex mode, digits are not encoding characters, so they act as delimiters.
    private static func processWordByWord(_ text: String, method: InputMethod) -> String {
        guard !text.isEmpty else { return "" }

        var result = ""
        var currentWord = ""

        for ch in text {
            let isDelimiter = ch.isWhitespace || ch.isPunctuation || ch.isSymbol ||
                              (ch.isNumber && method != .vni)
            if isDelimiter {
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
