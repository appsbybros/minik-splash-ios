import Foundation

enum PingPongHostAction: Hashable, Sendable {
    case removeAds
    case redeemCode
}

struct PingPongInterstitialPolicy: Equatable, Sendable {
    var completedMatchesPerOpportunity: Int = 2

    func isOpportunity(afterCompletedMatch number: Int) -> Bool {
        let cadence = max(completedMatchesPerOpportunity, 1)
        return number > 0 && number.isMultiple(of: cadence)
    }
}

/// The game reports completed matches to its host. Ads, commerce, entitlement,
/// and code redemption remain outside the game and can be supplied by the
/// shared product services when those systems exist.
protocol PingPongHostServices: AnyObject {
    var availableActions: Set<PingPongHostAction> { get }
    func completedMatch(number: Int, isInterstitialOpportunity: Bool)
    func perform(_ action: PingPongHostAction)
}

final class UnconfiguredPingPongHostServices: PingPongHostServices {
    let availableActions: Set<PingPongHostAction> = []

    func completedMatch(number: Int, isInterstitialOpportunity: Bool) {
        // Intentionally no-op. A future shared ad policy consumes this boundary.
    }

    func perform(_ action: PingPongHostAction) {
        // Intentionally no-op. No purchase, entitlement, or redemption success
        // is represented until the shared services are implemented.
    }
}
