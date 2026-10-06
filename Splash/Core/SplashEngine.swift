import Foundation

/// Port of Android core/SplashEngine.kt: independent simulation, collision, house-player
/// behaviour, paint, scoring and results. Statement order and random-number consumption follow
/// Android exactly so shared rooms, checkpoints and saved battles agree across platforms.
struct Member: Equatable {
    var id: String
    var character: String
    var team: Int
    var bot: Bool
    var name: String
    var hebrew: Bool
    var settings: PlayerSettings

    init(_ id: String, _ character: String, team: Int = 0, bot: Bool = false, name: String? = nil,
         hebrew: Bool = false, settings: PlayerSettings = PlayerSettings()) {
        self.id = id
        self.character = character
        self.team = team
        self.bot = bot
        self.name = name ?? Characters.get(character).en
        self.hebrew = hebrew
        self.settings = settings
    }
}

struct Choice: Equatable {
    var index: Int
    var text: String
    var position: V
    var color: Int
}

struct AnswerRecord: Equatable {
    let questionId: String
    let correct: Bool
    let hinted: Bool
    let answer: String
    let decisionElapsedSeconds: Double
}

struct PaintMark: Equatable {
    let color: Int
    let u: Double
    let v: Double
}

struct Feedback: Equatable {
    let questionId: String
    let answer: String
    let explanation: String
    let correct: Bool
    let expires: Double
}

final class SplashActor {
    let member: Member
    var position: V
    let profile: LearningProfile
    var settings: PlayerSettings
    var facing = V(0, 1)
    var walkTarget: V? = nil
    var autoPickupQuestion = ""
    var autoPickupIndex = -1
    var publicHeldColor = 5
    var direction = V(0, -1)
    var move = V(0, 0)
    var held: Int? = nil
    var height = 0.0
    var verticalSpeed = 0.0
    var crouchUntil = 0.0
    var cleanUntil = 0.0
    var shieldUntil = 0.0
    var recoveryUntil = 0.0
    var windupAt = -99.0
    var throwAt = -99.0
    var pickupAt = -99.0
    var hitAt = -99.0
    var gait = 0.0
    var score = 0
    var hits = 0
    var misses = 0
    var sequence = 0
    var questionAt = 0.0
    var pickupSeconds = 0.0
    var hinted = false
    var question: Question? = nil
    var choices: [Choice] = []
    var feedback: Feedback? = nil
    var paint: [PaintMark] = []
    var answers: [AnswerRecord] = []
    var nextBotThink = 0.0
    var botChoice: Int? = nil

    init(member: Member, position: V, profile: LearningProfile = LearningProfile()) {
        self.member = member
        self.position = position
        self.profile = profile
        self.settings = member.settings
    }
}

struct Shot {
    let id: String
    let owner: String
    let questionId: String
    var answer: String
    var explanation: String
    let color: Int
    var position: V
    var height: Double
    let velocity: V
    var vz: Double
    var age: Double = 0
}

struct Burst {
    let id: String
    let owner: String
    let questionId: String
    let position: V
    let height: Double
    let color: Int
    let at: Double
    let hit: String?
}

struct MatchResult: Equatable {
    let id: String
    let winners: [String]
    let scores: [String: Int]
    let teamScores: [Int]
    let draw: Bool
    let elapsed: Double
}

enum Command: Equatable {
    case move(V)
    case aim(V)
    case walkTo(V, questionId: String = "", index: Int = -1)
    case shootAt(String)
    case pickup(questionId: String, index: Int)
    /// Android `Command.Throw` (wire type "throw").
    case throwBalloon
    case jump
    case crouch
    case hint
}

final class SplashEngine {
    let members: [Member]
    let mode: GameMode
    let topic: Topic
    let seed: Int64
    let config: SplashConfig
    let hebrew: Bool
    let profiles: [String: LearningProfile]
    let matchId: String
    let random: KotlinRandom
    private var questionSalt: Int64
    var actors: [SplashActor]
    var shots: [Shot] = []
    var bursts: [Burst] = []
    var teamScores: [Int] = [0, 0]
    private(set) var time: Double = 0
    private(set) var result: MatchResult? = nil
    var paused = false
    var practice = false
    private var serial: Int64 = 0
    private var consumedOrder: [String] = []
    private var consumedSet = Set<String>()
    var onEvent: ((String, String) -> Void)?

