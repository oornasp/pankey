// CharacterTableTests.swift — Unit tests for Vietnamese character lookup tables.
import Testing
@testable import PankeyCore

@Suite("CharacterTable")
struct CharacterTableTests {

    // MARK: - toneMap structure

    @Test func toneMapContainsAll12BaseVowels() {
        let expected: Set<Character> = ["a","e","i","o","u","y","ă","â","ê","ô","ơ","ư"]
        #expect(Set(CharacterTable.toneMap.keys) == expected)
    }

    @Test func toneMapEachVowelHas6Tones() {
        for (vowel, tones) in CharacterTable.toneMap {
            #expect(tones.count == 6, "Vowel '\(vowel)' should have 6 tone variants")
        }
    }

    // MARK: - 'a' tones (NFC)

    @Test func toneMapAVariantsAreCorrectNFC() {
        let aTones = CharacterTable.toneMap["a"]!
        #expect(String(aTones[0]) == "a")
        #expect(String(aTones[1]) == "à")
        #expect(String(aTones[2]) == "á")
        #expect(String(aTones[3]) == "ả")
        #expect(String(aTones[4]) == "ã")
        #expect(String(aTones[5]) == "ạ")
    }

    // MARK: - Special vowels with diacritic + tone

    @Test func toneMapSpecialVowelsHaveDiacriticAndTone() {
        // ă with sắc (tone 2) = ắ
        let aTones = CharacterTable.toneMap["ă"]!
        #expect(String(aTones[2]) == "ắ")

        // ê with nặng (tone 5) = ệ
        let eTones = CharacterTable.toneMap["ê"]!
        #expect(String(eTones[5]) == "ệ")
    }

    // MARK: - Telex vowel substitutions

    @Test func telexVowelSubstitutionsComplete() {
        // aa/ee/oo/dd are pair substitutions.
        // aw/uw/ow are NOT here — 'w' is handled retroactively by
        // TelexProcessor.handleW() to support typing w at any word position.
        #expect(CharacterTable.telexVowelSubstitutions["aa"] == "â")
        #expect(CharacterTable.telexVowelSubstitutions["ee"] == "ê")
        #expect(CharacterTable.telexVowelSubstitutions["oo"] == "ô")
        #expect(CharacterTable.telexVowelSubstitutions["dd"] == "đ")
        #expect(CharacterTable.telexVowelSubstitutions.count == 4)
    }

    // MARK: - Tone key maps

    @Test func telexToneKeysMappings() {
        #expect(CharacterTable.telexToneKeys["z"] == 0)  // ngang
        #expect(CharacterTable.telexToneKeys["f"] == 1)  // huyền
        #expect(CharacterTable.telexToneKeys["s"] == 2)  // sắc
        #expect(CharacterTable.telexToneKeys["r"] == 3)  // hỏi
        #expect(CharacterTable.telexToneKeys["x"] == 4)  // ngã
        #expect(CharacterTable.telexToneKeys["j"] == 5)  // nặng
    }

    @Test func vniToneDigitsMappings() {
        // VNI: 1=sắc(2), 2=huyền(1), 3=hỏi(3), 4=ngã(4), 5=nặng(5)
        #expect(CharacterTable.vniToneDigits["1"] == 2)
        #expect(CharacterTable.vniToneDigits["2"] == 1)
        #expect(CharacterTable.vniToneDigits["3"] == 3)
        #expect(CharacterTable.vniToneDigits["4"] == 4)
        #expect(CharacterTable.vniToneDigits["5"] == 5)
    }

    // MARK: - Special vowels set

    @Test func specialVowelsSetContainsAllDiacriticVowels() {
        let expected: Set<Character> = ["ă", "â", "ê", "ô", "ơ", "ư"]
        #expect(CharacterTable.specialVowels == expected)
    }
}
