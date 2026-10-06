import UIKit

/// Calls the arena once per display frame without the display link retaining the view.
@MainActor
private final class ArenaFrameTarget: NSObject {
    weak var view: SplashArenaView?

    @objc func tick(_ link: CADisplayLink) {
        guard let view = view else {
            link.invalidate()
            return
        }
        view.frameTick()
    }
}

/// The dynamic layer: everything Android draws after the cached arena bitmap.
private final class ArenaCanvas: UIView {
    weak var owner: SplashArenaView?

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        owner?.render(context)
    }
}

private struct ParagraphLayout {
    let text: NSAttributedString
    let width: CGFloat
    let height: CGFloat
}

/// Port of Android SplashView.kt: the native arena renderer, private answers, particles, hit
/// testing, gestures and the "Learn with Minik" lesson overlay. Android draws with Canvas in
/// pixels scaled by density; iOS draws the same geometry with Core Graphics in points.
@MainActor
final class SplashArenaView: UIView {
    let engine: SplashEngine
    let localId: String
    private let art: ArtStore
    var onExit: () -> Void
    var onFinish: (MatchResult) -> Void
    var onSpeak: (String) -> Void
    var tutorialCompleted: (() -> Void)?
    var onControlSettings: ((PlayerSettings) -> Void)?
    var sendCommand: ((Command) -> Void)?
    var spectatorSnapshot: (() -> Void)?
    var remote = false
    var networkStatus = "" {
        didSet { if networkStatus != oldValue { canvas.setNeedsDisplay() } }
    }
    private(set) var running = true
    private(set) var tutorialStep = -1

    private let local: SplashActor
    private let arenaView = UIImageView()
    private let canvas = ArenaCanvas()
    private var displayLink: CADisplayLink?
    private let frameTarget = ArenaFrameTarget()
    private var gesture: Gestures!
    private var arenaSize = CGSize.zero
    private var layouts: [String: ParagraphLayout] = [:]
    private var layoutOrder: [String] = []
    private var fonts: [Int: UIFont] = [:]
    private var timerSecond = -1
    private var timerText = ""
    private var seq: Int64 = 0
    private var last: Int64 = 0
    private var finished = false
    private var highlighted = -1
    private var actorRects: [(id: String, rect: CGRect)] = []
    private var choiceRects: [Int: CGRect] = [:]
    private var buttons: [String: CGRect] = [:]
    private var buttonOrder: [String] = []
    private var aimPoints: [CGPoint] = []
    private(set) var aimGrip = CGPoint.zero
    private var aimGripRect = CGRect.null
    private(set) var lastTouchSummary = ""
    private var lessonDone = false
    private var lessonStarted = 0.0
    private var lessonPosition = V(0, 0)
    private var lessonAnswers = 0
    private var pointerIds: [ObjectIdentifier: Int] = [:]
    private var touchesById: [Int: UITouch] = [:]

    private let colors = SplashPalette.balloonColors
    private let white = SplashPalette.white
    private let ink = SplashPalette.ink

    init(engine: SplashEngine, localId: String, art: ArtStore, onExit: @escaping () -> Void,
         onFinish: @escaping (MatchResult) -> Void, onSpeak: @escaping (String) -> Void) {
        self.engine = engine
        self.localId = localId
        self.art = art
        self.onExit = onExit
        self.onFinish = onFinish
        self.onSpeak = onSpeak
        self.local = engine.actor(localId) ?? engine.actors[0]
        super.init(frame: .zero)
        let config = engine.config
        gesture = Gestures(window: config.doubleTapMs, slop: config.gestureSlopDp, doubleDistance: config.doubleTapDistanceDp) { [weak self] action in
            self?.touchAction(action)
        }
        backgroundColor = SplashPalette.ui(SplashPalette.sky)
        isMultipleTouchEnabled = true
        isAccessibilityElement = true
        accessibilityLabel = "Minik Splash arena"
        arenaView.contentMode = .scaleToFill
        arenaView.isUserInteractionEnabled = false
        addSubview(arenaView)
        canvas.owner = self
        canvas.isOpaque = false
        canvas.backgroundColor = .clear
        canvas.isUserInteractionEnabled = false
        canvas.contentMode = .redraw
        canvas.layer.drawsAsynchronously = true
        addSubview(canvas)
        frameTarget.view = self
    }

    required init?(coder: NSCoder) {
        return nil
    }

    // MARK: Lifecycle

    func stop() {
        running = false
        last = 0
        gesture.cancel()
        engine.paused = true
        local.move = V(0, 0)
        canvas.setNeedsDisplay()
    }

    func start() {
        running = true
        engine.paused = false
        last = 0
        startLink()
    }

    /// Releases the display link; the view is discarded afterwards.
    func teardown() {
        running = false
        displayLink?.invalidate()
        displayLink = nil
        sendCommand = nil
        spectatorSnapshot = nil
    }

