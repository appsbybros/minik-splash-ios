import XCTest
@testable import MinikPlus

final class MinikAdsTests: XCTestCase {
    func testConfigurationFailsClosedUntilEveryExternalGateIsPresent() {
        let missingApproval = MinikAdsConfiguration(
            product: .minikPlus,
            isEnabled: true,
            isPolicyApproved: false,
            applicationIdentifier: "app-id",
            interstitialAdUnitIdentifier: "unit-id"
        )
        XCTAssertNil(missingApproval.providerConfiguration)

        let missingIdentifier = MinikAdsConfiguration(
            product: .minikPlus,
            isEnabled: true,
            isPolicyApproved: true,
            applicationIdentifier: " ",
            interstitialAdUnitIdentifier: "unit-id"
        )
        XCTAssertNil(missingIdentifier.providerConfiguration)
    }

    func testProviderConfigurationAlwaysEnforcesChildDirectedNonPersonalizedGeneralAds() throws {
        let configuration = MinikAdsConfiguration(
            product: .minikPlusEnglish,
            isEnabled: true,
            isPolicyApproved: true,
            applicationIdentifier: " app-id ",
            interstitialAdUnitIdentifier: " unit-id "
        )

        let provider = try XCTUnwrap(configuration.providerConfiguration)
        XCTAssertEqual(provider.applicationIdentifier, "app-id")
        XCTAssertEqual(provider.interstitialAdUnitIdentifier, "unit-id")
        XCTAssertTrue(provider.isChildDirected)
        XCTAssertTrue(provider.treatsUserAsUnderAgeOfConsent)
        XCTAssertEqual(provider.maximumContentRating, .general)
        XCTAssertFalse(provider.allowsPersonalizedAds)
    }

    func testGoogleSampleAndTestIdentifiersFailClosed() {
        let sampleApplicationID = "ca-app-pub-3940256099942544~1458002511"
        let sampleInterstitialID = "ca-app-pub-3940256099942544/4411468910"
        let adManagerExampleID = "/21775744923/example/interstitial"

        XCTAssertTrue(MinikAdsConfiguration.isKnownGoogleSampleOrTestIdentifier(sampleApplicationID))
        XCTAssertTrue(MinikAdsConfiguration.isKnownGoogleSampleOrTestIdentifier(sampleInterstitialID))
        XCTAssertTrue(MinikAdsConfiguration.isKnownGoogleSampleOrTestIdentifier(adManagerExampleID))
        XCTAssertNil(MinikAdsConfiguration(
            product: .minikPlus,
            isEnabled: true,
            isPolicyApproved: true,
            applicationIdentifier: sampleApplicationID,
            interstitialAdUnitIdentifier: "production-unit"
        ).providerConfiguration)
        XCTAssertNil(MinikAdsConfiguration(
            product: .minikPlus,
            isEnabled: true,
            isPolicyApproved: true,
            applicationIdentifier: "production-app",
            interstitialAdUnitIdentifier: sampleInterstitialID
        ).providerConfiguration)
    }

    func testAndroidWriteTowerSoccerAndTicTacToeNeedThreeSharedCompletions() {
        let start = Date(timeIntervalSince1970: 1_000)
        var policy = AndroidCompatibleInterstitialPolicy(sessionStartedAt: start)

        XCTAssertEqual(
            policy.record(.languageWriteScreen, at: start, isRemoveAdsActive: false, isProviderReady: true),
            .initialCooldownSeeded
        )
        XCTAssertEqual(
            policy.record(.languageTower, at: start.addingTimeInterval(421), isRemoveAdsActive: false, isProviderReady: true),
            .belowCompletionThreshold
        )
        XCTAssertEqual(
            policy.record(.languageSoccer, at: start.addingTimeInterval(422), isRemoveAdsActive: false, isProviderReady: true),
            .requestPresentation
        )
    }

