// TelexProcessorTests.swift — Unit tests for Telex double-key, triple-key, and tone key processing.
import Testing
@testable import PankeyCore

@Suite("TelexProcessor")
struct TelexProcessorTests {

    // MARK: - Double-key vowel substitutions

    @Test func doubleKeyAaProducesCircumflex() {
        var buffer = "a"
        var tone = 0
        let result = TelexProcessor.process(key: "a", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "â")
        if case .modified = result { } else { Issue.record("Expected .modified, got \(result)") }
    }

    @Test func doubleKeyAwProducesBreve() {
        var buffer = "a"
        var tone = 0
        _ = TelexProcessor.process(key: "w", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "ă")
    }

    @Test func doubleKeyEeProducesCircumflex() {
        var buffer = "e"
        var tone = 0
        _ = TelexProcessor.process(key: "e", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "ê")
    }

    @Test func doubleKeyOoProducesCircumflex() {
        var buffer = "o"
        var tone = 0
        _ = TelexProcessor.process(key: "o", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "ô")
    }

    @Test func doubleKeyOwProducesHorn() {
        var buffer = "o"
        var tone = 0
        _ = TelexProcessor.process(key: "w", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "ơ")
    }

    @Test func doubleKeyUwProducesHorn() {
        var buffer = "u"
        var tone = 0
        _ = TelexProcessor.process(key: "w", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "ư")
    }

    @Test func doubleKeyDdProducesStroke() {
        var buffer = "d"
        var tone = 0
        _ = TelexProcessor.process(key: "d", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "đ")
    }

    // MARK: - Tone keys

    @Test func toneKeyFSetsTone1Huyền() {
        var buffer = "a"
        var tone = 0
        let result = TelexProcessor.process(key: "f", buffer: &buffer, currentTone: &tone)
        #expect(tone == 1)
        if case .toneApplied(1) = result { } else { Issue.record("Expected .toneApplied(1), got \(result)") }
    }

    @Test func toneKeysAllSixVariants() {
        let cases: [(Character, Int)] = [("z",0),("f",1),("s",2),("r",3),("x",4),("j",5)]
        for (key, expectedTone) in cases {
            var buffer = "a"
            var tone = 0
            _ = TelexProcessor.process(key: key, buffer: &buffer, currentTone: &tone)
            #expect(tone == expectedTone, "Key '\(key)' should set tone \(expectedTone)")
        }
    }

    @Test func toneKeyWithNoVowelAppends() {
        // 'f' with no vowel in buffer → appended as regular char
        var buffer = "s"
        var tone = 0
        let result = TelexProcessor.process(key: "f", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "sf")
        if case .appended = result { } else { Issue.record("Expected .appended when no vowel, got \(result)") }
    }

    // MARK: - Triple-key escape

    @Test func tripleKeyAaaCommitsLiteralPair() {
        // buffer = "a" (one 'a'), then pressing 'a' again gives "â",
        // then pressing 'a' a third time triggers triple-escape from "aa" state.
        // Simulate: buffer already has "a" (first press done), trigger with second 'a':
        var buffer = "a"
        var tone = 0
        _ = TelexProcessor.process(key: "a", buffer: &buffer, currentTone: &tone)
        // buffer is now "â"; simulate third 'a' which forms "â" + 'a':
        let result = TelexProcessor.process(key: "a", buffer: &buffer, currentTone: &tone)
        // Triple-key: "â" + "a" → last char of "â" is "â", pair "âa" — not in table.
        // This test verifies buffer does not end up as "ââ" (double substitution).
        #expect(!buffer.contains("ââ"))
        _ = result // result may vary by implementation
    }

    @Test func tripleKeyEscapeFromDoubleState() {
        // Direct triple-key: buffer has the pair before substitution can happen.
        // Set buffer to "a" (representing the char before 2nd press),
        // so pressing "a" yields â. Then if buffer was "a" (the base char already consumed once):
        var buffer = "aa"   // artificially place two base chars to test triple-escape path
        var tone = 0
        let result = TelexProcessor.process(key: "a", buffer: &buffer, currentTone: &tone)
        if case .tripleEscape(let committed) = result {
            #expect(committed == "aa")
        } else {
            Issue.record("Expected .tripleEscape for aaa sequence, got \(result)")
        }
    }
}
