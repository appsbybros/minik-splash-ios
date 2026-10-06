import Foundation

/// Port of Android OnlineSession.kt: the private-room Realtime Database protocol under
/// `minikSplash/rooms/CODE` (meta, slots, members, public, private, checkpoint, commands,
/// results, profiles), leases with authority handover, 20 Hz command pump, 12 Hz snapshots and
/// the room-seeded stable cup ordering. Field names and transactions match Android exactly so
/// iOS and Android players share rooms.
@MainActor
final class OnlineSession {
    private(set) var uid = ""
    private weak var controller: SplashController?
    private let host: String
    private let character: String
    private let hebrew: Bool
    private let mode: GameMode
    private let topic: Topic
    private let rounds: Int
    private let maxPlayers: Int
    private let playerSettings: PlayerSettings

    private var database: SplashDatabase?
    private var roomPath = ""
    private(set) var code = ""
    private var meta: Node = [:]
    private var memberOrder: [String] = []
    private var memberNodes: [String: Node] = [:]
    private var world: SplashEngine?
    private weak var view: SplashArenaView?
    private var shared: Node = [:]
    private var own: Node = [:]
    private let timeline = ReplicaTimeline()
    private var history: Node = [:]
    var standingsChanged: (() -> Void)?
    private var active = true
    private var closed = false
    private var authority = false
    private var claiming = false
    private var loadingWorld = false
    private var publishing = false
    private var round = 0
    private var lastHeartbeat: Int64 = 0
    private var lastPublish: Int64 = 0
    private var lastPrune: Int64 = 0
    private var lobbySignature = ""
    private var startBusy = false
    private var resultBusy = false
    private var counter: Int64 = 0
    private let prefix = UUID().uuidString.lowercased()
    /// Android LinkedHashMap: "move"/"aim" keep their first position when replaced.
    private var pending: [(String, Command)] = []
    private var listeners: [Int] = []
    private var commandToken: Int?
    private var status: (String) -> Void = { _ in }
    private var pumpTask: Task<Void, Never>?

    init(controller: SplashController, host: String, character: String, hebrew: Bool, mode: GameMode, topic: Topic,
         rounds: Int = 1, maxPlayers: Int = 6, playerSettings: PlayerSettings = PlayerSettings()) {
        self.controller = controller
        self.host = host
        self.character = character
        self.hebrew = hebrew
        self.mode = mode
        self.topic = topic
        self.rounds = rounds
        self.maxPlayers = maxPlayers
        self.playerSettings = playerSettings
    }

    private func tr(_ en: String, _ he: String) -> String { return AppText.t(en, he, hebrew: hebrew) }

    private func path(_ child: String) -> String { return roomPath + "/" + child }

    private func me(slot: Int) -> Node {
        var node = WorldCodec.member(Member(uid, character, team: 0, bot: false, name: Characters.get(character).name(hebrew),
                                            hebrew: hebrew, settings: playerSettings))
        node["slot"] = String(slot)
        return node
    }

    // MARK: Opening

    func open(_ join: String?, _ onStatus: @escaping (String) -> Void) throws {
        let joinCode = join ?? ""
        if !joinCode.isEmpty && !OnlineSession.isRoomCode(joinCode) {
            throw SplashOnlineError.message("Enter the six-character room code.")
        }
        let db = try SplashDatabaseFactory.make(host: host)
        status = onStatus
        database = db
        db.signIn { [weak self] result in
            guard let self = self, !self.closed else { return }
            switch result {
            case .success(let id):
                self.uid = id
                if joinCode.isEmpty { self.create() } else { self.enter(joinCode) }
            case .failure(let error):
                self.fail(error)
            }
        }
    }

    static func isRoomCode(_ value: String) -> Bool {
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ23456789")
        return value.count == 6 && value.allSatisfy { allowed.contains($0) }
    }

