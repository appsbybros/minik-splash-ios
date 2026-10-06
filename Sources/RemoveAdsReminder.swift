import Combine
import Foundation
import SwiftUI

struct RemoveAdsReminderState: Codable, Equatable, Sendable {
    var firstSeenAt: Date
    var nextPresentationAt: Date?
    var neverShowAgain: Bool
}

struct RemoveAdsReminderRepository: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let keyPrefix: String

    init(
        userDefaults: UserDefaults = .standard,
        keyPrefix: String = "minik.remove-ads-reminder.v1"
    ) {
        self.userDefaults = userDefaults
        self.keyPrefix = keyPrefix
    }

    func loadOrCreate(for product: ProductVariant, now: Date) -> RemoveAdsReminderState {
        let storageKey = key(for: product)
        if let data = userDefaults.data(forKey: storageKey),
           let state = try? JSONDecoder().decode(RemoveAdsReminderState.self, from: data) {
            return state
        }
        let state = RemoveAdsReminderState(
            firstSeenAt: now,
            nextPresentationAt: nil,
            neverShowAgain: false
        )
        save(state, for: product)
        return state
    }

    func save(_ state: RemoveAdsReminderState, for product: ProductVariant) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        userDefaults.set(data, forKey: key(for: product))
    }

    private func key(for product: ProductVariant) -> String {
        "\(keyPrefix).\(product.rawValue)"
    }
}

struct RemoveAdsReminderPolicy: Equatable, Sendable {
    static let firstDelay: TimeInterval = 2 * 24 * 60 * 60
    static let repeatDelay: TimeInterval = 14 * 24 * 60 * 60

    func isDue(
        state: RemoveAdsReminderState,
        now: Date,
        adsAreActive: Bool,
        purchaseIsAvailable: Bool,
        wasShownThisSession: Bool
    ) -> Bool {
        guard adsAreActive,
              purchaseIsAvailable,
              !state.neverShowAgain,
              !wasShownThisSession else {
            return false
        }
        if let nextPresentationAt = state.nextPresentationAt {
            return now >= nextPresentationAt
        }
        return now.timeIntervalSince(state.firstSeenAt) >= Self.firstDelay
    }
}

@MainActor
final class RemoveAdsReminderController: ObservableObject {
    @Published private(set) var isPresented = false

    private let product: ProductVariant
    private let repository: RemoveAdsReminderRepository
    private let policy: RemoveAdsReminderPolicy
    private var state: RemoveAdsReminderState
    private var wasShownThisSession = false

    init(
        product: ProductVariant,
        repository: RemoveAdsReminderRepository = RemoveAdsReminderRepository(),
        policy: RemoveAdsReminderPolicy = RemoveAdsReminderPolicy(),
        now: Date = Date()
    ) {
        self.product = product
        self.repository = repository
        self.policy = policy
        self.state = repository.loadOrCreate(for: product, now: now)
    }

    func evaluate(
        now: Date = Date(),
        adsAreActive: Bool,
        purchaseIsAvailable: Bool
    ) {
        guard policy.isDue(
            state: state,
            now: now,
            adsAreActive: adsAreActive,
            purchaseIsAvailable: purchaseIsAvailable,
            wasShownThisSession: wasShownThisSession
        ) else {
            if !adsAreActive || !purchaseIsAvailable { isPresented = false }
            return
        }

        // Android records the 14-day deferral when the reminder appears, not
        // when a particular button is selected, so dismissal cannot cause spam.
        state.nextPresentationAt = now.addingTimeInterval(RemoveAdsReminderPolicy.repeatDelay)
        repository.save(state, for: product)
        wasShownThisSession = true
        isPresented = true
    }

    func remindLater() {
        isPresented = false
    }

    func neverShowAgain() {
        state.neverShowAgain = true
        repository.save(state, for: product)
        isPresented = false
    }

    func removeAdsEntitlementActivated() {
        isPresented = false
    }

    func currentState() -> RemoveAdsReminderState {
        state
    }
}

struct RemoveAdsReminderView: View {
    @ObservedObject var controller: RemoveAdsReminderController
    @ObservedObject var commerceController: MinikCommerceController
    @State private var showsParentalGate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    MinikArtworkImage(name: MinikVisualAsset.logo)
                        .frame(maxWidth: 100)
                        .frame(height: 64)
                        .accessibilityHidden(true)

                    MinikArtworkImage(name: MinikVisualAsset.success)
                        .frame(maxWidth: 220)
                        .frame(height: 150)
                        .accessibilityHidden(true)

                    Text("For parents")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(red: 0.38, green: 0.33, blue: 0.77))

                    Text("A calmer experience, without ads")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text("You can remove ads from the app for a cleaner, more focused experience for your child.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    if let product = commerceController.removeAdsProduct {
                        Button {
                            showsParentalGate = true
                        } label: {
                            Text(String(
                                format: String(localized: "Remove Ads — %@"),
                                product.displayPrice
                            ))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(commerceController.isBusy)
                        .accessibilityHint("Opens a grown-up check before contacting the App Store")
                    }

                    Button("Remind me later") {
                        controller.remindLater()
                    }
                    .buttonStyle(.bordered)

                    Button("Don’t show this again") {
                        controller.neverShowAgain()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    if commerceController.isBusy {
                        ProgressView("Contacting the App Store…")
                    }
                }
                .padding(24)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
            .background(MinikPracticeBackground().ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { controller.remindLater() }
                }
            }
        }
        .sheet(isPresented: $showsParentalGate) {
            ParentalGateView(
                onCancel: { showsParentalGate = false },
                onUnlock: {
                    showsParentalGate = false
                    Task {
                        await commerceController.purchaseRemoveAds()
                        if commerceController.isRemoveAdsActive {
                            controller.removeAdsEntitlementActivated()
                        }
                    }
                }
            )
        }
        .onChange(of: commerceController.isRemoveAdsActive) { _, isActive in
            if isActive { controller.removeAdsEntitlementActivated() }
        }
    }
}
