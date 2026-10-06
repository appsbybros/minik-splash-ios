# Native StoreKit package validation

This package is not part of Minik's application schemes or
`ProductConfigurationTests`; an application build does not execute package
tests. Native validation has two layers that use the same iOS Simulator UDID.
On a Mac with Xcode, start at the repository root and run:

```bash
cd Packages/AppStoreCommerceKit
xcrun simctl list devices available
xcodebuild test \
  -scheme AppStoreCommerceKit \
  -destination 'platform=iOS Simulator,id=<available-simulator-UDID>' \
  -parallel-testing-enabled NO \
  -only-testing:AppStoreCommerceKitTests
xcodebuild test \
  -project IntegrationTestHost/AppStoreCommerceKitTestHost.xcodeproj \
  -scheme AppStoreCommerceKitHostedIntegrationTests \
  -testPlan AppStoreCommerceKitHostedIntegrationTests \
  -destination 'platform=iOS Simulator,id=<same-available-simulator-UDID>' \
  -parallel-testing-enabled NO
```

The first command runs platform-independent package tests. The second runs the
real StoreKit tests in a minimal hosted iOS application. Its shared scheme has
`IntegrationTestHost/AppStoreCommerceKit.storekit` active as the StoreKit
configuration, and the host copies that fixture into its application bundle so
the tests can use `SKTestSession(configurationFileNamed:)`. Its fixture product IDs are
`org.example.appstorecommerce.fixture.permanent` and
`org.example.appstorecommerce.fixture.monthly`; they are test-only and are not
App Store Connect identifiers.

For a Windows owner, use the manual GitHub Actions workflow named **App Store
Commerce Package Tests** (`.github/workflows/app-store-commerce-tests.yml`):

1. Review and commit the package/workflow changes locally.
2. Make sure that exact reviewed commit is available on GitHub. If GitHub only
   offers manual dispatch for workflow files on the repository's default
   branch, put the reviewed commit on the appropriate default branch first.
3. In GitHub, open **Actions**, select **App Store Commerce Package Tests**,
   choose **Run workflow**, select the branch containing the reviewed commit,
   and confirm **Run workflow**.
4. Confirm the recorded `checked_out_sha` is the reviewed commit before using
   the run as evidence.
5. Return both artifacts when present: `app-store-commerce-tests` (diagnostics
   plus package and hosted test logs) and `app-store-commerce-xcresult`
   (containing each result bundle that `xcodebuild` produced).

The diagnostics record the checked-out SHA, Xcode version, iOS Simulator SDK
version, package and hosted scheme destinations, hosted test-plan discovery,
complete available-simulator list, selected iOS runtime and unique simulator
UDID, and the explicit boot/bootstatus result.
The workflow uses the same selected UDID for boot, bootstatus, and
both `xcodebuild` test layers. Artifact retention is three days. It has only the
`workflow_dispatch` trigger, read-only repository permission, and no account
secrets.

Native Apple execution is **NOT RUN** until the workflow or a local Mac run
returns passing evidence tied to the reviewed SHA.

The included fixture covers a configured non-consumable purchase, restore,
refund update reconciliation through the real transaction-update stream, and
a local auto-renewable product. The native test observes verified subscription
states for active access, billing grace, and expiration; enabling StoreKitTest
controls alone is not treated as proof. Apple execution remains the required
evidence for those scenarios.
