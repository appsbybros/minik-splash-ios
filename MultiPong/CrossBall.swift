import Foundation

// Android cross/CrossBall.kt (MinikCrossPong 828c6fc).

/// Contact impulse: horizontal world velocity (units/s) and vertical lift (height units/s).
struct CrossLaunch: Equatable {
    var velocity: MPPoint
    var lift: Double
}

/// Complete, copyable ball state. `rebound` is a serve's planned launch from its own-side bounce (the cross form of the
/// classic serve's second segment); `stopped` after a net, an off-table landing or a dead bounce.
struct CrossBallState: Equatable {
    var position: MPPoint
    var height: Double
    var velocity: MPPoint
    var lift: Double
    var rebound: CrossLaunch? = nil
    var stopped = false
    func valid() -> Bool {
        var values = [position.x, position.y, height, velocity.x, velocity.y, lift]
        if let r = rebound { values += [r.velocity.x, r.velocity.y, r.lift] }
        guard values.allSatisfy({ $0.isFinite }) else { return false }
        guard position.length < 16, height >= -0.01, height <= 12, velocity.length < 20, abs(lift) < 30 else { return false }
        if let r = rebound { return r.velocity.length < 20 && abs(r.lift) < 30 }
        return true
    }
}

enum CrossBallEvent: Equatable {
    /// Height reached 0 above the table; `owner` = territory owner of the point.
    case bounce(point: MPPoint, owner: Int)
    /// Met a net wall or the centre post at `height` <= netHeight; the ball is stopped there.
    case net(point: MPPoint, height: Double)
    /// Height reached 0 off the table; the ball is stopped (it falls away visually).
    case landed(point: MPPoint)
    var point: MPPoint {
        switch self {
        case let .bounce(point, _): return point
        case let .net(point, _): return point
        case let .landed(point): return point
        }
    }
    var isBounce: Bool { if case .bounce = self { return true }; return false }
}

/// First event of a simulated copy, `seconds` after the forecast started, and the copy's state right after it.
struct CrossBallForecast {
    var event: CrossBallEvent
    var seconds: Double
    var state: CrossBallState
}

/// Linear horizontal flight (no spin) under gravity over the shared cross table. The ball may cross the empty gaps between
/// arms freely; a shot is never clamped or curved back onto the table.
final class CrossBall {
    static let substep = 1.0 / 120
    static let maxStep = 1.0 / 30
    static let forecastSeconds = 4.0
    static let minBounceLift = 0.05
    private static let guardTime = 1e-9

    let geometry: CrossGeometry
    let gravity: Double, restitution: Double, netHeight: Double
    private(set) var position: MPPoint
    private(set) var height: Double
    private(set) var velocity: MPPoint
    private(set) var lift: Double
    private(set) var rebound: CrossLaunch?
    private(set) var stopped: Bool

