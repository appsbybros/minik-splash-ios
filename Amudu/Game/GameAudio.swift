import AVFoundation

private final class AudioBundleToken {}

/// Android SoundPool (five streams, volume 0.7) and TextToSpeech, as AVAudioPlayer pools and AVSpeechSynthesizer.
@MainActor final class GameAudio {
    /// Android `audio` map: event kind (or lobby cue) → raw resource.
    static let files: [String: String] = [
        "throw": "sfx_throw.mp3",
        "bounce": "bounce.wav",
        "catch": "ball_catch.wav",
        "pickup": "sfx_pickup.mp3",
        "penalty": "sfx_wrong.mp3",
        "freeze": "whistle.wav",
        "finish": "sfx_finish.mp3",
        "connected": "connected.mp3",
        "ready": "player_ready.mp3",
    ]

    private var players: [String: [AVAudioPlayer]] = [:]
    private let synthesizer = AVSpeechSynthesizer()
    private let streamsPerSound = 3

    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        let bundle = Bundle(for: AudioBundleToken.self)
        for (kind, file) in GameAudio.files {
            let parts = file.split(separator: ".").map(String.init)
            guard parts.count == 2,
                  let url = bundle.url(forResource: parts[0], withExtension: parts[1]) ?? Bundle.main.url(forResource: parts[0], withExtension: parts[1]) else { continue }
            var pool: [AVAudioPlayer] = []
            for _ in 0..<streamsPerSound {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.volume = 0.7
                    player.prepareToPlay()
                    pool.append(player)
                }
            }
            players[kind] = pool
        }
    }

    /// Android `audio[kind]?.let { sounds.play(it, .7f, .7f, 0, 0, 1f) }`; kinds without a sound are ignored.
    func play(_ kind: String) {
        guard let pool = players[kind], !pool.isEmpty else { return }
        let player = pool.first(where: { !$0.isPlaying }) ?? pool[0]
        player.currentTime = 0
        player.play()
    }

    /// Android `speak(s, english)`: QUEUE_FLUSH with the phone language voice, or US English when requested.
    func speak(_ text: String, english: Bool = false) {
        if text.isEmpty { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = GameAudio.voice(english ? "en-US" : AppText.speechLanguage)
        synthesizer.speak(utterance)
    }

    func stopSpeech() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private static func voice(_ language: String) -> AVSpeechSynthesisVoice? {
        if let exact = AVSpeechSynthesisVoice(language: language) { return exact }
        let prefix = language.lowercased()
        return AVSpeechSynthesisVoice.speechVoices().first { $0.language.lowercased().hasPrefix(prefix) }
    }
}