    func testAndroidPictureMemoryCarriesItsLongRoundWeight() {
        let start = Date(timeIntervalSince1970: 2_000)
        var policy = AndroidCompatibleInterstitialPolicy(
            state: MinikAdPolicyState(lastPresentedAt: start.addingTimeInterval(-500)),
            sessionStartedAt: start.addingTimeInterval(-500)
        )

        XCTAssertEqual(
            policy.record(.languagePictureMemory, at: start, isRemoveAdsActive: false, isProviderReady: true),
            .requestPresentation
        )
        XCTAssertEqual(policy.state.completedOpportunityWeight, 3)
    }

    func testSessionWarmupStillAppliesWhenPersistedCooldownHasElapsed() {
        let start = Date(timeIntervalSince1970: 3_000)
        var policy = AndroidCompatibleInterstitialPolicy(
            state: MinikAdPolicyState(
                completedOpportunityWeight: 2,
                lastPresentedAt: start.addingTimeInterval(-800)
            ),
            sessionStartedAt: start
        )

        XCTAssertEqual(
            policy.record(.languageTicTacToe, at: start.addingTimeInterval(30), isRemoveAdsActive: false, isProviderReady: true),
            .sessionWarmup
        )
    }

    func testRemoveAdsSuppressesBeforeCountersOrTimestampsChange() {
        let start = Date(timeIntervalSince1970: 4_000)
        var policy = AndroidCompatibleInterstitialPolicy(sessionStartedAt: start)

        XCTAssertEqual(
            policy.record(.languageSoccer, at: start, isRemoveAdsActive: true, isProviderReady: true),
            .suppressedByEntitlement
        )
        XCTAssertEqual(policy.state, MinikAdPolicyState())
    }

    func testBackgroundProgressionMatchesAndroidSevenFiveFourThreeMinuteFloor() {
        var policy = AndroidCompatibleInterstitialPolicy()

        policy.applicationDidEnterBackground()
        XCTAssertEqual(policy.state.minimumInterval, 5 * 60)
        policy.applicationDidEnterBackground()
        XCTAssertEqual(policy.state.minimumInterval, 4 * 60)
        policy.applicationDidEnterBackground()
        XCTAssertEqual(policy.state.minimumInterval, 3 * 60)
        policy.applicationDidEnterBackground()
        XCTAssertEqual(policy.state.minimumInterval, 3 * 60)
    }

    func testPolicyRepositoryIsProductScoped() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let repository = MinikAdPolicyRepository(userDefaults: defaults, keyPrefix: "ads-test")
        let plusState = MinikAdPolicyState(completedOpportunityWeight: 7, minimumInterval: 180)

        repository.save(plusState, for: .minikPlus)

