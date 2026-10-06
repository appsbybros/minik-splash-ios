import Foundation

/// Port of Android ReplicaTimeline.kt: one-snapshot visual interpolation. Simulation and
/// scoring always remain with the authority.
final class ReplicaTimeline {
    private let sounds = ReplicaEvents()
    private var older: Node = [:]
    private var newer: Node = [:]
    private var arrived: Int64 = 0
    private var interval: Int64 = 100
    private var version = 0
    private var applied = -1

    func clear() {
        sounds.clear()
        older = [:]
        newer = [:]
        arrived = 0
        version = 0
        applied = -1
    }

    func accept(_ n: Node, _ now: Int64) {
        if !newer.isEmpty && n.num("time") < newer.num("time") { clear() }
        older = newer.isEmpty ? n : newer
        newer = n
        if arrived > 0 { interval = min(max(now - arrived, 50), 200) }
        arrived = now
        version += 1
    }

    private func vector(_ n: Node, _ key: String) -> V {
        let a = n.list(key)
        let x = a.count > 0 ? NodeValue.number(a[0]) ?? 0 : 0
        let y = a.count > 1 ? NodeValue.number(a[1]) ?? 0 : 0
        return V(x, y)
    }

    func render(_ e: SplashEngine, _ now: Int64) {
        if newer.isEmpty { return }
        if applied != version {
            for (type, id) in sounds.accept(newer) { e.onEvent?(type, id) }
            WorldCodec.applyShared(e, newer)
            applied = version
        }
        let f = min(max(Double(now - arrived) / Double(interval), 0.0), 1.0)
        let before = older.node("actors")
        let after = newer.node("actors")
        for a in e.actors {
            let b = before.node(a.member.id)
            let n = after.node(a.member.id)
            if b.isEmpty || n.isEmpty { continue }
            let from = vector(b, "position")
            let to = vector(n, "position")
            a.position = from + (to - from) * f
            a.height = b.num("height") + (n.num("height") - b.num("height")) * f
            a.gait = b.num("gait") + (n.num("gait") - b.num("gait")) * f
        }
        var oldShots: [String: Node] = [:]
        for item in older.list("shots") {
            let s = NodeValue.node(item)
            oldShots[s.str("id")] = s
        }
        var newShots: [String: Node] = [:]
        for item in newer.list("shots") {
            let s = NodeValue.node(item)
            newShots[s.str("id")] = s
        }
        for i in e.shots.indices {
            guard let b = oldShots[e.shots[i].id], let n = newShots[e.shots[i].id] else { continue }
            let from = vector(b, "position")
            e.shots[i].position = from + (vector(n, "position") - from) * f
            e.shots[i].height = b.num("height") + (n.num("height") - b.num("height")) * f
        }
        e.restoreClock(older.num("time") + (newer.num("time") - older.num("time")) * f)
    }
}
