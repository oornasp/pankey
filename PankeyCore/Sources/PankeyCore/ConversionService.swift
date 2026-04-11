// ConversionService.swift — Batch text conversion between Telex / VNI / Unicode
// Full implementation deferred to Phase 6; stubs compile and expose the public API.
import Foundation

/// Converts full paragraphs or clipboard content between encoding schemes.
public struct ConversionService {

    // MARK: - Telex → Unicode

    /// Convert a Telex-encoded string to NFC Unicode Vietnamese.
    public static func telexToUnicode(_ text: String) -> String {
        let words = text.components(separatedBy: .whitespaces)
        return words.map { convertTelexWord($0) }.joined(separator: " ")
    }

    // MARK: - Unicode → Telex

    /// Convert NFC Unicode Vietnamese to its Telex-encoded representation.
    /// Full implementation in Phase 6; returns input unchanged for now.
    public static func unicodeToTelex(_ text: String) -> String {
        let nfd = text.decomposedStringWithCanonicalMapping
        var result = ""
        var i = nfd.startIndex
        while i < nfd.endIndex {
            result += reverseMapToTelex(nfd[i], nfd: nfd, index: &i)
        }
        return result
    }

    // MARK: - VNI → Unicode

    /// Convert a VNI-encoded string to NFC Unicode Vietnamese.
    /// Full implementation in Phase 6; returns input unchanged for now.
    public static func vniToUnicode(_ text: String) -> String {
        let words = text.components(separatedBy: .whitespaces)
        return words.map { convertVNIWord($0) }.joined(separator: " ")
    }

    // MARK: - Internal helpers

    private static func convertTelexWord(_ word: String) -> String {
        var engine = VietEngine(method: .telex)
        var output = ""
        for ch in word {
            switch engine.handleKey(ch) {
            case .composing(let preview):
                output = preview
            case .commit(let text, _):
                output += text
            case .passthrough:
                output.append(ch)
            }
        }
        // Flush remaining buffer by sending a space
        if case .commit(let text, _) = engine.handleKey(" ") {
            output += text
        }
        return output
    }

    /// Phase 6 stub — full VNI word conversion
    private static func convertVNIWord(_ word: String) -> String {
        // TODO (Phase 6): implement VNI word-by-word conversion
        return word
    }

    /// Phase 6 stub — reverse NFD combining marks to Telex sequences
    private static func reverseMapToTelex(
        _ ch: Character,
        nfd: String,
        index: inout String.Index
    ) -> String {
        // TODO (Phase 6): map combining diacritical marks back to Telex keys
        index = nfd.index(after: index)
        return String(ch)
    }
}
