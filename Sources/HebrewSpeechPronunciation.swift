import Foundation

/// Speech-only pronunciation fixes for Hebrew interface utterances.
///
/// Apple's Hebrew voices guess the vowels of unvocalized text and sometimes
/// guess wrong: "ברצף" ("in a row") is read "birtsef" instead of "beretsef".
/// Each entry hands the synthesizer a replacement for one whole word, usually
/// a vocalized (niqqud) spelling. Screen text and the string catalog keep the
/// plain spelling.
///
/// To add a fix, append an entry. `written` is the whole word exactly as the
/// Hebrew localization spells it, prefix letters included (a prefix changes
/// the vowels, so "וברצף" would need its own entry); `spoken` is what the
/// voice should read instead.
enum HebrewSpeechPronunciation {
    struct Entry: Sendable {
        let written: String
        let spoken: String
    }

    static let entries: [Entry] = [
        // "correct answers in a row": be-RE-tsef. If a voice still misreads
        // it, "רצופות" (retsufot) or "ברציפות" (birtsifut) keeps the meaning.
        Entry(written: "ברצף", spoken: "בְּרֶצֶף")
    ]

    /// Replaces each table word where it stands alone, never inside a longer word.
    static func spokenText(_ text: String) -> String {
        var result = text
        for entry in entries {
            result = replacingWholeWord(entry.written, with: entry.spoken, in: result)
        }
        return result
    }

    private static func replacingWholeWord(
        _ word: String,
        with replacement: String,
        in text: String
    ) -> String {
        guard !word.isEmpty else { return text }
        var output = ""
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let match = text.range(of: word, range: searchStart..<text.endIndex) {
            let startsWord = match.lowerBound == text.startIndex
                || !text[text.index(before: match.lowerBound)].isLetter
            let endsWord = match.upperBound == text.endIndex
                || !text[match.upperBound].isLetter
            output.append(contentsOf: text[searchStart..<match.lowerBound])
            if startsWord && endsWord {
                output.append(contentsOf: replacement)
            } else {
                output.append(contentsOf: text[match])
            }
            searchStart = match.upperBound
        }
        output.append(contentsOf: text[searchStart...])
        return output
    }
}

extension InterfaceLocaleID {
    /// What a synthesizer should say for interface text in this locale. Only
    /// the spoken copy changes; callers keep displaying `text` as it is.
    func spokenText(for text: String) -> String {
        self == .hebrew ? HebrewSpeechPronunciation.spokenText(text) : text
    }
}
