import UIKit

/// Android ARGB int (0xAARRGGBB) as a UIColor.
func argbColor(_ value: UInt32) -> UIColor {
    let a = CGFloat((value >> 24) & 0xff) / 255
    let r = CGFloat((value >> 16) & 0xff) / 255
    let g = CGFloat((value >> 8) & 0xff) / 255
    let b = CGFloat(value & 0xff) / 255
    return UIColor(red: r, green: g, blue: b, alpha: a)
}

/// `hypot` on CGFloat values, computed in Double.
func distance2D(_ dx: CGFloat, _ dy: CGFloat) -> CGFloat {
    return CGFloat(hypot(Double(dx), Double(dy)))
}

/// Monotonic milliseconds (Android `SystemClock.uptimeMillis()`).
func uptimeMs() -> Int64 {
    return Int64(ProcessInfo.processInfo.systemUptime * 1000)
}

/// Android `postDelayed`: runs on the main thread after `seconds`; cancel the returned item to remove it.
@MainActor func afterDelay(_ seconds: Double, _ action: @escaping @MainActor () -> Void) -> DispatchWorkItem {
    let item = DispatchWorkItem {
        MainActor.assumeIsolated { action() }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    return item
}

@MainActor private final class DisplayLinkProxy: NSObject {
    weak var target: ArenaView?

    @objc func step(_ link: CADisplayLink) {
        target?.frameTick()
    }
}

/// Draws the arena every frame (Android `onDraw`), into a transparent layer above the arena picture.
private final class ArenaCanvas: UIView {
    var renderer: ((CGContext, CGRect) -> Void)?

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        renderer?(ctx, bounds)
    }
}

/// Android `AmuduView`: the projected arena, HUD, actor labels, lighting, the frame loop and the exact touch
/// arbitration (190 ms double tap, held catch, drag to run, swipe toss/throw).
final class ArenaView: UIView {
    let engine: AmuduEngine
    let ownId: String
    let art: ArtStore
    let hebrew: Bool
    var onBack: (@MainActor () -> Void)?
    var onResult: (@MainActor (Outcome) -> Void)?
    var onHuddle: (@MainActor () -> Void)?
    var onChoose: (@MainActor (GameActor) -> Void)?
    var onSay: (@MainActor () -> Void)?
    var onEvent: (@MainActor (GameEvent) -> Void)?
    var sendCommand: (@MainActor (GameCommand) -> Void)?
    var remote = false
    var remoteUpdate: (@MainActor () -> Void)?

    private let backgroundView = UIImageView()
    private let canvas = ArenaCanvas()
    private var link: CADisplayLink?
    private let proxy = DisplayLinkProxy()
    private(set) var running = false
    private var lastMs: Int64 = 0
    private var eventCursor: Int
    private var shownResult = false
    private var shownHuddle = -1
    private var lastSize = CGSize.zero
    private(set) var actorRects: [String: CGRect] = [:]
    private(set) var handPoints: [String: CGPoint] = [:]
    private var activeTouches = Set<UITouch>()
    private var pointer: UITouch?
    private var startX: CGFloat = 0
    private var startY: CGFloat = 0
    private var startAt: Int64 = 0
    private var dragged = false
    private var gesture = ""
    private var heldCatch: DispatchWorkItem?
    private var catchCommitted = false
    private var secondTap = false
    private var pendingTap: DispatchWorkItem?
    private var pendingTapAction: (@MainActor () -> Void)?
    private var tapAt: Int64 = 0
    private var tapX: CGFloat = 0
    private var tapY: CGFloat = 0
    private(set) var backRect = CGRect.zero
    private(set) var shoutRect = CGRect.zero
    private(set) var chatRect = CGRect.zero

    private struct Tag {
        let actor: GameActor
        let text: String
        let base: CGPoint
        let width: CGFloat
    }

    private var tags: [Tag] = []
    private var cachedLayouts: [String: (NSAttributedString, CGFloat)] = [:]

    init(engine: AmuduEngine, ownId: String, art: ArtStore, hebrew: Bool) {
        self.engine = engine
        self.ownId = ownId
        self.art = art
        self.hebrew = hebrew
        eventCursor = engine.events.map { $0.id }.max() ?? 0
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
        semanticContentAttribute = .forceLeftToRight
        backgroundColor = argbColor(0xff10263c)
        backgroundView.image = art.scene(engine.config.scene)
        backgroundView.contentMode = .scaleToFill
        backgroundView.isUserInteractionEnabled = false
        canvas.isOpaque = false
        canvas.backgroundColor = .clear
        canvas.contentMode = .redraw
        canvas.isUserInteractionEnabled = false
        addSubview(backgroundView)
        addSubview(canvas)
        proxy.target = self
        canvas.renderer = { [weak self] ctx, area in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.render(ctx, area)
            }
        }
        isAccessibilityElement = true
        accessibilityLabel = GameText.t("Amudu playing arena")
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.frame = bounds
        canvas.frame = bounds
        if bounds.size != lastSize {
            lastSize = bounds.size
            cancelInput()
            cachedLayouts.removeAll()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Drawn content is redrawn every frame; two pixels per point keeps it sharp without overloading older phones.
        let scale = max(traitCollection.displayScale, 1)
        canvas.contentScaleFactor = min(scale, 2)
    }

