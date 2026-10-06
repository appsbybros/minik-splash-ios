# AppStoreCommerceKit

Reusable StoreKit 2 commerce boundary for Apple-platform applications. The
caller supplies a `CommerceCatalog` mapping its own product IDs to its own
entitlement IDs plus a neutral `CommerceFulfillmentHandler`; this package
contains no application product IDs, UI, bundle assumptions, analytics,
advertising, or backend code.

`StoreKitCommerceStore` loads products, purchases configured products, verifies
transactions, refreshes current entitlements, listens for updates, and performs
an explicit user-initiated restore through `AppStore.sync()`.

## Supported product matrix

- Non-consumable: supported as a persistent entitlement.
- Auto-renewable subscription: supported through StoreKit's verified current
  entitlement sequence; the package does not invent an expiry date. That
  platform state covers active subscription, eligible billing grace, upgrades,
  revocation, and expiry. Cancelling future renewal does not itself remove a
  current entitlement.
- Consumable, non-renewing subscription, and unknown types: rejected before a
  purchase begins. They need a separate quantity or expiry fulfillment contract.

## Delivery and lifecycle

For a relevant verified purchase or update, the package first obtains the full
current entitlement snapshot and passes neutral `CommerceFulfillment` data to
the caller's handler. It finishes the StoreKit transaction only after that
handler succeeds. Failed fulfillment is not acknowledged. A replay after an
acknowledgement failure retries acknowledgement without redelivering content.
Unconfigured products are ignored and never finished by this package.

At app startup and foregrounding, call `refreshEntitlements()` and apply the
returned snapshot. Start one `transactionUpdates()` listener for the owning app
lifecycle and cancel its consuming task on teardown. Update processing failures
are emitted as `.failure` values and do not end later valid updates. The app
must still refresh on lifecycle transitions; an expiry is not assumed to arrive
as a timely transaction update.

`InMemoryCommerceStore` is a deterministic test seam. It requires every
purchase outcome to be explicitly configured and can emit entitlement and
failure updates for caller-side tests.

## Native validation

On a Mac with Xcode, run the `AppStoreCommerceKit` package scheme for its unit
tests, then run the shared `AppStoreCommerceKitHostedIntegrationTests` scheme in
`IntegrationTestHost/AppStoreCommerceKitTestHost.xcodeproj` against the same
iOS Simulator. The minimal host activates the local StoreKit configuration and
contains no Minik application behavior. Full commands and the Windows-owner
manual workflow are documented in `NATIVE-VALIDATION.md`.

The package test targets are independent of Minik's
`ProductConfigurationTests`; an app build does not run them. A second
application consumes the same package by supplying a different catalog and
fulfillment handler.
