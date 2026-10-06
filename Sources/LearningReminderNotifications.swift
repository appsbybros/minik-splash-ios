import Combine
import Foundation
import UserNotifications

enum LearningReminderAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

struct LearningReminderRequest: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let interval: TimeInterval
    let repeats: Bool
}

protocol LearningReminderNotificationService: Sendable {
    func authorizationStatus() async -> LearningReminderAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func isScheduled(identifier: String) async -> Bool
    func schedule(_ request: LearningReminderRequest) async throws
    func cancel(identifier: String) async
}

enum LearningReminderNotificationError: Error, Equatable {
    case invalidInterval
}

final class UserNotificationsLearningReminderService: LearningReminderNotificationService, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> LearningReminderAuthorizationStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .authorized
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func isScheduled(identifier: String) async -> Bool {
        await center.pendingNotificationRequests().contains { $0.identifier == identifier }
    }

    func schedule(_ request: LearningReminderRequest) async throws {
        guard request.interval >= 60 else {
            throw LearningReminderNotificationError.invalidInterval
        }
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: request.interval,
            repeats: request.repeats
        )
        try await center.add(UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: trigger
        ))
    }

    func cancel(identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

struct LearningReminderPolicy: Equatable, Sendable {
    /// A deliberately low-frequency first-release default. A parent must opt in.
    static let defaultInterval: TimeInterval = 7 * 24 * 60 * 60

    let product: ProductVariant
    let interval: TimeInterval

    init(
        product: ProductVariant,
        interval: TimeInterval = LearningReminderPolicy.defaultInterval
    ) {
        self.product = product
        self.interval = interval
    }

    func request(locale: InterfaceLocaleID) -> LearningReminderRequest {
        LearningReminderRequest(
            identifier: "minik.learning-reminder.\(product.rawValue)",
            title: locale.text("Time for Minik"),
            body: locale.text("A little Minik practice is ready when you are."),
            interval: interval,
            repeats: true
        )
    }
}

struct LearningReminderPreferenceRepository: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let keyPrefix: String

    init(
        userDefaults: UserDefaults = .standard,
        keyPrefix: String = "minik.learning-reminder.enabled.v1"
    ) {
        self.userDefaults = userDefaults
        self.keyPrefix = keyPrefix
    }

    func isEnabled(for product: ProductVariant) -> Bool {
        userDefaults.bool(forKey: storageKey(for: product))
    }

    func save(isEnabled: Bool, for product: ProductVariant) {
        userDefaults.set(isEnabled, forKey: storageKey(for: product))
    }

    private func storageKey(for product: ProductVariant) -> String {
        "\(keyPrefix).\(product.rawValue)"
    }
}

@MainActor
final class LearningReminderController: ObservableObject {
    enum Status: Equatable {
        case disabled
        case working
        case enabled
        case denied
        case failed
    }

    @Published private(set) var isEnabled: Bool
    @Published private(set) var status: Status

    private let policy: LearningReminderPolicy
    private let repository: LearningReminderPreferenceRepository
    private let service: any LearningReminderNotificationService

    init(
        policy: LearningReminderPolicy,
        repository: LearningReminderPreferenceRepository = LearningReminderPreferenceRepository(),
        service: any LearningReminderNotificationService = UserNotificationsLearningReminderService()
    ) {
        self.policy = policy
        self.repository = repository
        self.service = service
        let enabled = repository.isEnabled(for: policy.product)
        isEnabled = enabled
        status = enabled ? .working : .disabled
    }

    /// Called from the Parent Area toggle; this is the only path that may ask permission.
    func setEnabled(_ enabled: Bool, locale: InterfaceLocaleID) async {
        status = .working
        let request = policy.request(locale: locale)
        guard enabled else {
            repository.save(isEnabled: false, for: policy.product)
            isEnabled = false
            await service.cancel(identifier: request.identifier)
            status = .disabled
            return
        }

        do {
            var authorization = await service.authorizationStatus()
            if authorization == .notDetermined {
                authorization = try await service.requestAuthorization() ? .authorized : .denied
            }
            guard authorization == .authorized else {
                repository.save(isEnabled: false, for: policy.product)
                isEnabled = false
                status = .denied
                return
            }
            try await service.schedule(request)
            repository.save(isEnabled: true, for: policy.product)
            isEnabled = true
            status = .enabled
        } catch {
            repository.save(isEnabled: false, for: policy.product)
            isEnabled = false
            status = .failed
        }
    }

    /// Restores an opted-in schedule without ever presenting a permission prompt.
    func synchronize(locale: InterfaceLocaleID) async {
        let request = policy.request(locale: locale)
        let storedEnabled = repository.isEnabled(for: policy.product)
        guard storedEnabled else {
            isEnabled = false
            status = .disabled
            return
        }

        guard await service.authorizationStatus() == .authorized else {
            repository.save(isEnabled: false, for: policy.product)
            isEnabled = false
            status = .denied
            await service.cancel(identifier: request.identifier)
            return
        }

        do {
            if !(await service.isScheduled(identifier: request.identifier)) {
                try await service.schedule(request)
            }
            isEnabled = true
            status = .enabled
        } catch {
            isEnabled = true
            status = .failed
        }
    }

    func rescheduleForLocaleChange(_ locale: InterfaceLocaleID) async {
        guard repository.isEnabled(for: policy.product),
              await service.authorizationStatus() == .authorized else { return }
        do {
            try await service.schedule(policy.request(locale: locale))
            isEnabled = true
            status = .enabled
        } catch {
            status = .failed
        }
    }
}
