import UIKit

/// One atlas cell: its pixel rectangle and the hand anchor normalized to the 256x320 cell (Android `SpriteFrame`).
struct SpriteFrame {
    let rect: CGRect
    let handX: CGFloat
    let handY: CGFloat
}

/// Android `SpriteVisual`: the cropped cell to draw, its frame data, and whether side art is mirrored.
struct SpriteVisual {
    let image: UIImage
    let frame: SpriteFrame
    let mirrored: Bool
    let facing: String
}

private final class ArtBundleToken {}

/// Android `ArtStore`: the approved character atlases (front + directional), arenas and balls, with
/// `atlas.json` / `directions.json` frame crops and hand anchors.
final class ArtStore {
    private(set) var frames: [String: [SpriteFrame]] = [:]
    private(set) var directionalFrames: [String: [SpriteFrame]] = [:]
    private var frameImages: [String: [UIImage]] = [:]
    private var directionalImages: [String: [UIImage]] = [:]
    private var portraits: [String: UIImage] = [:]
    private(set) var scenes: [ArenaScene: UIImage] = [:]
    private(set) var balls: [BallKind: UIImage] = [:]
    private let placeholderFrame = SpriteFrame(rect: CGRect(x: 0, y: 0, width: 256, height: 320), handX: 0.5, handY: 0.6)

    init() {
        let bundle = Bundle(for: ArtBundleToken.self)
        for arena in ArenaScene.allCases { scenes[arena] = ArtStore.load(arena.artName, bundle) }
        for kind in BallKind.allCases { balls[kind] = ArtStore.load(kind.artName, bundle) }
        let atlas = ArtStore.characters(ArtStore.json("atlas", bundle))
        let directional = ArtStore.characters(ArtStore.json("directions", bundle))
        for c in AmuduCharacters.all {
            let sheet = ArtStore.load(c.id, bundle)
            let side = ArtStore.load(c.id + "_directions", bundle)
            let front = ArtStore.parse(atlas, c.id)
            let directions = ArtStore.parse(directional, c.id)
            frames[c.id] = front
            directionalFrames[c.id] = directions
            frameImages[c.id] = front.map { ArtStore.crop(sheet, $0.rect) }
            directionalImages[c.id] = directions.map { ArtStore.crop(side, $0.rect) }
            portraits[c.id] = ArtStore.crop(sheet, CGRect(x: 0, y: 0, width: 256, height: 320))
        }
    }

    private static func load(_ name: String, _ bundle: Bundle) -> UIImage {
        if let image = UIImage(named: name, in: bundle, compatibleWith: nil) { return image }
        if let image = UIImage(named: name) { return image }
        return UIImage()
    }

    private static func json(_ name: String, _ bundle: Bundle) -> [String: Any] {
        guard let url = bundle.url(forResource: name, withExtension: "json") ?? Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object
    }

    private static func characters(_ root: [String: Any]) -> [String: Any] {
        return (root["characters"] as? [String: Any]) ?? [:]
    }

    /// Hand anchors in both files are pixels of a 256x320 cell; Android normalizes x/256 and y/320.
    private static func parse(_ table: [String: Any], _ id: String) -> [SpriteFrame] {
        guard let entry = table[id] as? [String: Any], let list = entry["frames"] as? [Any] else { return [] }
        var out: [SpriteFrame] = []
        for item in list {
            guard let f = item as? [String: Any] else { continue }
            let r = (f["rect"] as? [Any])?.compactMap { AmuduCodec.number($0) } ?? []
            let h = (f["hand"] as? [Any])?.compactMap { AmuduCodec.number($0) } ?? []
            guard r.count >= 4, h.count >= 2 else { continue }
            let rect = CGRect(x: r[0], y: r[1], width: r[2], height: r[3])
            out.append(SpriteFrame(rect: rect, handX: CGFloat(h[0] / 256.0), handY: CGFloat(h[1] / 320.0)))
        }
        return out
    }

    private static func crop(_ image: UIImage, _ rect: CGRect) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let scale = image.scale
        let pixels = CGRect(x: rect.origin.x * scale, y: rect.origin.y * scale, width: rect.width * scale, height: rect.height * scale)
        guard let part = cg.cropping(to: pixels) else { return UIImage() }
        return UIImage(cgImage: part, scale: 1, orientation: .up)
    }

    func scene(_ scene: ArenaScene) -> UIImage { return scenes[scene] ?? UIImage() }

    func ball(_ kind: BallKind) -> UIImage { return balls[kind] ?? UIImage() }

    func portrait(_ id: String) -> UIImage { return portraits[AmuduCharacters.get(id).id] ?? UIImage() }

    /// Android `ArtStore.frame`: which of the 16 front cells an actor shows right now.
    func frame(_ a: GameActor, _ e: AmuduEngine) -> Int {
        if e.time - a.hitAt < 0.32 { return 10 }
        if e.time < a.duckUntil { return 9 }
        if e.time - a.throwAt < 0.13 { return 6 }
        if e.time - a.throwAt < 0.42 { return 7 }
        if e.time - a.catchAt < 0.35 { return 4 }
        // Hold the open-hand reach pose; never use a walk frame for a catch attempt.
        if e.time < a.catchUntil { return 6 }
        if a.actuallyMoving { return 12 + Kotlin.toInt(a.gait) % 4 }
        if e.ball.holder == a.member.id { return 4 }
        return 0
    }

    func visual(_ a: GameActor, _ e: AmuduEngine) -> SpriteVisual {
        let id = AmuduCharacters.get(a.member.character).id
        let index = frame(a, e)
        let facing: String
        if abs(a.facing.x) > abs(a.facing.y) * 0.85 {
            facing = a.facing.x < 0 ? "left" : "right"
        } else {
            facing = a.facing.y < 0 ? "back" : "front"
        }
        if facing == "front" {
            return SpriteVisual(image: cell(frameImages[id], index), frame: cellFrame(frames[id], index), mirrored: false, facing: facing)
        }
        let pose: Int
        switch index {
        case 2, 4: pose = 3
        case 5: pose = 4
        case 6, 7: pose = 5
        case 8: pose = 6
        case 9, 10: pose = 7
        case 12: pose = 1
        case 14: pose = 2
        default: pose = 0
        }
        let directional = pose + (facing == "back" ? 8 : 0)
        return SpriteVisual(image: cell(directionalImages[id], directional), frame: cellFrame(directionalFrames[id], directional),
                            mirrored: facing == "left", facing: facing)
    }

    private func cell(_ images: [UIImage]?, _ index: Int) -> UIImage {
        guard let images, index >= 0, index < images.count else { return UIImage() }
        return images[index]
    }

    private func cellFrame(_ list: [SpriteFrame]?, _ index: Int) -> SpriteFrame {
        guard let list, index >= 0, index < list.count else { return placeholderFrame }
        return list[index]
    }
}
