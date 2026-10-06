import XCTest
@testable import MinikPlus

final class ParentReleaseSourceTests: XCTestCase {
    func testRemoveAdsReminderUsesAndroidTwoDayFirstDelayAndFourteenDayRepeat() {
        let installedAt = Date(timeIntervalSince1970: 10_000)
        let policy = RemoveAdsReminderPolicy()
        let initial = RemoveAdsReminderState(
            firstSeenAt: installedAt,
            nextPresentationAt: nil,
            neverShowAgain: false
        )

        XCTAssertFalse(policy.isDue(
            state: initial,
            now: installedAt.addingTimeInterval(RemoveAdsReminderPolicy.firstDelay - 1),
            adsAreActive: true,
            purchaseIsAvailable: true,
            wasShownThisSession: false
        ))
        XCTAssertTrue(policy.isDue(
            state: initial,
            now: installedAt.addingTimeInterval(RemoveAdsReminderPolicy.firstDelay),
            adsAreActive: true,
            purchaseIsAvailable: true,
            wasShownThisSession: false
        ))

        let shownAt = installedAt.addingTimeInterval(RemoveAdsReminderPolicy.firstDelay)
        let repeated = RemoveAdsReminderState(
            firstSeenAt: installedAt,
            nextPresentationAt: shownAt.addingTimeInterval(RemoveAdsReminderPolicy.repeatDelay),
            neverShowAgain: false
        )
        XCTAssertFalse(policy.isDue(
            state: repeated,
            now: repeated.nextPresentationAt!.addingTimeInterval(-1),
            adsAreActive: true,
            purchaseIsAvailable: true,
            wasShownThisSession: false
        ))
        XCTAssertTrue(policy.isDue(
            state: repeated,
            now: repeated.nextPresentationAt!,
            adsAreActive: true,
            purchaseIsAvailable: true,
            wasShownThisSession: false
        ))
    }

    func testReminderRequiresRealAdsAndPurchasableRemoveAds() {
        let now = Date(timeIntervalSince1970: 20_000)
        let due = RemoveAdsReminderState(
            firstSeenAt: now.addingTimeInterval(-RemoveAdsReminderPolicy.firstDelay),
            nextPresentationAt: nil,
            neverShowAgain: false
        )
        let policy = RemoveAdsReminderPolicy()

        XCTAssertFalse(policy.isDue(
            state: due, now: now, adsAreActive: false,
            purchaseIsAvailable: true, wasShownThisSession: false
        ))
        XCTAssertFalse(policy.isDue(
            state: due, now: now, adsAreActive: true,
            purchaseIsAvailable: false, wasShownThisSession: false
        ))
        XCTAssertFalse(policy.isDue(
            state: due, now: now, adsAreActive: true,
            purchaseIsAvailable: true, wasShownThisSession: true
        ))
    }

    @MainActor
    func testReminderRecordsRepeatDateOnPresentationAndOnlyOncePerSession() throws {
        let suite = #function
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let repository = RemoveAdsReminderRepository(userDefaults: defaults, keyPrefix: "reminder-test")
        let firstSeen = Date(timeIntervalSince1970: 30_000)
        let controller = RemoveAdsReminderController(
            product: .minikPlus,
            repository: repository,
            now: firstSeen
        )
        let shownAt = firstSeen.addingTimeInterval(RemoveAdsReminderPolicy.firstDelay)

        controller.evaluate(now: shownAt, adsAreActive: true, purchaseIsAvailable: true)
        XCTAssertTrue(controller.isPresented)
        XCTAssertEqual(
            controller.currentState().nextPresentationAt,
            shownAt.addingTimeInterval(RemoveAdsReminderPolicy.repeatDelay)
        )

        controller.remindLater()
        controller.evaluate(
            now: shownAt.addingTimeInterval(RemoveAdsReminderPolicy.repeatDelay + 1),
            adsAreActive: true,
            purchaseIsAvailable: true
        )
        XCTAssertFalse(controller.isPresented)
    }

    @MainActor
    func testNeverShowIsDurableAndProductScoped() {
        let suite = #function
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let repository = RemoveAdsReminderRepository(userDefaults: defaults, keyPrefix: "reminder-test")
        let now = Date(timeIntervalSince1970: 40_000)
        let controller = RemoveAdsReminderController(
            product: .minikPlusEnglish,
            repository: repository,
            now: now
        )

        controller.neverShowAgain()

        XCTAssertTrue(repository.loadOrCreate(for: .minikPlusEnglish, now: now).neverShowAgain)
        XCTAssertFalse(repository.loadOrCreate(for: .minikMath, now: now).neverShowAgain)
    }

    func testReleaseInformationAcceptsOnlyConfiguredHTTPSDestinations() {
        let information = MinikReleaseInformation(
            privacyPolicyURL: " https://example.com/privacy ",
            termsOfUseURL: "http://example.com/terms",
            supportURL: "not a url",
            legalNotice: "  Legal notice  ",
            marketingVersion: " 2.3 ",
            buildNumber: " 45 "
        )

        XCTAssertEqual(information.privacyPolicyURL?.absoluteString, "https://example.com/privacy")
        XCTAssertNil(information.termsOfUseURL)
        XCTAssertNil(information.supportURL)
        XCTAssertEqual(information.legalNotice, "Legal notice")
        XCTAssertEqual(information.versionDescription, "Version 2.3 (45)")
    }

    func testReleaseInformationRoutesEachDestinationWithoutFallbackURLs() {
        let information = MinikReleaseInformation(
            privacyPolicyURL: "https://example.com/privacy",
            termsOfUseURL: "https://example.com/terms",
            supportURL: "https://example.com/support",
            legalNotice: nil,
            marketingVersion: nil,
            buildNumber: nil
        )

        XCTAssertEqual(information.url(for: .privacyPolicy), URL(string: "https://example.com/privacy"))
        XCTAssertEqual(information.url(for: .termsOfUse), URL(string: "https://example.com/terms"))
        XCTAssertEqual(information.url(for: .support), URL(string: "https://example.com/support"))
        XCTAssertTrue(information.hasExternalDestinations)
    }
}
