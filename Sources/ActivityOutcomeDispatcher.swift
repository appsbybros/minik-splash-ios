import Foundation

/// Shared boundary for persisting typed activity outcomes and optionally
/// forwarding them to a product-owned reward policy. Math intentionally
/// configures no reward handler until its scoring values are approved.
final class ActivityOutcomeDispatcher {
    typealias RewardHandler = (ActivityEvent) throws -> Void

    private let progressSink: ActivityEventSink
    private let rewardHandler: RewardHandler?

    init(
        progressSink: ActivityEventSink,
        rewardHandler: RewardHandler? = nil
    ) {
        self.progressSink = progressSink
        self.rewardHandler = rewardHandler
    }

    func dispatch(_ event: ActivityEvent) throws {
        try progressSink.record(event)
        try rewardHandler?(event)
    }
}
