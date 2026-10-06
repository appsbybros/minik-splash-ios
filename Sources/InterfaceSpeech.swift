import AVFoundation
import Combine
import Foundation

@MainActor
final class InterfaceSpeechPlayer: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, interfaceLocale: InterfaceLocaleID) {
        stop()
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        let localeIdentifier = interfaceLocale.rawValue
        let languageCode = Locale(identifier: localeIdentifier).language.languageCode?.identifier
        utterance.voice = AVSpeechSynthesisVoice(language: localeIdentifier)
            ?? languageCode.flatMap { AVSpeechSynthesisVoice(language: $0) }
            ?? AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