    private func create() {
        guard let db = database else { return }
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        code = String((0..<6).map { _ in alphabet[Int.random(in: 0..<alphabet.count)] })
        roomPath = "minikSplash/rooms/" + code
        let now = SplashClock.currentTimeMillis()
        let metaNode: Node = ["host": uid, "phase": "lobby", "mode": mode.name, "topic": topic.name,
                              "seed": NSNumber(value: now), "createdAt": NSNumber(value: now),
                              "leaseUntil": NSNumber(value: now + 8000), "epoch": 1, "round": 1, "rounds": rounds,
                              "maxPlayers": maxPlayers, "duration": 180]
        let initial: Node = ["meta": metaNode, "slots": ["0": uid] as Node, "members": [uid: me(slot: 0)] as Node]
        db.set(roomPath, initial) { [weak self] error in
            guard let self = self else { return }
            if let error = error { self.fail(error) } else { self.listen() }
        }
    }

    private func enter(_ value: String) {
        guard let db = database else { return }
        code = value
        roomPath = "minikSplash/rooms/" + code
        db.get(path("meta")) { [weak self] error, metaValue, exists in
            guard let self = self, !self.closed else { return }
            if let error = error {
                self.fail(error)
                return
            }
            if !exists {
                self.status(self.tr("Room not found.", "החדר לא נמצא."))
                return
            }
            db.get(self.path("members/" + self.uid)) { [weak self] error, _, memberExists in
                guard let self = self, !self.closed else { return }
                if let error = error {
                    self.fail(error)
                    return
                }
                if memberExists {
                    self.listen()
                    return
                }
                self.meta = NodeValue.node(metaValue)
                if self.meta.str("phase") != "lobby" {
                    self.status(self.tr("This battle has already started.", "הקרב הזה כבר התחיל."))
                    return
                }
                self.claimSlot(0)
            }
        }
    }

    private func claimSlot(_ index: Int) {
        guard let db = database else { return }
        if index >= KotlinNumber.int(meta.num("maxPlayers", Double(maxPlayers))) {
            status(tr("This room is full.", "החדר הזה מלא."))
            return
        }
        let id = uid
        db.transaction(path("slots/\(index)"), { current in
            if let current = current, (current as? String) != id { return .abort }
            return .commit(id)
        }, { [weak self] _, committed in
            guard let self = self, !self.closed else { return }
            if !committed {
                self.claimSlot(index + 1)
                return
            }
            db.set(self.path("members/" + self.uid), self.me(slot: index)) { [weak self] error in
                guard let self = self else { return }
                if let error = error { self.fail(error) } else { self.listen() }
            }
        })
    }

    private func listen() {
        guard let db = database else { return }
        SplashPrefs.onlineRoom = code
        if let profile = controller?.learningProfile() {
            db.set(path("profiles/" + uid), WorldCodec.profile(profile), nil)
        }
        db.onDisconnectSet(path("members/" + uid + "/connected"), false)
        db.set(path("members/" + uid + "/connected"), true, nil)
        watch("meta") { [weak self] n in
            guard let self = self else { return }
            self.meta = n
            self.syncRole()
            self.maybeStart()
        }
        watch("members") { [weak self] n in
            guard let self = self else { return }
            self.memberOrder = JavaOrder.hashMapOrder(Array(n.keys))
            var nodes: [String: Node] = [:]
            for (key, value) in n { nodes[key] = NodeValue.node(value) }
            self.memberNodes = nodes
            if self.authority, let world = self.world {
                for a in world.actors where !a.member.bot && self.memberNodes[a.member.id]?.flag("connected") != true {
                    a.move = V(0, 0)
                }
            }
            self.showLobby()
            self.maybeStart()
        }
        watch("public") { [weak self] n in
            guard let self = self else { return }
            if !self.authority && !n.isEmpty {
                self.shared = n
                self.timeline.accept(n, SplashClock.uptimeMillis())
            }
        }
        watch("results") { [weak self] n in
            guard let self = self else { return }
            self.history = n
            self.standingsChanged?()
        }
        watch("private/" + uid) { [weak self] n in
            guard let self = self else { return }
            self.own = n
            if !self.authority, let mine = self.world?.actor(self.uid) { WorldCodec.applyPersonal(mine, n) }
        }
        startPump()
    }

