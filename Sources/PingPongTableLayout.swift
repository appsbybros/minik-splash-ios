import CoreGraphics

/// Maps normalized table coordinates to the table painted into the arena asset.
/// The calibrated image-space rect follows the outer white table edge in the
/// 941 x 1672 production arena. Aspect-fit keeps that complete surface visible
/// on iPhone, iPad, and landscape layouts without stretching it.
struct PingPongTableLayout: Equatable {
    static let arenaImageSize = CGSize(width: 941, height: 1672)
    static let tableImageRectFromTopLeft = CGRect(
        x: 93,
        y: 186,
        width: 754,
        height: 1251
    )

    let containerSize: CGSize
    let arenaFrame: CGRect
    let tableFrame: CGRect

    init(containerSize: CGSize) {
        self.containerSize = containerSize

        guard containerSize.width > 0, containerSize.height > 0 else {
            arenaFrame = .zero
            tableFrame = .zero
            return
        }

        let scale = min(
            containerSize.width / Self.arenaImageSize.width,
            containerSize.height / Self.arenaImageSize.height
        )
        let arenaSize = CGSize(
            width: Self.arenaImageSize.width * scale,
            height: Self.arenaImageSize.height * scale
        )
        let arenaOrigin = CGPoint(
            x: (containerSize.width - arenaSize.width) / 2,
            y: (containerSize.height - arenaSize.height) / 2
        )
        arenaFrame = CGRect(origin: arenaOrigin, size: arenaSize)

        let imageRect = Self.tableImageRectFromTopLeft
        tableFrame = CGRect(
            x: arenaFrame.minX + imageRect.minX * scale,
            y: arenaFrame.maxY - (imageRect.maxY * scale),
            width: imageRect.width * scale,
            height: imageRect.height * scale
        )
    }

    func containsScenePoint(_ point: CGPoint) -> Bool {
        tableFrame.contains(point)
    }

    func tablePoint(fromScenePoint point: CGPoint) -> CGPoint? {
        guard tableFrame.width > 0,
              tableFrame.height > 0,
              containsScenePoint(point) else {
            return nil
        }
        return CGPoint(
            x: (point.x - tableFrame.minX) / tableFrame.width,
            y: (tableFrame.maxY - point.y) / tableFrame.height
        )
    }

    func scenePoint(fromTablePoint point: CGPoint) -> CGPoint {
        CGPoint(
            x: tableFrame.minX + point.x * tableFrame.width,
            y: tableFrame.maxY - point.y * tableFrame.height
        )
    }
}