    // MARK: Frame loop

    func start() {
        if running { return }
        running = true
        lastMs = 0
        let displayLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.step(_:)))
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        displayLink.add(to: .main, forMode: .common)
        link = displayLink
    }

    func stop() {
        running = false
        link?.invalidate()
        link = nil
        cancelInput()
    }

    func frameTick() {
        if !running { return }
        let now = uptimeMs()
        let ms = lastMs == 0 ? 16 : now - lastMs
        lastMs = now
        if !remote {
            engine.tick(Double(ms) / 1000.0)
        } else {
            remoteUpdate?()
        }
        let fresh = engine.events.filter { $0.id > eventCursor }
        for e in fresh {
            eventCursor = e.id
            onEvent?(e)
        }
        if engine.phase == .huddle && shownHuddle != engine.huddleSerial {
            shownHuddle = engine.huddleSerial
            onHuddle?()
        }
        if let r = engine.result, !shownResult {
            shownResult = true
            onResult?(r)
        }
        canvas.setNeedsDisplay()
    }

    func command(_ cmd: GameCommand) {
        if let send = sendCommand {
            send(cmd)
        } else {
            engine.command(ownId, UUID().uuidString.lowercased(), cmd)
        }
    }

    private func tr(_ en: String, _ he: String) -> String {
        return GameText.t(en, he, hebrew: hebrew)
    }

    // MARK: Projection

    func project(_ v: V, _ z: Double = 0.0) -> CGPoint {
        let w = Double(bounds.width)
        let h = Double(bounds.height)
        let cfg = engine.config
        let perspective = 0.79 + 0.21 * (v.y / cfg.depth)
        let x = w / 2 + (v.x - cfg.width / 2) / cfg.width * w * 0.92 * perspective
        let y = h * 0.30 + v.y / cfg.depth * h * 0.54 - z * h * 0.038
        return CGPoint(x: x, y: y)
    }

    private func inverseVector(_ dx: CGFloat, _ dy: CGFloat) -> V {
        let w = Double(bounds.width)
        let h = Double(bounds.height)
        return V(Double(dx) / (w * 0.92) * engine.config.width, Double(dy) / (h * 0.54) * engine.config.depth).unit()
    }

    // MARK: Drawing helpers

    private func font(_ size: CGFloat) -> UIFont {
        return UIFont.boldSystemFont(ofSize: size)
    }

    private func measure(_ s: String, _ size: CGFloat) -> CGFloat {
        return (s as NSString).size(withAttributes: [.font: font(size)]).width
    }

    /// Android `drawText` at a baseline, centered or right-aligned.
    private func text(_ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ color: UInt32 = 0xffffffff, right: Bool = false) {
        let f = font(size)
        let attributes: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: argbColor(color)]
        let string = s as NSString
        let width = string.size(withAttributes: attributes).width
        let originX = right ? x - width : x - width / 2
        string.draw(at: CGPoint(x: originX, y: y - f.ascender), withAttributes: attributes)
    }

    /// Android `StaticLayout` centered horizontally and vertically in `rect`.
    private func paragraph(_ s: String, _ rect: CGRect, _ size: CGFloat, _ color: UInt32 = 0xffffffff) {
        let w = max(rect.width, 1)
        let key = s + "/" + String(Int(w)) + "/" + String(Double(size)) + "/" + String(color)
        let entry: (NSAttributedString, CGFloat)
        if let cached = cachedLayouts[key] {
            entry = cached
        } else {
            if cachedLayouts.count > 90 { cachedLayouts.removeAll() }
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            style.baseWritingDirection = .natural
            style.lineBreakMode = .byWordWrapping
            let attributed = NSAttributedString(string: s, attributes: [.font: font(size), .foregroundColor: argbColor(color), .paragraphStyle: style])
            let bounding = attributed.boundingRect(with: CGSize(width: w, height: CGFloat.greatestFiniteMagnitude),
                                                   options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            entry = (attributed, ceil(bounding.height))
            cachedLayouts[key] = entry
        }
        let target = CGRect(x: rect.minX, y: rect.minY + (rect.height - entry.1) / 2, width: w, height: entry.1)
        entry.0.draw(with: target, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }

    private func panel(_ ctx: CGContext, _ r: CGRect, _ color: UInt32 = 0xe6173049) {
        ctx.setFillColor(argbColor(color).cgColor)
        ctx.addPath(UIBezierPath(roundedRect: r, cornerRadius: 18).cgPath)
        ctx.fillPath()
    }

    private func line(_ ctx: CGContext, _ a: CGPoint, _ b: CGPoint, _ color: UInt32, _ width: CGFloat) {
        ctx.setStrokeColor(argbColor(color).cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.move(to: a)
        ctx.addLine(to: b)
        ctx.strokePath()
    }

    private func radialGradient(_ colors: [UInt32], _ locations: [CGFloat]) -> CGGradient? {
        let cgColors = colors.map { argbColor($0).cgColor } as CFArray
        return CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: locations)
    }

    private func fillRadial(_ ctx: CGContext, _ center: CGPoint, _ radius: CGFloat, _ colors: [UInt32], _ locations: [CGFloat]) {
        guard radius > 0, let gradient = radialGradient(colors, locations) else { return }
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }

    /// Android: `RectF.intersects` (strict overlap).
    private func overlaps(_ a: CGRect, _ b: CGRect) -> Bool {
        return a.minX < b.maxX && b.minX < a.maxX && a.minY < b.maxY && b.minY < a.maxY
    }

    // MARK: Frame

    private func render(_ ctx: CGContext, _ rect: CGRect) {
        let width = rect.width
        let height = rect.height
        if width <= 1 || height <= 1 { return }
        let cfg = engine.config
        // Painted field outline and a circle are grounded in the same projection as actors.
        let corners = [V(0.5, 0.5), V(cfg.width - 0.5, 0.5), V(cfg.width - 0.5, cfg.depth - 0.5), V(0.5, cfg.depth - 0.5)].map { project($0) }
        ctx.setLineCap(.butt)
        ctx.setStrokeColor(argbColor(0x60ffffff).cgColor)
        ctx.setLineWidth(1.5)
        ctx.move(to: corners[0])
        for p in corners.dropFirst() { ctx.addLine(to: p) }
        ctx.closePath()
        ctx.strokePath()
        if engine.phase == .circle && engine.circleFormation {
            for i in 0...64 {
                let a = Double(i) * 2 * Double.pi / 64
                let pt = project(V(cfg.width / 2 + cos(a) * 4.5, cfg.depth / 2 + sin(a) * 4.5))
                if i == 0 { ctx.move(to: pt) } else { ctx.addLine(to: pt) }
            }
            ctx.setStrokeColor(argbColor(0x99ffffff).cgColor)
            ctx.setLineWidth(2)
            ctx.strokePath()
        }
        if engine.phase == .air {
            let p = project(engine.landing)
            ctx.setStrokeColor(argbColor(0x66fff06a).cgColor)
            ctx.setLineWidth(3)
            ctx.strokeEllipse(in: CGRect(x: p.x - 23, y: p.y - 10, width: 46, height: 20))
        }
        actorRects.removeAll()
        handPoints.removeAll()
        tags.removeAll()
        let loose = engine.ball.holder == nil
        if loose { drawBallShadow(ctx, width) }
        var ballDrawn = false
        let ordered = Kotlin.stableSorted(engine.actors) { $0.position.y < $1.position.y }
        for a in ordered {
            if loose && !ballDrawn && engine.ball.position.y < a.position.y {
                drawFlyingBall(ctx, width)
                ballDrawn = true
            }
            drawActor(ctx, a, width)
        }
        if loose && !ballDrawn { drawFlyingBall(ctx, width) }
        drawLighting(ctx, width, height)
        drawTags(ctx, width, height)
        drawAim(ctx)
        drawHud(ctx, width, height)
    }

    private func drawAim(_ ctx: CGContext) {
        guard engine.canAim(ownId), let mine = engine.actor(ownId) else { return }
        let origin = handPoints[ownId] ?? project(mine.position, 1.2)
        let end = project(mine.position + mine.direction * 4.5, 1.1)
        ctx.setStrokeColor(argbColor(0xffffe466).cgColor)
        ctx.setLineWidth(3)
        ctx.setLineCap(.round)
        ctx.setLineDash(phase: 0, lengths: [8, 6])
        ctx.move(to: origin)
        ctx.addLine(to: end)
        ctx.strokePath()
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.strokeEllipse(in: CGRect(x: end.x - 12, y: end.y - 12, width: 24, height: 24))
    }

    private func drawHud(_ ctx: CGContext, _ width: CGFloat, _ height: CGFloat) {
        let mine = engine.actor(ownId)
        let top = CGRect(x: 12, y: 9, width: width - 24, height: 53)
        panel(ctx, top)
        backRect = CGRect(x: top.minX, y: top.minY, width: 52, height: top.height)
        let cx = backRect.midX
        let cy = backRect.midY
        line(ctx, CGPoint(x: cx + 5, y: cy - 9), CGPoint(x: cx - 5, y: cy), 0xff7effe2, 4)
        line(ctx, CGPoint(x: cx - 5, y: cy), CGPoint(x: cx + 5, y: cy + 9), 0xff7effe2, 4)
        let turnText: String
        if engine.config.turns == 0 {
            turnText = tr("Turn \(engine.turn) · ∞", "תור \u{2066}\(engine.turn) · ∞\u{2069}")
        } else {
            turnText = tr("Turn \(engine.turn) / \(engine.config.turns)", "תור \u{2066}\(engine.turn) / \(engine.config.turns)\u{2069}")
        }
        text(turnText, width / 2, top.midY + 6, 17)
        text("● \(mine?.penalties ?? 0)", top.maxX - 15, top.midY + 6, 17, 0xffffc6cb, right: true)
        let instructionBox = CGRect(x: 14, y: 72, width: width - 28, height: max(height * 0.215 - 72, 1))
        panel(ctx, instructionBox, 0xd9163049)
        paragraph(instruction(), instructionBox, 16)
        if engine.phase == .shout && engine.called == ownId {
            shoutRect = CGRect(x: width * 0.2, y: height * 0.86, width: width * 0.6, height: height * 0.08)
            panel(ctx, shoutRect, 0xffffe05e)
            text(tr("SPUD!", "עמודו!"), shoutRect.midX, shoutRect.midY + 9, 26, 0xff173047)
        } else {
            shoutRect = .zero
            let status = engine.time < engine.infoUntil ? feedbackText() : tr("Drag to run · Tap / hold to catch · 0.7 sec\nDouble-tap to duck", "גררו כדי לרוץ · נגיעה או לחיצה לתפיסה · 0.7 שניות\nנגיעה כפולה להתכופפות")
            let r = CGRect(x: 12, y: height * 0.865, width: width - 24, height: height * 0.946 - height * 0.865)
            panel(ctx, r)
            paragraph(status, r, 14)
        }
        chatRect = CGRect(x: width - 57, y: height - 39, width: 45, height: 36)
        panel(ctx, chatRect, 0xc5173049)
        text("•••", chatRect.midX, chatRect.midY + 4, 19)
    }

    private func drawLighting(_ ctx: CGContext, _ width: CGFloat, _ height: CGFloat) {
        let daylight = engine.config.daylight
        let area = CGRect(x: 0, y: 0, width: width, height: height)
        switch daylight {
        case .noon:
            return
        case .morning:
            ctx.setFillColor(argbColor(0x3d7c6238).cgColor)
            ctx.fill(area)
            return
        case .evening:
            ctx.setFillColor(argbColor(0x8f202542).cgColor)
            ctx.fill(area)
            return
        case .night:
            break
        }
        let cfg = engine.config
        let lamps = [project(V(0.7, 2.2)), project(V(cfg.width - 0.7, 6.5)), project(V(1.2, cfg.depth - 1.0))]
        var spots: [CGPoint] = []
        for i in 0...2 {
            let x = cfg.width * (0.5 + 0.36 * sin(engine.time * 0.32 + Double(i) * 2.1))
            let y = cfg.depth * (0.52 + 0.36 * cos(engine.time * 0.24 + Double(i) * 2.0))
            spots.append(project(V(x, y)))
        }
        ctx.saveGState()
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setFillColor(argbColor(0xd10a1329).cgColor)
        ctx.fill(area)
        ctx.setBlendMode(.destinationOut)
        for (i, p) in (lamps + spots).enumerated() {
            let radius = width * (i < 3 ? 0.26 : 0.21)
            fillRadial(ctx, p, radius, [0xddffffff, 0x88ffffff, 0x00ffffff], [0, 0.42, 1])
        }
        ctx.setBlendMode(.normal)
        ctx.endTransparencyLayer()
        ctx.restoreGState()
        for p in lamps {
            line(ctx, p, CGPoint(x: p.x, y: p.y - 60), 0xff667782, 4)
            ctx.setFillColor(argbColor(0xffffe7a0).cgColor)
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: p.x - 6, y: p.y - 68, width: 12, height: 13), cornerRadius: 3).cgPath)
            ctx.fillPath()
            fillRadial(ctx, CGPoint(x: p.x, y: p.y - 61), 30, [0x99ffe493, 0x00000000], [0, 1])
        }
        let colors: [UInt32] = [0x7756dfff, 0x77f556cd, 0x77bfef69]
        for (i, p) in spots.enumerated() {
            let oval = CGRect(x: p.x - width * 0.20, y: p.y - height * 0.085, width: width * 0.40, height: height * 0.17)
            ctx.saveGState()
            ctx.addEllipse(in: oval)
            ctx.clip()
            fillRadial(ctx, p, width * 0.20, [colors[i], 0x00000000], [0, 1])
            ctx.restoreGState()
            let source = lamps[i]
            ctx.setFillColor(argbColor((colors[i] & 0x00ffffff) | 0x18000000).cgColor)
            ctx.move(to: CGPoint(x: source.x, y: source.y - 60))
            ctx.addLine(to: CGPoint(x: p.x - width * 0.14, y: p.y))
            ctx.addLine(to: CGPoint(x: p.x + width * 0.14, y: p.y))
            ctx.closePath()
            ctx.fillPath()
        }
    }

    private func visibleName(_ a: GameActor?) -> String {
        guard let a else { return "" }
        if a.member.id == ownId { return tr("You", "אתם") }
        if !a.suffixes.isEmpty { return "???" }
        return a.member.displayName(hebrew: hebrew)
    }

    /// Android `instruction()`.
    func instruction() -> String {
        let owner = engine.actor(engine.thrower)
        let target = engine.actor(engine.called)
        switch engine.phase {
        case .circle:
            if engine.thrower == ownId {
                if Kotlin.isBlank(engine.selected) {
                    return tr("Choose a player.\nThen swipe your ball upward!", "בחרו שחקן.\nואז החליקו את הכדור שלכם כלפי מעלה!")
                }
                return tr("Swipe up from your ball.\nFaster swipe → higher throw!", "החליקו מעלה מהכדור שלכם.\nהחלקה מהירה → זריקה גבוהה!")
            }
            let name = visibleName(owner)
            return tr("\(name) is choosing who to call.", "הגיע התור של \(name) לבחור למי לקרוא.")
        case .air:
            if engine.called == ownId {
                return tr("Your ball! Run to the landing ring.\nTap or hold briefly as it comes down.", "הכדור שלכם! רוצו לטבעת הנחיתה.\nגעו או לחצו קצרות כשהכדור יורד.")
            }
            let name = visibleName(target)
            return tr("Run! \(name) is trying to catch.", "רוצו! עכשיו התור של \(name) לתפוס.")
        case .retrieve:
            if engine.called == ownId { return tr("Pick up the ball: get close and tap.", "אספו את הכדור: התקרבו וגעו.") }
            return tr("Keep running until SPUD!", "המשיכו לרוץ עד עמודו!")
        case .shout:
            if engine.called == ownId {
                return tr("Your feet stay here. Aim and swipe to throw, or tap SPUD to stop the runners.", "הרגליים נשארות כאן. כוונו והחליקו כדי לזרוק, או לחצו עמודו לעצירת הרצים.")
            }
            return tr("Keep running, or stop and prepare to catch.", "המשיכו לרוץ, או עצרו והתכוננו לתפוס.")
        case .aim:
            if engine.thrower == ownId { return tr("Aim by tapping a player.\nFlick from your ball to throw.", "כוונו בנגיעה בשחקן.\nהחליקו מהכדור כדי לזרוק.") }
            return tr("SPUD! Stay still.\nTap to catch · Double-tap to duck", "עמודו! עמדו במקום.\nנגיעה לתפיסה · נגיעה כפולה להתכופפות")
        case .flight:
            return tr("Catch it or duck!", "תפסו או התכופפו!")
        case .resolve:
            return feedbackText()
        case .huddle:
            if engine.huddleTarget == ownId { return tr("Take a break.\nThe next round is on its way.", "זמן להפסקה קצרה.\nעוד מעט ממשיכים.") }
            return tr("Choose one funny word privately.", "בוחרים בסוד מילה מצחיקה אחת.")
        case .finished:
            return tr("What a game!", "איזה משחק!")
        }
    }

    private func drawActor(_ ctx: CGContext, _ a: GameActor, _ width: CGFloat) {
        let p = project(a.position)
        let perspective = 0.80 + 0.20 * a.position.y / engine.config.depth
        let w = CGFloat(Double(width) * (engine.actors.count >= 9 ? 0.157 : 0.200) * perspective)
        let h = w * 1.25
        let visual = art.visual(a, engine)
        let f = visual.frame
        let rect = CGRect(x: p.x - w / 2, y: p.y - h * 0.95, width: w, height: h)
        ctx.setFillColor(argbColor(0x40091326).cgColor)
        ctx.fillEllipse(in: CGRect(x: p.x - w * 0.3, y: p.y - h * 0.05, width: w * 0.6, height: h * 0.095))
        let id = a.member.id
        if id == ownId || id == engine.selected || id == engine.called {
            ctx.setStrokeColor(argbColor(id == ownId ? 0xff00e5ff : 0xffffea00).cgColor)
            ctx.setLineWidth(2.5)
            ctx.strokeEllipse(in: CGRect(x: p.x - w * 0.4, y: p.y - h * 0.03, width: w * 0.8, height: h * 0.075))
        }
        let handX = rect.minX + w * (visual.mirrored ? 1 - f.handX : f.handX)
        let hand = CGPoint(x: handX, y: rect.minY + h * f.handY)
        handPoints[id] = hand
        actorRects[id] = rect
        let holding = engine.ball.holder == id
        if holding && visual.facing == "back" { drawHeldBall(hand, w) }
        if visual.mirrored {
            ctx.saveGState()
            ctx.translateBy(x: p.x, y: 0)
            ctx.scaleBy(x: -1, y: 1)
            ctx.translateBy(x: -p.x, y: 0)
            visual.image.draw(in: rect)
            ctx.restoreGState()
        } else {
            visual.image.draw(in: rect)
        }
        if holding && visual.facing != "back" { drawHeldBall(hand, w) }
        let label = visibleName(a)
        let maxLength = engine.actors.count >= 9 ? 10 : 14
        var shown = label
        if label.utf16.count > maxLength {
            shown = String(decoding: Array(label.utf16.prefix(maxLength - 1)), as: UTF16.self) + "…"
        }
        tags.append(Tag(actor: a, text: shown + " · " + String(a.penalties), base: p, width: w * 1.24))
        if engine.time < a.catchUntil {
            let sweep = CGFloat(2 * Double.pi * (a.catchUntil - engine.time) / engine.config.catchWindow)
            let arc = UIBezierPath(arcCenter: hand, radius: w * 0.25, startAngle: -CGFloat.pi / 2, endAngle: -CGFloat.pi / 2 + sweep, clockwise: true)
            ctx.setStrokeColor(argbColor(0xb2ffe96a).cgColor)
            ctx.setLineWidth(2)
            ctx.addPath(arc.cgPath)
            ctx.strokePath()
        }
    }

    private func drawHeldBall(_ hand: CGPoint, _ w: CGFloat) {
        let b = w * 0.342 * CGFloat(engine.config.ball.visualScale)
        art.ball(engine.config.ball).draw(in: CGRect(x: hand.x - b / 2, y: hand.y - b / 2, width: b, height: b))
    }

    private func drawTags(_ ctx: CGContext, _ width: CGFloat, _ height: CGFloat) {
        var used: [CGRect] = []
        let bodies = actorRects.values.map { $0.insetBy(dx: -2, dy: -2) }
        let ordered = Kotlin.stableSorted(tags) { (l: Tag, r: Tag) -> Bool in
            let lo = l.actor.member.id == ownId ? 0 : 1
            let ro = r.actor.member.id == ownId ? 0 : 1
            return lo < ro
        }
        let baseSize: CGFloat = engine.actors.count >= 9 ? 10 : 11
        for tag in ordered {
            let measured = measure(tag.text, baseSize) + 12
            let tagWidth = min(max(measured, 45), max(tag.width, 45))
            let footY = tag.base.y + 3
            let labelHeight: CGFloat = 20
            var best = CGFloat.greatestFiniteMagnitude
            var chosen = CGRect.zero
            // Search around the feet, protecting every character's body as well as other labels.
            func consider(_ cx: CGFloat, _ y: CGFloat) {
                let left = min(max(cx - tagWidth / 2, 3), max(width - tagWidth - 3, 3))
                let top = min(max(y, height * 0.265), max(height * 0.845 - labelHeight, height * 0.265))
                let candidate = CGRect(x: left, y: top, width: tagWidth, height: labelHeight)
                let dx = candidate.midX - tag.base.x
                let dy = top - footY
                var cost = dx * dx + dy * dy
                for body in bodies where overlaps(body, candidate) {
                    let ow = min(body.maxX, candidate.maxX) - max(body.minX, candidate.minX)
                    let oh = min(body.maxY, candidate.maxY) - max(body.minY, candidate.minY)
                    cost += width * height + ow * oh * 100
                }
                for other in used where overlaps(other, candidate) { cost += width * height * 3 }
                if cost < best {
                    best = cost
                    chosen = candidate
                }
            }
            consider(tag.base.x, footY)
            if best > 1 {
                for ring in 1...7 {
                    let radius = CGFloat(22 * ring)
                    for i in 0..<16 {
                        let angle = Double(i) * Double.pi / 8
                        consider(tag.base.x + CGFloat(cos(angle)) * radius, footY + CGFloat(sin(angle)) * radius)
                    }
                    if best < radius * radius { break }
                }
            }
            if distance2D(chosen.midX - tag.base.x, chosen.minY - footY) > 6 {
                line(ctx, CGPoint(x: tag.base.x, y: footY), CGPoint(x: chosen.midX, y: chosen.midY), 0x99122e43, 1)
            }
            used.append(chosen)
            panel(ctx, chosen, 0xe3153043)
            let fitted = baseSize * min(1, (chosen.width - 9) / max(measure(tag.text, baseSize), 1))
            text(tag.text, chosen.midX, chosen.midY + 4, fitted)
        }
    }

    private func drawBallShadow(_ ctx: CGContext, _ width: CGFloat) {
        let ground = project(engine.ball.position)
        let size = width * 0.067 * CGFloat(engine.config.ball.visualScale)
        ctx.setFillColor(argbColor(0x450a1830).cgColor)
        ctx.fillEllipse(in: CGRect(x: ground.x - size * 0.6, y: ground.y - size * 0.15, width: size * 1.2, height: size * 0.3))
    }

    private func drawFlyingBall(_ ctx: CGContext, _ width: CGFloat) {
        let b = engine.ball
        let p = project(b.position, b.height)
        let size = width * 0.067 * CGFloat(engine.config.ball.visualScale)
        // No altitude clamp: a powerful lob can leave the viewport and return naturally.
        if engine.ballWithinReach(ownId) {
            let r = size * 0.72
            fillRadial(ctx, p, r * 1.45, [0xb200e5ff, 0x00000000], [0, 1])
            ctx.setStrokeColor(argbColor(0xffbafff4).cgColor)
            ctx.setLineWidth(2.5)
            ctx.strokeEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        }
        art.ball(engine.config.ball).draw(in: CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size))
    }

    /// Android `feedbackText()`: names the actor; "You" only for the local player; nicknames stay hidden.
    func feedbackText() -> String {
        let actor = engine.actor(engine.infoActor)
        var name = tr("That player", "השחקן הזה")
        if let actor, actor.suffixes.isEmpty { name = actor.member.displayName(hebrew: hebrew) }
        let you = engine.infoActor == ownId
        switch engine.infoCode {
        case "air_catch":
            return you ? tr("You caught the ball! Your turn to call.", "תפסתם את הכדור! תורכם לקרוא.")
                : tr("\(name) caught the ball! Their turn to call.", "תפיסה של \(name)! עכשיו התור של \(name) לקרוא.")
        case "tag_catch":
            return you ? tr("You caught the ball! The thrower gets a penalty.", "תפסתם את הכדור! נקודת חובה לזורק.")
                : tr("\(name) caught the ball! The thrower gets a penalty.", "הכדור נתפס על ידי \(name)! נקודת חובה לזורק.")
        case "tagged":
            return you ? tr("The ball hit you. One penalty.", "הכדור פגע בכם. נקודת חובה אחת.")
                : tr("The ball hit \(name). One penalty.", "הכדור פגע ב\(name). נקודת חובה אחת.")
        case "air_hit":
            return you ? tr("The ball touched you. Get close and tap to pick it up.", "הכדור נגע בכם. התקרבו וגעו כדי לאסוף אותו.")
                : tr("The ball touched \(name). They need to pick it up.", "הכדור נגע ב\(name). עכשיו על \(name) לאסוף אותו.")
        case "pickup":
            return you ? tr("Get close and tap to pick up the ball.", "התקרבו וגעו כדי לאסוף את הכדור.")
                : tr("\(name) needs to pick up the ball.", "על \(name) לאסוף את הכדור.")
        case "miss":
            return you ? tr("Your throw missed. One penalty.", "הזריקה שלכם החטיאה. נקודת חובה אחת.")
                : tr("\(name) missed. One penalty.", "הזריקה של \(name) החטיאה. נקודת חובה אחת.")
        case "wrong_nickname":
            return you ? tr("Incorrect nickname: one penalty.", "כינוי שגוי: נקודת חובה אחת.")
                : tr("\(name) used the wrong nickname. One penalty.", "כינוי שגוי מצד \(name). נקודת חובה אחת.")
        default:
            return tr(engine.infoEn, engine.infoHe)
        }
    }

    // MARK: Touch (Android onTouchEvent)

    private func hitActor(_ x: CGFloat, _ y: CGFloat) -> String? {
        var best: String?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (id, rect) in actorRects where rect.contains(CGPoint(x: x, y: y)) {
            let d = distance2D(rect.midX - x, rect.midY - y)
            if d < bestDistance {
                bestDistance = d
                best = id
            }
        }
        return best
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let wasEmpty = activeTouches.isEmpty
        activeTouches.formUnion(touches)
        guard wasEmpty, let touch = touches.first else { return }
        actionDown(touch, touch.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let primary = pointer, touches.contains(primary) else { return }
        actionMove(primary.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            activeTouches.remove(touch)
            let primary = pointer === touch
            if activeTouches.isEmpty {
                actionUp(touch.location(in: self))
            } else if primary {
                // ACTION_POINTER_UP of the primary pointer.
                cancelInput()
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        cancelInput()
    }

    private func actionDown(_ touch: UITouch, _ point: CGPoint) {
        let x = point.x
        let y = point.y
        if backRect.contains(point) {
            onBack?()
            return
        }
        if chatRect.contains(point) {
            onSay?()
            return
        }
        if shoutRect.contains(point) {
            command(.shout)
            return
        }
        pointer = touch
        startX = x
        startY = y
        startAt = uptimeMs()
        dragged = false
        catchCommitted = false
        secondTap = pendingTap != nil && startAt - tapAt <= Int64(engine.config.doubleTapMs) && distance2D(x - tapX, y - tapY) < 42
        if secondTap {
            pendingTap?.cancel()
            pendingTap = nil
            pendingTapAction = nil
        }
        var onBall = false
        if let hand = handPoints[ownId] { onBall = distance2D(x - hand.x, y - hand.y) < 45 }
        if engine.thrower == ownId && engine.phase == .circle && onBall {
            gesture = "toss"
        } else if engine.canAim(ownId) && onBall {
            gesture = "throw"
        } else {
            gesture = "move"
        }
        let catchPhase = (engine.phase == .air && engine.called == ownId) || (engine.phase == .flight && engine.thrower != ownId)
        if !secondTap && catchPhase {
            heldCatch = afterDelay(Double(engine.config.doubleTapMs) / 1000.0) { [weak self] in
                guard let self else { return }
                self.heldCatch = nil
                if self.pointer != nil && !self.dragged {
                    self.command(.catchBall)
                    self.catchCommitted = true
                }
            }
        }
    }

    private func actionMove(_ point: CGPoint) {
        let dx = point.x - startX
        let dy = point.y - startY
        let distance = distance2D(dx, dy)
        if distance > 10 {
            dragged = true
            heldCatch?.cancel()
            heldCatch = nil
            pendingTap?.cancel()
            pendingTap = nil
            pendingTapAction = nil
        }
        if dragged {
            switch gesture {
            case "move":
                command(.move(inverseVector(dx, dy) * min(1.0, Double(distance / 40))))
            case "throw":
                command(.aim(inverseVector(dx, dy)))
            default:
                break
            }
        }
    }

    private func actionUp(_ point: CGPoint) {
        if pointer == nil { return }
        heldCatch?.cancel()
        heldCatch = nil
        pointer = nil
        let x = point.x
        let y = point.y
        let now = uptimeMs()
        let dx = x - startX
        let dy = y - startY
        if dragged {
            if gesture == "toss" && dy < -18 {
                let speed = Double(-dy) / Double(max(Int64(60), now - startAt)) * 1000
                let drift = Double(dx / max(abs(dy), 30))
                command(.toss(power: Kotlin.clamp((speed - 180) / 1900, 0, 1), drift: Kotlin.clamp(drift, -1, 1)))
            }
            if gesture == "throw" {
                let speed = Double(distance2D(dx, dy)) / Double(max(Int64(45), now - startAt)) * 1000
                command(.throwBall(power: Kotlin.clamp((speed - 100) / 1700, 0, 1)))
            }
            command(.move(V.zero))
            return
        }
        if secondTap {
            secondTap = false
            command(.duck)
            return
        }
        if catchCommitted { return }
        if let previous = pendingTapAction {
            pendingTap?.cancel()
            pendingTap = nil
            pendingTapAction = nil
            previous()
        }
        tapAt = now
        tapX = x
        tapY = y
        let action: @MainActor () -> Void = { [weak self] in
            guard let self else { return }
            self.pendingTap = nil
            self.pendingTapAction = nil
            self.singleTap(x, y)
        }
        pendingTapAction = action
        pendingTap = afterDelay(Double(engine.config.doubleTapMs) / 1000.0) { action() }
    }

    private func singleTap(_ x: CGFloat, _ y: CGFloat) {
        let target = hitActor(x, y)
        if engine.phase == .circle && engine.thrower == ownId {
            if let t = target, t != ownId, let chosen = engine.actor(t) {
                if let choose = onChoose { choose(chosen) } else { command(.select(target: t)) }
            }
            return
        }
        if engine.canAim(ownId) {
            if let t = target, t != ownId, let other = engine.actor(t), let me = engine.actor(ownId) {
                command(.aim((other.position - me.position).unit()))
            }
            return
        }
        command(.catchBall)
    }

    private func cancelInput() {
        heldCatch?.cancel()
        heldCatch = nil
        catchCommitted = false
        secondTap = false
        pendingTap?.cancel()
        pendingTap = nil
        pendingTapAction = nil
        pointer = nil
        if engine.result == nil { command(.move(V.zero)) }
    }
}
