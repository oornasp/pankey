// CharacterTable.swift — Vietnamese character lookup tables (NFC precomposed)
// Tone indices: 0=ngang (flat), 1=huyền, 2=sắc, 3=hỏi, 4=ngã, 5=nặng

public enum CharacterTable {

    // MARK: - Vowel × Tone table (NFC precomposed)

    public static let toneMap: [Character: [Character]] = [
        "a": ["a", "à", "á", "ả", "ã", "ạ"],
        "e": ["e", "è", "é", "ẻ", "ẽ", "ẹ"],
        "i": ["i", "ì", "í", "ỉ", "ĩ", "ị"],
        "o": ["o", "ò", "ó", "ỏ", "õ", "ọ"],
        "u": ["u", "ù", "ú", "ủ", "ũ", "ụ"],
        "y": ["y", "ỳ", "ý", "ỷ", "ỹ", "ỵ"],
        "ă": ["ă", "ằ", "ắ", "ẳ", "ẵ", "ặ"],
        "â": ["â", "ầ", "ấ", "ẩ", "ẫ", "ậ"],
        "ê": ["ê", "ề", "ế", "ể", "ễ", "ệ"],
        "ô": ["ô", "ồ", "ố", "ổ", "ỗ", "ộ"],
        "ơ": ["ơ", "ờ", "ớ", "ở", "ỡ", "ợ"],
        "ư": ["ư", "ừ", "ứ", "ử", "ữ", "ự"],
    ]

    // MARK: - Telex vowel substitutions (double-key)

    /// Double-key sequences that produce a diacritic vowel or đ
    public static let telexVowelSubstitutions: [String: Character] = [
        "aa": "â",
        "aw": "ă",
        "ee": "ê",
        "oo": "ô",
        "ow": "ơ",
        "uw": "ư",
        "dd": "đ",
    ]

    // MARK: - Telex tone keys → tone index

    /// z=cancel/ngang(0), f=huyền(1), s=sắc(2), r=hỏi(3), x=ngã(4), j=nặng(5)
    public static let telexToneKeys: [Character: Int] = [
        "z": 0,
        "f": 1,
        "s": 2,
        "r": 3,
        "x": 4,
        "j": 5,
    ]

    // MARK: - VNI tone digits → tone index

    /// 1=sắc(2), 2=huyền(1), 3=hỏi(3), 4=ngã(4), 5=nặng(5)
    public static let vniToneDigits: [Character: Int] = [
        "1": 2,
        "2": 1,
        "3": 3,
        "4": 4,
        "5": 5,
    ]

    // MARK: - VNI diacritic digits → modified vowel

    /// vowelChar + digitChar → diacritical vowel (e.g. "a6" → â)
    public static let vniDiacriticMap: [String: Character] = [
        "a6": "â",
        "e6": "ê",
        "o6": "ô",
        "o7": "ơ",
        "u7": "ư",
        "a8": "ă",
        // "d9" → đ is handled separately in VNIProcessor
    ]

    // MARK: - Valid Vietnamese coda consonants (false-positive prevention)

    /// These are the ONLY valid syllable-final consonants in Vietnamese
    public static let validEndConsonants: Set<String> = [
        "c", "ch", "m", "n", "ng", "nh", "p", "t",
    ]

    // MARK: - Special vowels (Level 1 tone placement priority)

    /// Vowels with diacritics always receive the tone mark first
    public static let specialVowels: Set<Character> = ["ă", "â", "ê", "ô", "ơ", "ư"]
}