    init(_ geometry: CrossGeometry, gravity: Double, restitution: Double, netHeight: Double, initial: CrossBallState) {
        self.geometry = geometry; self.gravity = gravity; self.restitution = restitution; self.netHeight = netHeight
        position = initial.position; height = initial.height; velocity = initial.velocity; lift = initial.lift
        rebound = initial.rebound; stopped = initial.stopped
    }
    convenience init(_ geometry: CrossGeometry, tuning: MPTuning, initial: CrossBallState) {
        self.init(geometry, gravity: tuning.gravity, restitution: tuning.bounceRestitution, netHeight: tuning.netHeight, initial: initial)
    }
    var state: CrossBallState { CrossBallState(position: position, height: height, velocity: velocity, lift: lift, rebound: rebound, stopped: stopped) }
    func restore(_ s: CrossBallState) {
        position = s.position; height = s.height; velocity = s.velocity; lift = s.lift; rebound = s.rebound; stopped = s.stopped
    }
    func copy() -> CrossBall { CrossBall(geometry, gravity: gravity, restitution: restitution, netHeight: netHeight, initial: state) }
    /// A contact: the ball leaves `from` at `height` with `shot`; a serve also carries its own-bounce `rebound`.
    func launch(_ from: MPPoint, _ height: Double, _ shot: CrossLaunch, rebound: CrossLaunch? = nil) {
        restore(CrossBallState(position: from, height: max(height, 0), velocity: shot.velocity, lift: shot.lift, rebound: rebound))
    }
    /// Advances dt (the engine uses fixed 1/120 s substeps) and returns at most one event. A bounce is resolved at its exact
    /// time and the rest of the step continues from it; a further event inside that rest is left just ahead of the ball, so
    /// the next step reports it.
    @discardableResult func step(_ dt: Double) -> CrossBallEvent? {
        // A NaN step would turn the whole state into NaN.
        if stopped || dt.isNaN { return nil }
        let total = min(CrossBall.maxStep, max(0, dt))
        if total <= 0 { return nil }
        let (event, used) = move(total, apply: true)
        if let event, event.isBounce, !stopped, total - used > 1e-12 { _ = move(total - used, apply: false) }
        return event
    }
    /// Simulates a copy until its first event (receiver prediction, target indicator, AI intercept). The live ball never
    /// advances.
    func forecast(_ maxSeconds: Double = CrossBall.forecastSeconds) -> CrossBallForecast? {
        if stopped || maxSeconds <= 0 { return nil }
        let probe = copy()
        let (event, seconds) = probe.move(maxSeconds, apply: true)
        guard let event else { return nil }
        return CrossBallForecast(event: event, seconds: seconds, state: probe.state)
    }
    /// Time until the ball would reach table height.
    func groundTime() -> Double { (lift + sqrt(lift * lift + 2 * gravity * max(height, 0))) / gravity }
    private func move(_ limit: Double, apply: Bool) -> (CrossBallEvent?, Double) {
        let ground = groundTime()
        let air = min(limit, ground)
        let net = netTime(air)
        let landing: Double? = net ?? (ground <= limit ? ground : nil)
        guard let at = landing else { advance(air); return (nil, air) }
        if !apply {
            let safe = max(0, at - CrossBall.guardTime)
            advance(safe)
            return (nil, safe)
        }
        advance(at)
        let point = position
        if net != nil {
            let h = max(0, height)
            stop(h)
            return (.net(point: point, height: h), at)
        }
        height = 0
        guard let owner = geometry.owner(point) else {
            stop(0)
            return (.landed(point: point), at)
        }
        if let planned = rebound { velocity = planned.velocity; lift = planned.lift; rebound = nil }
        else { lift = abs(lift) * restitution }
        // A dead ball would otherwise bounce in place on every later step.
        if lift < CrossBall.minBounceLift { stop(0) }
        return (.bounce(point: point, owner: owner), at)
    }
    /// Earliest time within `span` at which the ball meets a net wall or the post at height <= netHeight.
    private func netTime(_ span: Double) -> Double? {
        var best: Double?
        for range in geometry.netSpans(position, position + velocity * span) {
            let lo = range.start * span
            let hi = range.end * span
            let t: Double
            if heightAt(lo) <= netHeight { t = lo }
            else if heightAt(hi) <= netHeight {
                // Height is concave: it descends onto the net top inside this range.
                let descent = (lift + sqrt(max(0, lift * lift + 2 * gravity * (height - netHeight)))) / gravity
                t = min(hi, max(lo, descent))
            } else { continue }
            if best == nil || t < best! { best = t }
        }
        return best
    }
    private func heightAt(_ t: Double) -> Double { height + lift * t - 0.5 * gravity * t * t }
    private func advance(_ t: Double) {
        if t <= 0 { return }
        position = position + velocity * t
        height += lift * t - 0.5 * gravity * t * t
        lift -= gravity * t
    }
    private func stop(_ atHeight: Double) {
        height = atHeight; velocity = MPPoint(0, 0); lift = 0; rebound = nil; stopped = true
    }
}
