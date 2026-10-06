import AVFoundation
import Combine
import Foundation

@MainActor
final class LanguageSoccerSoundPlayer: ObservableObject {
    private var players: [String: AVAudioPlayer] = [:]

    func playKick() {
        play(named: "minik_kick")
    }

    func playWrongLetterGoal() {
        play(named: "minik_kick2")
    }

    func stop() {
        for player in players.values { player.stop() }
    }

    private func play(named name: String) {
        if players[name] == nil,
           let url = Bundle.main.url(forResource: name, withExtension: "mp3"),
           let player = try? AVAudioPlayer(contentsOf: url) {
            player.prepareToPlay()
            players[name] = player
        }
        guard let player = players[name] else { return }
        player.currentTime = 0
        player.play()
    }
}
