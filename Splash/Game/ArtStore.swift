import UIKit

/// Port of Android ArtStore.kt: atlases, directional atlases, balloons, tinted splashes,
/// scenery and the timed pose selection. Art is the Android WebP converted losslessly to PNG.
struct SpriteFrame {
    let rect: CGRect
    let handX: CGFloat
    let handY: CGFloat
    let image: UIImage?
}

struct SpriteVisual {
    let frame: SpriteFrame
    let mirrored: Bool
    let key: String
}

/// Android `ArtStore.frame(actor, time)`: the timed pose index (pure, testable).
enum SplashPose {
    static func frame(_ a: SplashActor, _ time: Double) -> Int {
        if time < a.cleanUntil { return 11 }
        if time - a.hitAt < 0.23 { return 10 }
        if a.height > 0.1 { return 8 }
        if time < a.crouchUntil { return 9 }
        if time - a.throwAt < 0.10 { return 6 }
        if time - a.throwAt < 0.30 { return 7 }
        if time - a.pickupAt < 0.18 { return 3 }
        if a.held != nil && time - a.windupAt < 0.25 { return 5 }
        if a.move.length() > 0.12 { return 12 + KotlinNumber.int(a.gait) % 4 }
        if a.held != nil { return 4 }
        return 0
    }

    /// Android `ArtStore.visual` pose mapping for side/back atlases.
    static func directionalPose(_ index: Int) -> Int {
        switch index {
        case 3, 9, 10: return 7
        case 4: return 3
        case 5: return 4
        case 6, 7: return 5
        case 8: return 6
        case 12: return 1
        case 14: return 2
        default: return 0
        }
    }
}

@MainActor
final class ArtStore {
    static let shared = ArtStore()

    static let balloonNames = ["orange", "yellow", "green", "blue", "pink", "cyan"]

    private struct FrameMeta {
        let rect: CGRect
        let hand: CGPoint
    }

    private var frontMeta: [String: [FrameMeta]] = [:]
    private var directionMeta: [String: [FrameMeta]] = [:]
    private var frontFrames: [String: [SpriteFrame]] = [:]
    private var directionFrames: [String: [SpriteFrame]] = [:]
    private var portraits: [String: UIImage] = [:]
    private var images: [String: UIImage] = [:]
    private var wordBalloons: [Int: UIImage] = [:]
    private var paintedCache: [String: UIImage] = [:]
    private var paintedOrder: [String] = []

    private init() {
        frontMeta = ArtStore.loadMeta("atlas")
        directionMeta = ArtStore.loadMeta("directions")
    }