    private func startLink() {
        guard displayLink == nil, window != nil else {
            canvas.setNeedsDisplay()
            return
        }
        let link = CADisplayLink(target: frameTarget, selector: #selector(ArenaFrameTarget.tick(_:)))
        // Core Graphics drawing is budgeted for 60 Hz; the simulation itself is time-based.
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopLink()
        } else if running {
            startLink()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        arenaView.frame = bounds
        canvas.frame = bounds
        if bounds.size != arenaSize {
            // Android onSizeChanged.
            arenaSize = bounds.size
            layouts.removeAll()
            layoutOrder.removeAll()
            gesture.cancel()
            local.move = V(0, 0)
            last = 0
            renderArena()
            canvas.setNeedsDisplay()
        }
    }

    private func command(_ c: Command) {
        if let send = sendCommand {
            send(c)
        } else {
            engine.command(localId, "touch-\(seq)", c)
            seq += 1
        }
    }

    /// One display frame: Android onDraw's simulation half.
    func frameTick() {
        let now = SplashClock.uptimeMillis()
        if running {
            gesture.flush(now)
            if last > 0 && !remote { engine.tick(Double(now - last) / 1000.0) }
            spectatorSnapshot?()
            last = now
        }
        if let result = engine.result, !finished {
            finished = true
            Task { @MainActor [weak self] in self?.onFinish(result) }
        }
        canvas.setNeedsDisplay()
        if !running { stopLink() }
    }

    // MARK: Projection

    private var camera: RenderConfig {
        var c = engine.config.render
        if engine.practice {
            c.floorTop = 0.40
            c.floorDepth = 0.48
            c.characterWidth = 0.205
        } else if !local.settings.court {
            c.floorTop = 0.30
            c.floorDepth = 0.60
            c.horizontalPadding = 2.4
        }
        return c
    }

    private var viewWidth: CGFloat { return bounds.width }
    private var viewHeight: CGFloat { return bounds.height }

    func screen(_ v: V, _ z: Double = 0) -> CGPoint {
        let cam = camera
        let w = Double(viewWidth)
        let h = Double(viewHeight)
        let sx = w / (engine.config.width + cam.horizontalPadding)
        let sy = h * cam.floorDepth / engine.config.depth
        let x = w / 2 + (v.x - engine.config.width / 2) * sx * (cam.backPerspective + cam.depthPerspective * v.y)
        let y = h * cam.floorTop + v.y * sy - z * h * cam.heightScale
        return CGPoint(x: x, y: y)
    }

    private func world(_ x: CGFloat, _ y: CGFloat) -> V {
        let cam = camera
        let w = Double(viewWidth)
        let h = Double(viewHeight)
        let sx = w / (engine.config.width + cam.horizontalPadding)
        let sy = h * cam.floorDepth / engine.config.depth
        let wy = (Double(y) - h * cam.floorTop) / sy
        let wx = (Double(x) - w / 2) / (sx * (cam.backPerspective + cam.depthPerspective * wy)) + engine.config.width / 2
        return V(wx, wy)
    }

    func buttonCenter(_ key: String) -> CGPoint? {
        guard let r = buttons[key] else { return nil }
        return CGPoint(x: r.midX, y: r.midY)
    }

    func actorCenter(_ id: String) -> CGPoint? {
        guard let r = actorRects.first(where: { $0.id == id })?.rect else { return nil }
        return CGPoint(x: r.midX, y: r.midY)
    }

    func balloonCenter(_ index: Int) -> CGPoint? {
        guard let r = choiceRects[index] else { return nil }
        return CGPoint(x: r.midX, y: r.midY)
    }

    // MARK: Drawing helpers

    private func font(_ size: CGFloat, _ bold: Bool) -> UIFont {
        let key = Int(size * 10) * 2 + (bold ? 1 : 0)
        if let cached = fonts[key] { return cached }
        let made = UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
        fonts[key] = made
        return made
    }

    private func tr(_ en: String, _ he: String) -> String {
        return AppText.t(en, he, hebrew: engine.hebrew)
    }

    private func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        return CGRect(x: x, y: y, width: w, height: h)
    }

    /// Android `RectF(left, top, right, bottom)`.
    private func ltrb(_ l: CGFloat, _ t: CGFloat, _ r: CGFloat, _ b: CGFloat) -> CGRect {
        return CGRect(x: l, y: t, width: r - l, height: b - t)
    }

    private func rounded(_ c: CGContext, _ b: CGRect, _ radius: CGFloat, _ color: UInt32) {
        c.setFillColor(SplashPalette.ui(color).cgColor)
        if radius <= 0 {
            c.fill(b)
        } else {
            c.addPath(UIBezierPath(roundedRect: b, cornerRadius: radius).cgPath)
            c.fillPath()
        }
    }

    private func fillOval(_ c: CGContext, _ b: CGRect, _ color: UIColor) {
        c.setFillColor(color.cgColor)
        c.fillEllipse(in: b)
    }

    private func line(_ c: CGContext, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ width: CGFloat, _ color: UInt32) {
        c.setStrokeColor(SplashPalette.ui(color).cgColor)
        c.setLineWidth(width)
        c.move(to: CGPoint(x: x1, y: y1))
        c.addLine(to: CGPoint(x: x2, y: y2))
        c.strokePath()
    }

