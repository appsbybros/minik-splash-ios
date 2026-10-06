import SpriteKit
import SwiftUI
import UIKit

enum PingPongVisualStyle: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case modern
    case retro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .modern: return String(localized: "Modern")
        case .retro: return String(localized: "80s Style")
        }
    }
}

/// Colors and proportions of the Minik Math web Ping Pong reference
/// (900 x 560 canvas, radial #29284d -> #11111f field, dashed center line).
enum PingPongRetroPalette {
    static let backdrop = UIColor(red: 23 / 255, green: 23 / 255, blue: 40 / 255, alpha: 1)
    static let fieldCenter = UIColor(red: 41 / 255, green: 40 / 255, blue: 77 / 255, alpha: 1)
    static let fieldEdge = UIColor(red: 17 / 255, green: 17 / 255, blue: 31 / 255, alpha: 1)
    static let centerLine = UIColor(red: 69 / 255, green: 65 / 255, blue: 120 / 255, alpha: 0.24)
    static let childPaddle = UIColor(red: 105 / 255, green: 216 / 255, blue: 168 / 255, alpha: 1)
    static let minikPaddle = UIColor(red: 245 / 255, green: 140 / 255, blue: 200 / 255, alpha: 1)
    static let ballStroke = UIColor(red: 45 / 255, green: 42 / 255, blue: 88 / 255, alpha: 0.38)
    static let ballGlow = UIColor(red: 159 / 255, green: 146 / 255, blue: 255 / 255, alpha: 1)

    static var backgroundGradient: RadialGradient {
        RadialGradient(
            colors: [Color(uiColor: fieldCenter), Color(uiColor: fieldEdge)],
            center: .center,
            startRadius: 0,
            endRadius: 700
        )
    }
}

/// Fixed 80s Style lines in normalized table units (x = lateral, y = depth).
/// Paddles sit on fixed lines at the left/right field edges and contact
/// happens when the ball's edge meets a paddle face.
struct PingPongRetroGeometry: Equatable {
    var childPaddleDepth: CGFloat = 0.97
    var minikPaddleDepth: CGFloat = 0.03
    var childContactDepth: CGFloat = 0.95
    var minikContactDepth: CGFloat = 0.05
    var ballLateralRange: ClosedRange<CGFloat> = 0.02...0.98
    var paddleLateralRange: ClosedRange<CGFloat> = 0.1...0.9
    var paddleHalfLength: CGFloat = 0.1
    var ballLateralRadius: CGFloat = 0.02
}

/// Maps normalized table coordinates onto the 80s Style field. The table is
/// turned on its side: the child's end (y = 1) is the left edge, Minik's end
/// (y = 0) is the right edge and the net is the dashed center line.
struct PingPongRetroLayout: Equatable {
    /// Web reference proportions on its 900 x 560 canvas.
    enum Reference {
        static let shortSide: CGFloat = 560
        static let paddleWidth: CGFloat = 18
        static let paddleHeight: CGFloat = 112
        static let paddleCornerRadius: CGFloat = 9
        static let paddleEdgeInset: CGFloat = 16
        static let ballRadius: CGFloat = 13.5
        static let ballGlowBlur: CGFloat = 18
        static let ballStrokeWidth: CGFloat = 3
        static let fieldCornerRadius: CGFloat = 30
        static let centerLineWidth: CGFloat = 3
        static let centerLineDash: CGFloat = 10
        static let centerLineGap: CGFloat = 14
        static let centerLineInset: CGFloat = 20
    }

    static let widestAspect: CGFloat = 1.8
    static let tallestAspect: CGFloat = 0.55

    let containerSize: CGSize
    let fieldFrame: CGRect

    init(containerSize: CGSize) {
        self.containerSize = containerSize

        guard containerSize.width > 0, containerSize.height > 0 else {
            fieldFrame = .zero
            return
        }

        // Leave room for the SwiftUI score header (top) and status capsule (bottom).
        let horizontalInset: CGFloat = 16
        let topInset = (containerSize.height * 0.15).clamped(to: 84...150)
        let bottomInset = (containerSize.height * 0.10).clamped(to: 72...110)
        let availableHeight = max(containerSize.height - topInset - bottomInset, 1)
        var width = max(containerSize.width - horizontalInset * 2, 1)
        var height = availableHeight
        if width / height > Self.widestAspect {
            width = height * Self.widestAspect
        }
        if width / height < Self.tallestAspect {
            height = width / Self.tallestAspect
        }
        fieldFrame = CGRect(
            x: (containerSize.width - width) / 2,
            y: bottomInset + (availableHeight - height) / 2,
            width: width,
            height: height
        )
    }