    private func watch(_ child: String, _ block: @escaping @MainActor (Node) -> Void) {
        guard let db = database else { return }
        let token = db.observe(path(child), { [weak self] value in
            guard let self = self, !self.closed else { return }
            block(NodeValue.node(value))
        }, { [weak self] error in
            guard let self = self, !self.closed else { return }
            self.status(error.localizedDescription)
        })
        listeners.append(token)
    }

    // MARK: Lobby

    private func showLobby() {
        if meta.str("phase") != "lobby" || closed { return }
        let players = memberOrder.map { id -> String in
            let n = memberNodes[id] ?? [:]
            let you = id == uid ? tr(" · You", " · אתם") : ""
            let ready = n.flag("ready") ? " ✓" : tr(" · Not ready", " · עדיין לא מוכנים")
            return n.str("name") + you + ready
        }
        let signature = players.joined(separator: ", ") + meta.str("host")
        if signature == lobbySignature { return }
        lobbySignature = signature
        controller?.lobby(code: code, players: players, ready: { [weak self] in self?.markReady() }, start: { [weak self] in self?.start() })
    }

    private func markReady() {
        guard let db = database, !roomPath.isEmpty else { return }
        db.set(path("members/" + uid + "/ready"), true, nil)
    }

    private func start() {
        guard let db = database else { return }
        if meta.str("host") != uid {
            status(tr("The room creator starts the battle.", "יוצר החדר מתחיל את הקרב."))
            return
        }
        if startBusy || meta.str("phase") != "lobby" { return }
        if memberNodes.values.contains(where: { !$0.flag("bot") && !$0.flag("ready") }) {
            status(tr("All human players must be ready.", "כל השחקנים צריכים להיות מוכנים."))
            return
        }
        startBusy = true
        var order = memberOrder
        var nodes = memberNodes
        var i = 0
        let limit = KotlinNumber.int(meta.num("maxPlayers", 6))
        while order.count < limit {
            let id = "house\(i)"
            i += 1
            if nodes[id] != nil { continue }
            let candidates = Characters.all.filter { candidate in !nodes.values.contains { $0.str("character") == candidate.id } }
            guard let c = candidates.randomElement() else { break }
            nodes[id] = WorldCodec.member(Member(id, c.id, team: 0, bot: true, name: c.name(hebrew)))
            order.append(id)
        }
        var updated: Node = [:]
        var slots: Node = [:]
        for (index, id) in order.enumerated() {
            var n = nodes[id] ?? [:]
            n["team"] = index < order.count / 2 ? 0 : 1
            n["slot"] = String(index)
            updated[id] = n
            slots[String(index)] = id
        }
        let hostId = uid
        db.update(roomPath, ["members": updated, "slots": slots]) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.startBusy = false
                self.fail(error)
                return
            }
            db.transaction(self.path("meta"), { current in
                guard var m = current as? [String: Any], m["host"] as? String == hostId, m["phase"] as? String == "lobby" else { return .abort }
                m["phase"] = "playing"
                m["leaseUntil"] = NSNumber(value: SplashClock.currentTimeMillis() + 8000)
                return .commit(m)
            }, { [weak self] error, _ in
                guard let self = self else { return }
                self.startBusy = false
                if let error = error { self.status(error.localizedDescription) }
            })
        }
    }

    // MARK: Roles and worlds

    private func syncRole() {
        let nowAuthority = meta.str("host") == uid
        if nowAuthority != authority {
            authority = nowAuthority
            if authority {
                shared = [:]
                world = nil
            } else {
                stopCommandWatch()
                view?.remote = true
            }
        }
        showLobby()
    }

    private func maybeStart() {
        let phase = meta.str("phase")
        if phase == "playing" || phase == "finished" {
            if memberNodes.count < 2 { return }
            let next = KotlinNumber.int(meta.num("round", 1))
            if round != next {
                round = next
                world = nil
                view = nil
                shared = [:]
                timeline.clear()
            }
            if world == nil && !loadingWorld { loadWorld() }
        }
    }

    private func loadWorld() {
        guard let db = database else { return }
        if meta.str("phase") == "lobby" || memberNodes.count < 2 || loadingWorld || closed { return }
        loadingWorld = true
        let list = memberOrder.map { WorldCodec.member($0, memberNodes[$0] ?? [:]) }.stableSorted { a, b in
            if a.team != b.team { return a.team < b.team }
            return a.id.javaPrecedes(b.id)
        }
        let gameMode = GameMode(rawValue: meta.str("mode", "SOLO")) ?? .solo
        guard SplashEngine.validRoster(list, gameMode) else {
            loadingWorld = false
            status(tr("Connection failed.", "החיבור נכשל."))
            return
        }
        let seed = KotlinNumber.long(meta.num("seed")) &+ Int64(round)
        let e = SplashEngine(members: list, mode: gameMode, topic: .math, seed: seed,
                             config: SplashConfig(duration: meta.num("duration", 180.0)), hebrew: hebrew,
                             matchId: "\(code)-r\(round)")
        if !authority {
            presentWorld(e)
            return
        }
        let expectedRound = round
        db.get(path("checkpoint")) { [weak self] error, value, _ in
            guard let self = self else { return }
            if let error = error {
                self.loadingWorld = false
                self.fail(error)
                return
            }
            let n = NodeValue.node(value)
            if KotlinNumber.int(n.num("round")) == expectedRound {
                WorldCodec.restore(e, n)
                self.presentWorld(e)
                return
            }
            db.get(self.path("profiles")) { [weak self] error, profiles, _ in
                guard let self = self else { return }
                if let error = error {
                    self.loadingWorld = false
                    self.fail(error)
                    return
                }
                let ps = NodeValue.node(profiles)
                for a in e.actors {
                    let stored = ps.node(a.member.id)
                    if !stored.isEmpty { e.loadProfile(a.member.id, WorldCodec.profile(stored)) }
                }
                self.presentWorld(e)
            }
        }
    }

    private func presentWorld(_ e: SplashEngine) {
        loadingWorld = false
        if closed { return }
        world = e
        if !authority {
            for a in e.actors {
                a.question = nil
                a.choices = []
            }
            if !shared.isEmpty { WorldCodec.applyShared(e, shared) }
            if let mine = e.actor(uid) { WorldCodec.applyPersonal(mine, own) }
        }
        controller?.present(e, localId: uid, tutorial: false, online: self)
        if authority { startCommandWatch() }
    }

    func attach(_ v: SplashArenaView) {
        view = v
        v.remote = !authority
        v.sendCommand = { [weak self] c in self?.submit(c) }
        v.networkStatus = tr("Private room \(code)", "חדר פרטי \(code)")
        v.spectatorSnapshot = { [weak self, weak v] in
            guard let self = self, let v = v, !self.authority, !self.shared.isEmpty else { return }
            self.timeline.render(v.engine, SplashClock.uptimeMillis())
        }
    }

    // MARK: Commands

    private func setPending(_ key: String, _ command: Command) {
        if let index = pending.firstIndex(where: { $0.0 == key }) {
            pending[index] = (key, command)
        } else {
            pending.append((key, command))
        }
    }

    private func submit(_ c: Command) {
        if closed || !active || world?.result != nil { return }
        switch c {
        case .move: setPending("move", c)
        case .aim: setPending("aim", c)
        default:
            setPending("event-\(counter)", c)
            counter += 1
        }
    }

    private func flushCommands() {
        if pending.isEmpty { return }
        let batch = pending.map { $0.1 }
        pending.removeAll()
        for c in batch {
            let id = prefix + "-\(counter)"
            counter += 1
            if authority {
                world?.command(uid, id, c)
            } else if let db = database {
                var n = WorldCodec.command(c)
                n["at"] = db.serverTimestamp
                db.set(path("commands/" + uid + "/" + id), n) { [weak self] error in
                    if let error = error { self?.fail(error) }
                }
            }
        }
    }

    private func startCommandWatch() {
        stopCommandWatch()
        guard let db = database else { return }
        commandToken = db.observeChildren(path("commands"), { [weak self] key, value in
            self?.consumeCommands(key, value)
        }, { [weak self] error in
            guard let self = self, self.authority, !self.closed else { return }
            self.status(error.localizedDescription)
        })
    }

    private func consumeCommands(_ player: String, _ value: Any?) {
        if !authority || !active { return }
        let events = NodeValue.node(value)
        for id in events.keys.sorted(by: JavaOrder.firebaseKeyPrecedes) {
            guard let command = WorldCodec.command(events.node(id)) else { continue }
            world?.command(player, id, command)
        }
    }

    private func stopCommandWatch() {
        if let token = commandToken { database?.removeObserver(token) }
        commandToken = nil
    }

    // MARK: Pump

    private func startPump() {
        pumpTask?.cancel()
        pumpTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let session = self, !session.closed else { return }
                session.cycle()
                let hz = max(session.world?.config.inputHz ?? 20, 1)
                try? await Task.sleep(nanoseconds: UInt64(1000 / hz) * 1_000_000)
            }
        }
    }

    private func cycle() {
        guard let db = database, !roomPath.isEmpty, !meta.isEmpty, active else { return }
        let now = SplashClock.currentTimeMillis()
        flushCommands()
        if now - lastHeartbeat > 2000 {
            lastHeartbeat = now
            if authority {
                db.set(path("meta/leaseUntil"), NSNumber(value: now + 8000), nil)
            } else if Double(now) > meta.num("leaseUntil") {
                claim()
            }
        }
        guard let e = world else { return }
        if authority && now - lastPublish >= 1000 / Int64(max(e.config.snapshotHz, 1)) && !publishing {
            lastPublish = now
            publishing = true
            var checkpoint = WorldCodec.checkpoint(e)
            checkpoint["round"] = round
            var updates: Node = ["public": WorldCodec.shared(e), "checkpoint": checkpoint]
            for a in e.actors where !a.member.bot { updates["private/" + a.member.id] = WorldCodec.personal(a) }
            let commandsPath = path("commands")
            db.update(roomPath, updates) { [weak self] error in
                guard let self = self else { return }
                self.publishing = false
                guard error == nil, self.authority, now - self.lastPrune > 1000 else { return }
                self.lastPrune = now
                db.get(commandsPath) { _, value, _ in
                    let consumed = Set(e.consumedState())
                    var deletions: Node = [:]
                    let players = NodeValue.node(value)
                    for (player, events) in players {
                        for (event, _) in NodeValue.node(events) where consumed.contains(event) {
                            deletions[player + "/" + event] = NSNull()
                        }
                    }
                    if !deletions.isEmpty { db.update(commandsPath, deletions, nil) }
                }
            }
            if let result = e.result { commitResult(result) }
        }
    }

    private func commitResult(_ r: MatchResult) {
        guard let db = database else { return }
        if resultBusy { return }
        resultBusy = true
        let value = WorldCodec.result(r)
        db.transaction(path("results/r\(round)"), { current in
            return current == nil ? .commit(value) : .abort
        }, { [weak self] error, _ in
            guard let self = self else { return }
            if let error = error {
                self.resultBusy = false
                self.status(error.localizedDescription)
            } else if self.authority {
                db.set(self.path("meta/phase"), "finished", nil)
            }
        })
    }

    private func claim() {
        guard let db = database else { return }
        if claiming || closed { return }
        claiming = true
        let id = uid
        db.transaction(path("meta"), { current in
            guard var m = current as? [String: Any] else { return .abort }
            let lease = NodeValue.int64(m["leaseUntil"]) ?? Int64.max
            let now = SplashClock.currentTimeMillis()
            if lease >= now { return .abort }
            m["host"] = id
            m["epoch"] = NSNumber(value: (NodeValue.int64(m["epoch"]) ?? 0) &+ 1)
            m["leaseUntil"] = NSNumber(value: now + 8000)
            return .commit(m)
        }, { [weak self] error, _ in
            guard let self = self else { return }
            self.claiming = false
            if let error = error { self.status(error.localizedDescription) }
        })
    }

    // MARK: Lifecycle

    func background() {
        let inRoom = database != nil && !roomPath.isEmpty && !uid.isEmpty
        if active && inRoom {
            setPending("move", .move(V(0, 0)))
            flushCommands()
        }
        active = false
        pending.removeAll()
        if inRoom, let db = database {
            world?.actor(uid)?.move = V(0, 0)
            db.set(path("members/" + uid + "/connected"), false, nil)
            if authority { db.set(path("meta/leaseUntil"), 0, nil) }
        }
    }

    func foreground() {
        if closed { return }
        active = true
        if let db = database, !roomPath.isEmpty, !uid.isEmpty {
            db.set(path("members/" + uid + "/connected"), true, nil)
        }
    }

    func close() {
        if closed { return }
        background()
        closed = true
        pumpTask?.cancel()
        pumpTask = nil
        for token in listeners { database?.removeObserver(token) }
        listeners.removeAll()
        stopCommandWatch()
        view?.sendCommand = nil
        view?.spectatorSnapshot = nil
    }

    // MARK: Cups

    func standingsText() -> String {
        var scores: [String: Int] = [:]
        for id in memberOrder {
            var total = 0
            for (_, value) in history { total += KotlinNumber.int(NodeValue.node(value).node("scores").num(id)) }
            scores[id] = total
        }
        let seed = KotlinNumber.long(meta.num("seed"))
        // Online cup ties use a stable room-seeded order (Java hashCode xor seed).
        let order = memberOrder.stableSorted { a, b in
            let sa = scores[a] ?? 0
            let sb = scores[b] ?? 0
            if sa != sb { return sa > sb }
            return (Int64(a.javaHashCode) ^ seed) < (Int64(b.javaHashCode) ^ seed)
        }
        let total = KotlinNumber.int(meta.num("rounds", 1))
        let lines = order.map { id -> String in
            return (memberNodes[id]?.str("name") ?? id) + "   \(scores[id] ?? 0)"
        }
        return tr("Cup · \(round) / \(total)", "גביע · \(round) / \(total)") + "\n" + lines.joined(separator: "\n")
    }

    func isCup() -> Bool { return meta.num("rounds", 1) > 1 }
    func hasNextRound() -> Bool { return meta.num("rounds", 1) > Double(round) }

    func nextRound() {
        guard let db = database else { return }
        if !authority {
            status(tr("The host opens the next round.", "מארח החדר פותח את הסיבוב הבא."))
            return
        }
        if !hasNextRound() || meta.str("phase") != "finished" { return }
        var reset: Node = [:]
        for id in memberOrder {
            var n = memberNodes[id] ?? [:]
            n["ready"] = n.flag("bot")
            reset[id] = n
        }
        resultBusy = false
        lobbySignature = ""
        let updates: Node = ["members": reset, "meta/round": round + 1, "meta/phase": "lobby",
                             "meta/leaseUntil": NSNumber(value: SplashClock.currentTimeMillis() + 8000)]
        db.update(roomPath, updates) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.fail(error)
                return
            }
            self.world = nil
            self.view = nil
            self.showLobby()
        }
    }

    private func fail(_ error: Error) {
        if closed { return }
        let message = error.localizedDescription
        status(message.isEmpty ? tr("Connection failed.", "החיבור נכשל.") : message)
    }
}