    private static func loadMeta(_ name: String) -> [String: [FrameMeta]] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any],
              let characters = root["characters"] as? [String: Any] else { return [:] }
        var result: [String: [FrameMeta]] = [:]
        for (id, value) in characters {
            guard let entry = value as? [String: Any], let frames = entry["frames"] as? [Any] else { continue }
            var list: [FrameMeta] = []
            for item in frames {
                guard let frame = item as? [String: Any] else { continue }
                let r = NodeValue.list(frame["rect"]).map { NodeValue.number($0) ?? 0 }
                let h = NodeValue.list(frame["hand"]).map { NodeValue.number($0) ?? 0 }
                guard r.count == 4, h.count == 2 else { continue }
                list.append(FrameMeta(rect: CGRect(x: r[0], y: r[1], width: r[2], height: r[3]), hand: CGPoint(x: h[0], y: h[1])))
            }
            result[id] = list
        }
        return result
    }

    /// Releases decoded art after a memory warning; everything reloads on demand.
    func purge() {
        frontFrames.removeAll()
        directionFrames.removeAll()
        images.removeAll()
        wordBalloons.removeAll()
        paintedCache.removeAll()
        paintedOrder.removeAll()
    }

    func image(_ name: String) -> UIImage? {
        if let cached = images[name] { return cached }
        guard let loaded = UIImage(named: name) else { return nil }
        images[name] = loaded
        return loaded
    }

    /// Decodes an atlas once so per-frame crops share a ready bitmap.
    private func decoded(_ name: String) -> CGImage? {
        guard let source = UIImage(named: name)?.cgImage else { return nil }
        let width = source.width
        let height = source.height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return source }
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? source
    }

    private func cut(_ atlas: CGImage?, _ meta: [FrameMeta]) -> [SpriteFrame] {
        return meta.map { m -> SpriteFrame in
            var cell: UIImage? = nil
            if let atlas = atlas, let cropped = atlas.cropping(to: m.rect) {
                cell = UIImage(cgImage: cropped, scale: 1, orientation: .up)
            }
            return SpriteFrame(rect: m.rect, handX: m.hand.x, handY: m.hand.y, image: cell)
        }
    }

    func frames(_ character: String) -> [SpriteFrame] {
        if let cached = frontFrames[character] { return cached }
        let made = cut(decoded(character), frontMeta[character] ?? [])
        frontFrames[character] = made
        return made
    }

    func directional(_ character: String) -> [SpriteFrame] {
        if let cached = directionFrames[character] { return cached }
        let made = cut(decoded(character + "_directions"), directionMeta[character] ?? [])
        directionFrames[character] = made
        return made
    }

    /// The first 256 x 320 cell (ready pose) used on the home screen and in results.
    func portrait(_ character: String) -> UIImage? {
        if let cached = portraits[character] { return cached }
        guard let atlas = UIImage(named: character)?.cgImage,
              let cropped = atlas.cropping(to: CGRect(x: 0, y: 0, width: 256, height: 320)) else { return nil }
        let cell = UIImage(cgImage: cropped, scale: 1, orientation: .up)
        portraits[character] = cell
        return cell
    }

    func visual(_ a: SplashActor, _ index: Int) -> SpriteVisual? {
        let facing = Facing.of(a.facing)
        if facing == .front {
            let list = frames(a.member.character)
            guard index >= 0 && index < list.count else { return nil }
            return SpriteVisual(frame: list[index], mirrored: false, key: "front-\(index)")
        }
        let frame = SplashPose.directionalPose(index) + (facing == .back ? 8 : 0)
        let list = directional(a.member.character)
        guard frame < list.count else { return nil }
        return SpriteVisual(frame: list[frame], mirrored: facing == .left, key: "direction-\(frame)")
    }

    func scene(_ arena: Arena) -> UIImage? { return image("arena_" + arena.rawValue.lowercased()) }
    var lagoon: UIImage? { return image("lagoon") }
    var logo: UIImage? { return image("splash_icon") }

    func balloon(_ color: Int) -> UIImage? {
        guard color >= 0 && color < ArtStore.balloonNames.count else { return nil }
        return image("balloon_" + ArtStore.balloonNames[color])
    }

    /// Android `wordBalloonSource = Rect(35, 0, 245, 280)`: transparent side padding cropped.
    func wordBalloon(_ color: Int) -> UIImage? {
        if let cached = wordBalloons[color] { return cached }
        guard let source = balloon(color)?.cgImage,
              let cropped = source.cropping(to: CGRect(x: 35, y: 0, width: 210, height: 280)) else { return nil }
        let trimmed = UIImage(cgImage: cropped, scale: 1, orientation: .up)
        wordBalloons[color] = trimmed
        return trimmed
    }

    func splash(_ shape: Int, _ color: Int) -> UIImage? {
        guard shape >= 0 && shape < 6 && color >= 0 && color < 6 else { return nil }
        return image("splash_\(shape)_c\(color)")
    }

    /// Precomposes stable paint/pose combinations once (Android caches 48, oldest first out).
    func painted(_ a: SplashActor, _ index: Int) -> UIImage? {
        if a.paint.isEmpty { return nil }
        guard let pose = visual(a, index), let base = pose.frame.image else { return nil }
        let stains = a.paint.map { "\($0.color),\($0.u),\($0.v)" }.joined(separator: ";")
        let key = a.member.character + ":" + pose.key + ":" + stains
        if let cached = paintedCache[key] { return cached }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 320), format: format)
        let marks = a.paint
        let composed = renderer.image { _ in
            base.draw(in: CGRect(x: 0, y: 0, width: 256, height: 320))
            for stain in marks {
                let x = 256 * CGFloat(stain.u)
                let y = 320 * CGFloat(stain.v)
                let w: CGFloat = 256 * 0.43
                splash(1, stain.color)?.draw(in: CGRect(x: x - w / 2, y: y - w / 2, width: w, height: w),
                                             blendMode: .sourceAtop, alpha: 220.0 / 255.0)
            }
        }
        if paintedOrder.count >= 48 {
            let first = paintedOrder.removeFirst()
            paintedCache.removeValue(forKey: first)
        }
        paintedCache[key] = composed
        paintedOrder.append(key)
        return composed
    }
}
