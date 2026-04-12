// ConversionServiceTests.swift — Unit tests for batch text conversion between encodings.
import Testing
@testable import PankeyCore

@Suite("ConversionService")
struct ConversionServiceTests {

    // MARK: - Telex → Unicode

    @Test func telexToUnicodeSingleWord() {
        // khoong: kh + oo→ô + ng, ngang → "không"
        #expect(ConversionService.telexToUnicode("khoong") == "không")
    }

    @Test func telexToUnicodeMultiWord() {
        // tieengs = ti + ee→ê + ng + s(sắc) → "tiếng"
        // vieejt  = vi + ee→ê + j(nặng) + t → "việt"
        let result = ConversionService.telexToUnicode("tieengs vieejt")
        #expect(result == "tiếng việt")
    }

    @Test func telexToUnicodeNonConflictingAscii() {
        // Words with no Telex tone-key letters (z,f,s,r,x,j) and no double-vowel pairs
        // pass through without modification.
        let result = ConversionService.telexToUnicode("cat bat")
        #expect(result == "cat bat")
    }

    @Test func telexToUnicodeEmptyString() {
        #expect(ConversionService.telexToUnicode("") == "")
    }

    @Test func telexToUnicodeToi() {
        // tooi → "tôi"
        #expect(ConversionService.telexToUnicode("tooi") == "tôi")
    }

    // MARK: - VNI → Unicode

    @Test func vniToUnicodeSingleWord() {
        // kho6ng: kh + o + 6(→ô) + ng, ngang → "không"
        #expect(ConversionService.vniToUnicode("kho6ng") == "không")
    }

    @Test func vniToUnicodeToi() {
        // to6i: t + o + 6(→ô) + i → "tôi"
        #expect(ConversionService.vniToUnicode("to6i") == "tôi")
    }

    @Test func vniToUnicodeEmptyString() {
        #expect(ConversionService.vniToUnicode("") == "")
    }

    // MARK: - Unicode → Telex

    @Test func unicodeToTelexSingleWord() {
        // "không" (ô, ngang) → NFD: o + U+0302 → telex "oo", no tone suffix → "khoong"
        let result = ConversionService.unicodeToTelex("không")
        #expect(result == "khoong")
    }

    @Test func unicodeToTelexEmptyString() {
        #expect(ConversionService.unicodeToTelex("") == "")
    }

    @Test func unicodeToTelexPlainAscii() {
        #expect(ConversionService.unicodeToTelex("hello") == "hello")
    }

    // MARK: - convert() API

    @Test func convertSameFormatReturnsIdentical() {
        let text = "tiếng việt"
        #expect(ConversionService.convert(text, from: .unicode, to: .unicode) == text)
    }

    @Test func convertTelexToUnicode() {
        let result = ConversionService.convert("tooi", from: .telex, to: .unicode)
        #expect(result == "tôi")
    }

    @Test func convertUnicodeToTelex() {
        // round-trip: "tôi" → Telex → should produce "tooi"
        let result = ConversionService.convert("tôi", from: .unicode, to: .telex)
        #expect(result == "tooi")
    }
}
