import SwiftUI
import UIKit

/// Port of Android SplashActivity.kt: menu flow, tutorial, persistence, cups, online rooms,
/// pause and lifecycle. Ads, purchases and code redemption are not part of the iOS build.
enum SplashScreen {
    case home, settings, parentZone, progress, online, lobby, results, game
}

struct ResultPlayerRow: Identifiable {
    let id: String
    let character: String
    let name: String
    let score: Int
    let ink: UInt32
}

struct ResultTeamPanel: Identifiable {
    let id: Int
    let name: String
    let subtitle: String
    let color: UInt32
    let ink: UInt32
    let rows: [ResultPlayerRow]
}

struct ResultsModel {
    let title: String
    let teams: [ResultTeamPanel]
    let rows: [ResultPlayerRow]
    let teamNote: String?
    let correctLine: String
    let countsLine: String
    let onlineCup: Bool
    let nextRound: Bool
    let cupLine: String?
    let cupStandings: String?
    let nextBattle: Bool
    let playAgain: Bool
}

struct LobbyModel {
    let code: String
    let players: [String]
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let long: Bool
}

struct ParentGateModel: Equatable {
    let a: Int
    let b: Int
}

@MainActor
final class SplashController: ObservableObject {
    @Published private(set) var screen: SplashScreen = .home
    @Published var toast: ToastMessage?
    @Published var pausePresented = false
    @Published var gate: ParentGateModel?
    @Published var gateAnswer = ""
    @Published private(set) var results: ResultsModel?
    @Published private(set) var lobbyModel: LobbyModel?
    @Published private(set) var standings = ""
    @Published private(set) var settings = PlayerSettings()
    @Published private(set) var selected = "miniko"
    @Published private(set) var format = 0
    @Published private(set) var count = 6
    @Published var subjectsExpanded = false
    @Published var roomCode = ""
    @Published var emulatorHost = "127.0.0.1"

    private(set) var gameView: SplashArenaView?
    let art = ArtStore.shared
    private let sounds = SplashSounds()
    private let music = MenuMusic()
    private let speech = SplashSpeech()
    private let localStore = LocalBattleStore()
    private(set) var hebrew = false
    private var topic: Topic = .math
    private var learningSession = false
    private var parentPage = false
    private var cupRound = 0
    private var cupScores: [String: Int] = [:]
    private var cup = false
    private var atHome = false
    private var cupRoster: [Member]?
    private var network: OnlineSession?
    private var gateAction: (() -> Void)?
    private var lobbyReady: (() -> Void)?
    private var lobbyStart: (() -> Void)?
    private var lifecyclePaused = false
    private var memoryObserver: NSObjectProtocol?
    /// Android DEBUG-only QA exhibitions; never enabled on iOS.
    private let qa = false

