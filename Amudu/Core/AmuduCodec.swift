import Foundation

/// Android `Codec.kt`: the shared Realtime Database / checkpoint format. Field names, enum names and
/// command types are identical so iOS and Android devices can share a private room.
typealias Node = [String: Any]

extension Dictionary where Key == String, Value == Any {
    /// Kotlin `Node.num(k, d)`: any number (never a Boolean), else the default.
    func num(_ key: String, _ fallback: Double = 0.0) -> Double {
        return AmuduCodec.number(self[key]) ?? fallback
    }

    /// Kotlin `Node.str(k, d)`.
    func str(_ key: String, _ fallback: String = "") -> String {
        return (self[key] as? String) ?? fallback
    }

    /// Kotlin `Node.flag(k)`: only a real Boolean counts.
    func flag(_ key: String) -> Bool {
        return AmuduCodec.boolean(self[key]) ?? false
    }
}

enum AmuduCodec {
    // MARK: Value helpers

    static func isNull(_ value: Any?) -> Bool {
        guard let value else { return true }
        return value is NSNull
    }

    static func node(_ value: Any?) -> Node {
        if isNull(value) { return [:] }
        return (value as? [String: Any]) ?? [:]
    }

    static func items(_ value: Any?) -> [Any] {
        if isNull(value) { return [] }
        return (value as? [Any]) ?? []
    }

    static func number(_ value: Any?) -> Double? {
        if isNull(value) { return nil }
        guard let n = value as? NSNumber else { return nil }
        if CFGetTypeID(n) == CFBooleanGetTypeID() { return nil }
        return n.doubleValue
    }

    static func boolean(_ value: Any?) -> Bool? {
        if isNull(value) { return nil }
        guard let n = value as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else { return nil }
        return n.boolValue
    }

    /// Kotlin `Any.toString()` for the scalar values stored in suggestion/vote maps and lists.
    static func text(_ value: Any) -> String {
        if let s = value as? String { return s }
        if let b = boolean(value) { return b ? "true" : "false" }
        if let n = value as? NSNumber { return n.stringValue }
        return String(describing: value)
    }

    static func stringMap(_ value: Any?) -> [String: String] {
        var out: [String: String] = [:]
        for (key, raw) in node(value) where !isNull(raw) { out[key] = text(raw) }
        return out
    }

    /// A deterministic description of a node (Android uses `Map.toString()` as a change signature).
    static func describe(_ value: Any?) -> String {
        if isNull(value) { return "null" }
        if let n = value as? [String: Any] {
            let parts = n.keys.sorted().map { k in k + "=" + describe(n[k]) }
            return "{" + parts.joined(separator: ", ") + "}"
        }
        if let a = value as? [Any] { return "[" + a.map { describe($0) }.joined(separator: ", ") + "]" }
        if let scalar = value { return text(scalar) }
        return "null"
    }

    // MARK: Model encoding

    static func v(_ value: V) -> [Double] { return [value.x, value.y] }

    static func vector(_ value: Any?) -> V {
        let a = items(value)
        let x = a.count > 0 ? (number(a[0]) ?? 0.0) : 0.0
        let y = a.count > 1 ? (number(a[1]) ?? 0.0) : 0.0
        return V(x, y)
    }

    static func member(_ m: Member) -> Node {
        return ["id": m.id, "character": m.character, "name": m.name, "bot": m.bot, "hebrew": m.hebrew, "ready": m.bot, "connected": true]
    }

    static func readMember(_ n: Node) -> Member {
        return Member(n.str("id"), n.str("character"), n.str("name"), bot: n.flag("bot"), hebrew: n.flag("hebrew"))
    }

    static func config(_ c: GameConfig) -> Node {
        var n: Node = [:]
        n["scene"] = c.scene.rawValue
        n["ball"] = c.ball.rawValue
        n["freeze"] = c.freezeRule.rawValue
        n["participants"] = c.participants
        n["turns"] = c.turns
        n["huddleSeconds"] = c.huddleSeconds
        n["daylight"] = c.daylight.rawValue
        n["throwMode"] = c.throwMode.rawValue
        n["wind"] = c.wind.rawValue
        return n
    }