    /// Android `require` on the roster: 2-6 unique members; teams are 2v2 or 3v3.
    static func validRoster(_ members: [Member], _ mode: GameMode) -> Bool {
        guard members.count >= 2 && members.count <= 6 else { return false }
        guard Set(members.map { $0.id }).count == members.count else { return false }
        if mode == .teams {
            guard members.count == 4 || members.count == 6 else { return false }
            let half = members.count / 2
            return members.filter { $0.team == 0 }.count == half && members.filter { $0.team == 1 }.count == half
        }
        return true
    }

    init(members: [Member], mode: GameMode = .solo, topic: Topic = .math, seed: Int64 = 1,
         config: SplashConfig = SplashConfig(), hebrew: Bool = false,
         profiles: [String: LearningProfile] = [:], matchId: String? = nil) {
        precondition(SplashEngine.validRoster(members, mode), "Invalid Splash roster")
        self.members = members
        self.mode = mode
        self.topic = topic
        self.seed = seed
        self.config = config
        self.hebrew = hebrew
        self.profiles = profiles
        self.matchId = matchId ?? "local-\(seed)"
        self.random = KotlinRandom(seed: seed)
        self.questionSalt = Int64.random(in: Int64.min...Int64.max)
        var created: [SplashActor] = []
        for (i, m) in members.enumerated() {
            let position = V(2.4 + Double(i % 3) * 3.6, i < 3 ? 8.7 : 3.1)
            created.append(SplashActor(member: m, position: position, profile: profiles[m.id] ?? LearningProfile()))
        }
        self.actors = created
        let humans = members.filter { !$0.bot }
        let botSettings = PlayerSettings.bots((humans.isEmpty ? members : humans).map { $0.settings })
        for a in actors {
            if a.member.bot {
                a.settings = botSettings
            } else if topic != .math && a.settings.subjects == [.math] {
                a.settings.subjects = topic == .mixed ? [.math, .english, .world] : [topic]
            }
            nextQuestion(a)
        }
    }

    func questionSecret() -> Int64 { return questionSalt }
    func restoreQuestionSecret(_ value: Int64) { questionSalt = value }

    func loadProfile(_ id: String, _ profile: LearningProfile) {
        guard let a = actor(id) else { return }
        for (skill, state) in profile.skills { a.profile.skills[skill] = state }
        a.sequence = 0
        nextQuestion(a)
    }

    func restoreClock(_ value: Double) { time = value }
    func restoreResult(_ value: MatchResult?) { result = value }
    func serialState() -> Int64 { return serial }
    func consumedState() -> [String] { return consumedOrder }

    func restoreSerial(_ value: Int64, _ ids: [String]) {
        serial = value
        consumedOrder = []
        consumedSet = []
        for id in ids where !consumedSet.contains(id) {
            consumedOrder.append(id)
            consumedSet.insert(id)
        }
    }

    func actor(_ id: String) -> SplashActor? { return actors.first { $0.member.id == id } }
    func privateQuestion(_ id: String) -> Question? { return actor(id)?.question }

    private func nextSerial() -> Int64 {
        serial += 1
        return serial
    }

