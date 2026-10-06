import SwiftUI
import UIKit

struct LobbyLine: Identifiable {
    let id: String
    let text: String
}

struct LobbyState {
    let code: String
    let lines: [LobbyLine]
    let host: Bool
    let onReady: @MainActor () -> Void
    let onStart: @MainActor () -> Void
}

struct ResultRow: Identifiable {
    let id: String
    let character: String
    let name: String
    let penalties: Int
    let winner: Bool
}

struct HuddleProposal: Identifiable, Equatable {
    let id: String
    let name: String
    let votes: Int
}

struct HuddleState: Equatable {
    var seconds: Int
    var proposals: [HuddleProposal]
}

/// Android `AmuduActivity`: screens, saved settings, the local/online game lifecycle, dialogs, sounds and speech.
/// Ads, purchases and code redemption are not part of the iOS app yet.
@MainActor final class AppModel: ObservableObject {
    enum Screen: Equatable {
        case home
        case setup
        case help
        case connecting
        case lobby
        case game
        case result
    }

    private enum Keys {
        static let avatar = "amudu.avatar"
        static let name = "amudu.name"
        static let scene = "amudu.scene"
        static let ball = "amudu.ball"
        static let freeze = "amudu.freeze"
        static let count = "amudu.count"
        static let turns = "amudu.turns"
        static let house = "amudu.house"
        static let daylight = "amudu.daylight"
        static let throwMode = "amudu.throwMode"
        static let wind = "amudu.wind"
        static let room = "amudu.room"
        static let saved = "amudu.saved"
    }

    static let turnChoices = [10, 20, 35, 50, 0]

    @Published var screen: Screen = .home
    @Published var toast: String?
    @Published private(set) var avatar: String
    @Published private(set) var playerName: String
    @Published var scene: ArenaScene
    @Published var ball: BallKind
    @Published var freeze: FreezeRule
    @Published var count: Int
    @Published var turns: Int
    @Published var daylight: Daylight
    @Published var throwMode: ThrowMode
    @Published var wind: Wind
    @Published private(set) var house: [String]
    @Published var connectingInfo = ""
    @Published private(set) var lobbyState: LobbyState?
    @Published private(set) var results: [ResultRow] = []
    @Published var pauseVisible = false
    @Published var nicknameVisible = false
    @Published var nicknameInput = ""
    @Published var sayVisible = false
    @Published var joinVisible = false
    @Published var joinInput = ""
    @Published private(set) var huddle: HuddleState?
    @Published var huddleInput = ""
    @Published var wordListVisible = false
    @Published private(set) var savedRoom: String?
    @Published private(set) var hasSavedGame = false
    @Published private(set) var gameView: ArenaView?

    let art: ArtStore
    let audio: GameAudio
    private(set) var online: OnlineRoom?
    private let defaults: UserDefaults
    private var localId = "p0"
    private var nicknameTarget = ""
    private var huddleTimer: Timer?
    private var toastToken = 0
    private var isForeground = true

    var hebrew: Bool { return AppText.language == "he" }

    init() {
        art = ArtStore()
        audio = GameAudio()
        let d = UserDefaults.standard
        defaults = d
        let storedAvatar = d.string(forKey: Keys.avatar) ?? "miniko"
        avatar = AmuduCharacters.exists(storedAvatar) ? storedAvatar : "miniko"
        playerName = d.string(forKey: Keys.name) ?? ""
        scene = ArenaScene(rawValue: d.string(forKey: Keys.scene) ?? "PARK") ?? .park
        ball = BallKind(rawValue: d.string(forKey: Keys.ball) ?? "FOAM") ?? .foam
        freeze = FreezeRule(rawValue: d.string(forKey: Keys.freeze) ?? "FREEZE") ?? .freeze
        let storedCount = (d.object(forKey: Keys.count) as? Int) ?? 6
        count = min(max(storedCount, 2), 10)
        let storedTurns = (d.object(forKey: Keys.turns) as? Int) ?? 0
        turns = [0, 10, 20, 35, 50].contains(storedTurns) ? storedTurns : 0
        daylight = Daylight(rawValue: d.string(forKey: Keys.daylight) ?? "NOON") ?? .noon
        throwMode = ThrowMode(rawValue: d.string(forKey: Keys.throwMode) ?? "STANDARD") ?? .standard
        wind = Wind(rawValue: d.string(forKey: Keys.wind) ?? "NONE") ?? Wind.none
        var storedHouse: [String] = []
        for id in d.stringArray(forKey: Keys.house) ?? ["minik", "kyra", "flare"] where AmuduCharacters.exists(id) && !storedHouse.contains(id) {
            storedHouse.append(id)
        }
        house = storedHouse
        savedRoom = d.string(forKey: Keys.room)
        hasSavedGame = d.string(forKey: Keys.saved) != nil
    }

