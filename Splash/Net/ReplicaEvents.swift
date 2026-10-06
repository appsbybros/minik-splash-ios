import Foundation

/// Port of Android ReplicaEvents.kt: audio is derived once from authoritative event
/// timestamps, never from render-frame frequency.
final class ReplicaEvents {
    private var previous: Node = [:]
    private var burstOrder: [String] = []
    private var burstSet = Set<String>()

    func clear() {
        previous = [:]
        burstOrder = []
        burstSet = []
    }

    func accept(_ next: Node) -> [(String, String)] {
        var events: [(String, String)] = []
        let actors = next.node("actors")
        if !previous.isEmpty {
            let before = previous.node("actors")
            for id in JavaOrder.hashMapOrder(Array(actors.keys)) {
                let a = actors.node(id)
                let b = before.node(id)
                if b.isEmpty { continue }
                if a.num("pickupAt", -99) > b.num("pickupAt", -99) { events.append(("pickup", id)) }
                let wrong = a.num("recoveryUntil") > b.num("recoveryUntil")
                if wrong {
                    events.append(("wrong", id))
                } else if a.num("throwAt", -99) > b.num("throwAt", -99) {
                    events.append(("throw", id))
                }
            }
        }
        for value in next.list("bursts") {
            let b = NodeValue.node(value)
            let id = b.str("id")
            let added = !burstSet.contains(id)
            if added {
                burstSet.insert(id)
                burstOrder.append(id)
            }
            if added && !previous.isEmpty, let hit = b["hit"] as? String {
                events.append(("hit", hit))
            }
        }
        while burstOrder.count > 512 {
            let first = burstOrder.removeFirst()
            burstSet.remove(first)
        }
        if !previous.isEmpty && previous.node("result").isEmpty && !next.node("result").isEmpty {
            events.append(("finish", ""))
        }
        previous = next
        return events
    }
}