        XCTAssertEqual(repository.load(for: .minikPlus), plusState)
        XCTAssertEqual(repository.load(for: .minikPlusEnglish), MinikAdPolicyState())
        XCTAssertEqual(repository.load(for: .minikMath), MinikAdPolicyState())
    }

    func testCoordinatorConfiguresOnceAndResetsCounterOnlyAfterPresentation() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let service = RecordingInterstitialAdService(results: [.presented])
        let start = Date(timeIntervalSince1970: 5_000)
        let coordinator = MinikAdCoordinator(
            configuration: configuredProduct(),
            service: service,
            repository: MinikAdPolicyRepository(userDefaults: defaults, keyPrefix: "ads-test"),
            sessionStartedAt: start
        )

        await coordinator.start(isRemoveAdsActive: false)
        await coordinator.start(isRemoveAdsActive: false)
        _ = await coordinator.record(.languageWriteScreen, isRemoveAdsActive: false, at: start)
        _ = await coordinator.record(.languageTower, isRemoveAdsActive: false, at: start.addingTimeInterval(421))
        let result = await coordinator.record(
            .languageSoccer,
            isRemoveAdsActive: false,
            at: start.addingTimeInterval(422)
        )
        let configureCount = await service.configureCount()
        let presentationCount = await service.presentationCount()
        let finalState = await coordinator.currentPolicyState()

        XCTAssertEqual(result, .presentation(.presented))
        XCTAssertEqual(configureCount, 1)
        XCTAssertEqual(presentationCount, 1)
        XCTAssertEqual(finalState.completedOpportunityWeight, 0)
    }

    func testUnavailablePresentationKeepsAccumulatedCounterForNextSafeOpportunity() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let service = RecordingInterstitialAdService(results: [.unavailable])
        let start = Date(timeIntervalSince1970: 6_000)
        let coordinator = MinikAdCoordinator(
            configuration: configuredProduct(),
            service: service,
            repository: MinikAdPolicyRepository(userDefaults: defaults, keyPrefix: "ads-test"),
            sessionStartedAt: start
        )

        await coordinator.start(isRemoveAdsActive: false)
        _ = await coordinator.record(.languageWriteScreen, isRemoveAdsActive: false, at: start)
        _ = await coordinator.record(.languageTower, isRemoveAdsActive: false, at: start.addingTimeInterval(421))
        let result = await coordinator.record(
            .languageTicTacToe,
            isRemoveAdsActive: false,
            at: start.addingTimeInterval(422)
        )
        let finalState = await coordinator.currentPolicyState()

        XCTAssertEqual(result, .presentation(.unavailable))
        XCTAssertEqual(finalState.completedOpportunityWeight, 3)
    }

    func testMissingProviderConfigurationNeverMutatesCadenceState() async {
        let service = RecordingInterstitialAdService(results: [.presented])
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let coordinator = MinikAdCoordinator(
            configuration: MinikAdsConfiguration(
                product: .minikPlus,
                isEnabled: false,
                isPolicyApproved: false,
                applicationIdentifier: nil,
                interstitialAdUnitIdentifier: nil
            ),
            service: service,
            repository: MinikAdPolicyRepository(userDefaults: defaults, keyPrefix: "ads-test"),
            sessionStartedAt: Date(timeIntervalSince1970: 7_000)
        )

        await coordinator.start(isRemoveAdsActive: false)
        let result = await coordinator.record(
            .languageWriteScreen,
            isRemoveAdsActive: false,
            at: Date(timeIntervalSince1970: 8_000)
        )
        let configureCount = await service.configureCount()
        let finalState = await coordinator.currentPolicyState()

        XCTAssertEqual(result, .policy(.providerUnavailable))
        XCTAssertEqual(configureCount, 0)
        XCTAssertEqual(finalState, MinikAdPolicyState())
    }

    func testExistingRemoveAdsEntitlementSkipsProviderStartup() async {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let service = RecordingInterstitialAdService(results: [.presented])
        let coordinator = MinikAdCoordinator(
            configuration: configuredProduct(),
            service: service,
            repository: MinikAdPolicyRepository(userDefaults: defaults, keyPrefix: "ads-test")
        )

        await coordinator.start(isRemoveAdsActive: true)
        let configureCount = await service.configureCount()

        XCTAssertEqual(configureCount, 0)
    }

    private func configuredProduct() -> MinikAdsConfiguration {
        MinikAdsConfiguration(
            product: .minikPlus,
            isEnabled: true,
            isPolicyApproved: true,
            applicationIdentifier: "app-id",
            interstitialAdUnitIdentifier: "unit-id"
        )
    }
}

private actor RecordingInterstitialAdService: MinikInterstitialAdService {
    private var configurations: [MinikAdProviderConfiguration] = []
    private var results: [MinikInterstitialPresentationResult]
    private var presentations = 0

    init(results: [MinikInterstitialPresentationResult]) {
        self.results = results
    }

    func configure(_ configuration: MinikAdProviderConfiguration) async -> Bool {
        configurations.append(configuration)
        return true
    }

    func presentInterstitial() async -> MinikInterstitialPresentationResult {
        presentations += 1
        return results.isEmpty ? .unavailable : results.removeFirst()
    }

    func configureCount() -> Int { configurations.count }
    func presentationCount() -> Int { presentations }
}