    @discardableResult
    func command(_ id: String, _ eventId: String, _ cmd: Command) -> Bool {
        let blank = eventId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if result != nil || paused || blank || eventId.utf16.count > 120 || consumedSet.contains(eventId) { return false }
        guard let a = actor(id) else { return false }
        if consumedOrder.count > 8192 {
            let first = consumedOrder.removeFirst()
            consumedSet.remove(first)
        }
        consumedOrder.append(eventId)
        consumedSet.insert(eventId)
        switch cmd {
        case .move(let vector):
            if !vector.x.isFinite || !vector.y.isFinite { return false }
            a.walkTarget = nil
            a.autoPickupIndex = -1
            a.move = vector.length() > 1 ? vector.unit() : vector
            if a.move.length() > 0.05 { a.facing = a.move.unit() }
        case .aim(let vector):
            if !vector.x.isFinite || !vector.y.isFinite || vector.length() < 0.01 { return false }
            a.direction = vector.unit()
            a.facing = a.direction
            if a.held != nil { a.windupAt = time }
        case .walkTo(let position, let questionId, let index):
            if !position.x.isFinite || !position.y.isFinite { return false }
            if index >= 0 {
                if a.settings.walk != .easy || a.question?.id != questionId || a.held != nil { return false }
                guard let choice = a.choices.first(where: { $0.index == index }) else { return false }
                a.walkTarget = choice.position
                a.autoPickupQuestion = questionId
                a.autoPickupIndex = index
            } else {
                a.walkTarget = clamp(position, a)
                a.autoPickupIndex = -1
            }
        case .shootAt(let targetId):
            if a.settings.throwing != .easy || a.held == nil { return false }
            guard let target = actor(targetId) else { return false }
            if target === a || (mode == .teams && target.member.team == a.member.team) { return false }
            a.direction = (target.position - a.position).unit()
            a.facing = a.direction
            return command(id, eventId + "-throw", .throwBalloon)
        case .pickup(let questionId, let index):
            if a.held != nil || a.question?.id != questionId || time < a.cleanUntil || time < a.recoveryUntil { return false }
            guard let c = a.choices.first(where: { $0.index == index }) else { return false }
            if (c.position - a.position).length() > config.pickupRadius { return false }
            a.held = c.index
            a.autoPickupIndex = -1
            a.pickupAt = time
            a.pickupSeconds = time - a.questionAt
            onEvent?("pickup", id)
        case .throwBalloon:
            if time < a.cleanUntil || time < a.recoveryUntil { return false }
            guard let held = a.held, let q = a.question else { return false }
            guard let c = a.choices.first(where: { $0.index == held }) else { return false }
            let correct = c.text == q.answer
            a.answers.append(AnswerRecord(questionId: q.id, correct: correct, hinted: a.hinted, answer: q.answer,
                                          decisionElapsedSeconds: a.pickupSeconds))
            a.profile.record(q.skill, correct: correct, hint: a.hinted)
            a.feedback = Feedback(questionId: q.id, answer: q.answer, explanation: q.explanation(a.member.hebrew),
                                  correct: correct, expires: time + (correct ? 2.5 : 6.0))
            a.held = nil
            a.throwAt = time
            a.facing = a.direction
            if correct {
                let direction = a.direction.unit()
                let shotId = "\(matchId)-s\(nextSerial())"
                let launchHeight = a.height + (time < a.crouchUntil ? 0.48 : 1.15)
                shots.append(Shot(id: shotId, owner: id, questionId: q.id, answer: q.answer,
                                  explanation: q.explanation(a.member.hebrew), color: c.color,
                                  position: a.position + direction * 0.42, height: launchHeight,
                                  velocity: direction * config.throwSpeed, vz: config.launchLift))
                onEvent?("throw", id)
                nextQuestion(a)
            } else {
                burst(id, q.id, a.position, a.height + 0.9, c.color, id)
                applyPaint(a, c.color)
                a.score = max(a.score - config.mistakePoints, 0)
                a.recoveryUntil = time + config.mistakeRecovery
                onEvent?("wrong", id)
                nextQuestion(a)
            }
        case .jump:
            let ground = a.settings.arena == .andromeda ? 0.15 : 0.01
            if a.height < ground && time >= a.cleanUntil {
                a.verticalSpeed = config.jumpVelocity
                a.crouchUntil = 0
                onEvent?("jump", id)
            }
        case .crouch:
            if time >= a.cleanUntil {
                a.crouchUntil = time + config.crouchSeconds
                onEvent?("crouch", id)
            }
        case .hint:
            a.hinted = true
            guard let q = a.question else { return false }
            a.feedback = Feedback(questionId: q.id, answer: q.answer, explanation: q.explanation(a.member.hebrew),
                                  correct: false, expires: time + 3)
        }
        return true
    }

