import SpriteKit
import UIKit

final class PingPongScene: SKScene {
    var onPointResolved: ((PingPongRallyResolution) -> Void)?
    var onStatusChanged: ((String) -> Void)?

    private let arenaNode = SKSpriteNode(imageNamed: PingPongAssetNames.arena)
    private let ballNode = SKSpriteNode(imageNamed: PingPongAssetNames.ball)
    private let playerPaddleNode = SKSpriteNode()
    private let minikNode = SKSpriteNode()

    private var difficulty: PingPongDifficulty = .starter
    private var controlMode: PingPongControlMode?
    private var tuning = PingPongTuning.values(for: .starter)
    private var reduceMotion = false
    private var rallyModel = PingPongRallyModel()
    private var currentServer: PingPongParticipant = .minik
    private var isRallyActive = false
    private var awaitingChildServe = false
    private var childReturnIsOpen = false
    private var childHasAttemptedTap = false
    private var pendingMinikReturnTime: TimeInterval?
    private var lastUpdateTime: TimeInterval = 0
    private var activeTouchID: ObjectIdentifier?
    private var lastTouchPoint: CGPoint?
    private var lastTouchTime: TimeInterval?
    private var latestPaddleVelocity = CGVector.zero
    private var paddleIsLogicallyActive = false
    private var tableLayout = PingPongTableLayout(containerSize: .zero)
    private let retroLayer = PingPongRetroLayer()
    private let retroGame = PingPongRetroGame()
    private var retroLayout = PingPongRetroLayout(containerSize: .zero)
    private var visualStyle: PingPongVisualStyle = .modern

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = UIColor(red: 0.91, green: 0.65, blue: 0.42, alpha: 1)
        configureNodes()
        // 80s Style draws opaquely above the Modern nodes; hidden in Modern.
        retroLayer.zPosition = 100
        retroLayer.isHidden = true
        addChild(retroLayer)
        retroGame.onStatusChanged = { [weak self] message in
            self?.onStatusChanged?(message)
        }
        retroGame.onPointResolved = { [weak self] resolution in
            self?.onPointResolved?(resolution)
        }
    }

    override convenience init() {
        self.init(size: CGSize(width: 430, height: 760))
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        layoutNodes()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutNodes()
    }

    func configure(
        difficulty: PingPongDifficulty,
        controlMode: PingPongControlMode?,
        reduceMotion: Bool,
        visualStyle: PingPongVisualStyle = .modern
    ) {
        cancelGameplay()
        self.visualStyle = visualStyle
        retroLayer.isHidden = visualStyle != .retro
        retroGame.configure(
            difficulty: difficulty,
            controlMode: difficulty.supportsControlMode ? (controlMode ?? .tap) : nil
        )
        self.difficulty = difficulty
        self.controlMode = difficulty.supportsControlMode ? (controlMode ?? .tap) : nil
        self.tuning = .values(for: difficulty)
        self.reduceMotion = reduceMotion
        updatePlayerPaddleTexture(side: .forehand)
        setMinikPose(side: .forehand, striking: false)
    }

    func startRally(server: PingPongParticipant) {
        if visualStyle == .retro {
            retroGame.startRally(server: server)
            return
        }
        removeAction(forKey: "minik-serve")
        rallyModel = PingPongRallyModel()
        currentServer = difficulty == .starter ? .minik : server
        isRallyActive = true
        awaitingChildServe = false
        childReturnIsOpen = false
        childHasAttemptedTap = false
        pendingMinikReturnTime = nil
        ballNode.isHidden = false
        ballNode.setScale(1)
        hidePaddleUnlessPersistent()

        if currentServer == .minik {
            prepareMinikServe()
        } else {
            prepareChildServe()
        }
    }

    func suspendGameplay() {
        isPaused = true
    }

    func resumeGameplay() {
        lastUpdateTime = 0
        isPaused = false
    }

    func cancelGameplay() {
        retroGame.cancel()
        removeAllActions()
        isRallyActive = false
        awaitingChildServe = false
        childReturnIsOpen = false
        pendingMinikReturnTime = nil
        paddleIsLogicallyActive = false
        activeTouchID = nil
        playerPaddleNode.removeAllActions()
        minikNode.removeAllActions()
        ballNode.isHidden = true
        playerPaddleNode.isHidden = true
    }

    func performAccessibilityReturn(side: PingPongPaddleSide) {
        if visualStyle == .retro {
            retroGame.performAccessibilityReturn(side: side)
            return
        }
        guard isRallyActive else { return }
        if awaitingChildServe {
            let x: CGFloat = side == .backhand ? 0.34 : 0.66
            beginTapServe(at: CGPoint(x: x, y: 0.32))
            return
        }
        guard childReturnIsOpen, let flight = rallyModel.flight else { return }
        let point = CGPoint(
            x: side == .backhand ? min(flight.position.x, 0.44) : max(flight.position.x, 0.56),
            y: max(flight.position.y, PingPongTableGeometry.childStrikeYRange.lowerBound)
        )
        if difficulty == .starter {
            performStarterReturn(at: point)
        } else {
            performTapReturn(at: point)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        if visualStyle == .retro {
            retroGame.update(currentTime)
            retroLayer.render(
                ballPosition: retroGame.ballPosition,
                childLateral: retroGame.childLateral,
                minikLateral: retroGame.minikLateral
            )
            return
        }
        guard isRallyActive else {
            lastUpdateTime = currentTime
            return
        }
        let delta = lastUpdateTime == 0 ? 1.0 / 60.0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        let events = rallyModel.advance(by: delta, tuning: tuning)
        updateBallPresentation()
        for event in events {
            handle(event)
        }

        if paddleIsLogicallyActive,
           childReturnIsOpen,
           controlMode == .swipe || difficulty == .starter,
           let paddlePosition = lastTouchPoint {
            if difficulty == .starter {
                performStarterReturn(at: paddlePosition)
            } else {
                performSwipeReturn(at: paddlePosition, velocity: latestPaddleVelocity)
            }
        }

        if let due = pendingMinikReturnTime, currentTime >= due {
            pendingMinikReturnTime = nil
            performMinikReturn()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if visualStyle == .retro {
            if let touch = touches.first,
               let point = retroLayout.tablePoint(fromScenePoint: touch.location(in: self)) {
                retroGame.touchBegan(id: ObjectIdentifier(touch), at: point, timestamp: touch.timestamp)
            }
            return
        }
        guard isRallyActive, activeTouchID == nil, let touch = touches.first else { return }
        let point = tablePoint(fromScenePoint: touch.location(in: self))
        activeTouchID = ObjectIdentifier(touch)
        lastTouchPoint = point
        lastTouchTime = touch.timestamp
        latestPaddleVelocity = .zero

        if difficulty != .starter, controlMode == .tap {
            if PingPongServeInput.acceptsTap(at: point), let point {
                handleTap(at: point)
            }
            activeTouchID = nil
            lastTouchPoint = nil
            lastTouchTime = nil
            return
        }

        guard let point else {
            deactivatePersistentPaddle()
            return
        }
        updatePersistentPaddle(at: point)
        attemptPersistentContact(at: point, velocity: .zero)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if visualStyle == .retro {
            if let touch = touches.first,
               let point = retroLayout.tablePoint(fromScenePoint: touch.location(in: self)) {
                retroGame.touchMoved(id: ObjectIdentifier(touch), at: point, timestamp: touch.timestamp)
            }
            return
        }
        guard let touch = touches.first,
              activeTouchID == ObjectIdentifier(touch) else { return }
        let point = tablePoint(fromScenePoint: touch.location(in: self))
        let elapsed = max(touch.timestamp - (lastTouchTime ?? touch.timestamp), 1.0 / 120.0)
        guard let point else {
            lastTouchPoint = nil
            lastTouchTime = touch.timestamp
            latestPaddleVelocity = .zero
            deactivatePersistentPaddle()
            return
        }
        let oldPoint = lastTouchPoint ?? point
        latestPaddleVelocity = CGVector(
            dx: (point.x - oldPoint.x) / elapsed,
            dy: (point.y - oldPoint.y) / elapsed
        )
        lastTouchPoint = point
        lastTouchTime = touch.timestamp
        updatePersistentPaddle(at: point)
        attemptPersistentContact(at: point, velocity: latestPaddleVelocity)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if visualStyle == .retro {
            if let touch = touches.first {
                retroGame.touchEnded(id: ObjectIdentifier(touch))
            }
            return
        }
        guard let touch = touches.first,
              activeTouchID == ObjectIdentifier(touch) else { return }
        activeTouchID = nil
        lastTouchPoint = nil
        lastTouchTime = nil
        latestPaddleVelocity = .zero
        paddleIsLogicallyActive = false
        playerPaddleNode.run(.fadeOut(withDuration: 0.12))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func configureNodes() {
        arenaNode.zPosition = -30
        minikNode.zPosition = 5
        ballNode.zPosition = 12
        playerPaddleNode.zPosition = 15
        ballNode.isHidden = true
        playerPaddleNode.isHidden = true
        addChild(arenaNode)
        addChild(minikNode)
        addChild(ballNode)
        addChild(playerPaddleNode)
    }

    private func layoutNodes() {
        guard size.width > 0, size.height > 0 else { return }
        tableLayout = PingPongTableLayout(containerSize: size)
        retroLayout = PingPongRetroLayout(containerSize: size)
        retroLayer.layout(retroLayout, sceneSize: size)
        retroGame.updateGeometry(retroLayout.geometry)
        arenaNode.position = CGPoint(
            x: tableLayout.arenaFrame.midX,
            y: tableLayout.arenaFrame.midY
        )
        arenaNode.size = tableLayout.arenaFrame.size

        let topBandHeight = max(
            tableLayout.arenaFrame.maxY - tableLayout.tableFrame.maxY,
            tableLayout.tableFrame.height * 0.10
        )
        let minikBox = CGSize(
            width: tableLayout.tableFrame.width * 0.20,
            height: topBandHeight * 0.88
        )
        minikNode.size = aspectFitSize(for: minikNode.texture, inside: minikBox)
        minikNode.position = CGPoint(
            x: tableLayout.tableFrame.midX,
            y: min(
                tableLayout.arenaFrame.maxY - minikNode.size.height / 2,
                tableLayout.tableFrame.maxY + minikNode.size.height / 2
            )
        )

        let ballDiameter = min(
            tableLayout.tableFrame.width,
            tableLayout.tableFrame.height
        ) * 0.055
        ballNode.size = CGSize(width: ballDiameter, height: ballDiameter)
        updatePlayerPaddleLayout()
        updateBallPresentation()
    }

    private func prepareChildServe() {
        awaitingChildServe = true
        ballNode.position = scenePoint(from: CGPoint(x: 0.5, y: 0.87))
        if controlMode == .tap {
            onStatusChanged?(String(localized: "Tap anywhere on the table to serve"))
            playerPaddleNode.isHidden = true
        } else {
            onStatusChanged?(String(localized: "Swipe through the ball to serve"))
            updatePlayerPaddleTexture(side: .forehand)
        }
    }

    private func prepareMinikServe() {
        let side: PingPongPaddleSide = Double.random(in: 0...1) < tuning.minikForehandPreference
            ? .forehand
            : .backhand
        setMinikPose(side: side, striking: false)
        ballNode.position = scenePoint(from: CGPoint(x: 0.5, y: 0.13))
        onStatusChanged?(difficulty == .starter
            ? String(localized: "Get your paddle ready")
            : String(localized: "Minik is serving"))
        run(.sequence([
            .wait(forDuration: difficulty == .starter ? 0.52 : 0.68),
            .run { [weak self] in self?.beginMinikServe(side: side) }
        ]), withKey: "minik-serve")
    }

    private func beginMinikServe(side: PingPongPaddleSide) {
        guard isRallyActive else { return }
        animateMinikStrike(side: side)
        if Double.random(in: 0...1) < tuning.minikServeFaultProbability {
            let faultPlan = PingPongServePlan(
                server: .minik,
                start: CGPoint(x: 0.5, y: 0.13),
                firstBounce: CGPoint(x: -0.12, y: 0.28),
                secondBounce: CGPoint(x: 0.5, y: 0.72),
                speed: tuning.ballBaseSpeed,
                verticalVelocity: tuning.netHeight * 1.5
            )
            rallyModel.startServe(faultPlan, tuning: tuning)
            onStatusChanged?(String(localized: "Minik served"))
            return
        }
        let spread = difficulty == .starter ? 0.08 : tuning.minikCornerPreference
        let targetX = (0.5 + CGFloat.random(in: -spread...spread))
            .clamped(to: PingPongTableGeometry.tableXRange)
        let plan = PingPongServePlanner.tapPlan(
            at: CGPoint(x: targetX, y: difficulty == .starter ? 0.80 : 0.75),
            server: .minik,
            tuning: tuning
        )
        rallyModel.startServe(plan, tuning: tuning)
        onStatusChanged?(String(localized: "Minik served"))
    }

    private func handleTap(at point: CGPoint) {
        if awaitingChildServe {
            beginTapServe(at: point)
        } else if childReturnIsOpen {
            performTapReturn(at: point)
        }
    }

    private func beginTapServe(at point: CGPoint) {
        guard awaitingChildServe,
              PingPongServeInput.acceptsTap(at: point) else { return }
        awaitingChildServe = false
        animatePlayerStrike(at: CGPoint(x: point.x, y: 0.87))
        let plan = PingPongServePlanner.tapPlan(
            at: point,
            server: .child,
            tuning: tuning
        )
        rallyModel.startServe(plan, tuning: tuning)
        onStatusChanged?(String(localized: "Serve in play"))
    }

    private func attemptPersistentContact(at point: CGPoint, velocity: CGVector) {
        if awaitingChildServe, controlMode == .swipe {
            guard distance(point, CGPoint(x: 0.5, y: 0.87)) <= tuning.swipeCollisionForgiveness else {
                return
            }
            let contact = PingPongContact(
                contactPoint: point,
                normalizedTimingQuality: 1,
                normalizedSpatialQuality: 1,
                paddleVelocity: velocity,
                intendedHorizontalDirection: velocity.dx.clamped(to: -1...1),
                mode: .swipe
            )
            awaitingChildServe = false
            guard let plan = PingPongServePlanner.swipePlan(
                contact: contact,
                server: .child,
                tuning: tuning
            ) else {
                resolveImmediately(
                    PingPongRallyResolution(pointWinner: .minik, fault: .illegalServe)
                )
                return
            }
            rallyModel.startServe(plan, tuning: tuning)
            onStatusChanged?(String(localized: "Serve in play"))
            return
        }

        guard childReturnIsOpen else { return }
        if difficulty == .starter {
            performStarterReturn(at: point)
        } else {
            performSwipeReturn(at: point, velocity: velocity)
        }
    }

    private func performTapReturn(at point: CGPoint) {
        guard childReturnIsOpen, !childHasAttemptedTap, let flight = rallyModel.flight else { return }
        childHasAttemptedTap = true
        animatePlayerStrike(at: point)
        let forwardSpeed = max(abs(flight.planarVelocity.dy), 0.12)
        let timingOffset = TimeInterval((flight.position.y - 0.82) / forwardSpeed)
        guard let contact = PingPongContactEvaluator.tapContact(
            at: point,
            ballPosition: flight.position,
            secondsFromIdealContact: timingOffset,
            tuning: tuning
        ) else {
            onStatusChanged?(String(localized: "Swing missed"))
            return
        }
        childReturnIsOpen = false
        rallyModel.startReturn(contact: contact, striker: .child, tuning: tuning)
        onStatusChanged?(String(localized: "Good return"))
    }

    private func performSwipeReturn(at point: CGPoint, velocity: CGVector) {
        guard childReturnIsOpen, let flight = rallyModel.flight,
              let contact = PingPongContactEvaluator.swipeContact(
                paddlePosition: point,
                ballPosition: flight.position,
                paddleVelocity: velocity,
                tuning: tuning
              ) else { return }
        childReturnIsOpen = false
        rallyModel.startReturn(contact: contact, striker: .child, tuning: tuning)
        onStatusChanged?(String(localized: "Return in play"))
    }

    private func performStarterReturn(at point: CGPoint) {
        guard childReturnIsOpen, let flight = rallyModel.flight,
              let contact = PingPongContactEvaluator.starterAssistedContact(
                paddlePosition: point,
                ballPosition: flight.position,
                tuning: tuning
              ) else { return }
        childReturnIsOpen = false
        rallyModel.startReturn(contact: contact, striker: .child, tuning: tuning)
        onStatusChanged?(String(localized: "Nice return!"))
    }

    private func performMinikReturn() {
        guard isRallyActive,
              let flight = rallyModel.flight,
              flight.receiverMayReturn,
              flight.striker == .child else { return }
        let speed = hypot(flight.planarVelocity.dx, flight.planarVelocity.dy)
        let predictedLandingX = (
            flight.position.x
                + flight.planarVelocity.dx
                * CGFloat(tuning.minikReactionInterval)
                * tuning.minikPredictionAmount
        ).clamped(to: 0...1)
        let incoming = PingPongIncomingShot(
            predictedLandingX: predictedLandingX,
            speed: speed,
            depth: flight.position.y
        )
        let decision = PingPongMinikAI.decision(
            for: incoming,
            difficulty: difficulty,
            randomUnit: Double.random(in: 0...1)
        )
        guard decision.kind != .unreachable, let baseContact = decision.contact else {
            onStatusChanged?(String(localized: "Minik missed"))
            return
        }

        animateMinikStrike(side: decision.paddleSide)
        let contact = PingPongContact(
            contactPoint: flight.position,
            normalizedTimingQuality: baseContact.normalizedTimingQuality,
            normalizedSpatialQuality: baseContact.normalizedSpatialQuality,
            paddleVelocity: baseContact.paddleVelocity,
            intendedHorizontalDirection: baseContact.intendedHorizontalDirection,
            mode: nil
        )
        rallyModel.startReturn(contact: contact, striker: .minik, tuning: tuning)
        onStatusChanged?(
            decision.kind == .imperfectContact
                ? String(localized: "Minik made a difficult return")
                : String(localized: "Minik returned")
        )
    }

    private func handle(_ event: PingPongFlightEvent) {
        switch event {
        case .serveOwnBounce:
            break
        case .legalReceiverBounce(let receiver):
            if receiver == .child {
                childReturnIsOpen = true
                childHasAttemptedTap = false
                onStatusChanged?(difficulty == .starter
                    ? String(localized: "Move your paddle to the ball")
                    : String(localized: "Return the ball"))
            } else {
                pendingMinikReturnTime = lastUpdateTime + tuning.minikReactionInterval
                let x = rallyModel.flight?.position.x ?? 0.5
                setMinikPose(
                    side: PingPongPaddleSide.side(forNormalizedX: x),
                    striking: false
                )
            }
        case .resolved(let resolution):
            resolveImmediately(resolution)
        }
    }

    private func resolveImmediately(_ resolution: PingPongRallyResolution) {
        guard isRallyActive else { return }
        isRallyActive = false
        awaitingChildServe = false
        childReturnIsOpen = false
        pendingMinikReturnTime = nil
        onStatusChanged?(String(
            format: String(localized: "%@ won the point"),
            resolution.pointWinner.displayName
        ))
        onPointResolved?(resolution)
    }

    private func updateBallPresentation() {
        guard let flight = rallyModel.flight else { return }
        ballNode.position = scenePoint(from: flight.position)
        let heightScale = 1 + min(max(flight.height, 0), 0.4) * 0.55
        ballNode.setScale(heightScale)
    }

    private func updatePersistentPaddle(at point: CGPoint) {
        let isInside = PingPongTableGeometry.isInsideChildStrikeZone(point)
        paddleIsLogicallyActive = isInside
        guard isInside else {
            playerPaddleNode.run(.fadeOut(withDuration: 0.1))
            return
        }
        let side = difficulty == .starter
            ? PingPongPaddleSide.forehand
            : PingPongPaddleSide.side(forNormalizedX: point.x)
        updatePlayerPaddleTexture(side: side)
        updatePlayerPaddleLayout()
        playerPaddleNode.position = scenePoint(from: point)
        playerPaddleNode.isHidden = false
        playerPaddleNode.run(.fadeIn(withDuration: 0.08))
    }

    private func deactivatePersistentPaddle() {
        paddleIsLogicallyActive = false
        playerPaddleNode.run(.fadeOut(withDuration: 0.1))
    }

    private func animatePlayerStrike(at point: CGPoint) {
        let side = PingPongPaddleSide.side(forNormalizedX: point.x)
        updatePlayerPaddleTexture(side: side)
        updatePlayerPaddleLayout()
        playerPaddleNode.position = scenePoint(from: CGPoint(x: point.x, y: 0.98))
        playerPaddleNode.alpha = 0
        playerPaddleNode.isHidden = false
        playerPaddleNode.removeAllActions()
        if reduceMotion {
            playerPaddleNode.alpha = 1
            playerPaddleNode.run(.sequence([
                .wait(forDuration: 0.12),
                .fadeOut(withDuration: 0.08)
            ]))
            return
        }
        playerPaddleNode.run(.sequence([
            .group([
                .fadeIn(withDuration: 0.06),
                .move(to: scenePoint(from: point), duration: 0.10)
            ]),
            .wait(forDuration: 0.08),
            .group([
                .fadeOut(withDuration: 0.12),
                .moveBy(
                    x: 0,
                    y: -tableLayout.tableFrame.height * 0.06,
                    duration: 0.12
                )
            ])
        ]))
    }

    private func updatePlayerPaddleTexture(side: PingPongPaddleSide) {
        playerPaddleNode.texture = SKTexture(
            imageNamed: PingPongAssetNames.playerPaddle(difficulty: difficulty, side: side)
        )
    }

    private func updatePlayerPaddleLayout() {
        let box = difficulty == .starter
            ? CGSize(
                width: tableLayout.tableFrame.width * 0.27,
                height: tableLayout.tableFrame.height * 0.18
            )
            : CGSize(
                width: tableLayout.tableFrame.width * 0.36,
                height: tableLayout.tableFrame.height * 0.15
            )
        playerPaddleNode.size = aspectFitSize(for: playerPaddleNode.texture, inside: box)
    }

    private func setMinikPose(side: PingPongPaddleSide, striking: Bool) {
        minikNode.texture = SKTexture(
            imageNamed: PingPongAssetNames.minikPose(side: side, striking: striking)
        )
        let box = CGSize(
            width: tableLayout.tableFrame.width * 0.28,
            height: tableLayout.tableFrame.height * 0.22
        )
        minikNode.size = aspectFitSize(for: minikNode.texture, inside: box)
    }

    private func animateMinikStrike(side: PingPongPaddleSide) {
        setMinikPose(side: side, striking: true)
        minikNode.removeAction(forKey: "pose")
        if reduceMotion {
            minikNode.run(.sequence([
                .wait(forDuration: 0.16),
                .run { [weak self] in self?.setMinikPose(side: side, striking: false) }
            ]), withKey: "pose")
            return
        }
        minikNode.run(.sequence([
            .scale(to: 1.06, duration: 0.08),
            .scale(to: 1, duration: 0.10),
            .wait(forDuration: 0.12),
            .run { [weak self] in self?.setMinikPose(side: side, striking: false) }
        ]), withKey: "pose")
    }

    private func hidePaddleUnlessPersistent() {
        if activeTouchID == nil {
            playerPaddleNode.isHidden = true
        }
    }

    private func tablePoint(fromScenePoint point: CGPoint) -> CGPoint? {
        tableLayout.tablePoint(fromScenePoint: point)
    }

    private func scenePoint(from normalized: CGPoint) -> CGPoint {
        tableLayout.scenePoint(fromTablePoint: normalized)
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private func aspectFitSize(for texture: SKTexture?, inside box: CGSize) -> CGSize {
        guard let texture else { return box }
        let source = texture.size()
        guard source.width > 0, source.height > 0 else { return box }
        let scale = min(box.width / source.width, box.height / source.height)
        return CGSize(width: source.width * scale, height: source.height * scale)
    }

}
