import Foundation
import SwiftUI

/// Android's seven small stars twinkle across the upper 55% of the board.
struct LanguagePracticeStars: View {
    let startedAt: Date
    let usesFaces: Bool
    let duration: TimeInterval
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var placements = (0..<7).map { _ in
        Placement(x: Double.random(in: 0...1), y: Double.random(in: 0...0.55),
                  delay: Double.random(in: 0...0.35))
    }

    private struct Placement {
        let x: Double
        let y: Double
        let delay: TimeInterval
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active)) { context in
                let elapsed = context.date.timeIntervalSince(startedAt)
                ForEach(Array(placements.enumerated()), id: \.offset) { index, placement in
                    let age = max(0, elapsed - placement.delay)
                    let alphaPhase = age.truncatingRemainder(dividingBy: 0.4) / 0.4
                    let scalePhase = age.truncatingRemainder(dividingBy: 0.5) / 0.5
                    MinikArtworkImage(name: asset(index))
                        .frame(width: CGFloat([24, 28, 20, 26, 22, 24, 26][index]), height: 28)
                        .scaleEffect(reduceMotion ? 1 : CGFloat(0.9 + 0.25 * sin(.pi * scalePhase)))
                        .opacity(elapsed > duration ? 0 : (reduceMotion ? 1 : sin(.pi * alphaPhase)))
                        .position(x: 14 + CGFloat(placement.x) * max(0, geometry.size.width - 28),
                                  y: 14 + CGFloat(placement.y) * max(0, geometry.size.height - 28))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func asset(_ index: Int) -> String {
        (usesFaces ? LanguagePracticeArtwork.starFacePrefix : LanguagePracticeArtwork.starPrefix) + String(index + 1)
    }
}