    static func readConfig(_ n: Node) throws -> GameConfig {
        guard let scene = ArenaScene(rawValue: n.str("scene", "PARK")) else { throw AmuduError.invalidValue("scene") }
        guard let ball = BallKind(rawValue: n.str("ball", "FOAM")) else { throw AmuduError.invalidValue("ball") }
        guard let freeze = FreezeRule(rawValue: n.str("freeze", "FREEZE")) else { throw AmuduError.invalidValue("freeze") }
        guard let daylight = Daylight(rawValue: n.str("daylight", "NOON")) else { throw AmuduError.invalidValue("daylight") }
        guard let mode = ThrowMode(rawValue: n.str("throwMode", "STANDARD")) else { throw AmuduError.invalidValue("throwMode") }
        guard let wind = Wind(rawValue: n.str("wind", "NONE")) else { throw AmuduError.invalidValue("wind") }
        return try GameConfig(scene: scene, ball: ball, freezeRule: freeze, participants: Kotlin.toInt(n.num("participants", 6.0)),
                              turns: Kotlin.toInt(n.num("turns", 0.0)), huddleSeconds: n.num("huddleSeconds", 24.0), daylight: daylight,
                              throwMode: mode, wind: wind)
    }

    static func outcome(_ r: Outcome) -> Node {
        return ["id": r.id, "penalties": r.penalties, "winners": r.winners, "elapsed": r.elapsed]
    }

    static func readOutcome(_ n: Node) -> Outcome {
        var penalties: [String: Int] = [:]
        for (k, value) in node(n["penalties"]) { penalties[k] = Kotlin.toInt(number(value) ?? 0) }
        let winners = items(n["winners"]).map { text($0) }
        return Outcome(id: n.str("id"), penalties: penalties, winners: winners, elapsed: n.num("elapsed"))
    }

    private static func actorNode(_ a: GameActor) -> Node {
        var x: Node = [:]
        x["member"] = member(a.member)
        x["position"] = v(a.position)
        x["move"] = v(a.move)
        x["direction"] = v(a.direction)
        x["facing"] = v(a.facing)
        x["actuallyMoving"] = a.actuallyMoving
        x["catchRecoveryUntil"] = a.catchRecoveryUntil
        x["catchReadyAt"] = a.catchReadyAt
        x["catchReach"] = a.catchReach
        x["catchRoll"] = a.catchRoll
        x["catchProbability"] = a.catchProbability
        x["penalties"] = a.penalties
        x["suffixes"] = a.suffixes
        x["duckUntil"] = a.duckUntil
        x["catchUntil"] = a.catchUntil
        x["throwAt"] = a.throwAt
        x["catchAt"] = a.catchAt
        x["hitAt"] = a.hitAt
        x["gait"] = a.gait
        x["nextThink"] = a.nextThink
        x["catchDecided"] = a.catchDecided
        x["movementPenaltyTurn"] = a.movementPenaltyTurn
        return x
    }

    private static func ballNode(_ b: Ball) -> Node {
        var n: Node = [:]
        n["position"] = v(b.position)
        n["height"] = b.height
        n["velocity"] = v(b.velocity)
        n["vz"] = b.vz
        n["holder"] = b.holder ?? ""
        n["bounces"] = b.bounces
        n["flightId"] = b.flightId
        n["launchAt"] = b.launchAt
        return n
    }

