import CoreGraphics
import XCTest
@testable import MinikPlus

final class PingPongTableLayoutTests: XCTestCase {
    func testTableMappingRoundTripsAcrossSupportedAspectRatios() {
        let sizes = [
            CGSize(width: 430, height: 760),
            CGSize(width: 768, height: 1024),
            CGSize(width: 844, height: 390)
        ]
        let tablePoints = [
            CGPoint(x: 0.01, y: 0.01),
            CGPoint(x: 0.5, y: 0.5),
            CGPoint(x: 0.99, y: 0.99)
        ]

        for size in sizes {
            let layout = PingPongTableLayout(containerSize: size)
            let container = CGRect(origin: .zero, size: size)
            XCTAssertTrue(container.contains(layout.arenaFrame))
            XCTAssertTrue(layout.arenaFrame.contains(layout.tableFrame))

            for tablePoint in tablePoints {
                let scenePoint = layout.scenePoint(fromTablePoint: tablePoint)
                XCTAssertTrue(layout.containsScenePoint(scenePoint))
                let roundTrip = layout.tablePoint(fromScenePoint: scenePoint)
                XCTAssertEqual(roundTrip?.x ?? -1, tablePoint.x, accuracy: 0.0001)
                XCTAssertEqual(roundTrip?.y ?? -1, tablePoint.y, accuracy: 0.0001)
            }
        }
    }

    func testDecorativeAreaIsNotPlayableTableInput() throws {
        for size in [
            CGSize(width: 430, height: 760),
            CGSize(width: 768, height: 1024),
            CGSize(width: 844, height: 390)
        ] {
            let layout = PingPongTableLayout(containerSize: size)
            let outside = CGPoint(x: 1, y: 1)
            XCTAssertFalse(layout.containsScenePoint(outside))
            XCTAssertNil(layout.tablePoint(fromScenePoint: outside))

            let tableCenter = CGPoint(x: layout.tableFrame.midX, y: layout.tableFrame.midY)
            let normalizedCenter = try XCTUnwrap(
                layout.tablePoint(fromScenePoint: tableCenter)
            )
            XCTAssertEqual(normalizedCenter.x, 0.5, accuracy: 0.0001)
            XCTAssertEqual(normalizedCenter.y, 0.5, accuracy: 0.0001)
        }
    }

    func testLogicalTablePredicateAcceptsOnlyNormalizedTableCoordinates() {
        XCTAssertTrue(PingPongTableGeometry.isInsideTable(CGPoint(x: 0, y: 0)))
        XCTAssertTrue(PingPongTableGeometry.isInsideTable(CGPoint(x: 1, y: 1)))
        XCTAssertFalse(PingPongTableGeometry.isInsideTable(CGPoint(x: -0.001, y: 0.5)))
        XCTAssertFalse(PingPongTableGeometry.isInsideTable(CGPoint(x: 0.5, y: 1.001)))
        XCTAssertFalse(PingPongServeInput.acceptsTap(at: nil))
        XCTAssertFalse(PingPongServeInput.acceptsTap(at: CGPoint(x: -0.001, y: 0.5)))
        XCTAssertTrue(PingPongServeInput.acceptsTap(at: CGPoint(x: 0.5, y: 0.5)))
    }
}
