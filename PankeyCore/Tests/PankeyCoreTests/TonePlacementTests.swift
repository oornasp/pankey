// TonePlacementTests.swift — Integration tests for Vietnamese syllable composition via VietEngine.
import Testing
@testable import PankeyCore

@Suite("TonePlacement")
struct TonePlacementTests {

    // MARK: - Helper

    /// Feed a Telex/VNI keystroke string through the engine and return committed output.
    private func compose(_ keys: String, method: InputMethod = .telex) -> String {
        var engine = VietEngine(method: method)
        var result = ""
        for ch in keys {
            switch engine.handleKey(ch) {
            case .composing: break
            case .commit(let text, _): result += text
            case .passthrough: result.append(ch)
            }
        }
        // Flush residual buffer
        if case .commit(let text, _) = engine.handleKey(" ") {
            result += text
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Basic Telex words

    @Test func telexToi() {
        // tooi: t + oo→ô + i → "tôi" (ngang, level 1 special vowel)
        #expect(compose("tooi") == "tôi")
    }

    @Test func telexViet() {
        // vieest: vi + ee→ê + t + s(sắc) → "viết" (ê with sắc)
        #expect(compose("vieest") == "viết")
    }

    @Test func telexVietNam() {
        // vieejt: vi + ee→ê + j(nặng) + t → "việt" (ê with nặng)
        #expect(compose("vieejt") == "việt")
    }

    @Test func telexKhong() {
        // khoong: kh + oo→ô + ng, ngang tone (no tone key) → "không"
        #expect(compose("khoong") == "không")
    }

    @Test func telexDuoc() {
        // dduowcj: dd→đ + u + ow→ơ + c + j(nặng) → "được"
        // Requires ươ diphthong normalisation: u before ơ → ư
        #expect(compose("dduowcj") == "được")
    }

    @Test func telexNuoc() {
        // nuowcs: n + u + ow→ơ + c + s(sắc) → "nước"
        // Requires ươ diphthong normalisation: u before ơ → ư
        #expect(compose("nuowcs") == "nước")
    }

    // MARK: - Tone placement precedence

    @Test func level1SpecialVowelGetsTone() {
        // huees: h + u + ee→ê + s(sắc) → "huế" (ê is special, gets tone)
        #expect(compose("huees") == "huế")
    }

    @Test func level2SingleVowelGetsTone() {
        // maf: m + a + f(huyền) → "mà"
        #expect(compose("maf") == "mà")
    }

    @Test func level3DiphthongEndingInAMarksFirst() {
        // For diphthong "ia" WITHOUT coda: Vietnamese places tone on 'i' (index 0).
        // "ias": i + a + s(sắc) → level-3 rule: last=='a' → index 0 → 'i' gets sắc → "ía"
        #expect(compose("ias") == "ía")
    }

    @Test func level3Triphthong() {
        // "vườn": v + ươ + n + huyền. Correct Telex: uw→ư then ow→ơ = "vuwownf"
        // (vuowow would create three vowels [u,ơ,ơ] instead of [ư,ơ])
        #expect(compose("vuwownf") == "vườn")
    }

    // MARK: - VNI

    @Test func vniToi() {
        // to6i: t + o + 6(→ô) + i → "tôi"
        #expect(compose("to6i", method: .vni) == "tôi")
    }

    @Test func vniKhong() {
        // kho6ng: kh + o + 6(→ô) + ng, ngang → "không"
        #expect(compose("kho6ng", method: .vni) == "không")
    }

    // MARK: - Backspace

    @Test func backspaceUndoesLastKeystroke() {
        var engine = VietEngine(method: .telex)
        _ = engine.handleKey("t")
        _ = engine.handleKey("o")
        _ = engine.handleKey("o")  // oo → ô applied, buffer = "tô"
        let result = engine.handleKey("\u{08}")  // backspace
        if case .composing(let preview) = result {
            // ô should be undone; buffer back to "t"
            #expect(!preview.contains("ô"), "Backspace should undo ô substitution")
        } else if case .commit(let text, _) = result {
            // Empty commit on reduced buffer is also acceptable
            #expect(text == "" || !text.contains("ô"))
        } else {
            Issue.record("Expected .composing after backspace mid-composition, got \(result)")
        }
    }

    @Test func backspaceOnEmptyBufferReturnsPassthrough() {
        var engine = VietEngine(method: .telex)
        let result = engine.handleKey("\u{08}")
        if case .passthrough = result { } else {
            Issue.record("Backspace on empty buffer should passthrough, got \(result)")
        }
    }

    // MARK: - False-positive prevention

    @Test func englishWordDoesNotProduceBothGraveAndAcute() {
        // "sofas": 's' appended (no vowel yet), 'o' vowel, 'f'→tone1(huyền),
        // 'a' appended, 's'→tone2(sắc) — the final tone wins.
        // The assertion ensures we don't simultaneously see both ò and á (two separate marks).
        let result = compose("sofas")
        #expect(!(result.contains("ò") && result.contains("á")),
                "English 'sofas' should not garble with both grave and acute: got '\(result)'")
    }

    // MARK: - NFC normalisation

    @Test func outputIsNFCNormalised() {
        let result = compose("vieest")
        let nfc = result.precomposedStringWithCanonicalMapping
        #expect(result == nfc, "Engine output must be NFC normalised")
    }
}