    /// The public snapshot every room member reads (never private suggestions or votes).
    static func shared(_ e: AmuduEngine) -> Node {
        var n: Node = [:]
        n["id"] = e.id
        n["seed"] = e.seed
        n["config"] = config(e.config)
        n["time"] = e.time
        n["phase"] = e.phase.rawValue
        n["phaseAt"] = e.phaseAt
        n["turn"] = e.turn
        n["thrower"] = e.thrower
        n["selected"] = e.selected
        n["called"] = e.called
        n["nextThrower"] = e.nextThrower
        n["landing"] = v(e.landing)
        n["frozen"] = e.frozen
        n["regroupPending"] = e.regroupPending
        n["circleFormation"] = e.circleFormation
        if let anchor = e.pickupAnchor { n["pickupAnchor"] = v(anchor) } else { n["pickupAnchor"] = NSNull() }
        n["huddleTarget"] = e.huddleTarget
        n["huddleSerial"] = e.huddleSerial
        n["huddleDeadline"] = e.huddleDeadline
        n["infoActor"] = e.infoActor
        n["infoCode"] = e.infoCode
        n["infoEn"] = e.infoEn
        n["infoHe"] = e.infoHe
        n["infoUntil"] = e.infoUntil
        n["serial"] = e.serial
        var actors: Node = [:]
        for a in e.actors { actors[a.member.id] = actorNode(a) }
        n["actors"] = actors
        n["ball"] = ballNode(e.ball)
        var events: [Any] = []
        for ev in e.events {
            let item: Node = ["id": ev.id, "kind": ev.kind, "actor": ev.actor, "text": ev.text, "at": ev.at]
            events.append(item)
        }
        n["events"] = events
        if let r = e.result { n["result"] = outcome(r) } else { n["result"] = NSNull() }
        return n
    }

    /// The authority-only checkpoint (adds dedupe IDs and private nickname state).
    static func checkpoint(_ e: AmuduEngine) -> Node {
        var n = shared(e)
        n["consumed"] = e.consumed.ordered
        n["pendingHuddles"] = e.pendingHuddles
        n["suggestions"] = e.suggestions.dictionary
        n["votes"] = e.votes.dictionary
        return n
    }

    /// Kotlin `Codec.create`. Android iterates the actor map in its own order; a Swift dictionary has none, so
    /// a saved local game passes its roster order and other sources use UTF-16 key order.
    static func create(_ n: Node, order: [String]? = nil) throws -> AmuduEngine {
        let actorsNode = node(n["actors"])
        var keys = actorsNode.keys.sorted(by: Kotlin.less)
        if let order {
            let known = order.filter { actorsNode[$0] != nil }
            keys = known + keys.filter { !known.contains($0) }
        }
        let members = keys.map { readMember(node(node(actorsNode[$0])["member"])) }
        let engine = try AmuduEngine(members: members, config: readConfig(node(n["config"])), seed: Kotlin.toLong(n.num("seed")), id: n.str("id"))
        apply(engine, n)
        return engine
    }