    private func nextQuestion(_ a: SplashActor) {
        a.sequence += 1
        let mixed = seed ^ questionSalt ^ Int64(a.member.id.javaHashCode) ^ (Int64(a.sequence) &* 0x9E37_79B9)
        let r = KotlinRandom(seed: mixed)
        var selectedTopics = a.settings.orderedSubjects
        if selectedTopics.isEmpty { selectedTopics = [.math] }
        let selectedTopic = selectedTopics[(a.sequence - 1) % selectedTopics.count]
        let s = QuestionBank.chooseSkill(a.profile, selectedTopic, r, a.sequence)
        let previousLevel = a.profile.state(s).level
        // Review sometimes steps one level back; no timer pressure changes mastery.
        let level = a.sequence % 7 == 0 ? max(previousLevel - 1, 0) : previousLevel
        let question = QuestionBank.generate("\(a.member.id)-q\(a.sequence)", s, level, r, hebrew: a.member.hebrew)
        a.question = question
        let center = V(min(max(a.position.x, 2.1), config.width - 2.1), min(max(a.position.y, 2.1), config.depth - 2.1))
        let rotation = r.nextDouble() * 2 * Double.pi
        let colors = Array(Array(0...5).kotlinShuffled(r).prefix(4))
        var positions: [V] = []
        if a.settings.balloons == .onePlace {
            for i in 0..<4 {
                let angle = rotation + Double(i) * Double.pi / 2
                positions.append(center + V(cos(angle), sin(angle)) * config.answerRing)
            }
        } else {
            var spread: [V] = []
            for i in 0..<4 {
                let x = 0.8 + Double(i % 2) * (config.width / 2) + r.nextDouble() * (config.width / 2 - 1.6)
                let y = 1.3 + Double(i / 2) * (config.depth / 2 - 0.4) + r.nextDouble() * (config.depth / 2 - 2.0)
                spread.append(V(x, y))
            }
            positions = spread.kotlinShuffled(r)
        }
        var made: [Choice] = []
        for (i, text) in question.options.enumerated() where i < positions.count && i < colors.count {
            made.append(Choice(index: i, text: text, position: positions[i], color: colors[i]))
        }
        a.choices = made
        a.questionAt = time
        a.hinted = false
        a.botChoice = nil
        let skill = Characters.get(a.member.character).skill
        let think = config.botThinkMin + (1 - skill) * (config.botThinkMax - config.botThinkMin)
        a.nextBotThink = time + think + r.nextDouble() * 0.6
    }

    func tick(_ rawDt: Double) {
        if paused || result != nil { return }
        // Bounded fixed-step integration avoids tunnelling and time jumps after background.
        var left = min(max(rawDt, 0.0), 0.10)
        while left > 0 {
            let dt = min(left, 1.0 / 120)
            step(dt)
            left -= dt
        }
    }

