import XCTest
@testable import MinikMultiPingPong

// Android cross/CrossGeometryTest.kt (MinikCrossPong 828c6fc).
final class CrossGeometryTests: XCTestCase {
    private let tables = [CrossGeometry(3), CrossGeometry(4)]

    private func angleDiff(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 2 * Double.pi)
        if d > Double.pi { d -= 2 * Double.pi }
        if d < -Double.pi { d += 2 * Double.pi }
        return d
    }

    private func inConvex(_ p: MPPoint, _ corners: [MPPoint]) -> Bool {
        var signs: [Double] = []
        for i in corners.indices {
            let edge = corners[(i + 1) % corners.count] - corners[i]
            signs.append(edge.cross(p - corners[i]))
        }
        return signs.allSatisfy { $0 >= 0 } || signs.allSatisfy { $0 <= 0 }
    }

    private func arms(_ shapes: [CrossTableShape]) -> [(seat: Int, corners: [MPPoint])] {
        var found: [(seat: Int, corners: [MPPoint])] = []
        for shape in shapes {
            if case let .arm(seat, corners) = shape { found.append((seat: seat, corners: corners)) }
        }
        return found
    }

    private func hubs(_ shapes: [CrossTableShape]) -> [Double] {
        var found: [Double] = []
        for shape in shapes {
            if case let .hub(radius) = shape { found.append(radius) }
        }
        return found
    }

    // Kotlin: twoToFourSeats
    func testTwoToFourSeats() {
        // Swift clamps instead of throwing: Android rejects 0, 1 and 5 seats; a corrupt record is clamped to 2...4 on iOS.
        XCTAssertEqual(2, CrossGeometry(0).players)
        XCTAssertEqual(2, CrossGeometry(1).players)
        XCTAssertEqual(4, CrossGeometry(5).players)
        let two = CrossGeometry(2)
        // One straight net across the middle; each player owns a half of a 1 x 2.2 table.
        XCTAssertEqual(2, two.nets.count)
        XCTAssertEqual(0.5, two.netLength, accuracy: 1e-9)
        XCTAssertEqual(0, two.owner(MPPoint(0.3, 0.5)))
        XCTAssertEqual(1, two.owner(MPPoint(-0.3, -0.5)))
        XCTAssertNil(two.owner(MPPoint(0.7, 0.5)))
        XCTAssertNil(two.owner(MPPoint(0, 1.3)))
    }

    // Kotlin: seatZeroSitsAtTheBottomWithItsRightHandAtScreenRight
    func testSeatZeroSitsAtTheBottomWithItsRightHandAtScreenRight() {
        for g in tables {
            assertNear(MPPoint(0, 1), g.dir(0), 0)
            assertNear(MPPoint(1, 0), g.right(0), 0)
            for i in g.seats {
                XCTAssertEqual(1.0, g.dir(i).length, accuracy: 1e-12)
                XCTAssertEqual(0.0, g.dir(i).dot(g.right(i)), accuracy: 1e-12)
                // Same handedness for every seat: facing inward, the right hand is screen-clockwise.
                XCTAssertEqual(1.0, g.right(i).cross(g.dir(i)), accuracy: 1e-12)
                let a: Double = 2 * Double.pi * Double(i) / Double(g.players)
                assertNear(MPPoint(sin(a), cos(a)), g.dir(i), 1e-12)
                assertNear(MPPoint(cos(a), -sin(a)), g.right(i), 1e-12)
            }
        }
        let four = CrossGeometry(4)
        assertNear(MPPoint(1, 0), four.dir(1), 0)
        assertNear(MPPoint(0, -1), four.dir(2), 0)
        assertNear(MPPoint(-1, 0), four.dir(3), 0)
        let three = CrossGeometry(3)
        XCTAssertTrue(three.dir(1).x > 0 && three.dir(1).y < 0) // upper right
        XCTAssertTrue(three.dir(2).x < 0 && three.dir(2).y < 0) // upper left
        XCTAssertEqual(three.dir(1), three.dir(4))
        XCTAssertEqual(four.right(3), four.right(-1))
    }

    // Kotlin: armEndsAreNinetyOrOneHundredTwentyDegreesApart
    func testArmEndsAreNinetyOrOneHundredTwentyDegreesApart() {
        for g in tables {
            let expected: Double = g.players == 4 ? 90 : 120
            for i in g.seats {
                let a = g.fromLocal(i, 0, CrossGeometry.reach)
                let b = g.fromLocal(i + 1, 0, CrossGeometry.reach)
                XCTAssertEqual(CrossGeometry.reach, a.length, accuracy: 1e-12)
                let cosine: Double = (a.dot(b) / (a.length * b.length)).mpClamp(-1, 1)
                let degrees: Double = acos(cosine) * 180 / Double.pi
                XCTAssertEqual(expected, degrees, accuracy: 1e-9)
                assertNear(CrossGeometry.rotate(a, g.sector), b, 1e-12)
            }
        }
    }

    // Kotlin: everySeatIsSeatZeroRotated
    func testEverySeatIsSeatZeroRotated() {
        for g in tables {
            for k in g.seats {
                let alpha = g.angle(k)
                assertNear(CrossGeometry.rotate(g.dir(0), alpha), g.dir(k), 1e-12)
                assertNear(CrossGeometry.rotate(g.right(0), alpha), g.right(k), 1e-12)
                assertNear(CrossGeometry.rotate(g.home(0), alpha), g.home(k), 1e-12)
                for p in samples(500, seed: Int32(31 + k)) {
                    let q = CrossGeometry.rotate(p, alpha)
                    XCTAssertEqual(g.onTable(p), g.onTable(q))
                    XCTAssertEqual(g.owner(p).map { g.wrap($0 + k) }, g.owner(q))
                    for s in g.seats {
                        XCTAssertEqual(g.inArm(s, p), g.inArm(s + k, q))
                        XCTAssertEqual(g.inStrikeZone(s, p), g.inStrikeZone(s + k, q))
                        XCTAssertEqual(g.inServeZone(s, p), g.inServeZone(s + k, q))
                        let a = g.toLocal(s, p)
                        let b = g.toLocal(s + k, q)
                        XCTAssertEqual(a.u, b.u, accuracy: 1e-12)
                        XCTAssertEqual(a.v, b.v, accuracy: 1e-12)
                    }
                }
                for net in g.nets {
                    let matching = g.nets.filter { $0.left == g.wrap(net.left + k) }
                    XCTAssertEqual(1, matching.count)
                    if let other = matching.first { assertNear(CrossGeometry.rotate(net.end, alpha), other.end, 1e-12) }
                }
            }
        }
    }

    // Kotlin: seatViewPutsThatSeatAtTheBottomAndRoundTripsPointsAndVelocities
    func testSeatViewPutsThatSeatAtTheBottomAndRoundTripsPointsAndVelocities() {
        for g in tables {
            for k in g.seats {
                assertNear(MPPoint(0, 1), g.toView(k, g.dir(k)), 1e-12)
                assertNear(MPPoint(1, 0), g.toView(k, g.right(k)), 1e-12)
                assertNear(MPPoint(0, CrossGeometry.homeDepth), g.toView(k, g.home(k)), 1e-12)
                for p in samples(300, seed: Int32(7 * k + 3)) {
                    assertNear(CrossGeometry.rotate(p, -g.angle(k)), g.toView(k, p), 1e-12) // spec: toView = rotate(p, -θk)
                    assertNear(CrossGeometry.rotate(p, g.angle(k)), g.fromView(k, p), 1e-12)
                    assertNear(p, g.fromView(k, g.toView(k, p)), 1e-12)
                    assertNear(p, g.toView(k, g.fromView(k, p)), 1e-12)
                    XCTAssertEqual(p.length, g.toView(k, p).length, accuracy: 1e-12)
                }
                // Velocities transform with the same linear map: a moving point's view moves with the viewed velocity.
                let points = samples(100, seed: Int32(11 + k))
                let velocities = samples(100, seed: Int32(23 + k), span: 3.0)
                for (p, w) in zip(points, velocities) {
                    let dt = 0.37
                    assertNear(g.toView(k, p) + g.toView(k, w) * dt, g.toView(k, p + w * dt), 1e-12)
                    assertNear(w, g.fromView(k, g.toView(k, w)), 1e-12)
                    assertNear(w, g.toView(k, g.fromView(k, w)), 1e-12)
                }
            }
        }
    }

    // Kotlin: opponentsAppearWhereTheAimMapNamesThem
    func testOpponentsAppearWhereTheAimMapNamesThem() {
        let four = CrossGeometry(4)
        for k in four.seats {
            assertNear(MPPoint(1, 0), four.toView(k, four.dir(k + 1)), 1e-12)
            assertNear(MPPoint(0, -1), four.toView(k, four.dir(k + 2)), 1e-12)
            assertNear(MPPoint(-1, 0), four.toView(k, four.dir(k + 3)), 1e-12)
        }
        let three = CrossGeometry(3)
        for k in three.seats {
            let right = three.toView(k, three.dir(k + 1))
            let left = three.toView(k, three.dir(k + 2))
            XCTAssertTrue(right.x > 0 && right.y < 0)
            XCTAssertTrue(left.x < 0 && left.y < 0)
        }
    }

    // Kotlin: everyTablePointHasExactlyOneOwnerAndOffTablePointsNone
    func testEveryTablePointHasExactlyOneOwnerAndOffTablePointsNone() {
        for g in tables {
            var onTable = 0
            for p in samples(20000, seed: 5) {
                let owner = g.owner(p)
                if !g.onTable(p) {
                    XCTAssertNil(owner)
                    continue
                }
                onTable += 1
                let a = atan2(p.x, p.y)
                let half: Double = Double.pi / Double(g.players)
                let within = g.seats.filter { abs(self.angleDiff(a, g.angle($0))) < half }
                XCTAssertEqual(owner.map { [$0] } ?? [], within)
                XCTAssertNotNil(owner)
            }
            XCTAssertTrue(onTable > 2000)
            // Each seat owns its whole arm beyond the centre region.
            for s in g.seats {
                for u in [-0.49, -0.3, 0.0, 0.3, 0.49] {
                    for v in [0.75, 0.9, 1.09] { XCTAssertEqual(s, g.owner(g.fromLocal(s, u, v))) }
                }
            }
        }
    }

    // Kotlin: netsLieOnTheTerritoryBordersOfAdjacentSeats
    func testNetsLieOnTheTerritoryBordersOfAdjacentSeats() {
        XCTAssertEqual(sqrt(0.5), CrossGeometry(4).netLength, accuracy: 1e-12)
        XCTAssertEqual(0.72, CrossGeometry(3).netLength, accuracy: 1e-12)
        for g in tables {
            XCTAssertEqual(g.players, g.nets.count)
            for net in g.nets {
                XCTAssertEqual(g.wrap(net.left + 1), net.right)
                XCTAssertEqual(g.netLength, net.end.length, accuracy: 1e-12)
                let half: Double = Double.pi / Double(g.players)
                let bearing = atan2(net.end.x, net.end.y)
                XCTAssertEqual(half, abs(angleDiff(bearing, g.angle(net.left))), accuracy: 1e-12)
                XCTAssertEqual(half, abs(angleDiff(bearing, g.angle(net.right))), accuracy: 1e-12)
                XCTAssertTrue(g.onTable(net.end))
                XCTAssertFalse(g.onTable(net.end * 1.01)) // it spans the table, no further
                let normal = MPPoint(-net.end.y, net.end.x) * (1 / net.end.length)
                for s in [0.1, 0.4, 0.7, 0.99] {
                    let p = net.end * s
                    let sides = Set([g.owner(p + normal * 1e-6), g.owner(p - normal * 1e-6)].compactMap { $0 })
                    XCTAssertEqual(Set([net.left, net.right]), sides)
                }
            }
        }
    }

    // Kotlin: gapsBetweenArmsAreOffTheTable
    func testGapsBetweenArmsAreOffTheTable() {
        let four = CrossGeometry(4)
        XCTAssertEqual(0.0, four.hub)
        XCTAssertTrue(four.onTable(MPPoint(0, 0)))
        XCTAssertTrue(four.onTable(MPPoint(0.45, 0.45)))
        XCTAssertTrue(four.onTable(MPPoint(-0.45, -0.45)))
        XCTAssertFalse(four.onTable(MPPoint(0.55, 0.55)))
        XCTAssertFalse(four.onTable(MPPoint(0.9, 0.9)))
        XCTAssertFalse(four.onTable(MPPoint(-0.55, -0.6)))
        XCTAssertTrue(four.onTable(MPPoint(0.49, 1.09)))
        XCTAssertFalse(four.onTable(MPPoint(0.51, 1.0)))
        XCTAssertFalse(four.onTable(MPPoint(0, 1.11)))
        XCTAssertTrue(four.onTable(MPPoint(1.09, -0.49)))
        XCTAssertNil(four.owner(MPPoint(0.7, 0.7)))
        let three = CrossGeometry(3)
        XCTAssertEqual(0.72, three.hub)
        for k in three.seats {
            let bisector: Double = three.angle(k) + Double.pi / 3
            let notch = MPPoint(sin(bisector), cos(bisector))
            XCTAssertTrue(three.onTable(notch * 0.70)) // the round centre fills the notch
            XCTAssertFalse(three.onTable(notch * 0.75))
            XCTAssertFalse(three.onTable(notch * 1.2))
            XCTAssertNil(three.owner(notch * 0.75))
            XCTAssertTrue(three.onTable(three.fromLocal(k, 0.49, 1.09)))
            XCTAssertFalse(three.onTable(three.fromLocal(k, 0.51, 1.0)))
            XCTAssertFalse(three.onTable(three.fromLocal(k, 0, 1.11)))
        }
    }

    // Kotlin: strikeAndServeZonesAndHomeAreSeatLocal
    func testStrikeAndServeZonesAndHomeAreSeatLocal() {
        for g in tables {
            for s in g.seats {
                XCTAssertTrue(g.inStrikeZone(s, g.home(s)))
                XCTAssertFalse(g.onTable(g.home(s)))
                XCTAssertEqual(CrossGeometry.reach + 0.06, g.toLocal(s, g.home(s)).v, accuracy: 1e-12)
                XCTAssertTrue(g.inStrikeZone(s, g.fromLocal(s, 0.63, 0.69)))
                XCTAssertTrue(g.inStrikeZone(s, g.fromLocal(s, -0.63, 1.25)))
                XCTAssertFalse(g.inStrikeZone(s, g.fromLocal(s, 0, 0.67)))
                XCTAssertFalse(g.inStrikeZone(s, g.fromLocal(s, 0, 1.27)))
                XCTAssertFalse(g.inStrikeZone(s, g.fromLocal(s, 0.65, 1.0)))
                XCTAssertFalse(g.inStrikeZone(g.wrap(s + 1), g.home(s)))
                XCTAssertTrue(g.inServeZone(s, g.fromLocal(s, 0.41, 0.56)))
                XCTAssertTrue(g.inServeZone(s, g.fromLocal(s, -0.41, 0.97)))
                XCTAssertFalse(g.inServeZone(s, g.fromLocal(s, 0, 0.54)))
                XCTAssertFalse(g.inServeZone(s, g.fromLocal(s, 0, 0.99)))
                XCTAssertFalse(g.inServeZone(s, g.fromLocal(s, 0.43, 0.8)))
                XCTAssertFalse(g.inServeZone(g.wrap(s + 1), g.fromLocal(s, 0, 0.8)))
            }
        }
    }

    // Kotlin: drawnOutlineIsExactlyTheCollisionTable
    func testDrawnOutlineIsExactlyTheCollisionTable() {
        for g in tables {
            let shapes = g.outline()
            let armShapes = arms(shapes)
            XCTAssertEqual(Array(g.seats), armShapes.map { $0.seat })
            XCTAssertEqual(g.players == 3 ? [0.72] : [], hubs(shapes))
            for arm in armShapes {
                XCTAssertEqual(4, arm.corners.count)
                for corner in arm.corners { XCTAssertTrue(g.onTable(corner)) }
                XCTAssertEqual(CrossGeometry.width, (arm.corners[1] - arm.corners[0]).length, accuracy: 1e-12)
                XCTAssertEqual(CrossGeometry.reach, (arm.corners[2] - arm.corners[1]).length, accuracy: 1e-12)
            }
            for p in samples(20000, seed: 99) {
                let drawn = armShapes.contains { self.inConvex(p, $0.corners) } || p.length <= g.hub
                XCTAssertEqual(drawn, g.onTable(p), "\(p)")
            }
        }
    }

    // Kotlin: netSpansFindCrossingsRunsAndThePost
    func testNetSpansFindCrossingsRunsAndThePost() {
        let four = CrossGeometry(4)
        // Crossing the net 0|1 (on x = y) at (0.35, 0.35): a single point half way.
        let crossings = four.netSpans(MPPoint(0.2, 0.35), MPPoint(0.5, 0.35))
        XCTAssertEqual(1, crossings.count)
        if let crossing = crossings.first {
            XCTAssertEqual(0.5, crossing.start, accuracy: 1e-12)
            XCTAssertEqual(0.5, crossing.end, accuracy: 1e-12)
        }
        // Beyond the end of the net (over the notch) nothing is met.
        XCTAssertTrue(four.netSpans(MPPoint(0.3, 0.9), MPPoint(0.9, 0.3)).isEmpty)
        // Straight through the centre: the post column; the net rays only start inside it.
        let centre = four.netSpans(MPPoint(0, 1), MPPoint(0, -1))
        let posts = centre.filter { $0.end > $0.start }
        XCTAssertEqual(1, posts.count)
        if let post = posts.first {
            XCTAssertEqual(0.5 - CrossGeometry.post / 2, post.start, accuracy: 1e-12)
            XCTAssertEqual(0.5 + CrossGeometry.post / 2, post.end, accuracy: 1e-12)
            XCTAssertTrue(centre.allSatisfy { $0.start >= post.start - 1e-12 && $0.end <= post.end + 1e-12 })
        }
        // Three players: seat 0's centre line continues along the net between seats 1 and 2.
        let three = CrossGeometry(3)
        let spans = three.netSpans(MPPoint(0, 1), MPPoint(0, -1))
        XCTAssertTrue(spans.contains { abs($0.start - 0.5) < 1e-12 && abs($0.end - 0.86) < 1e-12 }) // run along the wall
        XCTAssertTrue(spans.contains { abs($0.start - (0.5 - CrossGeometry.post / 2)) < 1e-12 }) // the post
        // A stationary point over the post lies inside the whole (zero-length) path.
        XCTAssertEqual([CrossSpan(start: 0, end: 1)], four.netSpans(MPPoint(0.01, 0), MPPoint(0.01, 0)))
        XCTAssertTrue(four.netSpans(MPPoint(0.2, 0.1), MPPoint(0.2, 0.1)).isEmpty)
    }
}
