/// Display-only projection of the canonical alphabet card. Speech and curriculum
/// continue to use its original typed representations, independent of UI locale.
struct LanguageLearnCardPresentation: Hashable, Sendable {
    let letter: LearningTextRepresentation
    let word: LearningTextRepresentation
    let example: AssetReference
    let smallLetterAsset: String
    let capitalLetterAsset: String
}

struct LanguageLearnContentProvider: Sendable {
    private struct AlphabetItem: Sendable {
        let key: String
        let letter: String
        let word: String
        let image: AssetReference
        let spokenLetter: String?

        init(
            key: String,
            letter: String,
            word: String,
            image: AssetReference,
            spokenLetter: String? = nil
        ) {
            self.key = key
            self.letter = letter
            self.word = word
            self.image = image
            self.spokenLetter = spokenLetter
        }
    }

    private let configuration: ProductConfiguration

    init(configuration: ProductConfiguration) {
        self.configuration = configuration
    }

    func studyCards(for learnedLanguage: LanguageIdentifier) -> [StudyCard] {
        guard configuration.contentDomain == .language,
              configuration.allowsLearnedLanguage(learnedLanguage),
              let catalog = Self.catalog(for: learnedLanguage) else {
            return []
        }

        var cards: [StudyCard] = []
        cards.reserveCapacity(catalog.items.count)

        for item in catalog.items {
            let representations: [Representation] = [
                .learningText(LearningTextRepresentation(
                    text: item.letter,
                    language: learnedLanguage,
                    direction: catalog.direction,
                    speechText: item.spokenLetter
                )),
                .learningText(LearningTextRepresentation(
                    text: item.word,
                    language: learnedLanguage,
                    direction: catalog.direction
                )),
                .imageAsset(item.image)
            ]

            guard let card = StudyCard(
                id: StudyCardID(rawValue: "language.alphabet.\(learnedLanguage.rawValue).\(item.key)"),
                representations: representations,
                primarySkill: LanguageSkillIDs.alphabetRecognition,
                curriculumStage: LanguageCurriculumStageIDs.alphabet
            ) else {
                return []
            }
            cards.append(card)
        }

        return cards
    }

    static func presentation(for card: StudyCard) -> LanguageLearnCardPresentation? {
        guard card.representations.count == 3,
              case .learningText(let letter) = card.representations[0],
              case .learningText(let word) = card.representations[1],
              case .imageAsset(let example) = card.representations[2],
              let language = letter.language,
              let catalog = catalog(for: language),
              let item = catalog.items.first(where: {
                  $0.letter == letter.text && $0.word == word.text && $0.image == example
              }),
              word.language == language else { return nil }
        // These are fixed Android catalog asset names, never runtime structure IDs.
        let stem = String(item.image.rawValue.dropFirst("learn_".count))
        return LanguageLearnCardPresentation(
            letter: letter, word: word, example: example,
            smallLetterAsset: "language_letter_\(stem)",
            capitalLetterAsset: "language_letter_\(stem)_capital"
        )
    }

    static func pronunciationText(
        forLetter letter: String,
        language: LanguageIdentifier
    ) -> String? {
        guard let catalog = catalog(for: language),
              let item = catalog.items.first(where: { item in
                  item.letter.split(whereSeparator: { $0.isWhitespace }).contains {
                      String($0).lowercased() == letter.lowercased()
                  }
              }) else {
            return nil
        }
        return item.spokenLetter
    }

    private static func catalog(
        for language: LanguageIdentifier
    ) -> (items: [AlphabetItem], direction: ContentDirection)? {
        switch language {
        case .english:
            (englishAlphabet, .leftToRight)
        case .hebrew:
            (hebrewAlphabet, .rightToLeft)
        default:
            nil
        }
    }