    init() {
        AppText.configure(Locale.preferredLanguages.first ?? "en")
        hebrew = AppText.language == "he"
        if let node = NodeJSON.node(SplashPrefs.string("playerSettings") ?? "{}") { settings = WorldCodec.settings(node) }
        selected = SplashPrefs.string("character") ?? "miniko"
        format = min(max(SplashPrefs.int("format", 0), 0), 2)
        count = min(max(SplashPrefs.int("count", 6), 2), 6)
        topic = Topic(rawValue: SplashPrefs.string("topic") ?? "MATH") ?? .math
        emulatorHost = SplashPrefs.string("emulatorHost") ?? "127.0.0.1"
        memoryObserver = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in ArtStore.shared.purge() }
        }
        home()
    }

    private func tr(_ en: String, _ he: String) -> String { return AppText.t(en, he, hebrew: hebrew) }

    func showToast(_ text: String, long: Bool = false) {
        toast = ToastMessage(text: text, long: long)
    }

    // MARK: Pages

    private func showPage(_ next: SplashScreen) {
        atHome = false
        gameView?.teardown()
        gameView = nil
        music.setMenu(true)
        pausePresented = false
        screen = next
    }

    func home() {
        if let v = gameView, network == nil, !qa {
            localStore.save(v.engine, cupRound: cupRound, cupScores: cupScores, cup: cup)
        }
        gameView?.stop()
        network?.close()
        network = nil
        cup = false
        learningSession = false
        parentPage = false
        showPage(.home)
        atHome = true
    }

    var hasSavedBattle: Bool { return localStore.hasBattle() }
    var hasSavedCup: Bool { return SplashPrefs.string("cupState") != nil }
    var savedRoom: String? { return SplashPrefs.onlineRoom }

    func openSettings() { showPage(.settings) }

    func openParentZone() {
        showPage(.parentZone)
        parentPage = true
    }

    func openProgress() { showPage(.progress) }
    func openOnline() { showPage(.online) }

    func continueBattle() {
        guard let saved = localStore.load() else { return }
        cup = saved.cup
        cupRound = saved.round
        cupScores = saved.scores
        cupRoster = saved.cup ? saved.engine.members : nil
        present(saved.engine, localId: "p0")
    }

    func continueCup() {
        guard let text = SplashPrefs.string("cupState") else { return }
        restoreCup(text)
    }

    func startLocalCup() {
        cup = true
        cupRound = 0
        cupRoster = nil
        cupScores.removeAll()
        SplashPrefs.setString(nil, "cupState")
        startGame(false)
    }

    func nextCharacter(_ delta: Int) {
        let ids = Characters.all.map { $0.id }
        let index = ids.firstIndex(of: selected) ?? -1
        selected = ids[((index + delta) % ids.count + ids.count) % ids.count]
        SplashPrefs.setString(selected, "character")
    }

    // MARK: Settings

    private func saveSettings(_ value: PlayerSettings) {
        settings = value
        SplashPrefs.setString(NodeJSON.string(WorldCodec.settings(value)), "playerSettings")
    }

    func setWalk(_ index: Int) {
        var next = settings
        next.walk = WalkMode.allCases[min(max(index, 0), WalkMode.allCases.count - 1)]
        saveSettings(next)
    }

    func setThrowing(_ index: Int) {
        var next = settings
        next.throwing = ThrowMode.allCases[min(max(index, 0), ThrowMode.allCases.count - 1)]
        saveSettings(next)
    }

    func setFormat(_ index: Int) {
        format = min(max(index, 0), 2)
        SplashPrefs.setInt(format, "format")
    }

    func setCount(_ value: Int) {
        count = min(max(value, 2), 6)
        SplashPrefs.setInt(count, "count")
    }

    func setArena(_ index: Int) {
        var next = settings
        next.arena = Arena.allCases[min(max(index, 0), Arena.allCases.count - 1)]
        saveSettings(next)
    }

    func setCourt(_ index: Int) {
        var next = settings
        next.court = index == 0
        saveSettings(next)
    }

    func setBalloons(_ index: Int) {
        var next = settings
        next.balloons = BalloonMode.allCases[min(max(index, 0), BalloonMode.allCases.count - 1)]
        saveSettings(next)
    }

    /// Tapping a subject moves it to the other list; at least one stays chosen.
    func tapSubject(_ topic: Topic, chosen: Bool) {
        var next = settings.subjects
        if chosen { next.remove(topic) } else { next.insert(topic) }
        if next.isEmpty {
            showToast(tr("Choose at least one subject.", "בחרו לפחות נושא אחד."))
            return
        }
        var updated = settings
        updated.subjects = next
        saveSettings(updated)
    }

    /// Dropping a subject on a list (Android drag-and-drop transfer).
    func dropSubject(_ topic: Topic, intoChosen: Bool) {
        var next = settings.subjects
        if intoChosen { next.insert(topic) } else { next.remove(topic) }
        if next.isEmpty {
            showToast(tr("Choose at least one subject.", "בחרו לפחות נושא אחד."))
            return
        }
        var updated = settings
        updated.subjects = next
        saveSettings(updated)
    }

    // MARK: Parent gate

    func requestParentGate(_ action: @escaping () -> Void) {
        gateAnswer = ""
        gateAction = action
        gate = ParentGateModel(a: Int.random(in: 4...9), b: Int.random(in: 3...8))
    }

    func confirmGate(_ model: ParentGateModel) {
        let action = gateAction
        let answer = gateAnswer
        gate = nil
        gateAction = nil
        if Int(answer) == model.a * model.b {
            action?()
        } else {
            showToast(tr("Please try again.", "נסו שוב."))
        }
    }

    func cancelGate() {
        gate = nil
        gateAction = nil
    }

    // MARK: Learning profile

    func learningProfile() -> LearningProfile {
        let p = LearningProfile()
        guard let json = NodeJSON.node(SplashPrefs.string("learning") ?? "{}") else { return p }
        for skill in Skill.allCases {
            guard let a = json[skill.name] as? [String: Any] else { continue }
            p.skills[skill] = SkillState(level: KotlinNumber.int(a.num("level")), streak: KotlinNumber.int(a.num("streak")),
                                         independent: KotlinNumber.int(a.num("independent")),
                                         assisted: KotlinNumber.int(a.num("assisted")),
                                         wrong: KotlinNumber.int(a.num("wrong")), reviewed: KotlinNumber.int(a.num("reviewed")))
        }
        return p
    }

    private func saveProfile(_ p: LearningProfile) {
        if qa { return } // Automated exhibitions must never train the human learning profile.
        SplashPrefs.setString(NodeJSON.string(WorldCodec.profile(p)), "learning")
    }

    // MARK: Battles

    private func roster(_ tutorial: Bool) -> [Member] {
        if tutorial {
            return [Member("p0", selected, team: 0, bot: false, name: Characters.get(selected).name(hebrew), hebrew: hebrew, settings: settings),
                    Member("p1", "minik", team: 1, bot: false, name: Characters.get("minik").name(hebrew), hebrew: hebrew, settings: settings)]
        }
        if cup, let saved = cupRoster { return saved }
        let n = format == 1 ? 4 : (format == 2 ? 6 : count)
        let ordered = [Characters.get(selected)] + Characters.all.filter { $0.id != selected }.shuffled()
        var members: [Member] = []
        for (i, c) in ordered.prefix(n).enumerated() {
            members.append(Member("p\(i)", c.id, team: i < n / 2 ? 0 : 1, bot: i != 0 || qa, name: c.name(hebrew), hebrew: hebrew,
                                  settings: i == 0 ? settings : PlayerSettings.bots([settings])))
        }
        return members
    }

    func startGame(_ tutorial: Bool) {
        let members = roster(tutorial)
        let mode: GameMode = (tutorial || format == 0) ? .solo : .teams
        guard SplashEngine.validRoster(members, mode) else {
            showToast(tr("This cup could not be restored.", "לא ניתן לשחזר את הגביע הזה."), long: true)
            return
        }
        let e = SplashEngine(members: members, mode: mode, topic: .math, seed: SplashClock.currentTimeMillis(), config: SplashConfig(),
                             hebrew: hebrew, profiles: ["p0": learningProfile()])
        if cup && !tutorial { cupRoster = e.members }
        e.practice = tutorial
        if tutorial {
            e.actor("p0")?.position = V(5.4, 8.4)
            e.actor("p1")?.position = V(6.8, 3.7)
            e.resetPracticeQuestion("p0")
        }
        present(e, localId: "p0", tutorial: tutorial)
    }

    func present(_ e: SplashEngine, localId: String, tutorial: Bool = false, online: OnlineSession? = nil) {
        network = online
        learningSession = tutorial
        music.setMenu(false)
        gameView?.teardown()
        let v = SplashArenaView(engine: e, localId: localId, art: art, onExit: { [weak self] in
            self?.pauseMenu()
        }, onFinish: { [weak self] r in
            guard let self = self else { return }
            if let a = e.actor(localId) { self.saveProfile(a.profile) }
            self.showResults(r, e)
        }, onSpeak: { [weak self] text in
            self?.speech.speak(text)
        })
        gameView = v
        v.onControlSettings = { [weak self] s in self?.saveSettings(s) }
        if tutorial {
            v.beginTutorial()
            v.tutorialCompleted = { [weak self, weak v] in
                guard let self = self, let v = v else { return }
                if let a = e.actor(localId) { self.saveProfile(a.profile) }
                SplashPrefs.setBool(true, "tutorialDone")
                Task { @MainActor [weak self, weak v] in
                    guard let self = self, let v = v, self.gameView === v else { return }
                    v.stop()
                    self.home()
                }
            }
        }
        let board = sounds
        e.onEvent = { type, id in
            if id == localId || type == "hit" || type == "finish" { board.play(type) }
        }
        pausePresented = false
        screen = .game
        v.start()
        online?.attach(v)
    }

    func pauseMenu() {
        if learningSession {
            gameView?.stop()
            home()
            return
        }
        if pausePresented { return }
        gameView?.stop()
        network?.background()
        pausePresented = true
    }

    func continueFromPause() {
        pausePresented = false
        network?.foreground()
        gameView?.start()
    }

    func returnFromPause() {
        pausePresented = false
        if let v = gameView, let a = v.engine.actor(v.localId) { saveProfile(a.profile) }
        home()
    }

    private func displayName(_ a: SplashActor) -> String {
        if a.member.id == (network?.uid ?? "p0") {
            return tr("You", "אתם") + " · " + Characters.get(a.member.character).name(hebrew)
        }
        if a.member.bot { return Characters.get(a.member.character).name(hebrew) }
        return a.member.name
    }

    private func row(_ a: SplashActor, _ ink: UInt32) -> ResultPlayerRow {
        return ResultPlayerRow(id: a.member.id, character: a.member.character, name: displayName(a), score: a.score, ink: ink)
    }

    private func showResults(_ r: MatchResult, _ e: SplashEngine) {
        if e.practice || learningSession {
            home()
            return
        }
        gameView?.stop()
        if network == nil && !qa { localStore.clear() }
        let title = r.draw ? tr("A colorful draw!", "תיקו צבעוני!") : tr("What a splash!", "איזה קרב צבעוני!")
        var teams: [ResultTeamPanel] = []
        var rows: [ResultPlayerRow] = []
        if e.mode == .teams {
            let order = [0, 1].stableSorted { a, b in
                let sa = a < r.teamScores.count ? r.teamScores[a] : 0
                let sb = b < r.teamScores.count ? r.teamScores[b] : 0
                return sa > sb
            }
            for team in order {
                let style = Teams.style(team)
                let won = !r.draw && r.winners.contains { e.actor($0)?.member.team == team }
                let state: String
                if won {
                    state = tr("Winners!", "המנצחים!")
                } else if r.draw {
                    state = tr("Draw", "תיקו")
                } else {
                    state = tr("Great teamwork", "עבודת צוות נהדרת")
                }
                let score = team < r.teamScores.count ? r.teamScores[team] : 0
                let subtitle = state + " · " + tr("Team score: ", "ניקוד קבוצתי: ") + "\(score)"
                let members = e.actors.filter { $0.member.team == team }.stableSorted { $0.score > $1.score }
                teams.append(ResultTeamPanel(id: team, name: style.name(hebrew), subtitle: subtitle, color: style.color, ink: style.ink,
                                             rows: members.map { row($0, style.ink) }))
            }
        } else {
            rows = e.actors.stableSorted { $0.score > $1.score }.map { row($0, SplashPalette.white) }
        }
        let teamNote = e.mode == .teams
            ? tr("Team scores count hits. Individual scores also include wrong-answer penalties.", "ניקוד הקבוצה סופר פגיעות. הניקוד האישי כולל גם הפחתות על תשובות שגויות.")
            : nil
        let me = e.actor(network?.uid ?? "p0") ?? e.actors[0]
        let correct = me.answers.filter { $0.correct }.count
        let correctLine = tr("Correct answers: \(correct) · Hits: \(me.hits)", "תשובות נכונות: \(correct) · פגיעות: \(me.hits)")
        let countsLine = tr("Your answer still counts when a throw misses.", "תשובה נכונה נחשבת גם כשהזריקה מחטיאה.")
        var onlineCup = false
        var nextRound = false
        if let session = network {
            if session.isCup() {
                onlineCup = true
                standings = session.standingsText()
                session.standingsChanged = { [weak self, weak session] in
                    guard let self = self, let session = session else { return }
                    self.standings = session.standingsText()
                }
            }
            nextRound = session.hasNextRound()
        }
        var cupLine: String? = nil
        var cupStandings: String? = nil
        var nextBattle = false
        var playAgain = false
        if cup {
            for a in e.actors { cupScores[a.member.id] = (cupScores[a.member.id] ?? 0) + a.score }
            cupRound += 1
            saveCup()
            cupLine = tr("Cup · round \(cupRound) / 3", "גביע · סיבוב \(cupRound) / 3")
            let ranked = e.actors.stableSorted { (cupScores[$0.member.id] ?? 0) > (cupScores[$1.member.id] ?? 0) }
            cupStandings = ranked.map { Characters.get($0.member.character).name(hebrew) + "  " + "\(cupScores[$0.member.id] ?? 0)" }.joined(separator: "\n")
            nextBattle = cupRound < 3
        } else if network == nil {
            playAgain = true
        }
        results = ResultsModel(title: title, teams: teams, rows: rows, teamNote: teamNote, correctLine: correctLine, countsLine: countsLine,
                               onlineCup: onlineCup, nextRound: nextRound, cupLine: cupLine, cupStandings: cupStandings,
                               nextBattle: nextBattle, playAgain: playAgain)
        showPage(.results)
    }

    func resultsNextRound() { network?.nextRound() }
    func resultsNextBattle() { startGame(false) }
    func resultsPlayAgain() { startGame(false) }

    private func saveCup() {
        if cupRound >= 3 {
            SplashPrefs.setString(nil, "cupState")
            return
        }
        let n: Node = ["round": cupRound, "scores": cupScores, "selected": selected, "format": format, "count": count,
                       "topic": topic.name, "roster": (cupRoster ?? []).map { WorldCodec.member($0) }]
        SplashPrefs.setString(NodeJSON.string(n), "cupState")
    }

    private func restoreCup(_ text: String) {
        let failure = tr("This cup could not be restored.", "לא ניתן לשחזר את הגביע הזה.")
        guard let n = NodeJSON.node(text), let round = NodeValue.number(n["round"]), let scoresNode = n["scores"] as? [String: Any],
              let savedSelected = n["selected"] as? String, let savedFormat = NodeValue.number(n["format"]),
              let savedCount = NodeValue.number(n["count"]), let savedTopic = Topic(rawValue: n.str("topic")) else {
            showToast(failure, long: true)
            return
        }
        var restoredRoster: [Member]? = nil
        if let list = n["roster"] as? [Any] {
            restoredRoster = list.map { item -> Member in
                let m = NodeValue.node(item)
                return WorldCodec.member(m.str("id"), m)
            }
        }
        let restoredFormat = min(max(KotlinNumber.int(savedFormat), 0), 2)
        if let members = restoredRoster, !SplashEngine.validRoster(members, restoredFormat == 0 ? .solo : .teams) {
            showToast(failure, long: true)
            return
        }
        cup = true
        cupRound = KotlinNumber.int(round)
        cupRoster = restoredRoster
        var scores: [String: Int] = [:]
        for (key, value) in scoresNode { scores[key] = KotlinNumber.int(NodeValue.number(value) ?? 0) }
        cupScores = scores
        selected = savedSelected
        format = restoredFormat
        count = min(max(KotlinNumber.int(savedCount), 2), 6)
        topic = savedTopic
        startGame(false)
    }

    // MARK: Online

    func connectOnline(_ host: String, _ code: String?, rounds: Int = 1) {
        let mode: GameMode = format == 0 ? .solo : .teams
        let players = format == 1 ? 4 : (format == 2 ? 6 : count)
        let session = OnlineSession(controller: self, host: host, character: selected, hebrew: hebrew, mode: mode, topic: .math,
                                    rounds: rounds, maxPlayers: players, playerSettings: settings)
        network = session
        do {
            try session.open(code) { [weak self] state in self?.showToast(state, long: true) }
        } catch {
            showToast(error.localizedDescription, long: true)
        }
    }

    func createRoom() {
        SplashPrefs.setString(emulatorHost, "emulatorHost")
        connectOnline(emulatorHost, nil)
    }

    func createCupRoom() { connectOnline(emulatorHost, nil, rounds: 3) }

    func joinRoom() {
        connectOnline(emulatorHost, roomCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
    }

    func returnToRoom(_ saved: String) { connectOnline(emulatorHost, saved) }

    func lobby(code: String, players: [String], ready: @escaping () -> Void, start: @escaping () -> Void) {
        lobbyModel = LobbyModel(code: code, players: players)
        lobbyReady = ready
        lobbyStart = start
        showPage(.lobby)
    }

    func lobbyMarkReady() { lobbyReady?() }
    func lobbyStartGame() { lobbyStart?() }

    func copyCode(_ code: String) {
        UIPasteboard.general.string = code
        showToast(tr("Code copied", "הקוד הועתק"))
    }

    // MARK: Lifecycle (Android onPause / onResume)

    func scenePhaseChanged(active: Bool) {
        if active {
            lifecyclePaused = false
            onResume()
        } else if !lifecyclePaused {
            lifecyclePaused = true
            onPause()
        }
    }

    private func onPause() {
        if let v = gameView {
            if let a = v.engine.actor(v.localId) { saveProfile(a.profile) }
            if network == nil && !qa { localStore.save(v.engine, cupRound: cupRound, cupScores: cupScores, cup: cup) }
        }
        music.setForeground(false)
        sounds.setPaused(true)
        gameView?.stop()
        speech.stop()
        network?.background()
    }

    private func onResume() {
        music.setForeground(true)
        music.setMenu(gameView == nil)
        sounds.setPaused(false)
        if !pausePresented {
            gameView?.start()
            network?.foreground()
        }
    }
}
