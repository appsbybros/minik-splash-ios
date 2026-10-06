# Windows-accessible iOS Simulator testing

The preferred remote validation path is the manual **iOS Simulator Build** workflow in GitHub Actions. It uses one GitHub **macos-latest** job, generates the Xcode project with XcodeGen once, builds the requested unsigned Simulator products, and optionally runs ProductConfigurationTests once after the required builds are compile-clean. It never runs automatically; `workflow_dispatch` is the only allowed event.

The existing **codemagic.yaml** is retained only as a deprecated manual alternative and as historical build knowledge. GitHub Actions is preferred because the private repository is already hosted by GitHub and no additional CI service needs repository access.

Corrective checkpoint `5b64a3a` also removed the pre-existing `push` and `pull_request` triggers from **iOS CI**. Every workflow currently under `.github/workflows/` now requires an explicit `workflow_dispatch`; ordinary pushes do not start any of these macOS jobs.

## First validation run

Push the checkpoint branch yourself, then in the GitHub repository select:

1. **Actions**
2. **iOS Simulator Build**
3. **Run workflow**
4. Branch: **codex-sprint-8h-20260830**
5. **run_tests**: **true**
6. **product**: **all**
7. **Run workflow**

This attempts all four product builds in the same paid runner session and reports every failed product instead of stopping at the first compile error. Only after all four builds are clean does it run ProductConfigurationTests once on a dynamically selected available iPhone Simulator, reusing MinikPlus DerivedData. A normal Git push consumes zero minutes from this workflow because `workflow_dispatch` is its only trigger.

## Later single-product builds

For ordinary visual checks, start the same workflow manually, choose the branch containing the desired code, leave **run_tests** set to **false**, and select exactly one product. Only that product is built:

- MinikPlus
- MinikPlusEnglish
- MinikMath
- MinikPingPong

The default product is MinikMath. Select **all** only when all four products need validation.

## Results, failures, and artifacts

Open the workflow run and expand the failed step to inspect the complete XcodeGen or xcodebuild output. With **product=all**, the build step attempts MinikPlus, MinikPlusEnglish, MinikMath, and MinikPingPong before returning an aggregate failure, so one runner session exposes compile errors across the whole product set. The separate **Simulator-build-logs** artifact is uploaded after either a successful or failed build step and contains the plain-text logs for every requested product; it is retained for three days and never contains DerivedData. Each product is marked package-ready only after its build, app discovery, and ZIP packaging succeed. Its artifact uploads from that explicit state even when another requested product fails; no artifact is created for a failed or missing product, and any product failure still fails the overall run. When tests were requested and reached, download the separate **ProductConfigurationTests** artifact for the .xcresult bundle and test log.

For **product=all**, a fully successful run exposes four short-lived product artifacts; a partially failed run exposes only the products that reached the package-ready state:

- **MinikPlus-simulator** containing **MinikPlus-simulator.zip**
- **MinikPlusEnglish-simulator** containing **MinikPlusEnglish-simulator.zip**
- **MinikMath-simulator** containing **MinikMath-simulator.zip**
- **MinikPingPong-simulator** containing **MinikPingPong-simulator.zip**

Each product ZIP preserves the compiled iOS Simulator .app. It is not an IPA and cannot be installed on a physical iPhone or submitted to App Store Connect.

On Windows, download the required artifact, extract the GitHub artifact archive, and upload the enclosed simulator ZIP to Appetize. This is useful for layout, navigation, interaction, localization, and accessibility smoke testing, but it does not replace physical-device and TestFlight QA. StoreKit, haptics, device-only lifecycle behavior, physical-device performance, audio timing, and final production behavior remain later gates.

GitHub retains these workflow artifacts for three days. Delete a run's artifacts sooner from the run summary when they are no longer needed, or allow them to expire automatically. Repository owners can inspect consumed and remaining Actions quota under **Settings → Billing and plans → Usage** (the exact GitHub settings label can vary by account type).

No secrets, Apple certificates, provisioning profiles, API tokens, or signing credentials belong in this workflow.
