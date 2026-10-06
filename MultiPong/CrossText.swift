import Foundation

/// Android cross/CrossText.kt (MinikCrossPong working tree on 828c6fc, 2026-10-04): status and rally explanations from the local
/// seat's point of view (EN/HE verbatim, gender-neutral Hebrew plural; Spanish, Arabic, Hindi and Dutch through `MPText`).
enum CrossText {
    private static func name(_ names: [String], _ seat: Int?) -> String {
        guard let seat, seat >= 0, seat < names.count else { return "?" }
        return names[seat]
    }
    static func outcome(_ o: CrossRallyOutcome, names: [String], local: Int?, hebrew he: Bool) -> String {
        MPText.t(outcomeRaw(o, names: names, local: local, hebrew: he))
    }
    private static func outcomeRaw(_ o: CrossRallyOutcome, names: [String], local: Int?, hebrew he: Bool) -> String {
        func n(_ seat: Int?) -> String { name(names, seat) }
        if let out = o.eliminated {
            let why = o.kind == .missed ? MPText.t("missed at 0", "החמצה ב־0", he) : MPText.t("error at 0", "טעות ב־0", he)
            return MPText.t("\(n(out)) dropped below zero and is out! (\(why))", "\(n(out)) מתחת לאפס ומחוץ למשחק! (\(why))", he)
        }
        if let t = o.targetReached {
            let reached = t >= 0 && t < o.scoresAfter.count ? o.scoresAfter[t] : 0
            return MPText.t("\(n(t)) reached \(reached)! The player with the fewest points is out", "\(n(t)) הגיע/ה ל־\(reached)! מי שיש לו/ה הכי מעט נקודות יוצא/ת", he)
        }
        let s = o.striker, r = o.receiver
        let owner = o.faultOwner ?? s
        let zero = MPText.t(" (already at 0 — no change)", " (כבר ב־0, ללא שינוי)", he)
        let change = o.floored ? zero : ": −1"
        switch o.kind {
        case .missed:
            let index = r ?? -1
            let delta = index >= 0 && index < o.deltas.count ? o.deltas[index] : 0
            let lost = delta < 0 ? "−1" : MPText.t("stays 0", "נשאר/ת 0", he)
            if he { return "החמצה של \(n(r)) מול \(n(s)): \(n(s)) +1, \(n(r)) \(lost)" }
            if MPText.language == "en" { return "\(n(r)) missed \(s == local ? "your" : n(s) + "'s") shot: \(n(s)) +1, \(n(r)) \(lost)" }
            return MPText.t("\(n(r)) missed: \(n(s)) +1, \(n(r)) \(lost)")
        case .net: return MPText.t("\(n(owner)) hit the net", "פגיעה ברשת של \(n(owner))", he) + change
        case .out: return MPText.t("\(n(owner)): the ball landed out", "הכדור של \(n(owner)) יצא מהשולחן", he) + change
        case .ownSide: return MPText.t("\(n(owner)): the ball landed on their own side", "הכדור של \(n(owner)) נחת בצד של \(n(owner))", he) + change
        case .badServe: return MPText.t("\(n(owner)): the serve was not legal", "הגשה לא חוקית של \(n(owner))", he) + change
        }
    }
    /// Whole-fixture status: eliminations, the table change, spectating and the final duel; else the rally status. `names` are in
    /// fixture (roster) order.
    static func matchStatus(_ m: CrossMatch, names: [String], last: CrossRallyOutcome?, hebrew he: Bool) -> String {
        func tr(_ en: String, _ hebrew: String) -> String { MPText.t(en, hebrew, he) }
        let left = m.active.count
        if m.transition != nil {
            let gone = m.eliminated.last
            let who = gone.map { name(names, $0) } ?? ""
            let head = gone != nil && gone == m.localSeat ? tr("You are out!", "יצאתם מהמשחק!") : tr("\(who) is out!", "\(who) מחוץ למשחק!")
            let nextPlayers = m.players - m.eliminated.count
            let reset = m.next?.scores.allSatisfy { $0 == 0 } == true
            let tail: String
            if nextPlayers == 2 { tail = tr("Final duel next: first to \(m.target) wins.", "עכשיו קרב גמר: הראשון ל־\(m.target) מנצח.") }
            else if reset { tail = tr("Next: a table of \(nextPlayers), everyone from 0.", "ממשיכים בשולחן של \(nextPlayers), כולם מ־0.") }
            else { tail = tr("Next: a table of \(nextPlayers), scores stay.", "ממשיכים בשולחן של \(nextPlayers), הניקוד נשמר.") }
            return head + " " + tail
        }
        if m.localOut && !m.finished { return tr("You are out. Watching the rest of the match.", "יצאתם מהמשחק. צופים בהמשך.") }
        let stageNames = m.active.map { name(names, $0) }
        let base = status(m.engine, names: stageNames, last: last, hebrew: he)
        if m.duel && m.engine.referee.ralliesPlayed == 0 && m.engine.referee.phase == .awaitingServe {
            return tr("Final duel: \(stageNames.joined(separator: " vs ")). First to \(m.target)!", "קרב גמר: \(stageNames.joined(separator: " מול ")). הראשון ל־\(m.target)!") + "\n" + base
        }
        if m.pending { return base + " \u{00b7} " + tr("Tie for the fewest points: play on!", "תיקו בתחתית: ממשיכים לשחק!") }
        if m.mode == .elimination && left > 2 && m.engine.referee.ralliesPlayed == 0 && m.stage > 0 {
            return tr("Now \(left) players.", "עכשיו \(left) שחקנים.") + " " + base
        }
        return base
    }
    static func status(_ e: CrossEngine, names: [String], last: CrossRallyOutcome?, hebrew he: Bool) -> String {
        func tr(_ en: String, _ hebrew: String) -> String { MPText.t(en, hebrew, he) }
        if e.paused { return tr("Paused — tap ▶ to continue", "מושהה — הקישו ▶ כדי להמשיך") }
        let ref = e.referee
        switch e.status {
        case .yourServe:
            if e.control == .pro { return tr("Your serve: swipe up through the ball toward a player", "ההגשה שלכם: החליקו למעלה דרך הכדור לעבר שחקן") }
            return tr("Your serve: tap your side. Drag sideways to choose who gets it", "ההגשה שלכם: הקישו בצד שלכם. גררו הצידה כדי לבחור למי")
        case .otherServe: return tr("\(name(names, ref.server)) is serving", "הגשה: \(name(names, ref.server))")
        case .incoming: return tr("The ball is coming to you!", "הכדור בדרך אליכם!")
        case .yourReturn:
            switch e.control {
            case .beginner: return tr("Move your paddle to the ball — it hits by itself. Swipe a little left or right to choose who gets it (🎯)", "הזיזו את המחבט לכדור — החבטה אוטומטית. החליקו מעט שמאלה או ימינה כדי לבחור למי (🎯)")
            case .standard: return tr("Tap as the ball reaches your paddle; drag sideways to aim", "הקישו כשהכדור מגיע למחבט; גררו הצידה לכיוון")
            case .pro: return tr("Swipe through the ball toward a player", "החליקו דרך הכדור לעבר שחקן")
            }
        case .inPlay:
            if let receiver = e.predictedReceiver { return tr("Ball to \(name(names, receiver))", "הכדור אצל \(name(names, receiver))") }
            return tr("Rally", "ראלי")
        case .point: return last.map { outcome($0, names: names, local: e.localSeat, hebrew: he) } ?? ""
        case .youWon: return tr("You win! 🎉", "ניצחתם! 🎉")
        case .matchOver: return tr("\(name(names, ref.winner ?? 0)) wins the match", "ניצחון ל־\(name(names, ref.winner ?? 0))")
        case .practiceDone: return ""
        }
    }
}