    static func apply(_ e: AmuduEngine, _ n: Node) {
        if n.isEmpty { return }
        e.time = n.num("time")
        e.phase = Phase(rawValue: n.str("phase", "CIRCLE")) ?? .circle
        e.phaseAt = n.num("phaseAt")
        e.turn = Kotlin.toInt(n.num("turn", 1.0))
        e.thrower = n.str("thrower")
        e.selected = n.str("selected")
        e.called = n.str("called")
        e.nextThrower = n.str("nextThrower")
        e.frozen = n.flag("frozen")
        e.regroupPending = n.flag("regroupPending")
        e.circleFormation = n.flag("circleFormation")
        e.pickupAnchor = isNull(n["pickupAnchor"]) ? nil : vector(n["pickupAnchor"])
        e.landing = vector(n["landing"])
        e.huddleTarget = n.str("huddleTarget")
        e.huddleSerial = Kotlin.toInt(n.num("huddleSerial"))
        e.huddleDeadline = n.num("huddleDeadline")
        e.infoActor = n.str("infoActor")
        e.infoCode = n.str("infoCode")
        e.infoEn = n.str("infoEn")
        e.infoHe = n.str("infoHe")
        e.infoUntil = n.num("infoUntil")
        e.serial = Kotlin.toInt(n.num("serial"))
        for (id, value) in node(n["actors"]) {
            guard let a = e.actor(id) else { continue }
            let x = node(value)
            a.position = vector(x["position"])
            a.move = vector(x["move"])
            a.direction = vector(x["direction"])
            a.facing = vector(x["facing"])
            a.actuallyMoving = x.flag("actuallyMoving")
            a.catchRecoveryUntil = x.num("catchRecoveryUntil")
            a.catchReadyAt = x.num("catchReadyAt")
            a.catchReach = x.num("catchReach", 1.0)
            a.catchRoll = x.num("catchRoll")
            a.catchProbability = x.num("catchProbability", 1.0)
            a.penalties = Kotlin.toInt(x.num("penalties"))
            a.suffixes = items(x["suffixes"]).map { text($0) }
            a.duckUntil = x.num("duckUntil")
            a.catchUntil = x.num("catchUntil")
            a.throwAt = x.num("throwAt", -99.0)
            a.catchAt = x.num("catchAt", -99.0)
            a.hitAt = x.num("hitAt", -99.0)
            a.gait = x.num("gait")
            a.nextThink = x.num("nextThink")
            a.catchDecided = x.flag("catchDecided")
            a.movementPenaltyTurn = Kotlin.toInt(x.num("movementPenaltyTurn", -1.0))
        }
        let b = node(n["ball"])
        let holder = b.str("holder")
        e.ball = Ball(vector(b["position"]), b.num("height"), vector(b["velocity"]), b.num("vz"), Kotlin.isBlank(holder) ? nil : holder,
                      bounces: Kotlin.toInt(b.num("bounces")), flightId: b.str("flightId"), launchAt: b.num("launchAt"))
        var events: [GameEvent] = []
        for item in items(n["events"]) {
            let x = node(item)
            events.append(GameEvent(id: Kotlin.toInt(x.num("id")), kind: x.str("kind"), actor: x.str("actor"), text: x.str("text"), at: x.num("at")))
        }
        e.events = events
        let result = node(n["result"])
        e.result = result.isEmpty ? nil : readOutcome(result)
        if n["consumed"] != nil {
            e.consumed.replace(with: items(n["consumed"]).map { text($0) })
            e.pendingHuddles = items(n["pendingHuddles"]).map { text($0) }
            let suggestions = stringMap(n["suggestions"])
            e.suggestions = OrderedStringMap(suggestions.keys.sorted(by: Kotlin.less).compactMap { k in suggestions[k].map { (k, $0) } })
            let votes = stringMap(n["votes"])
            e.votes = OrderedStringMap(votes.keys.sorted(by: Kotlin.less).compactMap { k in votes[k].map { (k, $0) } })
        }
    }

    static func command(_ c: GameCommand) -> Node {
        switch c {
        case .move(let value):
            return ["type": "move", "vector": v(value)]
        case .aim(let value):
            return ["type": "aim", "vector": v(value.unit())]
        case .select(let target, let typedName):
            return ["type": "select", "target": target, "name": typedName]
        case .toss(let power, let drift):
            return ["type": "toss", "power": power, "drift": drift]
        case .catchBall:
            return ["type": "catch"]
        case .duck:
            return ["type": "duck"]
        case .shout:
            return ["type": "shout"]
        case .end:
            return ["type": "end"]
        case .throwBall(let power):
            return ["type": "throw", "power": power]
        case .say(let index):
            return ["type": "say", "index": index]
        }
    }

    static func readCommand(_ n: Node) -> GameCommand? {
        switch n.str("type") {
        case "move": return .move(vector(n["vector"]))
        case "aim": return .aim(vector(n["vector"]))
        case "select": return .select(target: n.str("target"), typedName: n.str("name"))
        case "toss": return .toss(power: n.num("power"), drift: n.num("drift"))
        case "catch": return .catchBall
        case "duck": return .duck
        case "shout": return .shout
        case "end": return .end
        case "throw": return .throwBall(power: n.num("power"))
        case "say": return .say(index: Kotlin.toInt(n.num("index")))
        default: return nil
        }
    }
}
