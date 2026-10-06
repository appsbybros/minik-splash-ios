import XCTest
@testable import MinikPlus

final class SoccerIntroductionRepositoryTests: XCTestCase {
    func testIntroductionIsRegisteredForExactlyTheFirstThreeLaunches() throws {
        let suiteName = "SoccerIntroductionRepositoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = SoccerIntroductionRepository(
            userDefaults: defaults,
            storageKey: "soccer.introduction"
        )

        XCTAssertTrue(repository.registerPresentationIfNeeded())
        XCTAssertTrue(repository.registerPresentationIfNeeded())
        XCTAssertTrue(repository.registerPresentationIfNeeded())
        XCTAssertFalse(repository.registerPresentationIfNeeded())
        XCTAssertFalse(repository.registerPresentationIfNeeded())
    }
}
