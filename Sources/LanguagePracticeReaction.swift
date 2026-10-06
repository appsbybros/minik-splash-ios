import SwiftUI

/// Large, transparent original artwork overlays the board like WriteScreen.
/// No card/capsule is inserted into the vertical content flow.
struct LanguagePracticeReaction: View {
    let correct: Bool
    let startedAt: Date
    var successAsset = MinikVisualAsset.success
    var direction: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            if correct && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: scenePhase != .active)) { context in
                    let sample = LanguageSuccessJump.sample(
                        elapsed: context.date.timeIntervalSince(startedAt),
                        width: Double(geometry.size.width), height: Double(geometry.size.height),
                        artworkHeight: 265, direction: direction
                    )
                    // WriteScreen draws the picture inside the 200 x 265 dp container's 8 dp
                    // padding and scales and turns the container about its bottom centre.
                    MinikArtworkImage(name: successAsset)
                        .padding(8)
                        .frame(width: 200, height: 265)
                        .scaleEffect(x: CGFloat(sample.scale * direction), y: CGFloat(sample.scale), anchor: .bottom)
                        .rotationEffect(.degrees(sample.rotation), anchor: .bottom)
                        .opacity(sample.opacity)
                        .position(x: CGFloat(sample.x), y: CGFloat(sample.y))
                }
            } else {
                MinikArtworkImage(name: correct ? successAsset : MinikVisualAsset.tryAgain)
                    .padding(correct ? 8 : 0)
                    .frame(width: correct ? 200 : 165, height: correct ? 265 : 220)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .accessibilityHidden(true)
    }
}

enum LanguagePracticeArtwork {
    static let starPrefix = "language_star_"
    static let starFacePrefix = "language_star_face_"
    static let successTwo = "language_success_two"
    static let successStreak = "language_success_streak"
}
