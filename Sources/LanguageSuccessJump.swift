import Foundation

/// WriteScreen.playSuccessJumpAnimation (1550 ms), in physical coordinates.
enum LanguageSuccessJump {
    static let duration: TimeInterval = 1.55
    struct Sample: Equatable, Sendable {
        let x: Double
        let y: Double
        let scale: Double
        let rotation: Double
        let opacity: Double
    }

    static func sample(elapsed: TimeInterval, width: Double, height: Double,
                       artworkHeight: Double, direction: Double) -> Sample {
        let t = min(1, max(0, elapsed / duration))
        let startY = artworkHeight + 12
        let endY = startY + artworkHeight * 0.65
        let translationY = mix(startY, endY, t) - 4 * height * 0.55 * t * (1 - t)
        let scale = t < 0.16 ? mix(0.84, 1.06, t / 0.16)
            : (t < 0.48 ? mix(1.06, 1, (t - 0.16) / 0.32)
               : mix(1, 0.91, (t - 0.48) / 0.52))
        let rotation = t < 0.48 ? mix(-7 * direction, 3 * direction, t / 0.48)
            : mix(3 * direction, -5 * direction, (t - 0.48) / 0.52)
        let opacity = t < 0.08 ? t / 0.08 : (t > 0.82 ? (1 - t) / 0.18 : 1)
        return Sample(x: width / 2 + mix(-direction * width * 0.42, direction * width * 0.42, t),
                      y: height - artworkHeight / 2 + translationY,
                      scale: scale, rotation: rotation, opacity: min(1, max(0, opacity)))
    }

    private static func mix(_ start: Double, _ end: Double, _ t: Double) -> Double {
        start + (end - start) * min(1, max(0, t))
    }
}
