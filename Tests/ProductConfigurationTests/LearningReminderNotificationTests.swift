import XCTest
@testable import MinikPlus

final class LearningReminderNotificationTests: XCTestCase {
    func testPreferenceIsDisabledByDefaultAndIsolatedByProduct() {
        let defaults = makeDefaults()
        let repository = LearningReminderPreferenceRepository(userDefaults: defaults)

        XCTAssertFalse(repository.isEnabled(for: .minikPlus))
        repository.save(isEnabled: true, for: .minikPlus)

        XCTAssertTrue(repository.isEnabled(for: .minikPlus))
        XCTAssertFalse(repository.isEnabled(for: .minikPlusEnglish))
        XCTAssertFalse(repository.isEnabled(for: .minikMath))
    }

    func testFirstReleasePolicyIsWeeklyRepeatingAndProductScoped() {
        let request = LearningReminderPolicy(product: .minikPlus).request(locale: .english)

        XCTAssertEqual(request.identifier, "minik.learning-reminder.minikPlus")
        XCTAssertEqual(request.interval, 7 * 24 * 60 * 60)
        XCTAssertTrue(request.repeats)
        XCTAssertFalse(request.title.isEmpty)
        XCTAssertFalse(request.body.isEmpty)
    }

    @MainActor
    func testParentEnableRequestsPermissionAndSchedulesExactlyOnce() async {
        let defaults = makeDefaults()
        let repository = LearningReminderPreferenceRepository(userDefaults: defaults)
        let service = FakeLearningReminderNotificationService(
            authorization: .notDetermined,
            requestResult: true
        )
        let controller = LearningReminderController(
            policy: LearningReminderPolicy(product: .minikPlus),
            repository: repository,
            service: service
        )

        await controller.setEnabled(true, locale: .english)

        XCTAssertTrue(controller.isEnabled)
        XCTAssertEqual(controller.status, .enabled)
        XCTAssertTrue(repository.isEnabled(for: .minikPlus))
        let requestCount = await service.requestAuthorizationCount()
        let scheduled = await service.scheduledRequests()
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(scheduled.count, 1)
    }

    @MainActor
    func testDeniedPermissionLeavesPreferenceOffAndDoesNotSchedule() async {
        let defaults = makeDefaults()
        let repository = LearningReminderPreferenceRepository(userDefaults: defaults)
        let service = FakeLearningReminderNotificationService(
            authorization: .denied,
            requestResult: false
        )
        let controller = LearningReminderController(
            policy: LearningReminderPolicy(product: .minikPlus),
            repository: repository,
            service: service
        )

        await controller.setEnabled(true, locale: .english)

        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(controller.status, .denied)
        XCTAssertFalse(repository.isEnabled(for: .minikPlus))
        let requestCount = await service.requestAuthorizationCount()
        let scheduled = await service.scheduledRequests()
        XCTAssertEqual(requestCount, 0)
        XCTAssertTrue(scheduled.isEmpty)
    }

    @MainActor
    func testLifecycleSynchronizationNeverPromptsAndRepairsMissingSchedule() async {
        let defaults = makeDefaults()
        let repository = LearningReminderPreferenceRepository(userDefaults: defaults)
        repository.save(isEnabled: true, for: .minikPlus)
        let service = FakeLearningReminderNotificationService(
            authorization: .authorized,
            requestResult: true
        )
        let controller = LearningReminderController(
            policy: LearningReminderPolicy(product: .minikPlus),
            repository: repository,
            service: service
        )

        await controller.synchronize(locale: .english)
        await controller.synchronize(locale: .english)

        let requestCount = await service.requestAuthorizationCount()
        let scheduled = await service.scheduledRequests()
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(scheduled.count, 1)
        XCTAssertEqual(controller.status, .enabled)
    }

    @MainActor
    func testDisableCancelsOnlyTheProductReminder() async {
        let defaults = makeDefaults()
        let repository = LearningReminderPreferenceRepository(userDefaults: defaults)
        repository.save(isEnabled: true, for: .minikPlus)
        let service = FakeLearningReminderNotificationService(
            authorization: .authorized,
            requestResult: true
        )
        let controller = LearningReminderController(
            policy: LearningReminderPolicy(product: .minikPlus),
            repository: repository,
            service: service
        )

        await controller.setEnabled(false, locale: .english)

        XCTAssertFalse(controller.isEnabled)
        XCTAssertEqual(controller.status, .disabled)
        let cancelled = await service.cancelledIdentifiers()
        XCTAssertEqual(cancelled, ["minik.learning-reminder.minikPlus"])
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "LearningReminderNotificationTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }
}

private actor FakeLearningReminderNotificationService: LearningReminderNotificationService {
    private var authorization: LearningReminderAuthorizationStatus
    private let requestResult: Bool
    private var requestCount = 0
    private var scheduled: [LearningReminderRequest] = []
    private var cancelled: [String] = []

    init(authorization: LearningReminderAuthorizationStatus, requestResult: Bool) {
        self.authorization = authorization
        self.requestResult = requestResult
    }

    func authorizationStatus() async -> LearningReminderAuthorizationStatus {
        authorization
    }

    func requestAuthorization() async throws -> Bool {
        requestCount += 1
        authorization = requestResult ? .authorized : .denied
        return requestResult
    }

    func isScheduled(identifier: String) async -> Bool {
        scheduled.contains { $0.identifier == identifier }
    }

    func schedule(_ request: LearningReminderRequest) async throws {
        scheduled.removeAll { $0.identifier == request.identifier }
        scheduled.append(request)
    }

    func cancel(identifier: String) async {
        scheduled.removeAll { $0.identifier == identifier }
        cancelled.append(identifier)
    }

    func requestAuthorizationCount() -> Int { requestCount }
    func scheduledRequests() -> [LearningReminderRequest] { scheduled }
    func cancelledIdentifiers() -> [String] { cancelled }
}