    func tr(_ en: String, _ he: String) -> String {
        return GameText.t(en, he, hebrew: hebrew)
    }

    /// Android `Toast.LENGTH_LONG`.
    func status(_ s: String) {
        toastToken += 1
        let token = toastToken
        toast = s
        _ = afterDelay(3.5) { [weak self] in
            guard let self, self.toastToken == token else { return }
            self.toast = nil
        }
    }

    func sound(_ kind: String) {
        audio.play(kind)
    }

    // MARK: Home

    func home() {
        saveLocal()
        gameView?.stop()
        gameView = nil
        online?.close()
        online = nil
        pauseVisible = false
        nicknameVisible = false
        sayVisible = false
        hideHuddle()
        savedRoom = defaults.string(forKey: Keys.room)
        hasSavedGame = defaults.string(forKey: Keys.saved) != nil
        screen = .home
    }

    /// Android: the EditText keeps at most 22 characters and every change is saved.
    func updateName(_ value: String) {
        var text = value
        if text.utf16.count > 22 { text = String(decoding: Array(text.utf16.prefix(22)), as: UTF16.self) }
        playerName = text
        defaults.set(text, forKey: Keys.name)
    }

    func shiftAvatar(_ d: Int) {
        let ids = AmuduCharacters.ids
        let index = ids.firstIndex(of: avatar) ?? -1
        avatar = ids[Kotlin.floorMod(index + d, ids.count)]
        defaults.set(avatar, forKey: Keys.avatar)
    }

    private func validName() -> Bool {
        if Words.validName(playerName) { return true }
        status(tr("Enter a name with letters, spaces or numbers (up to 22 characters).", "כתבו שם באותיות, רווחים או מספרים (עד 22 תווים)."))
        return false
    }

    func openSetup() {
        house.removeAll { $0 == avatar }
        screen = .setup
    }

    func openHelp() {
        screen = .help
    }

    func requestJoin() {
        if validName() {
            joinInput = ""
            joinVisible = true
        }
    }

    func returnToRoom(_ code: String) {
        if validName() { openRoom(code) }
    }

    func join() {
        let code = Kotlin.trim(joinInput).uppercased()
        let upper: ClosedRange<Unicode.Scalar> = "A"..."Z"
        let digits: ClosedRange<Unicode.Scalar> = "2"..."9"
        let valid = code.unicodeScalars.count == 6 && code.unicodeScalars.allSatisfy { upper.contains($0) || digits.contains($0) }
        if valid {
            openRoom(code)
        } else {
            status(tr("Enter the six-character room code.", "הזינו קוד חדר בן שישה תווים."))
        }
    }

    func continueSaved() {
        guard let json = defaults.string(forKey: Keys.saved),
              let data = json.data(using: .utf8),
              let wrapper = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let engine = try? AmuduCodec.create(AmuduCodec.node(wrapper["checkpoint"]), order: wrapper["order"] as? [String]) else {
            status(tr("Saved game could not be restored.", "לא ניתן לשחזר את המשחק."))
            return
        }
        present(engine, uid: "p0", network: nil)
    }

    // MARK: Setup

    private func config(_ n: Int? = nil) -> GameConfig? {
        return try? GameConfig(scene: scene, ball: ball, freezeRule: freeze, participants: n ?? count, turns: turns, daylight: daylight,
                               throwMode: throwMode, wind: wind)
    }

    func persist() {
        defaults.set(scene.rawValue, forKey: Keys.scene)
        defaults.set(ball.rawValue, forKey: Keys.ball)
        defaults.set(freeze.rawValue, forKey: Keys.freeze)
        defaults.set(count, forKey: Keys.count)
        defaults.set(turns, forKey: Keys.turns)
        defaults.set(house, forKey: Keys.house)
        defaults.set(daylight.rawValue, forKey: Keys.daylight)
        defaults.set(throwMode.rawValue, forKey: Keys.throwMode)
        defaults.set(wind.rawValue, forKey: Keys.wind)
    }

    func setHouse(_ id: String, _ selected: Bool) {
        if selected {
            if !house.contains(id) { house.append(id) }
        } else {
            house.removeAll { $0 == id }
        }
        persist()
    }

    func startLocal() {
        var roster = [Member("p0", avatar, AmuduCharacters.get(avatar).name(hebrew: hebrew), bot: false, hebrew: hebrew)]
        let chosen = Array(AmuduCharacters.availableBots(humans: [roster[0]], requested: house, fillTo: count - 1).prefix(max(count - 1, 0)))
        for (i, id) in chosen.enumerated() {
            roster.append(Member("house\(i)", id, AmuduCharacters.get(id).name(hebrew: hebrew), bot: true, hebrew: hebrew))
        }
        online?.close()
        online = nil
        let seed = Int64(Date().timeIntervalSince1970 * 1000)
        guard let cfg = config(roster.count), let engine = try? AmuduEngine(members: roster, config: cfg, seed: seed) else { return }
        present(engine, uid: "p0", network: nil)
    }

