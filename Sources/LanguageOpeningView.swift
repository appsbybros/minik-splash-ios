import AVFoundation
import SwiftUI
import UIKit

/// IntroScreen's once-per-launch opening: original clip, 20% audio, tap to
/// dismiss, completion fallback at ten seconds, and the original 0.84 crop.
/// Reduce Motion and leaving the active scene return directly to the welcome.
@MainActor
struct LanguageOpeningView: View {
    let onFinish: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var player: AVPlayer?
    @State private var finished = false

    var body: some View {
        GeometryReader { _ in
            LanguageOpeningPlayer(player: player)
                .scaleEffect(x: 1, y: 1 / 0.84)
                .clipped()
                .background(.white)
                .contentShape(Rectangle())
                .onTapGesture(perform: finish)
                .accessibilityElement()
                .accessibilityLabel("Welcome to Minik!")
                .accessibilityHint("Continue")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(.default) { finish() }
        }
        .task {
            guard !reduceMotion,
                  let url = Bundle.main.url(forResource: "intro_animation_plus", withExtension: "mp4") else {
                finish()
                return
            }
            let openingPlayer = AVPlayer(url: url)
            openingPlayer.volume = 0.2
            player = openingPlayer
            openingPlayer.play()
            do {
                try await Task.sleep(nanoseconds: 10_000_000_000)
                finish()
            } catch {
                // View removal cancels the timeout; it must not dismiss a later route.
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { notification in
            guard let item = player?.currentItem,
                  let ended = notification.object as? AVPlayerItem,
                  ended === item else { return }
            finish()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { finish() }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        player?.pause()
        onFinish()
    }
}

@MainActor
private struct LanguageOpeningPlayer: UIViewRepresentable {
    let player: AVPlayer?

    func makeUIView(context: Context) -> LanguageOpeningSurface {
        let view = LanguageOpeningSurface()
        view.backgroundColor = .white
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: LanguageOpeningSurface, context: Context) {
        uiView.playerLayer.player = player
    }

    static func dismantleUIView(_ uiView: LanguageOpeningSurface, coordinator: ()) {
        uiView.playerLayer.player = nil
    }
}

@MainActor
private final class LanguageOpeningSurface: UIView {
    nonisolated override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