    private static let englishAlphabet = [
        AlphabetItem(key: "a", letter: "A a", word: "Apple", image: AssetReference(rawValue: "learn_a"), spokenLetter: "a"),
        AlphabetItem(key: "b", letter: "B b", word: "Banana", image: AssetReference(rawValue: "learn_b"), spokenLetter: "b"),
        AlphabetItem(key: "c", letter: "C c", word: "Carrot", image: AssetReference(rawValue: "learn_c"), spokenLetter: "c"),
        AlphabetItem(key: "d", letter: "D d", word: "Door", image: AssetReference(rawValue: "learn_d"), spokenLetter: "d"),
        AlphabetItem(key: "e", letter: "E e", word: "Elephant", image: AssetReference(rawValue: "learn_e"), spokenLetter: "e"),
        AlphabetItem(key: "f", letter: "F f", word: "Fish", image: AssetReference(rawValue: "learn_f"), spokenLetter: "f"),
        AlphabetItem(key: "g", letter: "G g", word: "Grandfather", image: AssetReference(rawValue: "learn_g"), spokenLetter: "g"),
        AlphabetItem(key: "h", letter: "H h", word: "Hat", image: AssetReference(rawValue: "learn_h"), spokenLetter: "h"),
        AlphabetItem(key: "i", letter: "I i", word: "Igloo", image: AssetReference(rawValue: "learn_i"), spokenLetter: "i"),
        AlphabetItem(key: "j", letter: "J j", word: "Juice", image: AssetReference(rawValue: "learn_j"), spokenLetter: "j"),
        AlphabetItem(key: "k", letter: "K k", word: "Kangaroo", image: AssetReference(rawValue: "learn_k"), spokenLetter: "k"),
        AlphabetItem(key: "l", letter: "L l", word: "Lettuce", image: AssetReference(rawValue: "learn_l"), spokenLetter: "l"),
        AlphabetItem(key: "m", letter: "M m", word: "Mom", image: AssetReference(rawValue: "learn_m"), spokenLetter: "m"),
        AlphabetItem(key: "n", letter: "N n", word: "Nose", image: AssetReference(rawValue: "learn_n"), spokenLetter: "n"),
        AlphabetItem(key: "o", letter: "O o", word: "Onion", image: AssetReference(rawValue: "learn_o"), spokenLetter: "o"),
        AlphabetItem(key: "p", letter: "P p", word: "Pear", image: AssetReference(rawValue: "learn_p"), spokenLetter: "p"),
        AlphabetItem(key: "q", letter: "Q q", word: "Queen", image: AssetReference(rawValue: "learn_q"), spokenLetter: "q"),
        AlphabetItem(key: "r", letter: "R r", word: "Ruler", image: AssetReference(rawValue: "learn_r"), spokenLetter: "r"),
        AlphabetItem(key: "s", letter: "S s", word: "Scissors", image: AssetReference(rawValue: "learn_s"), spokenLetter: "s"),
        AlphabetItem(key: "t", letter: "T t", word: "Tomato", image: AssetReference(rawValue: "learn_t"), spokenLetter: "t"),
        AlphabetItem(key: "u", letter: "U u", word: "Unicorn", image: AssetReference(rawValue: "learn_u"), spokenLetter: "u"),
        AlphabetItem(key: "v", letter: "V v", word: "Violin", image: AssetReference(rawValue: "learn_v"), spokenLetter: "v"),
        AlphabetItem(key: "w", letter: "W w", word: "Watermelon", image: AssetReference(rawValue: "learn_w"), spokenLetter: "w"),
        AlphabetItem(key: "x", letter: "X x", word: "X-ray", image: AssetReference(rawValue: "learn_x"), spokenLetter: "x"),
        AlphabetItem(key: "y", letter: "Y y", word: "Yard", image: AssetReference(rawValue: "learn_y"), spokenLetter: "y"),
        AlphabetItem(key: "z", letter: "Z z", word: "Zebra", image: AssetReference(rawValue: "learn_z"), spokenLetter: "z")
    ]