    func openPrivateRoom() {
        if !validName() { return }
        if house.count >= count {
            status(tr("Leave a place for yourself.", "השאירו מקום לעצמכם."))
        } else {
            openRoom(nil)
        }
    }

    // MARK: Game

    func present(_ e: AmuduEngine, uid: String, network: OnlineRoom?) {
        gameView?.stop()
        localId = uid
        e.paused = false
        pauseVisible = false
        nicknameVisible = false
        sayVisible = false
        hideHuddle()
        let view = ArenaView(engine: e, ownId: uid, art: art, hebrew: hebrew)
        view.onBack = { [weak self] in self?.back() }
        view.onResult = { [weak self] r in self?.result(r) }
        view.onHuddle = { [weak self] in self?.showHuddle() }
        view.onEvent = { [weak self] ev in self?.event(ev) }
        view.onChoose = { [weak self, weak view] a in
            guard let self, let view else { return }
            if a.suffixes.isEmpty {
                view.command(.select(target: a.member.id))
            } else {
                self.nicknameTarget = a.member.id
                self.nicknameInput = ""
                self.nicknameVisible = true
            }
        }
        view.onSay = { [weak self] in self?.sayVisible = true }
        gameView = view
        network?.attach(view)
        screen = .game
        view.start()
    }

    var sayPhrases: [String] {
        return hebrew ? Words.phrasesHe : Words.phrasesEn.map { AppText.t($0) }
    }

    var funnyWords: [String] {
        return hebrew ? Words.he : Words.en
    }

    func say(_ index: Int) {
        gameView?.command(.say(index: index))
    }

    func callWithNickname() {
        nicknameVisible = false
        gameView?.command(.select(target: nicknameTarget, typedName: nicknameInput))
    }

    private func event(_ e: GameEvent) {
        audio.play(e.kind)
        switch e.kind {
        case "call":
            guard let engine = gameView?.engine, let a = engine.actor(engine.called) else { return }
            let english = hebrew && a.member.bot && a.suffixes.isEmpty && (a.member.character == "mia" || a.member.character == "gaya")
            audio.speak(english ? AmuduCharacters.get(a.member.character).en : a.fullName(hebrew: hebrew), english: english)
        case "renamed":
            if e.actor != localId {
                let name = gameView?.engine.actor(e.actor)?.fullName(hebrew: hebrew) ?? e.text
                status(tr("Remember: ", "זכרו: ") + name)
                audio.speak(name)
            }
        case "freeze":
            audio.speak(GameText.stopCall(), english: AppText.language == "hi")
        case "say":
            let i = Int(e.text) ?? 0
            let list = hebrew ? Words.phrasesHe : Words.phrasesEn
            audio.speak(AppText.t(i >= 0 && i < list.count ? list[i] : ""))
        default:
            break
        }
    }

    private func result(_ r: Outcome) {
        guard let e = gameView?.engine else { return }
        gameView?.stop()
        gameView = nil
        defaults.removeObject(forKey: Keys.saved)
        hasSavedGame = false
        hideHuddle()
        pauseVisible = false
        let ordered = Kotlin.stableSorted(e.actors) { $0.penalties < $1.penalties }
        results = ordered.map { a in
            ResultRow(id: a.member.id, character: a.member.character, name: a.fullName(hebrew: hebrew), penalties: a.penalties,
                      winner: r.winners.contains(a.member.id))
        }
        screen = .result
    }

    func back() {
        guard let v = gameView else {
            if screen != .home { home() }
            return
        }
        if online == nil {
            v.engine.paused = true
            v.stop()
            saveLocal()
        }
        pauseVisible = true
    }

    var pauseMessage: String {
        return online == nil ? tr("Your game is paused.", "המשחק מושהה.") : tr("The game continues for the others.", "המשחק ממשיך אצל האחרים.")
    }

    func resumeFromPause() {
        pauseVisible = false
        guard let v = gameView else { return }
        v.engine.paused = false
        v.start()
    }

    func finishFromPause() {
        pauseVisible = false
        guard let v = gameView else { return }
        if let room = online {
            room.endGame()
        } else {
            v.engine.finish()
        }
        v.engine.paused = false
        v.start()
    }