    /// Android `text()`: single line, vertically centred on y.
    private func text(_ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ color: UInt32, bold: Bool = false, alignLeft: Bool = false) {
        let f = font(size, bold)
        let string = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: SplashPalette.ui(color)])
        let width = string.size().width
        let top = y - (f.ascender - f.descender) / 2
        string.draw(at: CGPoint(x: alignLeft ? x : x - width / 2, y: top))
    }

    private func measure(_ s: String, _ size: CGFloat) -> CGFloat {
        return NSAttributedString(string: s, attributes: [.font: font(size, true)]).size().width
    }

    /// Android StaticLayout paragraph: centred, bold, at most `maxLines` lines, ellipsised.
    private func paragraph(_ s: String, _ b: CGRect, _ size: CGFloat, _ color: UInt32, maxLines: Int = 3, rtl: Bool? = nil) {
        let isRTL = rtl ?? AppText.rtl
        let key = "\(s)|\(Int(b.width))|\(size)|\(color)|\(maxLines)|\(isRTL)"
        let layout: ParagraphLayout
        if let cached = layouts[key] {
            layout = cached
        } else {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            style.baseWritingDirection = isRTL ? .rightToLeft : .natural
            style.lineBreakMode = .byWordWrapping
            let f = font(size, true)
            let attributed = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: SplashPalette.ui(color), .paragraphStyle: style])
            let width = max(1, floor(b.width))
            let full = attributed.boundingRect(with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
                                               options: [.usesLineFragmentOrigin], context: nil)
            let height = min(ceil(full.height), ceil(f.lineHeight * CGFloat(maxLines)) + 1)
            layout = ParagraphLayout(text: attributed, width: width, height: height)
            if layoutOrder.count >= 128 {
                let first = layoutOrder.removeFirst()
                layouts.removeValue(forKey: first)
            }
            layouts[key] = layout
            layoutOrder.append(key)
        }
        let rect = CGRect(x: b.minX, y: b.midY - layout.height / 2, width: layout.width, height: layout.height)
        layout.text.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }

    /// Android `canvas.scale(sx, sy, px, py)`.
    private func scale(_ c: CGContext, _ sx: CGFloat, _ sy: CGFloat, _ px: CGFloat, _ py: CGFloat) {
        c.translateBy(x: px, y: py)
        c.scaleBy(x: sx, y: sy)
        c.translateBy(x: -px, y: -py)
    }

    // MARK: Arena (cached like Android's arenaBitmap)

    private func renderArena() {
        let size = bounds.size
        guard size.width > 0 && size.height > 0 else {
            arenaView.image = nil
            return
        }
        let renderer = UIGraphicsImageRenderer(size: size)
        arenaView.image = renderer.image { context in
            self.paintArena(context.cgContext, size)
        }
    }

    private func gradient(_ top: UInt32, _ bottom: UInt32) -> CGGradient? {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let colors = [SplashPalette.ui(top).cgColor, SplashPalette.ui(bottom).cgColor] as CFArray
        return CGGradient(colorsSpace: space, colors: colors, locations: nil)
    }

    private func paintArena(_ c: CGContext, _ size: CGSize) {
        let width = size.width
        let height = size.height
        c.setFillColor(SplashPalette.ui(SplashPalette.sky).cgColor)
        c.fill(CGRect(origin: .zero, size: size))
        if let scenery = art.scene(local.settings.arena) {
            let ratio = max(width / scenery.size.width, height / scenery.size.height)
            let rw = scenery.size.width * ratio
            let rh = scenery.size.height * ratio
            scenery.draw(in: ltrb((width - rw) / 2, (height - rh) / 2, (width + rw) / 2, (height + rh) / 2))
        }
        if let shade = gradient(0xa0091b32, 0x200c2540) {
            c.saveGState()
            c.clip(to: ltrb(0, 0, width, height * 0.4))
            c.drawLinearGradient(shade, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: height * 0.42),
                                 options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            c.restoreGState()
        }
        if !local.settings.court { return }
        // Transparent room geometry; scenery continues beneath the entire screen.
        let w = engine.config.width
        let d = engine.config.depth
        let tl = screen(V(0, 0))
        let topRight = screen(V(w, 0))
        let br = screen(V(w, d))
        let bl = screen(V(0, d))
        let floorPath = CGMutablePath()
        floorPath.move(to: tl)
        floorPath.addLine(to: topRight)
        floorPath.addLine(to: br)
        floorPath.addLine(to: bl)
        floorPath.closeSubpath()
        if let floorShade = gradient(0x55427283, 0x771b435b) {
            c.saveGState()
            c.addPath(floorPath)
            c.clip()
            c.drawLinearGradient(floorShade, start: CGPoint(x: 0, y: tl.y), end: CGPoint(x: 0, y: bl.y),
                                 options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            c.restoreGState()
        }
        for i in 0...6 {
            let a = screen(V(Double(i) * w / 6, 0))
            let b = screen(V(Double(i) * w / 6, d))
            line(c, a.x, a.y, b.x, b.y, 1, 0x284ee4ed)
        }
        for j in 0...6 {
            let a = screen(V(0, Double(j) * d / 6))
            let b = screen(V(w, Double(j) * d / 6))
            line(c, a.x, a.y, b.x, b.y, 1, 0x284ee4ed)
        }
        let middle = (tl.y + bl.y) / 2
        if engine.mode == .teams {
            rounded(c, ltrb(tl.x, tl.y, topRight.x, middle), 0, 0x1535d5ff)
            rounded(c, ltrb(tl.x, middle, topRight.x, bl.y), 0, 0x19ffea00)
            c.saveGState()
            c.setLineDash(phase: 0, lengths: [8, 8])
            line(c, tl.x, middle, topRight.x, middle, 2, 0x887deaf0)
            c.restoreGState()
        }
        // Back and side glass panels, highlights and structural rails; no opaque front wall.
        let glass = height * 0.13
        rounded(c, ltrb(tl.x, tl.y - glass, topRight.x, tl.y), 0, 0x203de9ff)
        line(c, tl.x, tl.y - glass, topRight.x, tl.y - glass, 2, 0xb58ae6eb)
        line(c, tl.x, tl.y, topRight.x, topRight.y, 2, 0xb58ae6eb)
        line(c, tl.x, tl.y - glass, bl.x, bl.y, 2, 0xb58ae6eb)
        line(c, topRight.x, topRight.y - glass, br.x, br.y, 2, 0xb58ae6eb)
        for i in 0...3 {
            let x = tl.x + (topRight.x - tl.x) * CGFloat(i) / 3
            line(c, x, tl.y - glass, x, tl.y, 1.4, 0xb58ae6eb)
        }
        line(c, bl.x, bl.y, br.x, br.y, 3, 0xff70f5e1)
        rounded(c, ltrb(tl.x - 4, tl.y, tl.x, bl.y), 0, 0x227cf2ff)
        rounded(c, ltrb(topRight.x, tl.y, topRight.x + 4, bl.y), 0, 0x227cf2ff)
    }

    // MARK: Frame

    func render(_ c: CGContext) {
        guard viewWidth > 0 && viewHeight > 0 else { return }
        c.interpolationQuality = .medium
        drawFloorEffects(c)
        let a = local
        if a.held == nil {
            var best: Choice? = nil
            var bestDistance = Double.greatestFiniteMagnitude
            for choice in a.choices {
                let distance = (choice.position - a.position).length()
                if distance <= engine.config.pickupRadius && distance < bestDistance {
                    best = choice
                    bestDistance = distance
                }
            }
            highlighted = best?.index ?? -1
        } else {
            highlighted = -1
        }
        choiceRects.removeAll()
        // Private choices are drawn only for this user. Never render remote question sets.
        if a.held == nil {
            for choice in a.choices { drawChoice(c, choice) }
        }
        actorRects.removeAll()
        for actor in engine.actors.stableSorted(by: { $0.position.y < $1.position.y }) { drawActor(c, actor) }
        // Keep personal answer faces legible even when a body overlaps their world position.
        if a.held == nil {
            for choice in a.choices {
                guard let face = choiceRects[choice.index] else { continue }
                if actorRects.contains(where: { $0.rect.intersects(face) }) { drawChoice(c, choice) }
            }
        }
        if a.held != nil && a.settings.throwing == .standard {
            drawAim(c, a)
        } else {
            aimPoints.removeAll()
            aimGripRect = .null
        }
        for shot in engine.shots { drawShot(c, shot) }
        drawParticles(c)
        drawHud(c)
        if tutorialStep >= 0 {
            updateLesson()
            drawTutorial(c)
        }
        if !running {
            rounded(c, box(viewWidth * 0.12, viewHeight * 0.40, viewWidth * 0.76, viewHeight * 0.18), 24, 0xee102c46)
            text(tr("Paused · tap to continue", "המשחק מושהה · נגיעה להמשך"), viewWidth * 0.5, viewHeight * 0.49, 17, white, bold: true)
        }
    }

    private func drawFloorEffects(_ c: CGContext) {
        for b in engine.bursts {
            let pos = screen(b.position)
            let age = engine.time - b.at
            let alpha = min(max(KotlinNumber.int(130 * (1 - age / 7)), 0), 130)
            art.splash(3, b.color)?.draw(in: ltrb(pos.x - 24, pos.y - 9, pos.x + 24, pos.y + 9), blendMode: .normal, alpha: CGFloat(alpha) / 255)
        }
    }

    private func displayText(_ text: String) -> String {
        return local.question?.skill == .english ? text : AppText.t(text)
    }

    private func drawChoice(_ c: CGContext, _ ch: Choice) {
        let pos = screen(ch.position)
        let displayAnswer = displayText(ch.text)
        var longest = 0
        for other in local.choices { longest = max(longest, displayText(other.text).utf16.count) }
        let wordChoices = longest > 3
        let cam = camera
        let fraction = longest > 6 ? cam.longWordBalloonWidth : (wordChoices ? cam.wordBalloonWidth : cam.numberBalloonWidth)
        let w = viewWidth * CGFloat(fraction)
        let h = w * (wordChoices ? 1.22 : 1.02)
        let age = max(engine.time - local.questionAt, 0)
        let pop = age < 0.35 ? sin(age / 0.35 * Double.pi) * 5 : 0.0
        let bob = CGFloat(sin(engine.time * 2.8 + Double(ch.index)) * 1.3 - pop)
        let b = ltrb(pos.x - w / 2, pos.y - h + bob, pos.x + w / 2, pos.y + bob)
        choiceRects[ch.index] = b
        fillOval(c, ltrb(pos.x - w * 0.32, pos.y - 3, pos.x + w * 0.32, pos.y + 5), SplashPalette.ui(0x55302b47))
        if (ch.position - local.position).length() <= engine.config.pickupRadius {
            c.setStrokeColor(SplashPalette.ui(0xffd5fff5).cgColor)
            c.setLineWidth(2.5)
            c.strokeEllipse(in: ltrb(pos.x - w * 0.62, pos.y - 6, pos.x + w * 0.62, pos.y + 7))
            text(tr("TAP", "געו"), pos.x, b.minY - 5, 9, 0xffd5fff5, bold: true)
        }
        let squash = age < 0.4 ? CGFloat(sin(age / 0.4 * Double.pi) * 0.12) : 0
        c.saveGState()
        scale(c, 1 + squash, 1 - squash, b.midX, b.maxY)
        let balloon = wordChoices ? art.wordBalloon(ch.color) : art.balloon(ch.color)
        balloon?.draw(in: b)
        c.restoreGState()
        let label = ltrb(b.midX - w * 0.34, b.minY + h * 0.40, b.midX + w * 0.34, b.minY + h * 0.86)
        var answerSize: CGFloat = longest > 10 ? 10.5 : (wordChoices ? 12 : 17)
        if wordChoices {
            var widest: CGFloat = 0
            for word in displayAnswer.components(separatedBy: " ") { widest = max(widest, measure(word, answerSize)) }
            if widest > label.width { answerSize = max(answerSize * label.width / widest, 9.5) }
        }
        paragraph(displayAnswer, label, answerSize, ink, maxLines: 2, rtl: AppText.rtl && local.question?.skill != .english)
    }

    private func drawActor(_ c: CGContext, _ a: SplashActor) {
        let feet = screen(a.position, a.height)
        let frameIndex = SplashPose.frame(a, engine.time)
        let visual = art.visual(a, frameIndex)
        let size = viewWidth * CGFloat(camera.characterWidth * (0.85 + 0.017 * a.position.y))
        let h = size * 1.25
        let b = ltrb(feet.x - size / 2, feet.y - h * 304 / 320, feet.x + size / 2, feet.y + h * 16 / 320)
        actorRects.append((id: a.member.id, rect: b))
        let ground = screen(a.position)
        let sh = CGFloat(min(max(1 - a.height * 0.18, 0.5), 1.0))
        fillOval(c, ltrb(ground.x - size * 0.28 * sh, ground.y - 3, ground.x + size * 0.28 * sh, ground.y + 6), SplashPalette.ui(0x603d1738))
        let mirrored = visual?.mirrored ?? false
        if let frameImage = visual?.frame.image {
            // Small reflected silhouette anchors the character to the polished floor.
            c.saveGState()
            scale(c, 1, -0.24, feet.x, feet.y)
            if mirrored { scale(c, -1, 1, feet.x, feet.y) }
            frameImage.draw(in: b, blendMode: .normal, alpha: 30.0 / 255.0)
            c.restoreGState()
        }
        var alpha: CGFloat = 1
        if engine.time < a.shieldUntil && KotlinNumber.int(engine.time * 12) % 2 == 0 { alpha = 170.0 / 255.0 }
        let body = art.painted(a, frameIndex) ?? visual?.frame.image
        c.saveGState()
        if mirrored { scale(c, -1, 1, feet.x, feet.y) }
        body?.draw(in: b, blendMode: .normal, alpha: alpha)
        c.restoreGState()
        if let held = a.held {
            let color = a.choices.first(where: { $0.index == held })?.color ?? a.publicHeldColor
            let handX = visual?.frame.handX ?? 128
            let handY = visual?.frame.handY ?? 190
            let hx = b.minX + (mirrored ? 1 - handX / 256 : handX / 256) * size
            let hy = b.minY + handY / 320 * h
            let sw = size * 0.29
            let sway = CGFloat(sin(engine.time * 4) * 1.2)
            art.balloon(color)?.draw(in: ltrb(hx - sw / 2, hy - sw * 0.65 + sway, hx + sw / 2, hy + sw * 0.35 + sway))
        }
        let name: String
        if a.member.id == localId {
            name = tr("You", "אתם")
        } else if a.member.bot {
            name = Characters.get(a.member.character).name(engine.hebrew)
        } else {
            name = a.member.name
        }
        let team = Teams.style(a.member.team)
        let teams = engine.mode == .teams
        let label = teams ? team.emblem + " " + name : name
        rounded(c, ltrb(feet.x - size * 0.5, ground.y + 8, feet.x + size * 0.5, ground.y + 23), 6, teams ? team.color : 0xe0092037)
        text(label + " · \(a.score)", feet.x, ground.y + 15.5, 10, teams ? team.ink : white, bold: true)
    }

    private func drawAim(_ c: CGContext, _ a: SplashActor) {
        let dir = a.direction.unit()
        let releaseHeight = a.height + (engine.time < a.crouchUntil ? 0.48 : 1.15)
        aimPoints.removeAll()
        let visual = art.visual(a, SplashPose.frame(a, engine.time))
        guard let body = actorRects.first(where: { $0.id == a.member.id })?.rect else { return }
        let handX = visual?.frame.handX ?? 128
        let handY = visual?.frame.handY ?? 190
        let mirrored = visual?.mirrored ?? false
        let origin = CGPoint(x: body.minX + (mirrored ? 1 - handX / 256 : handX / 256) * body.width, y: body.minY + handY / 320 * body.height)
        let path = CGMutablePath()
        path.move(to: origin)
        aimPoints.append(origin)
        let gravity = engine.config.gravity * a.settings.projectileGravityFactor
        for i in 1...22 {
            let t = Double(i) * 0.052
            let pos = a.position + dir * (0.42 + engine.config.throwSpeed * t)
            let z = releaseHeight + engine.config.launchLift * t - 0.5 * gravity * t * t
            let pt = screen(pos, z)
            path.addLine(to: pt)
            aimPoints.append(pt)
        }
        c.saveGState()
        c.setStrokeColor(SplashPalette.ui(0xfff4ffd4).cgColor)
        c.setLineWidth(2.3)
        c.setLineDash(phase: 0, lengths: [5, 5])
        c.addPath(path)
        c.strokePath()
        c.restoreGState()
        let reach = CGFloat(engine.config.arcTouchDp)
        let exclusion = body.insetBy(dx: -reach, dy: -reach)
        let grip = aimPoints.dropFirst(5).first { p in
            !exclusion.contains(p) && p.x > 30 && p.x < viewWidth - 30 && p.y > 170 && p.y < viewHeight * 0.88
        } ?? aimPoints[aimPoints.count - 1]
        aimGrip = CGPoint(x: min(max(grip.x, 26), viewWidth - 26), y: min(max(grip.y, 175), viewHeight * 0.88))
        aimGripRect = ltrb(aimGrip.x - 22, aimGrip.y - 22, aimGrip.x + 22, aimGrip.y + 22)
        // The arc itself is the control; its forgiving hit area is invisible.
    }

    private func drawShot(_ c: CGContext, _ s: Shot) {
        let pos = screen(s.position, s.height)
        let ground = screen(s.position)
        fillOval(c, ltrb(ground.x - 7, ground.y - 2, ground.x + 7, ground.y + 3), SplashPalette.ui(0x40351f40))
        let size = viewWidth * 0.066
        c.saveGState()
        c.translateBy(x: pos.x, y: pos.y)
        c.rotate(by: CGFloat(atan2(s.velocity.y, s.velocity.x) + Double.pi / 2))
        c.translateBy(x: -pos.x, y: -pos.y)
        art.balloon(s.color)?.draw(in: ltrb(pos.x - size * 0.42, pos.y - size * 0.58, pos.x + size * 0.42, pos.y + size * 0.58))
        c.restoreGState()
    }

    private func drawParticles(_ c: CGContext) {
        var budget = engine.config.particleLimit
        for b in engine.bursts {
            let age = engine.time - b.at
            if age < 0 || age > 1.1 { continue }
            let burstCenter = screen(b.position, b.height)
            let size = viewWidth * CGFloat(0.095 * (0.45 + min(age, 0.25) * 3))
            let splashAlpha = CGFloat(KotlinNumber.int((1 - age / 1.1) * 245)) / 255
            art.splash(age < 0.15 ? 4 : 0, b.color)?.draw(in: ltrb(burstCenter.x - size, burstCenter.y - size, burstCenter.x + size, burstCenter.y + size),
                                                          blendMode: .normal, alpha: splashAlpha)
            let dropAlpha = KotlinNumber.int((1 - age / 1.1) * 255)
            let dropColor = SplashPalette.ui(colors[min(max(b.color, 0), 5)], alpha: dropAlpha)
            let spin = Double(b.id.javaHashCode % 6)
            for i in 0..<16 {
                if budget <= 0 { break }
                budget -= 1
                let angle = Double(i) * 2.399 + spin
                let speed = Double(18 + i % 5 * 5)
                let dx = CGFloat(cos(angle) * speed * age)
                let dy = CGFloat(sin(angle) * speed * age + 48 * age * age)
                fillOval(c, ltrb(burstCenter.x + dx, burstCenter.y + dy, burstCenter.x + dx + 3, burstCenter.y + dy + CGFloat(3 + i % 3)), dropColor)
            }
        }
    }

    private func drawHud(_ c: CGContext) {
        buttons.removeAll()
        buttonOrder.removeAll()
        rounded(c, ltrb(10, 8, viewWidth - 10, 54), 18, 0xd00b253d)
        let back = ltrb(16, 12, 54, 50)
        setButton("back", back)
        text("‹", back.midX, back.midY - 2, 36, colors[5], bold: true)
        let remaining = KotlinNumber.int(max(engine.config.duration - engine.time, 0))
        if timerSecond != remaining {
            timerSecond = remaining
            let seconds = remaining % 60
            timerText = "\(remaining / 60):" + (seconds < 10 ? "0" : "") + "\(seconds)"
        }
        text(engine.practice ? tr("Practice", "תרגול") : timerText, viewWidth / 2, 30, engine.practice ? 17 : 20, white, bold: true)
        text(tr("YOU", "אתם") + " \(local.score)", viewWidth - 59, 30, 14, colors[1], bold: true)
        let card = ltrb(18, 64, viewWidth - 18, 133)
        rounded(c, card, 18, 0xdd0a283d)
        c.setStrokeColor(SplashPalette.ui(0x6600e5ff).cgColor)
        c.setLineWidth(1)
        c.addPath(UIBezierPath(roundedRect: card, cornerRadius: 18).cgPath)
        c.strokePath()
        if let question = local.question {
            let sprayAge = engine.time - local.questionAt
            if sprayAge >= 0 && sprayAge <= 0.4 {
                let sprayAlpha = KotlinNumber.int(150 * (1 - sprayAge / 0.4))
                for i in 0...13 {
                    let x = card.minX + card.width * CGFloat(i * 37 % 100) / 100
                    let y = card.minY + card.height * CGFloat(i * 53 % 100) / 100
                    let r = CGFloat(2 + i % 3)
                    fillOval(c, CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2), SplashPalette.ui(colors[i % 6], alpha: sprayAlpha))
                }
            }
            let arithmetic = question.skill.isArithmetic
            paragraph(AppText.t(question.text(engine.hebrew)), ltrb(card.minX + 8, card.minY + 7, card.maxX - 8, card.maxY - 25),
                      arithmetic ? 28 : 17, white, maxLines: 2, rtl: !arithmetic && AppText.rtl)
            text(tr("YOUR QUESTION", "השאלה שלכם"), card.midX, card.maxY - 12, 13, 0xff90ebe7, bold: true)
        }
        setButton("speak", ltrb(viewWidth - 49, 137, viewWidth - 12, 169))
        text("♫", viewWidth - 30, 152, 19, white)
        if engine.mode == .teams {
            for team in 0...1 {
                let x: CGFloat = team == 0 ? 18 : viewWidth / 2 + 8
                let span = viewWidth / 2 - 26
                let size = span / 10
                let style = Teams.style(team)
                let score = team < engine.teamScores.count ? engine.teamScores[team] : 0
                text(style.emblem + " \(score) / \(engine.config.teamTarget)", x + span / 2, 147, 10, white, bold: true)
                let filled = score * 10 / max(engine.config.teamTarget, 1)
                for i in 0..<10 {
                    rounded(c, ltrb(x + CGFloat(i) * size, 157, x + CGFloat(i + 1) * size - 2, 164), 2, i < filled ? style.color : 0x55304b61)
                }
            }
        }
        if !engine.practice {
            let advice = contextAdvice()
            if !advice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let b = ltrb(14, viewHeight * 0.89, viewWidth - 14, viewHeight * 0.97)
                rounded(c, b, 14, 0xe6103048)
                paragraph(advice, ltrb(b.minX + 8, b.minY, b.maxX - 8, b.maxY), 14, white, maxLines: 3)
            }
        }
        if !networkStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text(networkStatus, viewWidth / 2, viewHeight * 0.982, 9, 0xffbdf8ff)
        }
    }

    private func setButton(_ key: String, _ rect: CGRect) {
        if buttons[key] == nil { buttonOrder.append(key) }
        buttons[key] = rect
    }

    private func feedbackExplanation(_ f: Feedback) -> String { return AppText.t(f.explanation) }

    private func contextAdvice() -> String {
        if let f = local.feedback, engine.time < f.expires, !f.correct {
            let why = feedbackExplanation(f)
            return tr("Previous question: \(why) That wrong-answer balloon burst in your hand. Choose the right balloon, then throw!",
                      "השאלה הקודמת: \(why) הבלון עם התשובה השגויה התפוצץ ביד. בחרו את הבלון הנכון ואז זרקו!")
        }
        let threat = engine.shots.first { shot in
            shot.owner != localId && (engine.mode == .solo || engine.actor(shot.owner)?.member.team != local.member.team)
                && (shot.position - local.position).length() < 3.2
        }
        if let threat = threat {
            if threat.height > 1 {
                return tr("Incoming balloon! Double-tap to duck, or move away.", "בלון מתקרב! געו פעמיים כדי להתכופף, או התרחקו.")
            }
            return tr("Low balloon! Tap your character to jump, or dodge.", "בלון נמוך! געו בדמות כדי לקפוץ, או התחמקו.")
        }
        if local.height > 0.2 { return tr("Nice jump! You can still aim and throw in the air.", "קפיצה יפה! אפשר לכוון ולזרוק גם באוויר.") }
        if local.held != nil {
            if local.settings.throwing == .easy {
                return tr("Balloon ready. Tap an opponent to aim and throw.", "הבלון מוכן. געו ביריב כדי לכוון ולזרוק.")
            }
            return tr("Balloon ready. Drag the arc to aim; tap the arc to throw.", "הבלון מוכן. גררו את הקשת לכיוון וגעו בה כדי לזרוק.")
        }
        if !local.settings.court { return "" }
        if local.walkTarget != nil { return tr("On your way! Watch for incoming balloons.", "אתם בדרך! שימו לב לבלונים מתקרבים.") }
        if local.settings.walk == .easy {
            return tr("Solve your question. Tap a balloon to walk over and collect it.", "פתרו את השאלה. געו בבלון כדי להגיע אליו ולאסוף אותו.")
        }
        return tr("Tap a place or drag your character. Tap a nearby glowing balloon.", "געו במקום או גררו את הדמות. געו בבלון מואר קרוב לאיסוף.")
    }

    // MARK: Learn with Minik

    func beginTutorial() {
        engine.practice = true
        enterLesson(0)
    }

    private func enterLesson(_ step: Int) {
        gesture.cancel()
        tutorialStep = min(max(step, 0), 10)
        lessonDone = false
        lessonStarted = engine.time
        lessonPosition = local.position
        lessonAnswers = local.answers.count
        local.move = V(0, 0)
        local.walkTarget = nil
        local.feedback = nil
        switch tutorialStep {
        case 1: local.settings.walk = .easy
        case 2: local.settings.walk = .standard
        case 4: local.settings.throwing = .easy
        case 5: local.settings.throwing = .standard
        default: break
        }
        if [1, 2, 4, 5, 6].contains(tutorialStep) { engine.resetPracticeQuestion(localId) }
        if [1, 2, 4, 5].contains(tutorialStep) { onControlSettings?(local.settings) }
        canvas.setNeedsDisplay()
    }

    private func updateLesson() {
        let recent = Array(local.answers.dropFirst(min(lessonAnswers, local.answers.count)))
        var done = false
        switch tutorialStep {
        case 1, 2: done = local.held != nil
        case 4, 5: done = recent.contains { $0.correct }
        case 6: done = recent.contains { !$0.correct }
        case 7: done = local.height > 0.25
        case 8: done = engine.time < local.crouchUntil
        case 9: done = recent.filter { $0.correct }.count >= 4
        default: done = false
        }
        lessonDone = lessonDone || done
    }

    private func lessonText() -> String {
        if let f = local.feedback, !f.correct, engine.time < f.expires {
            let why = feedbackExplanation(f)
            return tr("The previous answer was wrong, so that balloon burst in your hand. \(why) Choose a correct answer and your balloon will fly where you throw it.",
                      "הבלון התפוצץ ביד כי התשובה לשאלה הקודמת הייתה שגויה. \(why) בלון עם תשובה נכונה יעוף לכיוון שתזרקו ולא יתפוצץ ביד.")
        }
        if let held = local.choices.first(where: { $0.index == local.held }), [1, 2, 4, 5].contains(tutorialStep) {
            let correct = held.text == local.question?.answer
            if correct {
                local.hinted = true
                let easy = local.settings.throwing == .easy
                let en = "Great! You picked the balloon with the correct answer. " + (easy
                    ? "Tap Minik to throw. A wrong answer would burst in your hand."
                    : "Drag the aiming arc, then tap it to throw. A wrong answer would burst in your hand.")
                let he = "נהדר! אספתם את הבלון עם התשובה הנכונה. " + (easy
                    ? "געו במיניק כדי לזרוק. תשובה שגויה תתפוצץ ביד."
                    : "גררו את קשת הכיוון ואז געו בה כדי לזרוק. תשובה שגויה תתפוצץ ביד.")
                return tr(en, he)
            }
            return tr("You chose a wrong answer. Try throwing it to see why it bursts. Then choose the correct answer.",
                      "בחרתם תשובה שגויה. נסו לזרוק וראו שהיא מתפוצצת ביד. אחר כך בחרו את התשובה הנכונה.")
        }
        switch tutorialStep {
        case 0:
            return tr("Choose how to walk. Easy: tap an answer balloon to walk and collect it. Standard: walk first, then tap the nearby balloon. Both let you tap a place to walk there.",
                      "בחרו דרך הליכה. קלה: נגיעה בבלון מובילה אליו ואוספת אותו. רגילה: מתקרבים ואז נוגעים בבלון. בשתיהן אפשר לגעת במקום כדי להגיע אליו.")
        case 1:
            return tr("Try Easy walking: solve the question and tap its balloon. Your character walks there and picks it up.",
                      "נסו הליכה קלה: פתרו את השאלה וגעו בבלון המתאים. הדמות תגיע אליו ותאסוף אותו.")
        case 2:
            return tr("Try Standard walking: drag from your character, or tap a place. When a balloon glows nearby, tap it to collect.",
                      "נסו הליכה רגילה: גררו מהדמות או געו במקום. כשהבלון הקרוב מואר, געו בו לאיסוף.")
        case 3:
            return tr("Choose how to throw. Easy: tap an opponent while holding a balloon. Standard: drag the arc to aim, then tap the arc. You can try both.",
                      "בחרו דרך זריקה. קלה: מחזיקים בלון ונוגעים ביריב. רגילה: גוררים את הקשת לכיוון ואז נוגעים בה. אפשר לנסות את שתיהן.")
        case 4:
            return tr("Try Easy throwing: collect the correct balloon, then tap Minik. The balloon flies towards him; he can still dodge.",
                      "נסו זריקה קלה: אספו בלון נכון ואז געו במיניק. הבלון יעוף אליו; עדיין אפשר להתחמק.")
        case 5:
            return tr("Try Standard throwing: collect a correct balloon. Drag the arc to aim; your aim stays when you let go. Tap any part of the arc to throw.",
                      "נסו זריקה רגילה: אספו בלון נכון. גררו את הקשת לכיוון; הכיוון נשמר בשחרור. געו בקשת כדי לזרוק.")
        case 6:
            return tr("Try a wrong answer on purpose. Throw it: it bursts in your hand and adds paint. The correct answer appears, then you can try again.",
                      "נסו בכוונה תשובה שגויה וזרקו: היא מתפוצצת ביד ומוסיפה צבע. התשובה הנכונה תופיע, ואז אפשר לנסות שוב.")
        case 7:
            return tr("Tap your character once to jump over a low balloon. You can jump while holding a balloon. In Andromeda you stay airborne longer.",
                      "געו פעם אחת בדמות כדי לקפוץ מעל בלון נמוך. אפשר לקפוץ גם עם בלון ביד. באנדרומדה נשארים באוויר יותר זמן.")
        case 8:
            return tr("Double-tap the arena to duck under a high balloon. Your character really becomes lower. One tap and two taps are different actions.",
                      "געו פעמיים ברצף בזירה כדי להתכופף מתחת לבלון גבוה. הדמות באמת נעשית נמוכה יותר. נגיעה אחת ושתי נגיעות הן פעולות שונות.")
        case 9:
            return tr("Warm up with four correct answers, at your own pace. You may continue practicing as long as you like. No timer and no ads here.",
                      "תרגלו ארבע תשובות נכונות, בקצב שלכם. אפשר להמשיך לתרגל כמה שרוצים. אין כאן טיימר או פרסומות.")
        default:
            return tr("Ready to splash! Your control choices are saved in Settings. Finish learning to return to the main menu.",
                      "מוכנים להתיז! הבחירות נשמרו בהגדרות. סיימו את הלימוד כדי לחזור לתפריט הראשי.")
        }
    }

    private static let lessonTitlesHe = ["איך הולכים?", "הליכה קלה", "הליכה רגילה", "איך זורקים?", "זריקה קלה", "זריקה רגילה",
                                         "לומדים גם מטעות", "קופצים", "מתכופפים", "תרגול חופשי", "כל הכבוד!"]
    private static let lessonTitlesEn = ["How to walk", "Easy walking", "Standard walking", "How to throw", "Easy throwing",
                                         "Standard throwing", "Learning from mistakes", "Jump", "Duck", "Free practice", "Well done!"]

    private func drawTutorial(_ c: CGContext) {
        let top: CGFloat = 142
        let bottom = min(viewHeight * 0.415, top + 166)
        let b = ltrb(12, top, viewWidth - 12, bottom)
        rounded(c, b, 16, 0xf0143c59)
        let titles = engine.hebrew ? SplashArenaView.lessonTitlesHe : SplashArenaView.lessonTitlesEn
        let title = titles[min(max(tutorialStep, 0), titles.count - 1)]
        text((lessonDone ? "✓ " : "") + AppText.t(title), b.midX, top + 15, 17, 0xffa8fff0, bold: true)
        paragraph(lessonText(), ltrb(b.minX + 10, top + 30, b.maxX - 10, b.maxY - 45), 15, white, maxLines: 5)
        let w = (b.width - 20) / 3
        func nav(_ key: String, _ title: String, _ left: CGFloat, _ color: UInt32) {
            let r = ltrb(left, bottom - 38, left + w, bottom - 5)
            setButton(key, r)
            rounded(c, r, 10, color)
            paragraph(title, r, 13, ink, maxLines: 2)
        }
        nav("lessonPrev", tr("Previous", "הקודם"), b.minX + 4, 0xffd0e5ff)
        if tutorialStep == 0 || tutorialStep == 3 {
            nav("lessonEasy", tr("Try Easy", "נסו קלה"), b.minX + w + 8, 0xffb4f6e7)
            nav("lessonStandard", tr("Try Standard", "נסו רגילה"), b.minX + 2 * w + 12, 0xffffe5a4)
        } else {
            let tryMode = [1, 2, 4, 5].contains(tutorialStep)
            if tryMode {
                nav("lessonOther", tr("Try other mode", "נסו מצב אחר"), b.minX + w + 8, 0xffffe5a4)
            } else {
                nav("lessonRetry", tr("Try again", "נסו שוב"), b.minX + w + 8, 0xffffe5a4)
            }
            let nextTitle: String
            if tutorialStep == 10 {
                nextTitle = tr("Main menu", "תפריט ראשי")
            } else if tryMode {
                nextTitle = tr("Use this mode", "בחירת המצב")
            } else {
                nextTitle = tr("Next", "הבא")
            }
            nav("lessonNext", nextTitle, b.minX + 2 * w + 12, 0xffb4f6e7)
        }
    }

    private func lessonButton(_ key: String) {
        switch key {
        case "lessonPrev":
            let previous: Int
            switch tutorialStep {
            case 1, 2: previous = 0
            case 4, 5: previous = 3
            default: previous = max(tutorialStep - 1, 0)
            }
            enterLesson(previous)
        case "lessonEasy": enterLesson(tutorialStep == 0 ? 1 : 4)
        case "lessonStandard": enterLesson(tutorialStep == 0 ? 2 : 5)
        case "lessonOther":
            let other: Int
            switch tutorialStep {
            case 1: other = 2
            case 2: other = 1
            case 4: other = 5
            default: other = 4
            }
            enterLesson(other)
        case "lessonRetry": enterLesson(tutorialStep)
        case "lessonNext":
            if tutorialStep == 10 {
                tutorialCompleted?()
            } else {
                let next: Int
                switch tutorialStep {
                case 1, 2: next = 3
                case 4, 5: next = 6
                default: next = tutorialStep + 1
                }
                enterLesson(next)
            }
        default: break
        }
    }

    // MARK: Touch

    private func touchAction(_ e: TouchAction) {
        if e.type != "press" { lastTouchSummary = "\(e.type):\(e.target.kind) held=\(String(describing: local.held)) time=\(engine.time)" }
        switch e.type {
        case "press":
            return
        case "end":
            if e.target.kind == .body { command(.move(V(0, 0))) }
        case "double":
            command(.crouch)
        case "drag":
            let dragScale = engine.config.movementDragDp
            if e.target.kind == .body {
                let v = V(e.dx / dragScale, e.dy / dragScale)
                command(.move(v.length() > 1 ? v.unit() : v))
            }
            if e.target.kind == .arc {
                let lift = viewHeight * CGFloat(camera.heightScale)
                let aim = world(CGFloat(e.x), CGFloat(e.y) + lift) - local.position
                command(.aim(aim))
            }
        case "tap":
            switch e.target.kind {
            case .body:
                if e.target.balloon >= 0 { collectOrWalk(e.target) } else { command(.jump) }
            case .arc: command(.throwBalloon)
            case .balloon: collectOrWalk(e.target)
            case .opponent: command(.shootAt(e.target.actorId))
            case .world: command(.walkTo(world(CGFloat(e.x), CGFloat(e.y))))
            }
        default:
            return
        }
    }

    private func collectOrWalk(_ target: TouchTarget) {
        if local.settings.walk == .easy {
            guard let ch = local.choices.first(where: { $0.index == target.balloon }) else { return }
            command(.walkTo(ch.position, questionId: target.questionId, index: target.balloon))
        } else {
            command(.pickup(questionId: target.questionId, index: target.balloon))
        }
    }

    private func allocatePointer(_ touch: UITouch) -> Int {
        let key = ObjectIdentifier(touch)
        if let existing = pointerIds[key] { return existing }
        var id = 0
        while touchesById[id] != nil { id += 1 }
        pointerIds[key] = id
        touchesById[id] = touch
        return id
    }

    private func releasePointer(_ touch: UITouch) -> Int? {
        let key = ObjectIdentifier(touch)
        guard let id = pointerIds.removeValue(forKey: key) else { return nil }
        touchesById.removeValue(forKey: id)
        return id
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
            let first = touchesById.isEmpty
            let id = allocatePointer(touch)
            let p = touch.location(in: self)
            pointerDown(id, p.x, p.y, Int64(touch.timestamp * 1000), first)
        }
    }

    private func pointerDown(_ id: Int, _ x: CGFloat, _ y: CGFloat, _ now: Int64, _ first: Bool) {
        let point = CGPoint(x: x, y: y)
        if first {
            if buttons["back"]?.contains(point) == true {
                stop()
                onExit()
                return
            }
            if buttons["speak"]?.contains(point) == true {
                onSpeak(AppText.t(local.question?.text(engine.hebrew) ?? ""))
                return
            }
            if let key = buttonOrder.first(where: { $0.hasPrefix("lesson") && buttons[$0]?.contains(point) == true }) {
                lessonButton(key)
                return
            }
        }
        let body = actorRects.first(where: { $0.id == localId })?.rect
        let bodyTarget = body?.insetBy(dx: -9, dy: -7).contains(point) ?? false
        // Nearby balloon face has explicit pickup priority, then body, then a wide arc band.
        var choice: Int? = nil
        if local.held == nil {
            var smallest = CGFloat.greatestFiniteMagnitude
            for ch in local.choices {
                guard let rect = choiceRects[ch.index], rect.contains(point) else { continue }
                let reachable = local.settings.walk == .easy || (ch.position - local.position).length() <= engine.config.pickupRadius
                if reachable && rect.width < smallest {
                    smallest = rect.width
                    choice = ch.index
                }
            }
        }
        var opponent: String? = nil
        if local.held != nil && local.settings.throwing == .easy {
            opponent = actorRects.first(where: { entry in
                entry.id != localId && entry.rect.contains(point)
                    && (engine.mode == .solo || engine.actor(entry.id)?.member.team != local.member.team)
            })?.id
        }
        var core = CGRect.null
        if let body = body {
            core = ltrb(body.midX - body.width * 0.18, body.minY + body.height * 0.25, body.midX + body.width * 0.18, body.minY + body.height * 0.7)
        }
        let questionId = local.question?.id ?? ""
        let target: TouchTarget
        if let opponent = opponent {
            target = TouchTarget(kind: .opponent, actorId: opponent)
        } else if let choice = choice, bodyTarget {
            target = TouchTarget(kind: .body, balloon: choice, questionId: questionId)
        } else if core.contains(point) {
            target = TouchTarget(kind: .body)
        } else if let choice = choice {
            target = TouchTarget(kind: .balloon, balloon: choice, questionId: questionId)
        } else if local.held != nil && aimGripRect.contains(point) {
            target = TouchTarget(kind: .arc)
        } else if bodyTarget {
            target = TouchTarget(kind: .body)
        } else if local.held != nil && nearArc(point) {
            target = TouchTarget(kind: .arc)
        } else {
            target = TouchTarget(kind: .world)
        }
        gesture.down(id, Double(x), Double(y), now, target)
    }

    private func nearArc(_ p: CGPoint) -> Bool {
        guard aimPoints.count >= 2 else { return false }
        let reach = CGFloat(engine.config.arcTouchDp)
        for i in 0..<(aimPoints.count - 1) {
            let a = aimPoints[i]
            let b = aimPoints[i + 1]
            let dx = b.x - a.x
            let dy = b.y - a.y
            let t = min(max(((p.x - a.x) * dx + (p.y - a.y) * dy) / max(dx * dx + dy * dy, 1), 0), 1)
            if hypot(p.x - a.x - t * dx, p.y - a.y - t * dy) < reach { return true }
        }
        return false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Android ACTION_MOVE reports every pointer.
        let ids = touchesById.keys.sorted()
        for id in ids {
            guard let touch = touchesById[id] else { continue }
            let p = touch.location(in: self)
            gesture.move(id, Double(p.x), Double(p.y))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
            let p = touch.location(in: self)
            guard let id = releasePointer(touch) else { continue }
            if !running && touchesById.isEmpty {
                start()
                continue
            }
            gesture.up(id, Double(p.x), Double(p.y), Int64(touch.timestamp * 1000))
            // Recognition has its own deadline; a busy graphics frame must not postpone a tap.
            let delay = UInt64(engine.config.doubleTapMs + 1) * 1_000_000
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: delay)
                guard let self = self, self.running else { return }
                self.gesture.flush(SplashClock.uptimeMillis())
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { _ = releasePointer(touch) }
        gesture.cancel()
    }
}