    private static let hebrewAlphabet = [
        AlphabetItem(key: "alef", letter: "א", word: "אריה", image: AssetReference(rawValue: "learn_alef")),
        AlphabetItem(key: "beit", letter: "ב", word: "בננה", image: AssetReference(rawValue: "learn_beit")),
        AlphabetItem(key: "gimel", letter: "ג", word: "גזר", image: AssetReference(rawValue: "learn_gimel")),
        AlphabetItem(key: "dalet", letter: "ד", word: "דג", image: AssetReference(rawValue: "learn_dalet")),
        AlphabetItem(key: "he", letter: "ה", word: "הר", image: AssetReference(rawValue: "learn_eih")),
        AlphabetItem(key: "vav", letter: "ו", word: "ורד", image: AssetReference(rawValue: "learn_vav")),
        AlphabetItem(key: "zayin", letter: "ז", word: "זברה", image: AssetReference(rawValue: "learn_zain")),
        AlphabetItem(key: "het", letter: "ח", word: "חתול", image: AssetReference(rawValue: "learn_het")),
        AlphabetItem(key: "tet", letter: "ט", word: "טווס", image: AssetReference(rawValue: "learn_tet")),
        AlphabetItem(key: "yod", letter: "י", word: "יען", image: AssetReference(rawValue: "learn_yud")),
        AlphabetItem(key: "kaf", letter: "כ", word: "כבשה", image: AssetReference(rawValue: "learn_kaf")),
        AlphabetItem(key: "lamed", letter: "ל", word: "ליצן", image: AssetReference(rawValue: "learn_lamed")),
        AlphabetItem(key: "mem", letter: "מ", word: "מלכה", image: AssetReference(rawValue: "learn_mem")),
        AlphabetItem(key: "nun", letter: "נ", word: "נמר", image: AssetReference(rawValue: "learn_noon")),
        AlphabetItem(key: "samekh", letter: "ס", word: "סוס", image: AssetReference(rawValue: "learn_sameh")),
        AlphabetItem(key: "ayin", letter: "ע", word: "עכבר", image: AssetReference(rawValue: "learn_hain")),
        AlphabetItem(key: "pe", letter: "פ", word: "פרפר", image: AssetReference(rawValue: "learn_pei")),
        AlphabetItem(key: "tsadi", letter: "צ", word: "צב", image: AssetReference(rawValue: "learn_chadik")),
        AlphabetItem(key: "qof", letter: "ק", word: "קנגורו", image: AssetReference(rawValue: "learn_kuf")),
        AlphabetItem(key: "resh", letter: "ר", word: "רכבת", image: AssetReference(rawValue: "learn_reish")),
        AlphabetItem(key: "shin", letter: "ש", word: "שבלול", image: AssetReference(rawValue: "learn_shin")),
        AlphabetItem(key: "tav", letter: "ת", word: "תות", image: AssetReference(rawValue: "learn_taf")),
        AlphabetItem(key: "final-kaf", letter: "ך", word: "מלך", image: AssetReference(rawValue: "learn_kaf_sofit"), spokenLetter: "כ' סופית"),
        AlphabetItem(key: "final-mem", letter: "ם", word: "עולם", image: AssetReference(rawValue: "learn_mem_sofit"), spokenLetter: "מ' סופית"),
        AlphabetItem(key: "final-nun", letter: "ן", word: "שעון", image: AssetReference(rawValue: "learn_noon_sofit"), spokenLetter: "נ' סופית"),
        AlphabetItem(key: "final-pe", letter: "ף", word: "אף", image: AssetReference(rawValue: "learn_pei_sofit"), spokenLetter: "פ' סופית"),
        AlphabetItem(key: "final-tsadi", letter: "ץ", word: "עץ", image: AssetReference(rawValue: "learn_chadik_sofit"), spokenLetter: "צ' סופית")
    ]
}

enum LanguageSkillIDs {
    static let alphabetRecognition = SkillID(rawValue: "language.alphabetRecognition")
}

enum LanguageCurriculumStageIDs {
    static let alphabet = CurriculumStageID(rawValue: "language.alphabet")
}
