import SpriteKit
import UIKit

/// One rendered world for every seat (Android cross/CrossCourt.kt, MinikCrossPong 1908719): the shared table rotated so the viewer's
/// seat is at the bottom, a mild fixed perspective, and in full screen a camera that pans sideways with the ball (never a zoom
/// change). Drawing, input and collision all use CrossGeometry; the court never invents table areas or nets. Android draws in
/// view coordinates (y down); here "canvas" points are those coordinates and `sk` turns them into SpriteKit's (y up).
final class CrossScene: SKScene {
    static let depth = 4.2
    static let near = 1.45
    static let tilt = 0.92
    static let liftMax = 0.62
    static let liftScale = 0.75
    static let ballSize = 0.042
    static let character = 0.92
    static let stand = 0.20
    static let scoreboard = 74.0
    static let cameraEase = 0.32
    /// Android BotArt: characters with a 4x2 atlas; anyone else is drawn as Minik.
    static let atlasCharacters: Set<String> = ["flare", "kyra", "gaya", "mia", "amber", "comet", "miniko", "coach67", "june", "moshiko"]
    /// Android BotArt.legs (828c6fc): characters whose atlas is cut at the thighs and has legs drawn behind it.
    static let legCharacters: Set<String> = ["flare", "gaya", "mia", "amber", "comet", "june", "moshiko"]
    static let legsWide = 1.5, legsOverlap = 48.0, legsExtent = 520.0, cellRows = 512.0
    static let seatColors: [(Double, Double, Double)] = [(239, 68, 68), (59, 130, 246), (34, 197, 94), (250, 204, 21)]

    var engine: CrossEngine { didSet { if engine !== oldValue { rebuild() } } }
    /// Who advances the clock: a multi-stage match drives its current table; by default the engine itself.
    var step: ((Double) -> Void)?
    /// Once per frame after the clock advanced (the controller drains events here).
    var onFrame: (() -> Void)?
    var tutorialTarget: Int?
    var acceptsInput = true
    var names: [String] = []
    /// Remote human avatars (emoji) by stage seat; characters come from the seat's characterId.
    var avatarIcons: [Int: String] = [:]
    /// Full screen: the table as long as the classic 2-player table, and a camera that pans with the ball. Overview (false): the
    /// whole table at once with a fixed camera.
    var fullScreen = true { didSet { if oldValue != fullScreen { layoutCourt() } } }

    private var scale = 1.0, cx = 0.0, cy = 0.0
    /// Horizontal camera pan in points (full screen only), eased toward the ball.
    private var pan = 0.0, panMin = 0.0, panMax = 0.0
    private var notes: [Int: (text: String, at: TimeInterval)] = [:]
    private var previousTime: TimeInterval = 0
    private var activeTouch: UITouch?
    private var downPoint = CGPoint.zero
    private var samples: [(time: TimeInterval, point: CGPoint)] = []
    private var textures: [String: SKTexture] = [:]
    private var available: [String: Bool] = [:]
    private let canvas = SKNode()
    private let hud = SKNode()
    private let tableShadow = SKShapeNode(), tableBorder = SKShapeNode(), tableFill = SKShapeNode(), tableEdge = SKShapeNode()
    private let centreLines = SKShapeNode(), highlightNode = SKShapeNode(), bounceNode = SKShapeNode()
    private var territoryNodes: [SKShapeNode] = []
    private var territoryPaths: [CGPath] = []
    private var outsidePath: CGPath = CGMutablePath()
    private let netsNode = SKNode()
    private var actors: [Int: CrossActorNodes] = [:]
    private let ballShadow = SKShapeNode(circleOfRadius: 1), ballNode = SKShapeNode(circleOfRadius: 1), ballShine = SKShapeNode(circleOfRadius: 1)
    private let netFlash = SKShapeNode(circleOfRadius: 1)
    private let paddleNode = SKSpriteNode()
    private let arrowNode = SKShapeNode()
    private var tags: [Int: CrossTagNodes] = [:]
    private var boards: [Int: CrossBoardNodes] = [:]
    private static let font = "HelveticaNeue-Bold"

