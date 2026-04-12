// VNIProcessorTests.swift — Unit tests for VNI numeric keystroke processing.
import Testing
@testable import PankeyCore

@Suite("VNIProcessor")
struct VNIProcessorTests {

    // MARK: - Tone digits (1–5)

    @Test func digit1SetsSacTone() {
        var buffer = "a"
        var tone = 0
        _ = VNIProcessor.process(key: "1", buffer: &buffer, currentTone: &tone)
        #expect(tone == 2, "VNI 1 → sắc = index 2")
    }

    @Test func digit2SetsHuyenTone() {
        var buffer = "a"
        var tone = 0
        _ = VNIProcessor.process(key: "2", buffer: &buffer, currentTone: &tone)
        #expect(tone == 1, "VNI 2 → huyền = index 1")
    }

    @Test func digit3SetsHoiTone() {
        var buffer = "a"
        var tone = 0
        _ = VNIProcessor.process(key: "3", buffer: &buffer, currentTone: &tone)
        #expect(tone == 3, "VNI 3 → hỏi = index 3")
    }

    @Test func digit4SetsNgaTone() {
        var buffer = "a"
        var tone = 0
        _ = VNIProcessor.process(key: "4", buffer: &buffer, currentTone: &tone)
        #expect(tone == 4, "VNI 4 → ngã = index 4")
    }

    @Test func digit5SetsNangTone() {
        var buffer = "a"
        var tone = 0
        _ = VNIProcessor.process(key: "5", buffer: &buffer, currentTone: &tone)
        #expect(tone == 5, "VNI 5 → nặng = index 5")
    }

    // MARK: - Diacritic digits (6–8)

    @Test func digit6AppliesCircumflexToA() {
        var buffer = "a"
        var tone = 0
        _ = VNIProcessor.process(key: "6", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "â")
    }

    @Test func digit6AppliesCircumflexToE() {
        var buffer = "e"
        var tone = 0
        _ = VNIProcessor.process(key: "6", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "ê")
    }

    @Test func digit6AppliesCircumflexToO() {
        var buffer = "o"
        var tone = 0
        _ = VNIProcessor.process(key: "6", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "ô")
    }

    @Test func digit7AppliesHornToO() {
        var buffer = "o"
        var tone = 0
        _ = VNIProcessor.process(key: "7", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "ơ")
    }

    @Test func digit7AppliesHornToU() {
        var buffer = "u"
        var tone = 0
        _ = VNIProcessor.process(key: "7", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "ư")
    }

    @Test func digit8AppliesBrevToA() {
        var buffer = "a"
        var tone = 0
        _ = VNIProcessor.process(key: "8", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "ă")
    }

    // MARK: - d + 9 → đ

    @Test func digit9AppliesStrokeToDd() {
        var buffer = "d"
        var tone = 0
        _ = VNIProcessor.process(key: "9", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "đ")
    }

    // MARK: - Regular keys

    @Test func regularKeyIsAppended() {
        var buffer = "t"
        var tone = 0
        let result = VNIProcessor.process(key: "r", buffer: &buffer, currentTone: &tone)
        #expect(buffer == "tr")
        if case .appended = result { } else { Issue.record("Expected .appended, got \(result)") }
    }
}
