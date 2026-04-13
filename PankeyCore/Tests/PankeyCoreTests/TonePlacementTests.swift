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

    // MARK: - Original 3 reported bugs

    @Test func bug1_dduocjw_produces_duoc() {
        // The 'w' after coda 'c' should retroactively modify uo → ươ
        #expect(compose("dduocjw") == "được")
    }

    @Test func bug2_hehe_stays_hehe() {
        // Parser must NOT re-enter vowel mode after coda, so "hehe" stays "hehe"
        #expect(compose("hehe") == "hehe")
    }

    @Test func bug3_phair_produces_phai() {
        // For 'ai' diphthong without coda, tone goes on first vowel 'a'
        #expect(compose("phair") == "phải")
    }

    // MARK: - Retroactive W at various positions

    @Test func retroactiveW_dduowcj() {
        // Standard path: ow pair for ơ, then j for nặng
        #expect(compose("dduowcj") == "được")
    }

    @Test func retroactiveW_dduocwj() {
        // w after coda, then j: both orderings should work
        #expect(compose("dduocwj") == "được")
    }

    @Test func retroactiveW_thuowng() {
        // uo → ươ via w between vowels
        #expect(compose("thuowng") == "thương")
    }

    @Test func retroactiveW_thuongw() {
        // w at end after coda: retroactively modifies uo → ươ
        #expect(compose("thuongw") == "thương")
    }

    @Test func retroactiveW_nguowif() {
        // ươi triphthong: tone on ơ
        #expect(compose("nguowif") == "người")
    }

    @Test func retroactiveW_nuowcs() {
        // nước: ươ diphthong + coda c + sắc
        #expect(compose("nuowcs") == "nước")
    }

    @Test func retroactiveW_nuocws() {
        // Same as above but w after coda
        #expect(compose("nuocws") == "nước")
    }

    // MARK: - W with single vowels

    @Test func singleW_uw() {
        #expect(compose("uw") == "ư")
    }

    @Test func singleW_ow() {
        #expect(compose("ow") == "ơ")
    }

    @Test func singleW_aw() {
        #expect(compose("aw") == "ă")
    }

    @Test func singleW_tawm() {
        // aw → ă for single vowel context
        #expect(compose("tawm") == "tăm")
    }

    // MARK: - W toggle (undo)

    @Test func wToggle_uww() {
        // uw → ư, then ww undoes → u
        #expect(compose("uww") == "u")
    }

    @Test func wToggle_aww() {
        #expect(compose("aww") == "a")
    }

    // MARK: - W with multi-vowel patterns

    @Test func multiW_tuaw_gives_tua_horn() {
        // ua pattern: only u gets horn → ưa (like OpenKey's insertW)
        #expect(compose("tuaw") == "tưa")
    }

    @Test func multiW_quaw_gives_breve() {
        // qu is an onset cluster, so vowel is just 'a' → ă
        #expect(compose("quaw") == "quă")
    }

    // MARK: - Basic Telex words

    @Test func telexToi() {
        #expect(compose("tooi") == "tôi")
    }

    @Test func telexViet() {
        #expect(compose("vieest") == "viết")
    }

    @Test func telexVietNam() {
        #expect(compose("vieejt") == "việt")
    }

    @Test func telexKhong() {
        #expect(compose("khoong") == "không")
    }

    @Test func telexDuoc() {
        #expect(compose("dduowcj") == "được")
    }

    @Test func telexNuoc() {
        #expect(compose("nuowcs") == "nước")
    }

    // MARK: - Tone placement precedence

    @Test func level1SpecialVowelGetsTone() {
        #expect(compose("huees") == "huế")
    }

    @Test func level2SingleVowelGetsTone() {
        #expect(compose("maf") == "mà")
    }

    @Test func level3DiphthongEndingInAMarksFirst() {
        // "ia" without coda → tone on first vowel (i) → "ía"
        #expect(compose("ias") == "ía")
    }

    @Test func level3Triphthong() {
        #expect(compose("vuwownf") == "vườn")
    }

    // MARK: - Comprehensive diphthong tone placement

    @Test func diphthong_ai_no_coda() {
        // ai without coda → tone on first (a) → phải
        #expect(compose("phair") == "phải")
    }

    @Test func diphthong_oi_no_coda() {
        // oi without coda → tone on first (o) → tối
        // (But ô is special, so it gets priority — test with plain o)
        #expect(compose("oir") == "ỏi")
    }

    @Test func diphthong_ui_no_coda() {
        // ui without coda → tone on first (u)
        #expect(compose("tuif") == "tùi")
    }

    @Test func diphthong_ao_no_coda() {
        // ao without coda → tone on first (a)
        #expect(compose("baof") == "bào")
    }

    @Test func diphthong_au_no_coda() {
        // au without coda → tone on first (a)
        #expect(compose("caus") == "cáu")
    }

    @Test func diphthong_oa_no_coda() {
        // oa without coda → tone on SECOND (a) — different from ai/oi!
        #expect(compose("hoaf") == "hoà")
    }

    @Test func diphthong_oa_with_coda() {
        // oa with coda → tone on second (a) → toán
        #expect(compose("toans") == "toán")
    }

    @Test func diphthong_ia_with_g_onset() {
        // gia: gi is onset, vowel is just 'a' → tone on a
        #expect(compose("giaf") == "già")
    }

    @Test func diphthong_ua_with_q_onset() {
        // qua: qu is onset, vowel is just 'a' → tone on a
        #expect(compose("quans") == "quán")
    }

    // MARK: - Special diphthongs iê, uô, ươ

    @Test func specialDiphthong_ie_with_coda() {
        // iê with coda → tone on ê (second)
        #expect(compose("vieest") == "viết")
    }

    @Test func specialDiphthong_uo_with_coda() {
        // uô with coda → tone on ô (second)
        #expect(compose("muoons") == "muốn")
    }

    @Test func specialDiphthong_uo_no_coda() {
        // ươ without coda → tone on ư (first)
        #expect(compose("muwa") == "mưa")
    }

    // MARK: - Triphthongs

    @Test func triphthong_uoi_tone_middle() {
        // tuổi: tone on ô (middle vowel for triphthong)
        #expect(compose("tuooir") == "tuổi")
    }

    @Test func triphthong_oai_tone_middle() {
        // ngoài: tone on a (middle vowel)
        #expect(compose("ngoaif") == "ngoài")
    }

    // MARK: - VNI

    @Test func vniToi() {
        #expect(compose("to6i", method: .vni) == "tôi")
    }

    @Test func vniKhong() {
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
            #expect(!preview.contains("ô"), "Backspace should undo ô substitution")
        } else if case .commit(let text, _) = result {
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
