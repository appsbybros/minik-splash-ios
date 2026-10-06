import XCTest
@testable import MinikPlus

final class MathProductionActivityTests: XCTestCase {
    func testCanonicalMathProductHasExactlyThirteenIdentities() {
        XCTAssertEqual(MathProductionActivityID.allCases.count, 13)
        XCTAssertEqual(Set(MathProductionActivityID.allCases).count, 13)
        XCTAssertNotEqual(
            MathProductionActivityID.allCases.count,
            MathActivityKind.allCases.count
        )
        XCTAssertEqual(MathActivityKind.allCases.count, 7)
    }

    func testPingPongIsCanonicalButOutsideMathCurriculum() {
        XCTAssertTrue(MathProductionActivityID.allCases.contains(.pingPong))
        XCTAssertEqual(MathProductionActivityID.pingPong.curriculumRole, .nonCurriculum)
        XCTAssertNil(MathProductionActivityID.pingPong.engine)
        XCTAssertEqual(MathProductionActivityID.pingPong.launchRoute(for: .m1), .pingPong)
        XCTAssertFalse(MathActivityKind.allCases.map(\.rawValue).contains("pingPong"))
    }

    func testLanguageProductionContractRemainsExactlyThirteen() {
        XCTAssertEqual(LanguageActivityKind.productionKinds.count, 13)
        XCTAssertEqual(Set(LanguageActivityKind.productionKinds).count, 13)
        XCTAssertEqual(
            Set(LanguageActivityKind.productionKinds),
            Set(LanguageActivityKind.sections.flatMap(\.activities))
        )
    }

    func testEveryEducationalIdentityUsesTheDedicatedM1ProductionRoute() {
        for activity in MathProductionActivityID.allCases where activity != .pingPong {
            XCTAssertEqual(activity.launchRoute(for: .m1), .m1Production)
        }
    }

    func testPrototypeRoutesAreExplicitAndLevelAware() {
        XCTAssertEqual(MathProductionActivityID.learnMath.launchRoute(for: .m1), .m1Production)
        XCTAssertEqual(MathProductionActivityID.visualToAnswer.launchRoute(for: .m1), .m1Production)
        XCTAssertEqual(MathProductionActivityID.buildMath.launchRoute(for: .m1), .m1Production)
        XCTAssertEqual(
            MathProductionActivityID.buildMath.launchRoute(for: .m2),
            .m2Production
        )
        XCTAssertEqual(
            MathProductionActivityID.buildMath.launchRoute(for: .m3),
            .m3Production
        )
        XCTAssertEqual(
            MathProductionActivityID.buildMath.launchRoute(for: .m4),
            .m4Production
        )
        XCTAssertEqual(MathProductionActivityID.buildMath.launchRoute(for: .m5), .m5Production)
        XCTAssertEqual(MathProductionActivityID.buildMath.launchRoute(for: .m6), .m6Production)
        XCTAssertEqual(MathProductionActivityID.buildMath.launchRoute(for: .m7), .m7Production)
        XCTAssertEqual(MathProductionActivityID.buildMath.launchRoute(for: .m8), .m8Production)
        XCTAssertEqual(MathProductionActivityID.learnMath.launchRoute(for: .m8), .m8Production)
        XCTAssertEqual(MathProductionActivityID.buildMath.launchRoute(for: .m9), .m9Production)
        XCTAssertEqual(MathProductionActivityID.learnMath.launchRoute(for: .m9), .m9Production)
        XCTAssertEqual(MathProductionActivityID.buildMath.launchRoute(for: .m10), .m10Production)
        XCTAssertEqual(MathProductionActivityID.learnMath.launchRoute(for: .m10), .m10Production)
    }
}