    init(engine: CrossEngine) {
        self.engine = engine
        super.init(size: CGSize(width: 430, height: 760))
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.13, green: 0.24, blue: 0.43, alpha: 1)
        canvas.zPosition = 0; hud.zPosition = 20
        addChild(canvas); addChild(hud)
        tableShadow.strokeColor = UIColor(red: 10 / 255, green: 20 / 255, blue: 40 / 255, alpha: 70 / 255); tableShadow.lineWidth = 10; tableShadow.fillColor = .clear
        tableShadow.lineJoin = .round; tableShadow.zPosition = 0.5
        tableBorder.strokeColor = UIColor(red: 28 / 255, green: 66 / 255, blue: 140 / 255, alpha: 1); tableBorder.lineWidth = 9; tableBorder.fillColor = .clear
        tableBorder.lineJoin = .round; tableBorder.zPosition = 1.0
        tableFill.fillColor = UIColor(red: 64 / 255, green: 196 / 255, blue: 205 / 255, alpha: 1); tableFill.strokeColor = .clear; tableFill.lineWidth = 0; tableFill.zPosition = 1.1
        centreLines.strokeColor = UIColor(white: 1, alpha: 210 / 255); centreLines.lineWidth = 1.6; centreLines.zPosition = 1.3
        tableEdge.strokeColor = UIColor(white: 1, alpha: 210 / 255); tableEdge.lineWidth = 2.6; tableEdge.fillColor = .clear; tableEdge.lineJoin = .round; tableEdge.zPosition = 1.4
        highlightNode.strokeColor = UIColor(red: 1, green: 221 / 255, blue: 87 / 255, alpha: 235 / 255); highlightNode.lineWidth = 3.4; highlightNode.fillColor = .clear
        highlightNode.lineJoin = .round; highlightNode.zPosition = 1.5
        bounceNode.fillColor = .clear; bounceNode.strokeColor = .white; bounceNode.lineWidth = 2; bounceNode.zPosition = 1.6
        netsNode.zPosition = 4
        ballShadow.fillColor = UIColor(red: 10 / 255, green: 34 / 255, blue: 45 / 255, alpha: 1); ballShadow.strokeColor = .clear; ballShadow.zPosition = 4.8
        netFlash.fillColor = .clear; netFlash.strokeColor = UIColor(red: 1, green: 84 / 255, blue: 84 / 255, alpha: 1); netFlash.zPosition = 5.1
        ballNode.fillColor = UIColor(red: 245 / 255, green: 248 / 255, blue: 251 / 255, alpha: 1)
        ballNode.strokeColor = UIColor(red: 171 / 255, green: 186 / 255, blue: 200 / 255, alpha: 1); ballNode.zPosition = 5
        ballShine.fillColor = .white; ballShine.strokeColor = .clear; ballShine.zPosition = 5.05
        paddleNode.zPosition = 6
        arrowNode.fillColor = UIColor(white: 1, alpha: 230 / 255); arrowNode.strokeColor = .clear; arrowNode.zPosition = 30
        let arrow = CGMutablePath()
        arrow.move(to: CGPoint(x: 10, y: 0)); arrow.addLine(to: CGPoint(x: -6, y: -7)); arrow.addLine(to: CGPoint(x: -6, y: 7)); arrow.closeSubpath()
        arrowNode.path = arrow
        for node in [tableShadow, tableBorder, tableFill, centreLines, tableEdge, highlightNode, bounceNode] { canvas.addChild(node) }
        canvas.addChild(netsNode)
        for node in [ballShadow, ballNode, ballShine, netFlash] { canvas.addChild(node) }
        canvas.addChild(paddleNode)
        hud.addChild(arrowNode)
        rebuild()
    }
    required init?(coder: NSCoder) { return nil }
    override func didMove(to view: SKView) { view.isMultipleTouchEnabled = false; layoutCourt() }
    override func didChangeSize(_ oldSize: CGSize) { layoutCourt() }
    /// Starts or stops the frame loop (Android resumeFrames/stopFrames); pausing play itself is the controller's job.
    func setActive(_ active: Bool) { isPaused = !active; previousTime = 0; if !active { cancelTouch() } }

    private var g: CrossGeometry { engine.geometry }
    private var viewSeat: Int { engine.localSeat ?? 0 }
    private var height: Double { Double(size.height) }

    // ---- projection -------------------------------------------------------------------------------
    private func k(_ y: Double) -> Double { CrossScene.depth / (CrossScene.depth + (CrossScene.near - y)) }
    /// Concave display height: low balls separate clearly from the net band, high lobs stay on screen.
    private func lift(_ h: Double) -> Double { CrossScene.liftMax * (1 - exp(-max(h, 0) / CrossScene.liftScale)) }
    /// Android `screen`: view coordinates (y down) including the camera pan.
    func screen(_ p: MPPoint, _ h: Double = 0) -> CGPoint {
        let v = g.toView(viewSeat, p), kk = k(v.y)
        return CGPoint(x: cx + v.x * scale * kk - pan, y: cy + (v.y * CrossScene.tilt - lift(h)) * scale * kk)
    }
    /// The same point without the pan, for nodes inside the panned canvas.
    private func unpanned(_ p: MPPoint, _ h: Double = 0) -> CGPoint {
        let q = screen(p, h)
        return CGPoint(x: q.x + CGFloat(pan), y: q.y)
    }
    /// View coordinates (y down) → SpriteKit (y up).
    private func sk(_ q: CGPoint) -> CGPoint { CGPoint(x: q.x, y: size.height - q.y) }
    private func sizeAt(_ p: MPPoint) -> Double { scale * k(g.toView(viewSeat, p).y) }
    /// Inverse of `screen` for points on the table plane (height 0).
    func world(_ sx: Double, _ sy: Double) -> MPPoint {
        let yy = (sy - cy) / (scale * CrossScene.tilt)
        let y = yy * (CrossScene.depth + CrossScene.near) / (CrossScene.depth + yy)
        return g.fromView(viewSeat, MPPoint((sx + pan - cx) / (scale * k(y)), y))
    }

    func layoutCourt() {
        let w = Double(size.width), h = Double(size.height)
        guard w > 1, h > 1 else { return }
        // Fit the whole table, the other players beside/behind their arm ends and the viewer's paddle area.
        var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0
        let geometry = g, seat = viewSeat
        func include(_ p: MPPoint, up: Double = 0) {
            let v = geometry.toView(seat, p), kk = k(v.y)
            minX = min(minX, v.x * kk); maxX = max(maxX, v.x * kk)
            minY = min(minY, (v.y * CrossScene.tilt - up) * kk); maxY = max(maxY, v.y * CrossScene.tilt * kk)
        }
        for s in geometry.seats {
            geometry.armCorners(s).forEach { include($0) }
            if s == seat {
                include(geometry.fromLocal(s, -0.62, CrossGeometry.reach + 0.22)); include(geometry.fromLocal(s, 0.62, CrossGeometry.reach + 0.22))
            } else { include(geometry.fromLocal(s, 0, CrossGeometry.reach + CrossScene.stand), up: CrossScene.character * 0.80) }
        }
        // Side players may be partly outside the screen; their name tags stay inside it.
        minX -= 0.10; maxX += 0.10
        let margin = 6.0, board = CrossScene.scoreboard
        let tall = (h - board - 2 * margin) / max(0.01, maxY - minY)
        scale = max(1, fullScreen ? tall : min((w - 2 * margin) / max(0.01, maxX - minX), tall))
        cx = fullScreen ? w / 2 : w / 2 - (minX + maxX) / 2 * scale
        // The camera may pan just far enough to show each side arm's end and its whole player.
        let reach = 0.32
        panMin = min(0, cx + (minX - reach) * scale - margin)
        panMax = max(0, cx + (maxX + reach) * scale - w + margin)
        pan = fullScreen ? pan.mpClamp(panMin, panMax) : 0
        // Centre the table in the space below the scoreboard.
        let spare = h - board - (maxY - minY) * scale
        cy = board + spare * 0.55 - minY * scale
        buildPaths()
        render()
    }
    /// Per-seat nodes for the current table (a new stage may have fewer seats).
    private func rebuild() {
        cancelTouch()
        actors.values.forEach { $0.remove() }
        tags.values.forEach { $0.remove() }
        boards.values.forEach { $0.remove() }
        actors = [:]; tags = [:]; boards = [:]
        for s in g.seats {
            if s != viewSeat { actors[s] = CrossActorNodes(parent: canvas) }
            tags[s] = CrossTagNodes(parent: hud, font: CrossScene.font)
            boards[s] = CrossBoardNodes(parent: hud, font: CrossScene.font)
        }
        notes = [:]
        layoutCourt()
    }
    private func buildPaths() {
        // Paths are built camera-free inside the canvas, which the pan shifts.
        var table: CGPath?
        for s in g.seats {
            let corners = g.armCorners(s).map { sk(unpanned($0)) }
            let arm = CGMutablePath()
            arm.addLines(between: corners); arm.closeSubpath()
            table = table.map { $0.union(arm) } ?? arm
        }
        if g.hub > 0 {
            let hub = CGMutablePath()
            for i in 0...72 {
                let a = Double(i) * 2 * Double.pi / 72
                let q = sk(unpanned(MPPoint(sin(a) * g.hub, cos(a) * g.hub)))
                if i == 0 { hub.move(to: q) } else { hub.addLine(to: q) }
            }
            hub.closeSubpath()
            table = table.map { $0.union(hub) } ?? hub
        }
        let shape: CGPath = table ?? CGMutablePath()
        tableShadow.path = shape; tableShadow.position = CGPoint(x: 3, y: -6)
        tableBorder.path = shape; tableFill.path = shape; tableEdge.path = shape
        territoryNodes.forEach { $0.removeFromParent() }
        territoryNodes = []; territoryPaths = []
        for s in g.seats {
            let wedge = CGMutablePath()
            wedge.move(to: sk(unpanned(MPPoint(0, 0))))
            let from = g.angle(s) - g.sector / 2
            for i in 0...24 {
                let a = from + g.sector * Double(i) / 24
                wedge.addLine(to: sk(unpanned(MPPoint(sin(a), cos(a)) * 3.0)))
            }
            wedge.closeSubpath()
            let clipped = wedge.intersection(shape)
            territoryPaths.append(clipped)
            let node = SKShapeNode(path: clipped)
            let c = CrossScene.seatColors[s % CrossScene.seatColors.count]
            node.fillColor = UIColor(red: CGFloat(c.0 / 255), green: CGFloat(c.1 / 255), blue: CGFloat(c.2 / 255), alpha: CGFloat(s == viewSeat ? 34.0 / 255 : 52.0 / 255))
            node.strokeColor = .clear; node.lineWidth = 0; node.zPosition = 1.2
            canvas.addChild(node); territoryNodes.append(node)
        }
        // Centre lines along each arm, like the classic table markings.
        let lines = CGMutablePath()
        for s in g.seats {
            lines.move(to: sk(unpanned(g.fromLocal(s, 0, max(g.netLength, 0.62)))))
            lines.addLine(to: sk(unpanned(g.fromLocal(s, 0, CrossGeometry.reach))))
        }
        centreLines.path = lines
        // Players are drawn only outside the table (Android clipOutPath).
        let w = Double(size.width)
        outsidePath = CGPath(rect: CGRect(x: -3 * w, y: -height, width: 7 * w, height: 3 * height), transform: nil).subtracting(shape)
        actors.values.forEach { $0.setMask(outsidePath) }
        buildNets()
    }
    private func buildNets() {
        netsNode.removeAllChildren()
        let netHeight = engine.physics.netHeight
        for net in g.nets {
            let steps = 10
            let base = (0...steps).map { sk(unpanned(net.end * (Double($0) / Double(steps)))) }
            let top = (0...steps).map { sk(unpanned(net.end * (Double($0) / Double(steps)), netHeight)) }
            let band = CGMutablePath()
            band.addLines(between: base + top.reversed()); band.closeSubpath()
            let fill = SKShapeNode(path: band)
            fill.fillColor = UIColor(red: 236 / 255, green: 246 / 255, blue: 1, alpha: 120 / 255); fill.strokeColor = .clear; fill.zPosition = 0
            netsNode.addChild(fill)
            let mesh = CGMutablePath()
            for i in 1..<steps { mesh.move(to: base[i]); mesh.addLine(to: top[i]) }
            let meshNode = SKShapeNode(path: mesh)
            meshNode.strokeColor = UIColor(red: 70 / 255, green: 110 / 255, blue: 170 / 255, alpha: 150 / 255); meshNode.lineWidth = 1; meshNode.zPosition = 0.1
            netsNode.addChild(meshNode)
            let tape = CGMutablePath()
            tape.move(to: top[0]); tape.addLine(to: top[steps])
            let tapeNode = SKShapeNode(path: tape)
            tapeNode.strokeColor = .white; tapeNode.lineWidth = 2.4; tapeNode.zPosition = 0.2
            netsNode.addChild(tapeNode)
            // Posts at the table edge.
            let post = CGMutablePath()
            post.move(to: base[steps]); post.addLine(to: CGPoint(x: top[steps].x, y: top[steps].y + 2))
            let postNode = SKShapeNode(path: post)
            postNode.strokeColor = UIColor(red: 30 / 255, green: 80 / 255, blue: 150 / 255, alpha: 1); postNode.lineWidth = 3.2; postNode.zPosition = 0.3
            netsNode.addChild(postNode)
        }
        if g.players == 2 { return }
        let c0 = sk(unpanned(MPPoint(0, 0))), c1 = sk(unpanned(MPPoint(0, 0), netHeight))
        let centre = CGMutablePath()
        centre.move(to: c0); centre.addLine(to: CGPoint(x: c1.x, y: c1.y + 2))
        let centreNode = SKShapeNode(path: centre)
        centreNode.strokeColor = UIColor(red: 30 / 255, green: 80 / 255, blue: 150 / 255, alpha: 1); centreNode.lineWidth = 4; centreNode.zPosition = 0.4
        netsNode.addChild(centreNode)
        let cap = SKShapeNode(circleOfRadius: 3.2)
        cap.fillColor = UIColor(red: 250 / 255, green: 214 / 255, blue: 90 / 255, alpha: 1); cap.strokeColor = .clear
        cap.position = CGPoint(x: c1.x, y: c1.y + 2); cap.zPosition = 0.5
        netsNode.addChild(cap)
    }

    // ---- frame loop ---------------------------------------------------------------------------------
    override func update(_ currentTime: TimeInterval) {
        let elapsed = previousTime == 0 ? 0 : min(1.0 / 30, max(0, currentTime - previousTime))
        previousTime = currentTime
        if let step { step(elapsed) } else { engine.advance(elapsed) }
        follow(elapsed)
        onFrame?()
        render()
    }
    /// Full screen: ease the camera toward the ball (or the server before a serve); no zoom change.
    private func follow(_ dt: Double) {
        guard fullScreen, size.width > 1 else { return }
        let v = g.toView(viewSeat, engine.renderBallPosition)
        let target = (cx + v.x * scale * k(v.y) - Double(size.width) / 2).mpClamp(panMin, panMax)
        pan += (target - pan) * (1 - exp(-dt / CrossScene.cameraEase))
    }

    // ---- drawing --------------------------------------------------------------------------------------
    private func render() {
        guard size.width > 1, size.height > 1 else { return }
        canvas.position = CGPoint(x: -pan, y: 0)
        let receiver = tutorialTarget ?? engine.predictedReceiver
        if let receiver, receiver >= 0, receiver < territoryPaths.count {
            highlightNode.isHidden = false; highlightNode.path = territoryPaths[receiver]
        } else { highlightNode.isHidden = true }
        if let bounce = engine.bouncePoint, engine.bounceAge < 0.38 {
            let q = sk(unpanned(bounce)), r = sizeAt(bounce) * (0.04 + engine.bounceAge * 0.10)
            bounceNode.isHidden = false
            bounceNode.path = CGPath(ellipseIn: CGRect(x: q.x - CGFloat(r), y: q.y - CGFloat(r), width: CGFloat(2 * r), height: CGFloat(2 * r)), transform: nil)
            bounceNode.alpha = CGFloat(1 - engine.bounceAge / 0.38) * 220 / 255
        } else { bounceNode.isHidden = true }
        // Back-to-front: farther players first, so nearer bodies overlap correctly.
        let others = g.seats.filter { $0 != viewSeat }.sorted { screen(g.home($0)).y < screen(g.home($1)).y }
        for (order, seat) in others.enumerated() { renderPlayer(seat, order: order) }
        renderBall()
        renderPaddle()
        renderTags()
        renderScoreboard()
    }
    private func lean(_ stroke: MPStroke) -> Double {
        let blend: Double
        if !stroke.active { blend = 0 }
        else if stroke.age <= 0.27 { blend = (stroke.age / 0.20).mpClamp(0, 1) }
        else { blend = ((stroke.total - stroke.age) / (stroke.total - 0.27)).mpClamp(0, 1) }
        return blend * blend * (3 - 2 * blend)
    }
    /// Android ActorPresentation.frame: 0 ready, 1 windup, 2 accelerate, 3 contact, 4 follow.
    private static func frame(_ stroke: MPStroke) -> Int {
        guard stroke.active else { return 0 }
        if stroke.age < 0.11 { return 1 }
        if stroke.age < CrossActor.windup { return 2 }
        if stroke.age <= 0.27 { return 3 }
        if stroke.age < CrossActor.followEnd { return 4 }
        return 0
    }
    /// Android BotArt.cell.
    private static func cell(_ frame: Int, left: Bool) -> Int {
        switch frame {
        case 1: return left ? 5 : 2
        case 2, 3: return left ? 6 : 3
        case 4: return left ? 7 : 4
        default: return 0
        }
    }
    private func hasImage(_ name: String) -> Bool {
        if let known = available[name] { return known }
        let exists = UIImage(named: name) != nil
        available[name] = exists
        return exists
    }
    private func texture(_ name: String) -> SKTexture {
        if let existing = textures[name] { return existing }
        let value = SKTexture(imageNamed: name)
        value.filteringMode = .linear
        textures[name] = value
        return value
    }
    private func cellTexture(_ sheetName: String, _ cell: Int) -> SKTexture {
        let key = sheetName + "/" + String(cell)
        if let existing = textures[key] { return existing }
        let frame = SKTexture(rect: CGRect(x: Double(cell % 4) / 4, y: cell < 4 ? 0.5 : 0, width: 0.25, height: 0.5), in: texture(sheetName))
        textures[key] = frame
        return frame
    }
    private func renderPlayer(_ seat: Int, order: Int) {
        guard let nodes = actors[seat], seat < engine.seats.count else { return }
        nodes.setDepth(2 + Double(order) * 0.1)
        let info = engine.seats[seat]
        let stroke = engine.stroke(seat)
        let racket = engine.racket(seat)
        let home = g.home(seat)
        let homeView = g.toView(viewSeat, home)
        let unit = sizeAt(home)
        let height = CrossScene.character * unit
        let lateral = g.toLocal(seat, racket).u.mpClamp(-0.75, 0.75)
        // The body stays on its stand line beyond the arm end; the stroke leans the racket to the ball.
        let anchor = unpanned(g.fromLocal(seat, lateral, CrossGeometry.reach + CrossScene.stand))
        let contact = unpanned(stroke.active ? stroke.point : racket, stroke.active ? max(stroke.height, 0.1) : 0.25)
        let homeScreen = unpanned(home)
        let side = abs(homeView.x) > abs(homeView.y) * 0.9
        let facingLeft = side ? homeView.x > 0 : contact.x < homeScreen.x - 2
        let frame = CrossScene.frame(stroke)
        let botCharacter = info.bot?.characterId ?? ""
        let character = botCharacter.isEmpty ? info.characterId : botCharacter
        nodes.hideAll()
        if CrossScene.atlasCharacters.contains(character) {
            let legs = CrossScene.legCharacters.contains(character) && hasImage("mpx_legs_" + character)
            let sheet = legs && hasImage("mpx_bot_" + character) ? "mpx_bot_" + character : "mp_bot_" + character
            let cell = CrossScene.cell(frame, left: facingLeft)
            let frameTexture = cellTexture(sheet, cell)
            let sheetSize = texture(sheet).size()
            let cellWidth = Double(sheetSize.width) / 4, cellHeight = Double(sheetSize.height) / 2
            let width = cellHeight > 0 ? height * cellWidth / cellHeight : height
            let face = MPArt.face(character, left: facingLeft)
            let restX = Double(anchor.x) - width * 0.5, restY = Double(anchor.y) - height * 0.74
            // Lean at most about half a body toward the ball: never move the character onto the table.
            let contactX = (Double(contact.x) - face.x * width).mpClamp(restX - width * 0.55, restX + width * 0.55)
            let contactY = (Double(contact.y) - face.y * height).mpClamp(restY - height * 0.35, restY + height * 0.35)
            let t = lean(stroke)
            let x = restX + (contactX - restX) * t, y = restY + (contactY - restY) * t
            if legs {
                // Legs first, behind the body: they follow the body as it leans into a stroke.
                let rows = height / CrossScene.cellRows
                let legsWidth = width * CrossScene.legsWide
                let top = y + height - CrossScene.legsOverlap * rows
                place(nodes.legs, cellTexture("mpx_legs_" + character, cell), x: x - (legsWidth - width) / 2, y: top, width: legsWidth,
                      height: (CrossScene.legsOverlap + CrossScene.legsExtent) * rows)
            }
            place(nodes.body, frameTexture, x: x, y: y, width: width, height: height)
            // The striking arm and racket reach over the table during contact.
            if frame == 2 || frame == 3 {
                let path = CGMutablePath()
                for (index, p) in MPArt.arm(character, left: facingLeft).enumerated() {
                    let q = sk(CGPoint(x: x + p.x * width, y: y + p.y * height))
                    if index == 0 { path.move(to: q) } else { path.addLine(to: q) }
                }
                path.closeSubpath()
                let r = MPArt.radius(character, left: facingLeft)
                // The racket's face, as an ellipse in SpriteKit coordinates (its top edge in view coordinates becomes its maxY).
                let ovalTop = y + (face.y - r.y) * height, ovalHeight = 2 * r.y * height
                path.addEllipse(in: CGRect(x: x + (face.x - r.x) * width, y: Double(self.size.height) - ovalTop - ovalHeight, width: 2 * r.x * width, height: ovalHeight))
                nodes.showArm(frameTexture, mask: path)
                place(nodes.arm, frameTexture, x: x, y: y, width: width, height: height)
            }
        } else if info.kind == .remote, let icon = avatarIcons[seat], character.isEmpty {
            nodes.emoji.isHidden = false
            nodes.emoji.text = icon
            nodes.emoji.fontSize = CGFloat(max(8, height * 0.42))
            nodes.emoji.position = sk(anchor)
        } else {
            renderMinik(nodes, frame: frame, left: facingLeft, anchor: anchor, reach: contact, height: height, stroke: stroke)
        }
    }
    private func renderMinik(_ nodes: CrossActorNodes, frame: Int, left: Bool, anchor: CGPoint, reach: CGPoint, height: Double, stroke: MPStroke) {
        let poses = ["ready", "windup", "accelerate", "contact", "follow"]
        let prefix = left ? "mp_minik_left_" : "mp_minik_motion_"
        let side = height * 1.15
        let face = left ? MPPoint(0.1732875093, 0.8169685305) : MPPoint(995.0 / 1280, 1030.0 / 1280)
        let t = lean(stroke)
        let restX = Double(anchor.x) - side * 0.5, restY = Double(anchor.y) - side * 0.70
        let contactX = (Double(reach.x) - face.x * side).mpClamp(restX - side * 0.45, restX + side * 0.45)
        let contactY = (Double(reach.y) - face.y * side).mpClamp(restY - side * 0.3, restY + side * 0.3)
        let x = restX + (contactX - restX) * t, y = restY + (contactY - restY) * t
        let recovery = stroke.recoveryBlend
        let index = max(0, min(poses.count - 1, frame))
        if frame == 0 && recovery < 1 {
            place(nodes.recovery, texture(prefix + "follow"), x: x, y: y, width: side, height: side)
            nodes.recovery.alpha = CGFloat(1 - recovery)
            place(nodes.body, texture(prefix + poses[0]), x: x, y: y, width: side, height: side)
            nodes.body.alpha = CGFloat(recovery)
        } else {
            place(nodes.body, texture(prefix + poses[index]), x: x, y: y, width: side, height: side)
        }
    }
    /// A sprite filling the view-coordinate box whose top-left corner is (x, y).
    private func place(_ node: SKSpriteNode, _ texture: SKTexture, x: Double, y: Double, width: Double, height: Double) {
        node.isHidden = false
        node.texture = texture
        node.anchorPoint = CGPoint(x: 0, y: 1)
        node.size = CGSize(width: max(1, width), height: max(1, height))
        node.position = sk(CGPoint(x: x, y: y))
    }
    private func renderBall() {
        let state = engine.ballState
        let ground = engine.renderBallPosition
        let h = state.height
        let unit = sizeAt(ground)
        let radius = unit * CrossScene.ballSize * (1 + min(h, 0.4) * 0.35)
        let s = sk(unpanned(ground)), b = sk(unpanned(ground, h))
        let lifted = min(h, 1.5) / 1.5
        if g.onTable(ground) {
            ballShadow.isHidden = false
            ballShadow.position = CGPoint(x: s.x + CGFloat(radius * 0.15), y: s.y - CGFloat(radius * 0.2))
            ballShadow.xScale = CGFloat(radius * (1 + lifted * 0.6)); ballShadow.yScale = CGFloat(radius * (0.5 + lifted * 0.25))
            ballShadow.alpha = CGFloat(110 - 70 * lifted) / 255 * 0.8
        } else { ballShadow.isHidden = true }
        if engine.netAge < 0.5 {
            netFlash.isHidden = false
            netFlash.position = b
            netFlash.setScale(CGFloat(radius * (1.5 + engine.netAge * 4)))
            netFlash.lineWidth = CGFloat(2.5 / max(0.5, radius * (1.5 + engine.netAge * 4)))
            netFlash.alpha = CGFloat(1 - engine.netAge / 0.5) * 240 / 255
        } else { netFlash.isHidden = true }
        ballNode.position = b; ballNode.setScale(CGFloat(max(0.5, radius)))
        ballNode.lineWidth = CGFloat(0.8 / max(0.5, radius))
        ballShine.position = CGPoint(x: b.x - CGFloat(radius * 0.3), y: b.y + CGFloat(radius * 0.35)); ballShine.setScale(CGFloat(max(0.2, radius * 0.35)))
        // A ball outside the visible area gets a small edge arrow pointing to it.
        let onScreen = screen(ground, h)
        let inset = 14.0, w = Double(size.width)
        let bx = Double(onScreen.x), by = Double(onScreen.y)
        if bx < 0 || bx > w || by < 0 || by > height {
            let ex = bx.mpClamp(inset, w - inset), ey = by.mpClamp(inset, height - inset)
            let angle = atan2(by - ey, bx - ex)
            arrowNode.isHidden = false
            arrowNode.position = sk(CGPoint(x: ex, y: ey))
            arrowNode.zRotation = CGFloat(-angle)
        } else { arrowNode.isHidden = true }
    }
    private func renderPaddle() {
        guard let local = engine.localSeat else { paddleNode.isHidden = true; return }
        let stroke = engine.stroke(local)
        let at = engine.paddle ?? engine.restingPaddle
        let contact = stroke.active && stroke.contacted && stroke.age < stroke.contactAt + 0.07
        let p = contact ? stroke.point : at
        let back = stroke.active ? stroke.left : g.toView(local, p).x < 0
        let name: String
        switch engine.control {
        case .beginner: name = "mp_ping_pong_player_starter_paddle"
        case .standard: name = back ? "mp_ping_pong_player_medium_backhand" : "mp_ping_pong_player_medium_forehand"
        case .pro: name = back ? "mp_ping_pong_player_hard_backhand" : "mp_ping_pong_player_hard_forehand"
        }
        let image = texture(name), imageSize = image.size()
        let unit = sizeAt(p)
        let factor = min(unit * 0.62 / max(1, Double(imageSize.width)), unit * 0.55 / max(1, Double(imageSize.height)))
        let faceX = engine.control == .beginner ? 0.50 : (back ? 0.28 : 0.76)
        paddleNode.isHidden = false
        paddleNode.texture = image
        paddleNode.size = CGSize(width: Double(imageSize.width) * factor, height: Double(imageSize.height) * factor)
        paddleNode.anchorPoint = CGPoint(x: faceX, y: 0.72)
        paddleNode.position = sk(unpanned(p, contact ? stroke.height : 0))
        // Android rotates clockwise by (tilt + swing angle) degrees unless animations are off; SpriteKit's zRotation is
        // counter-clockwise.
        let degrees = UIAccessibility.isReduceMotionEnabled ? 0 : engine.paddleTilt + stroke.angle
        paddleNode.zRotation = CGFloat(-degrees * Double.pi / 180)
    }
    private func seatColor(_ seat: Int, _ shift: Double, alpha: Double) -> UIColor {
        let c = CrossScene.seatColors[seat % CrossScene.seatColors.count]
        return UIColor(red: CGFloat((c.0 / 2 + shift) / 255), green: CGFloat((c.1 / 2 + shift) / 255), blue: CGFloat((c.2 / 2 + shift + 10) / 255), alpha: CGFloat(alpha / 255))
    }
    /// Name and score next to every player, with a server marker and floating +1/−1 notes. The other players' badges sit
    /// above their heads (Android CrossCourt.drawTags, 1908719).
    private func renderTags() {
        let now = CACurrentMediaTime()
        let ref = engine.referee
        let w = Double(size.width)
        for s in g.seats {
            guard let tag = tags[s] else { continue }
            var at: CGPoint
            if s == viewSeat {
                at = screen(g.fromLocal(s, 0, CrossGeometry.reach + 0.30))
                at.y = min(at.y, CGFloat(height - 16))
            } else {
                // Use the sprite's actual stand-line projection: a separate world-height
                // projection can put the badge over the opponent's face on tall screens.
                let lateral = g.toLocal(s, engine.racket(s)).u.mpClamp(-0.75, 0.75)
                let anchor = screen(g.fromLocal(s, lateral, CrossGeometry.reach + CrossScene.stand))
                at = CGPoint(x: anchor.x, y: anchor.y - CGFloat(CrossScene.character * sizeAt(g.home(s)) * 0.84) - 8)
            }
            let serving = ref.server == s && ref.phase == .awaitingServe
            let label = (serving ? "🏓 " : "") + (s < names.count ? names[s] : "") + "  " + String(ref.score(s))
            tag.label.text = label
            tag.label.fontSize = 13.5
            let boxWidth = Double(tag.label.frame.width) + 16
            let x = Double(at.x).mpClamp(boxWidth / 2 + 2, max(boxWidth / 2 + 2, w - boxWidth / 2 - 2))
            let y = Double(at.y).mpClamp(CrossScene.scoreboard + 16, max(CrossScene.scoreboard + 16, height - 4))
            let box = CGRect(x: x - boxWidth / 2, y: height - (y + 6), width: boxWidth, height: 21)
            tag.box.path = CrossScene.rounded(box, 10)
            tag.box.fillColor = seatColor(s, 20, alpha: 215)
            let highlight = (tutorialTarget ?? engine.predictedReceiver) == s
            tag.outline.isHidden = !highlight
            tag.outline.path = tag.box.path
            tag.label.position = CGPoint(x: x, y: height - y)
            // Beginner/Standard: who a return would go to now, following the latest sideways swipe.
            if engine.aimTarget == s {
                tag.aim.isHidden = false
                tag.aim.position = CGPoint(x: x, y: height - (y - 20))
                tag.aim.alpha = CGFloat((170 + 85 * sin(now * 1000 / 160)).mpClamp(0, 255) / 255)
            } else { tag.aim.isHidden = true }
            if let note = notes[s] {
                let age = (now - note.at) / 1.6
                if age >= 1 { notes[s] = nil; tag.note.isHidden = true }
                else {
                    tag.note.isHidden = false
                    tag.note.text = note.text
                    tag.note.fontColor = note.text.hasPrefix("+") ? UIColor(red: 140 / 255, green: 1, blue: 160 / 255, alpha: 1)
                        : (note.text.hasPrefix("−") ? UIColor(red: 1, green: 140 / 255, blue: 140 / 255, alpha: 1) : .white)
                    tag.note.alpha = CGFloat(1 - age)
                    tag.note.position = CGPoint(x: x, y: height - (y - 22 - age * 26))
                }
            } else { tag.note.isHidden = true }
        }
    }
    /// Every participant's score in one readable row above the table, the server marked.
    private func renderScoreboard() {
        let ref = engine.referee
        let order = g.seats.map { g.wrap(viewSeat + $0) }
        let gap = 6.0, top = 6.0, h = CrossScene.scoreboard - 12
        let w = (Double(size.width) - gap * Double(order.count + 1)) / Double(max(1, order.count))
        for (i, s) in order.enumerated() {
            guard let board = boards[s] else { continue }
            let x = gap + Double(i) * (w + gap)
            let rect = CGRect(x: x, y: height - (top + h), width: max(1, w), height: h)
            board.box.path = CrossScene.rounded(rect, 14)
            board.box.fillColor = seatColor(s, 15, alpha: 225)
            board.outline.isHidden = !(ref.winner == s || (tutorialTarget ?? engine.predictedReceiver) == s)
            board.outline.path = board.box.path
            let name = s < names.count ? names[s] : ""
            let shown = name.count > 10 ? String(name.prefix(9)) + "…" : name
            board.name.text = (ref.server == s ? "🏓 " : "") + shown
            board.name.fontSize = 13
            board.name.position = CGPoint(x: x + w / 2, y: height - (top + h * 0.36))
            board.score.text = String(ref.score(s))
            board.score.fontSize = 26
            board.score.position = CGPoint(x: x + w / 2, y: height - (top + h * 0.86))
        }
    }
    /// A rounded rectangle whose corner radius always fits (CGPath requires it).
    private static func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
        guard rect.width > 0, rect.height > 0 else { return CGMutablePath() }
        let r = min(radius, rect.width / 2 - 0.01, rect.height / 2 - 0.01)
        guard r > 0 else { return CGPath(rect: rect, transform: nil) }
        return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
    }
    /// Show the score change of a resolved rally next to every affected player.
    func showOutcome(_ outcome: CrossRallyOutcome) {
        let now = CACurrentMediaTime()
        for s in g.seats {
            let d = s < outcome.deltas.count ? outcome.deltas[s] : 0
            if d > 0 { notes[s] = ("+\(d)", now) }
            else if d < 0 { notes[s] = ("−\(-d)", now) }
            else if outcome.faultOwner == s || (outcome.kind == .missed && outcome.receiver == s) { notes[s] = ("0", now) }
        }
    }

    // ---- input --------------------------------------------------------------------------------------
    private func viewPoint(_ touch: UITouch) -> CGPoint {
        let p = touch.location(in: self)
        return CGPoint(x: p.x, y: size.height - p.y)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard acceptsInput, activeTouch == nil, let touch = touches.first else { return }
        activeTouch = touch
        let p = viewPoint(touch)
        downPoint = p
        samples = [(touch.timestamp, p)]
        send(p, down: true)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard acceptsInput, let touch = activeTouch, touches.contains(touch) else { return }
        for sample in event?.coalescedTouches(for: touch) ?? [touch] {
            let p = viewPoint(sample)
            samples.append((sample.timestamp, p))
            send(p, down: false)
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        if acceptsInput {
            let p = viewPoint(touch)
            samples.append((touch.timestamp, p))
            send(p, down: false)
            engine.endTouch(cancelled: false)
        }
        activeTouch = nil; samples = []
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { cancelTouch() }
    func cancelTouch() {
        if activeTouch != nil { engine.release() }
        activeTouch = nil; samples = []
    }
    /// Android VelocityTracker: the finger's speed over the last few samples, in points per second.
    private func fingerVelocity() -> CGVector {
        guard let last = samples.last else { return .zero }
        samples = samples.filter { last.time - $0.time <= 0.08 }
        guard let first = samples.first, last.time - first.time > 0.004 else { return .zero }
        let dt = CGFloat(last.time - first.time)
        return CGVector(dx: (last.point.x - first.point.x) / dt, dy: (last.point.y - first.point.y) / dt)
    }
    private func send(_ p: CGPoint, down: Bool) {
        let point = world(Double(p.x), Double(p.y))
        let here = g.toView(viewSeat, point)
        let unit = max(1, scale * k(here.y))
        let finger = fingerVelocity()
        let velocity = MPPoint(Double(finger.dx) / unit, Double(finger.dy) / (unit * CrossScene.tilt))
        let drag = MPPoint(Double(p.x - downPoint.x), Double(p.y - downPoint.y))
        engine.touch(point, drag: drag, velocity: velocity, down: down)
    }
}

/// One player's sprites: legs, body, Minik's recovery pose and an emoji, clipped to the space outside the table, plus the
/// striking arm drawn over the table.
private final class CrossActorNodes {
    let crop = SKCropNode(), mask = SKShapeNode()
    let legs = SKSpriteNode(), body = SKSpriteNode(), recovery = SKSpriteNode(), emoji = SKLabelNode()
    let armCrop = SKCropNode(), armMask = SKShapeNode(), arm = SKSpriteNode()
    init(parent: SKNode) {
        mask.fillColor = .white; mask.strokeColor = .clear; mask.lineWidth = 0
        armMask.fillColor = .white; armMask.strokeColor = .clear; armMask.lineWidth = 0
        crop.maskNode = mask
        legs.zPosition = 0; recovery.zPosition = 0.1; body.zPosition = 0.2; emoji.zPosition = 0.3
        emoji.fontColor = .white; emoji.horizontalAlignmentMode = .center; emoji.verticalAlignmentMode = .baseline
        for node in [legs, recovery, body] { crop.addChild(node) }
        crop.addChild(emoji)
        armCrop.maskNode = armMask
        armCrop.addChild(arm)
        parent.addChild(crop); parent.addChild(armCrop)
    }
    func setMask(_ path: CGPath) { mask.path = path }
    func setDepth(_ z: Double) { crop.zPosition = CGFloat(z); armCrop.zPosition = CGFloat(z + 0.05) }
    func hideAll() {
        legs.isHidden = true; body.isHidden = true; recovery.isHidden = true; emoji.isHidden = true; armCrop.isHidden = true
        body.alpha = 1; recovery.alpha = 1
    }
    func showArm(_ texture: SKTexture, mask path: CGPath) { armCrop.isHidden = false; armMask.path = path }
    func remove() { crop.removeFromParent(); armCrop.removeFromParent() }
}

/// A player's name tag: box, highlight outline, label, the 🎯 aim marker and the floating score note.
private final class CrossTagNodes {
    let box = SKShapeNode(), outline = SKShapeNode()
    let label: SKLabelNode, aim: SKLabelNode, note: SKLabelNode
    init(parent: SKNode, font: String) {
        label = SKLabelNode(fontNamed: font); aim = SKLabelNode(text: "🎯"); note = SKLabelNode(fontNamed: font)
        box.strokeColor = .clear; box.zPosition = 0
        outline.fillColor = .clear; outline.strokeColor = UIColor(red: 1, green: 221 / 255, blue: 87 / 255, alpha: 1); outline.lineWidth = 2.2; outline.zPosition = 0.1
        label.fontColor = .white; label.horizontalAlignmentMode = .center; label.verticalAlignmentMode = .baseline; label.zPosition = 0.2
        aim.fontSize = 20; aim.horizontalAlignmentMode = .center; aim.verticalAlignmentMode = .baseline; aim.zPosition = 0.3
        note.fontSize = 22; note.horizontalAlignmentMode = .center; note.verticalAlignmentMode = .baseline; note.zPosition = 0.4
        for node in [box, outline] { parent.addChild(node) }
        for node in [label, aim, note] { parent.addChild(node) }
    }
    func remove() { [box, outline].forEach { $0.removeFromParent() }; [label, aim, note].forEach { $0.removeFromParent() } }
}

/// One scoreboard box: background, highlight outline, name and score.
private final class CrossBoardNodes {
    let box = SKShapeNode(), outline = SKShapeNode()
    let name: SKLabelNode, score: SKLabelNode
    init(parent: SKNode, font: String) {
        name = SKLabelNode(fontNamed: font); score = SKLabelNode(fontNamed: font)
        box.strokeColor = .clear; box.zPosition = 0
        outline.fillColor = .clear; outline.strokeColor = UIColor(red: 1, green: 221 / 255, blue: 87 / 255, alpha: 1); outline.lineWidth = 2.5; outline.zPosition = 0.1
        for label in [name, score] {
            label.fontColor = .white; label.horizontalAlignmentMode = .center; label.verticalAlignmentMode = .baseline; label.zPosition = 0.2
        }
        for node in [box, outline] { parent.addChild(node) }
        for node in [name, score] { parent.addChild(node) }
    }
    func remove() { [box, outline].forEach { $0.removeFromParent() }; [name, score].forEach { $0.removeFromParent() } }
}
