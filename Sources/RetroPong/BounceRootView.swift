import SwiftUI

/// Standalone Minik Bounce. Like Android Bounce, a finished game is an interstitial
/// opportunity and the setup screen's "For parents" link opens a grown-up gate before
/// Remove Ads and Restore.
@MainActor struct BounceRootView: View {
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var phase
    @StateObject private var commerce: MinikCommerceController
    @State private var showsParents = false
    @State private var parentsUnlocked = false
    private let adCoordinator: MinikAdCoordinator

    init() {
        _commerce = StateObject(wrappedValue: MinikCommerceComposition.makeController(product: .current))
        adCoordinator = MinikAdsComposition.makeCoordinator(product: .current)
    }

    private var hebrew: Bool { locale.language.languageCode?.identifier == "he" }
    private func t(_ english: String, _ hebrewText: String) -> String { hebrew ? hebrewText : english }

    var body: some View {
        RetroPongView(onMatchFinished: matchFinished, onParents: {
            parentsUnlocked = false
            showsParents = true
        })
        .onAppear { Task { @MainActor in StoreScreenshotScene.applyOrientation() } }
        .task {
            await commerce.start()
            await adCoordinator.start(isRemoveAdsActive: commerce.isRemoveAdsActive)
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .active {
                Task { await commerce.refreshEntitlements() }
            } else if newPhase == .background {
                Task { await adCoordinator.applicationDidEnterBackground() }
            }
        }
        .sheet(isPresented: $showsParents) { parentsSheet }
    }

    /// The game's result is already saved; it appears once the ad boundary finishes.
    private func matchFinished(_ completion: @escaping () -> Void) {
        let removesAds = commerce.isRemoveAdsActive
        Task {
            await adCoordinator.record(.bounceMatch, isRemoveAdsActive: removesAds)
            completion()
        }
    }

    @ViewBuilder private var parentsSheet: some View {
        if parentsUnlocked {
            NavigationStack {
                VStack(spacing: 18) {
                    Text(commerce.isRemoveAdsActive
                         ? t("Ads are removed on this Apple account.", "הפרסומות הוסרו בחשבון Apple הזה.")
                         : t("Remove ads with a one-time App Store purchase.", "הסירו פרסומות ברכישה חד־פעמית ב־App Store."))
                        .multilineTextAlignment(.center)
                    if !commerce.isRemoveAdsActive {
                        Button(t("Remove ads", "הסרת פרסומות") + (commerce.removeAdsProduct.map { " · " + $0.displayPrice } ?? "")) {
                            Task { await commerce.purchaseRemoveAds() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(commerce.removeAdsProduct == nil || commerce.isBusy)
                        if commerce.removeAdsProduct == nil {
                            Text(t("The App Store product is currently unavailable. Please try again later.",
                                   "המוצר אינו זמין כרגע ב־App Store. נסו שוב מאוחר יותר."))
                                .font(.callout)
                                .multilineTextAlignment(.center)
                        }
                    }
                    Button(t("Restore purchases", "שחזור רכישות")) {
                        Task { await commerce.restorePurchases() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(commerce.isBusy)
                }
                .padding(24)
                .frame(maxWidth: 520)
                .navigationTitle(t("For parents", "להורים"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(t("Close", "סגירה")) { showsParents = false }
                    }
                }
            }
            .environment(\.layoutDirection, hebrew ? .rightToLeft : .leftToRight)
        } else {
            ParentalGateView(
                onCancel: { showsParents = false },
                onUnlock: { parentsUnlocked = true }
            )
        }
    }
}
