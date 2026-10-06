import XCTest
@testable import MinikPlus

final class MathM1ActivitySessionFactoryTests: XCTestCase {
    private var factory: MathM1ActivitySessionFactory {
        MathM1ActivitySessionFactory(
            configuration: ProductConfiguration.configuration(for: .minikMath)
        )
    }

    func testEveryEducationalM1IdentityBuildsItsOwnProductionSession() {
        for activity in MathProductionActivityID.allCases where activity != .pingPong {
            XCTAssertNotNil(factory.makeSession(for: activity), activity.rawValue)
            XCTAssertEqual(activity.launchRoute(for: .m1), .m1Production)
        }
        XCTAssertNil(factory.makeSession(for: .pingPong))
    }

    func testMixedContainsOnlyGradedEducationalModesAndAvoidsImmediateRepeat() {
        XCTAssertFalse(MathM1MixedSession.eligibleActivities.contains(.learnMath))
        XCTAssertFalse(MathM1MixedSession.eligibleActivities.contains(.mathCards))
        XCTAssertFalse(MathM1MixedSession.eligibleActivities.contains(.pingPong))
        var session = MathM1MixedSession()
        for _ in 0..<30 {
            let previous = session.currentActivity
            session.advance()
            XCTAssertNotEqual(session.currentActivity, previous)
        }
    }

    func testLearnAndCardsCoverCompleteM1Range() throws {
        guard case .learn(let learn)? = factory.makeSession(for: .learnMath),
              case .cards(let cards)? = factory.makeSession(for: .mathCards) else {
            return XCTFail("Expected Learn and Cards sessions.")
        }
        XCTAssertEqual(learn.cardCount, 11)
        XCTAssertEqual(cards.cardCount, 11)
    }

    func testM1CountSessionsIncludeExtraTokens() throws {
        for activity in [MathProductionActivityID.buildQuantity, .mathTower] {
            let produced = try XCTUnwrap(factory.makeSession(for: activity))
            let session: MathCountConstructionSession
            switch produced {
            case .buildQuantity(let value), .tower(let value): session = value
            default: return XCTFail("Expected count construction for \(activity).")
            }
            for round in session.rounds {
                XCTAssertGreaterThan(round.availableTokenIDs.count, round.target)
            }
        }
    }

    func testBuildNumberWrongAnswerCanBeRetried() throws {
        guard case .buildNumber(var session)? = factory.makeSession(for: .buildNumber) else {
            return XCTFail("Expected Build Number session.")
        }
        let challenge = session.currentChallenge
        let expectedID = try XCTUnwrap(challenge.expectedTokenSequence.first)
        let wrongID = try XCTUnwrap(
            challenge.availableTokens.first(where: { $0.id != expectedID })?.id
        )

        session.selectToken(wrongID)
        session.submit()
        XCTAssertEqual(session.answerResult, .incorrect)

        session.retryCurrentChallenge()
        XCTAssertNil(session.answerResult)
        XCTAssertTrue(session.selectedTokenIDs.isEmpty)
    }
}