    /// Scale from the web reference's 560-point short side to this field.
    var unit: CGFloat {
        min(fieldFrame.width, fieldFrame.height) / Reference.shortSide
    }

    var geometry: PingPongRetroGeometry {
        guard fieldFrame.width > 0, fieldFrame.height > 0 else {
            return PingPongRetroGeometry()
        }
        let width = fieldFrame.width
        let height = fieldFrame.height
        let paddleLineOffset = (Reference.paddleEdgeInset + Reference.paddleWidth / 2) * unit / width
        let contactOffset = (
            Reference.paddleEdgeInset + Reference.paddleWidth + Reference.ballRadius
        ) * unit / width
        let ballRadius = min(Reference.ballRadius * unit / height, 0.2)
        let paddleHalfLength = min(Reference.paddleHeight * unit / 2 / height, 0.45)
        return PingPongRetroGeometry(
            childPaddleDepth: 1 - paddleLineOffset,
            minikPaddleDepth: paddleLineOffset,
            childContactDepth: 1 - contactOffset,
            minikContactDepth: contactOffset,
            ballLateralRange: ballRadius...(1 - ballRadius),
            paddleLateralRange: paddleHalfLength...(1 - paddleHalfLength),
            paddleHalfLength: paddleHalfLength,
            ballLateralRadius: ballRadius
        )
    }

    /// Input mapping. Not limited to the field, so a touch anywhere on screen
    /// still steers the paddle by its vertical position.
    func tablePoint(fromScenePoint point: CGPoint) -> CGPoint? {
        guard fieldFrame.width > 0, fieldFrame.height > 0 else {
            return nil
        }
        return CGPoint(
            x: (fieldFrame.maxY - point.y) / fieldFrame.height,
            y: 1 - (point.x - fieldFrame.minX) / fieldFrame.width
        )
    }

    func scenePoint(fromTablePoint point: CGPoint) -> CGPoint {
        CGPoint(
            x: fieldFrame.minX + (1 - point.y) * fieldFrame.width,
            y: fieldFrame.maxY - point.x * fieldFrame.height
        )
    }
}

/// Presentation-only layer for 80s Style: dark field, dashed center line,
/// glowing ball and two paddles fixed on the left/right paddle lines.
final class PingPongRetroLayer: SKNode {
    private typealias Reference = PingPongRetroLayout.Reference

    private let backdropNode = SKSpriteNode(color: PingPongRetroPalette.backdrop, size: .zero)
    private let fieldNode = SKSpriteNode()
    private let childPaddleNode = SKShapeNode()
    private let minikPaddleNode = SKShapeNode()
    private let ballNode = SKSpriteNode()

    private var fieldLayout = PingPongRetroLayout(containerSize: .zero)
    private var geometry = PingPongRetroGeometry()