    private func step(_ dt: Double) {
        if result != nil { return }
        time += dt
        for a in actors {
            if a.member.bot && !practice { bot(a) }
            if let target = a.walkTarget {
                let delta = target - a.position
                let pickup = a.autoPickupIndex >= 0 && a.autoPickupQuestion == a.question?.id
                let distance = pickup ? config.pickupRadius * 0.75 : 0.10
                if delta.length() <= distance {
                    a.move = V(0, 0)
                    a.walkTarget = nil
                    if pickup {
                        let index = a.autoPickupIndex
                        a.autoPickupIndex = -1
                        command(a.member.id, "walk-pickup-\(nextSerial())", .pickup(questionId: a.autoPickupQuestion, index: index))
                    }
                } else {
                    a.move = delta.unit() * min(1.0, delta.length() / (config.moveSpeed * 0.10))
                }
            }
            if time >= a.cleanUntil && time >= a.recoveryUntil {
                a.position = clamp(a.position + a.move * (config.moveSpeed * dt), a)
                if a.move.length() > 0.05 && time - a.windupAt > 0.35 && time - a.throwAt > 0.3 { a.facing = a.move.unit() }
                if a.settings.arena == .andromeda && a.move.length() > 0.1 && a.height < 0.005 && a.verticalSpeed <= 0 && time >= a.crouchUntil {
                    a.verticalSpeed = 0.95
                }
                a.gait += a.move.length() * dt * 7
            }
            if a.height > 0 || a.verticalSpeed > 0 {
                a.height += a.verticalSpeed * dt
                a.verticalSpeed -= a.settings.arena == .andromeda ? a.settings.jumpGravity * dt : config.jumpGravity * dt
                if a.height <= 0 {
                    a.height = 0
                    a.verticalSpeed = 0
                }
            }
            if a.paint.count >= config.paintLayers && time >= a.cleanUntil && a.cleanUntil > 0 {
                a.paint.removeAll()
                a.cleanUntil = 0
                a.shieldUntil = time + config.returnShield
            }
        }
        // Soft physical separation; all participants remain independently active.
        for i in 0..<actors.count {
            for j in (i + 1)..<max(i + 1, actors.count) {
                let a = actors[i]
                let b = actors[j]
                let d = a.position - b.position
                let n = d.length()
                if n > 0 && n < config.personalSpace {
                    let push = d.unit() * ((config.personalSpace - n) * 0.5)
                    a.position = clamp(a.position + push, a)
                    b.position = clamp(b.position - push, b)
                }
            }
        }
        var index = 0
        while index < shots.count {
            var s = shots[index]
            let old = s.position
            let oldH = s.height
            s.position = s.position + s.velocity * dt
            s.height += s.vz * dt
            let factor = actor(s.owner)?.settings.projectileGravityFactor ?? 1.0
            s.vz -= config.gravity * factor * dt
            s.age += dt
            var target: SplashActor? = nil
            var nearest = Double.greatestFiniteMagnitude
            for a in actors {
                if a.member.id == s.owner || time < a.shieldUntil || time < a.cleanUntil { continue }
                guard let owner = actor(s.owner) else { continue }
                if mode == .teams && !config.friendlyFire && a.member.team == owner.member.team { continue }
                let line = s.position - old
                let length2 = line.x * line.x + line.y * line.y
                let toActor = a.position - old
                let t = length2 < 0.00001 ? 0.0 : min(max((toActor.x * line.x + toActor.y * line.y) / length2, 0.0), 1.0)
                let h = oldH + (s.height - oldH) * t
                let top = a.height + (time < a.crouchUntil ? config.crouchHeight : config.standingHeight)
                let close = (a.position - (old + line * t)).length() <= config.actorRadius + 0.14
                if close && h + 0.12 >= a.height && h - 0.12 <= top && t < nearest {
                    target = a
                    nearest = t
                }
            }
            if let hitTarget = target {
                if let owner = actor(s.owner) {
                    owner.score += 1
                    owner.hits += 1
                    if mode == .teams && owner.member.team >= 0 && owner.member.team < teamScores.count {
                        teamScores[owner.member.team] += 1
                    }
                }
                applyPaint(hitTarget, s.color)
                explode(s, hitTarget.member.id)
                shots.remove(at: index)
                onEvent?("hit", hitTarget.member.id)
                continue
            } else if s.height <= 0.1 || outsideShot(s) || s.age > 6 {
                if let owner = actor(s.owner) { owner.misses += 1 }
                explode(s, nil)
                shots.remove(at: index)
                continue
            }
            shots[index] = s
            index += 1
        }
        bursts.removeAll { time - $0.at > 7 }
        if !practice {
            let timeUp = time >= config.duration
            let soloDone = mode == .solo && actors.contains { $0.score >= config.target }
            let teamDone = mode == .teams && teamScores.contains { $0 >= config.teamTarget }
            if timeUp || soloDone || teamDone { finish() }
        }
    }

    private func clamp(_ p: V, _ a: SplashActor) -> V {
        if a.settings.court {
            return V(min(max(p.x, 0.55), config.width - 0.55), min(max(p.y, 0.8), config.depth - 0.65))
        }
        return V(min(max(p.x, -0.75), config.width + 0.75), min(max(p.y, -0.65), config.depth + 0.9))
    }

    private func outsideShot(_ s: Shot) -> Bool {
        let margin = actor(s.owner)?.settings.court != false ? 0.0 : 6.0
        return s.position.x < -margin || s.position.y < -margin || s.position.x > config.width + margin || s.position.y > config.depth + margin
    }

    func resetPracticeQuestion(_ id: String) {
        guard practice, let a = actor(id) else { return }
        a.held = nil
        a.walkTarget = nil
        a.move = V(0, 0)
        nextQuestion(a)
    }

    private func applyPaint(_ a: SplashActor, _ color: Int) {
        let u = 0.25 + random.nextDouble() * 0.5
        let v = 0.28 + random.nextDouble() * 0.38
        a.paint.append(PaintMark(color: color, u: u, v: v))
        a.hitAt = time
        if a.paint.count >= config.paintLayers {
            a.cleanUntil = time + config.cleanSeconds
            a.move = V(0, 0)
        }
    }

    private func burst(_ owner: String, _ questionId: String, _ p: V, _ h: Double, _ color: Int, _ hit: String?) {
        bursts.append(Burst(id: "\(matchId)-b\(nextSerial())", owner: owner, questionId: questionId, position: p,
                            height: h, color: color, at: time, hit: hit))
    }

