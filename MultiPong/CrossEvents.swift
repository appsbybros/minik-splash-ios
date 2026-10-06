import Foundation

// Android cross/CrossEvents.kt (MinikCrossPong 828c6fc).

/// Event data only: the cross engine has no UI or audio dependency. Seats are table seat indices.
enum CrossEvent: Equatable {
    case swing(seat: Int, id: Int)
    case contact(seat: Int, id: Int, point: MPPoint, height: Double)
    case bounce(owner: Int, point: MPPoint)
    case net(striker: Int, point: MPPoint, height: Double)
    case rally(CrossRallyOutcome)
    case victory(seat: Int)
    case served(seat: Int)
    /// Elimination mode: `seat` (a FIXTURE seat) is out: below zero, or the fewest points when someone reached the target.
    case eliminated(seat: Int, lowest: Bool)
    /// A new table stage began with `players` players (elimination shrinks the table).
    case stage(stage: Int, players: Int)
}

/// Android `Cue`: the existing Modern sound samples.
enum CrossCue: Equatable {
    case swing, contact, net, ordinaryPoint, thirdPoint, playerFault, applause
    /// iOS `MPAudio` sample names, as `MPAudio.events` plays them for the classic game.
    var sound: String {
        switch self {
        case .swing: return "minik_kick2"
        case .contact: return "minik_kick"
        case .net: return "splash"
        case .ordinaryPoint: return "success_pictures_screen_sound"
        case .thirdPoint: return "success_in_a_raw_sound"
        case .playerFault: return "failure_sound"
        case .applause: return "minik_claps"
        }
    }
}

/// Maps drained cross events to the existing cues from the LOCAL seat's perspective (none when spectating): every
/// swing/contact/net sample; success when the local seat gains (third point on its third gain in a row, as the classic child
/// streak); failure for the local seat's own net/out/own-side (missed receives and bad serves have no failure cue, as in
/// the classic sound policy); applause only when the local seat wins. Feed every drained event exactly once, in order: the
/// streak is per match.
final class CrossSoundPolicy {
    let localSeat: Int?
    private(set) var streak = 0
    init(localSeat: Int?) { self.localSeat = localSeat }
    func reset() { streak = 0 }
    func cues(_ event: CrossEvent) -> [CrossCue] {
        switch event {
        case .swing: return [.swing]
        case .contact: return [.contact]
        case .net: return [.net]
        case let .rally(outcome): return rally(outcome)
        case let .victory(seat): return localSeat != nil && seat == localSeat ? [.applause] : []
        case .bounce, .served, .eliminated, .stage: return []
        }
    }
    private func rally(_ outcome: CrossRallyOutcome) -> [CrossCue] {
        guard let local = localSeat else { return [] }
        let delta = local >= 0 && local < outcome.deltas.count ? outcome.deltas[local] : 0
        if delta > 0 {
            streak += 1
            return [streak == 3 ? .thirdPoint : .ordinaryPoint]
        }
        streak = 0
        let ownFaults: [CrossRallyKind] = [.net, .out, .ownSide]
        return outcome.faultOwner == local && ownFaults.contains(outcome.kind) ? [.playerFault] : []
    }
}