    override init() {
        super.init()
        backdropNode.zPosition = 0
        fieldNode.zPosition = 1
        childPaddleNode.zPosition = 2
        minikPaddleNode.zPosition = 2
        ballNode.zPosition = 3
        for paddle in [childPaddleNode, minikPaddleNode] {
            paddle.lineWidth = 0
            paddle.strokeColor = .clear
        }
        childPaddleNode.fillColor = PingPongRetroPalette.childPaddle
        minikPaddleNode.fillColor = PingPongRetroPalette.minikPaddle
        ballNode.isHidden = true
        addChild(backdropNode)
        addChild(fieldNode)
        addChild(childPaddleNode)
        addChild(minikPaddleNode)
        addChild(ballNode)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func layout(_ layout: PingPongRetroLayout, sceneSize: CGSize) {
        fieldLayout = layout
        geometry = layout.geometry
        guard layout.fieldFrame.width > 0, layout.fieldFrame.height > 0 else { return }
        let unit = layout.unit
        let field = layout.fieldFrame

        backdropNode.size = sceneSize
        backdropNode.position = CGPoint(x: sceneSize.width / 2, y: sceneSize.height / 2)

        fieldNode.texture = Self.fieldTexture(size: field.size, unit: unit)
        fieldNode.size = field.size
        fieldNode.position = CGPoint(x: field.midX, y: field.midY)

        let paddleSize = CGSize(
            width: Reference.paddleWidth * unit,
            height: Reference.paddleHeight * unit
        )
        let paddleRect = CGRect(
            x: -paddleSize.width / 2,
            y: -paddleSize.height / 2,
            width: paddleSize.width,
            height: paddleSize.height
        )
        let radius = min(Reference.paddleCornerRadius * unit, paddleSize.width / 2)
        let paddlePath = CGPath(
            roundedRect: paddleRect,
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        childPaddleNode.path = paddlePath
        minikPaddleNode.path = paddlePath

        let ball = Self.ballTexture(unit: unit)
        ballNode.texture = ball.texture
        ballNode.size = ball.size
    }

    /// Draws the 80s rally state. Paddle depth is fixed on the edge lines;
    /// only the lateral (screen-vertical) position changes.
    func render(ballPosition: CGPoint?, childLateral: CGFloat, minikLateral: CGFloat) {
        guard fieldLayout.fieldFrame.width > 0, fieldLayout.fieldFrame.height > 0 else { return }
        if let ballPosition {
            ballNode.isHidden = false
            ballNode.position = fieldLayout.scenePoint(fromTablePoint: ballPosition)
        } else {
            ballNode.isHidden = true
        }
        childPaddleNode.position = fieldLayout.scenePoint(fromTablePoint: CGPoint(
            x: childLateral.clamped(to: geometry.paddleLateralRange),
            y: geometry.childPaddleDepth
        ))
        minikPaddleNode.position = fieldLayout.scenePoint(fromTablePoint: CGPoint(
            x: minikLateral.clamped(to: geometry.paddleLateralRange),
            y: geometry.minikPaddleDepth
        ))
    }

    private static func fieldTexture(size: CGSize, unit: CGFloat) -> SKTexture {
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let cgContext = context.cgContext
            let rect = CGRect(origin: .zero, size: size)
            UIBezierPath(
                roundedRect: rect,
                cornerRadius: Reference.fieldCornerRadius * unit
            ).addClip()

            let colors = [
                PingPongRetroPalette.fieldCenter.cgColor,
                PingPongRetroPalette.fieldEdge.cgColor
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            ) {
                let center = CGPoint(x: rect.midX, y: rect.midY)
                cgContext.drawRadialGradient(
                    gradient,
                    startCenter: center,
                    startRadius: 0,
                    endCenter: center,
                    endRadius: hypot(rect.width, rect.height) / 2,
                    options: [.drawsAfterEndLocation]
                )
            }

            cgContext.setStrokeColor(PingPongRetroPalette.centerLine.cgColor)
            cgContext.setLineWidth(Reference.centerLineWidth * unit)
            cgContext.setLineDash(
                phase: 0,
                lengths: [Reference.centerLineDash * unit, Reference.centerLineGap * unit]
            )
            cgContext.move(to: CGPoint(x: rect.midX, y: Reference.centerLineInset * unit))
            cgContext.addLine(to: CGPoint(
                x: rect.midX,
                y: rect.height - Reference.centerLineInset * unit
            ))
            cgContext.strokePath()
        }
        return SKTexture(image: image)
    }

    private static func ballTexture(unit: CGFloat) -> (texture: SKTexture, size: CGSize) {
        let radius = Reference.ballRadius * unit
        let blur = Reference.ballGlowBlur * unit
        let strokeWidth = Reference.ballStrokeWidth * unit
        let side = ceil((radius + blur + strokeWidth) * 2)
        let size = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat.default()
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cgContext = context.cgContext
            let circle = CGRect(
                x: side / 2 - radius,
                y: side / 2 - radius,
                width: radius * 2,
                height: radius * 2
            )
            // Shadow blur is specified in device pixels, so scale it with the renderer.
            cgContext.setShadow(
                offset: .zero,
                blur: blur * format.scale,
                color: PingPongRetroPalette.ballGlow.cgColor
            )
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fillEllipse(in: circle)
            cgContext.setStrokeColor(PingPongRetroPalette.ballStroke.cgColor)
            cgContext.setLineWidth(strokeWidth)
            cgContext.strokeEllipse(in: circle)
        }
        return (SKTexture(image: image), size)
    }
}