    private func saveLocal() {
        guard let v = gameView, online == nil, v.engine.result == nil else { return }
        let wrapper: [String: Any] = ["checkpoint": AmuduCodec.checkpoint(v.engine), "order": v.engine.actors.map { $0.member.id }]
        guard JSONSerialization.isValidJSONObject(wrapper),
              let data = try? JSONSerialization.data(withJSONObject: wrapper),
              let json = String(data: data, encoding: .utf8) else { return }
        defaults.set(json, forKey: Keys.saved)
        hasSavedGame = true
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if isForeground { return }
            isForeground = true
            online?.foreground()
            if !pauseVisible, let v = gameView {
                v.engine.paused = false
                v.start()
            }
        case .inactive, .background:
            if !isForeground { return }
            isForeground = false
            saveLocal()
            gameView?.stop()
            online?.background()
            audio.stopSpeech()
        @unknown default:
            break
        }
    }

    // MARK: Nickname huddle

    func showHuddle() {
        guard let e = gameView?.engine, e.phase == .huddle, huddle == nil else { return }
        // The nickname target sees only the neutral pause in the arena.
        if e.huddleTarget == localId { return }
        huddleInput = Words.suggestion(Int.random(in: 0...5), hebrew: hebrew)
        huddle = HuddleState(seconds: 0, proposals: [])
        refreshHuddle()
        huddleTimer?.invalidate()
        huddleTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.refreshHuddle()
            }
        }
    }

    private func refreshHuddle() {
        guard let e = gameView?.engine, e.phase == .huddle else {
            hideHuddle()
            return
        }
        let seconds: Int
        var proposals: [(String, String)] = []
        let votes: [String: String]
        if let room = online {
            seconds = room.huddleRemainingSeconds()
            let map = room.huddleSuggestions
            for key in map.keys.sorted(by: Kotlin.less) {
                if let value = map[key] { proposals.append((key, value)) }
            }
            votes = room.huddleVotes
        } else {
            seconds = max(Kotlin.toInt(ceil(e.huddleDeadline - e.time)), 0)
            for entry in e.suggestions.entries { proposals.append((entry.key, entry.value)) }
            votes = e.votes.dictionary
        }
        let list = proposals.map { p in HuddleProposal(id: p.0, name: p.1, votes: votes.values.filter { $0 == p.0 }.count) }
        let next = HuddleState(seconds: seconds, proposals: list)
        if huddle != next { huddle = next }
    }

    private func hideHuddle() {
        huddleTimer?.invalidate()
        huddleTimer = nil
        if huddle != nil { huddle = nil }
        wordListVisible = false
    }

    func limitHuddleInput(_ value: String) {
        if value.utf16.count > 24 { huddleInput = String(decoding: Array(value.utf16.prefix(24)), as: UTF16.self) }
    }

    func suggestNickname() {
        guard let e = gameView?.engine else { return }
        let text = huddleInput
        if !Words.validSuggestion(text) {
            status(tr("Write one word using letters and optional numbers, up to 24 characters.", "כתבו מילה אחת באותיות, ואפשר גם מספרים, עד 24 תווים."))
            return
        }
        if let room = online {
            room.propose(text)
        } else {
            e.propose(localId, text)
        }
        refreshHuddle()
    }

    func voteFor(_ id: String) {
        guard let e = gameView?.engine else { return }
        if let room = online {
            room.vote(id)
        } else {
            e.vote(localId, id)
        }
        refreshHuddle()
    }

    // MARK: Private rooms

    private func openRoom(_ code: String?) {
        online?.close()
        connectingInfo = tr("Connecting to your private room.", "מתחברים לחדר הפרטי.")
        screen = .connecting
        let identity = Member("", avatar, Kotlin.trim(playerName), bot: false, hebrew: hebrew)
        let net = OnlineRoom(model: self, identity: identity, config: config() ?? GameConfig.defaults, house: house)
        online = net
        net.open(join: code) { [weak self] text in
            guard let self else { return }
            self.connectingInfo = text
            self.status(text)
        }
    }

    func lobby(code: String, players: [Member], ready: Set<String>, uid: String, host: Bool,
               onReady: @escaping @MainActor () -> Void, onStart: @escaping @MainActor () -> Void) {
        defaults.set(code, forKey: Keys.room)
        savedRoom = code
        var lines: [LobbyLine] = []
        for m in players {
            var text = m.displayName(hebrew: hebrew)
            if m.id == uid { text += tr(" · You", " · אתם") }
            text += ready.contains(m.id) ? " ✓" : tr(" · Not ready", " · עדיין לא מוכנים")
            lines.append(LobbyLine(id: m.id, text: text))
        }
        lobbyState = LobbyState(code: code, lines: lines, host: host, onReady: onReady, onStart: onStart)
        if screen != .lobby { screen = .lobby }
    }

    func copyCode(_ code: String) {
        UIPasteboard.general.string = code
        status(tr("Code copied.", "הקוד הועתק."))
    }
}