    private func explode(_ s: Shot, _ hit: String?) {
        burst(s.owner, s.questionId, s.position, max(s.height, 0.0), s.color, hit)
        // Feedback references its original question; never rewrites a newer question.
        guard let owner = actor(s.owner) else { return }
        var keepWrong = false
        if let f = owner.feedback { keepWrong = !f.correct && time < f.expires }
        if !keepWrong {
            owner.feedback = Feedback(questionId: s.questionId, answer: s.answer, explanation: s.explanation,
                                      correct: true, expires: time + 1.8)
        }
    }

    private func bot(_ a: SplashActor) {
        if time < a.cleanUntil || time < a.recoveryUntil { return }
        let skill = Characters.get(a.member.character).skill
        let threats = shots.filter { shot in
            shot.owner != a.member.id && (mode == .solo || actor(shot.owner)?.member.team != a.member.team)
        }
        let threat = threats.first { shot in
            if (shot.position - a.position).length() >= 1.8 { return false }
            let d = shot.velocity.unit()
            let n = (a.position - shot.position).unit()
            return d.x * n.x + d.y * n.y > 0.65
        }
        if let threat = threat, a.height == 0.0, time >= a.crouchUntil {
            if threat.height > 1.0 {
                command(a.member.id, "bot-\(nextSerial())", .crouch)
            } else {
                command(a.member.id, "bot-\(nextSerial())", .jump)
            }
        }
        if a.held == nil {
            if time < a.nextBotThink {
                a.move = V(0, 0)
                return
            }
            guard let q = a.question, !a.choices.isEmpty else { return }
            if a.botChoice == nil {
                if random.nextDouble() < skill {
                    a.botChoice = a.choices.first(where: { $0.text == q.answer })?.index
                } else {
                    a.botChoice = a.choices[random.nextInt(a.choices.count)].index
                }
            }
            guard let choice = a.choices.first(where: { $0.index == a.botChoice }) else { return }
            let d = choice.position - a.position
            if d.length() <= config.pickupRadius * 0.8 {
                a.move = V(0, 0)
                command(a.member.id, "bot-\(nextSerial())", .pickup(questionId: q.id, index: choice.index))
                a.nextBotThink = time + 0.22 + random.nextDouble() * 0.25
            } else {
                a.move = d.unit()
            }
        } else {
            let opponents = actors.filter { other in other !== a && (mode == .solo || other.member.team != a.member.team) }
            guard var opponent = opponents.first else { return }
            var best = Double.greatestFiniteMagnitude
            for candidate in opponents {
                let value = (candidate.position - a.position).length() + (time < candidate.cleanUntil ? 20.0 : 0.0)
                if value < best {
                    best = value
                    opponent = candidate
                }
            }
            let distance = (opponent.position - a.position).length()
            let lead = config.moveSpeed * distance / config.throwSpeed * skill * 0.7
            let predicted = opponent.position + opponent.move * lead
            let errorX = random.nextDouble() - 0.5
            let errorY = random.nextDouble() - 0.5
            let error = V(errorX, errorY) * (1 - skill) * 2.0
            a.direction = (predicted - a.position + error).unit()
            a.move = distance > 7 ? (opponent.position - a.position).unit() * 0.6 : V(0, 0)
            if time >= a.nextBotThink { command(a.member.id, "bot-\(nextSerial())", .throwBalloon) }
        }
    }

    func finish() {
        if result != nil || practice { return }
        var winners: [String] = []
        if mode == .teams {
            if teamScores[0] != teamScores[1] {
                let team = teamScores[0] > teamScores[1] ? 0 : 1
                winners = actors.filter { $0.member.team == team }.map { $0.member.id }
            }
        } else {
            let best = actors.map { $0.score }.max() ?? 0
            let leaders = actors.filter { $0.score == best }
            winners = leaders.count > 1 ? [] : leaders.map { $0.member.id }
        }
        var scores: [String: Int] = [:]
        for a in actors { scores[a.member.id] = a.score }
        result = MatchResult(id: matchId, winners: winners, scores: scores, teamScores: teamScores,
                             draw: winners.isEmpty, elapsed: time)
        onEvent?("finish", matchId)
    }
}
