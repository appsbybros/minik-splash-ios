import Foundation
import StoreKitTest
import XCTest

final class StoreKitConfigurationTests: XCTestCase {
    func testLocalFixtureConfigurationCanCreateAnAutomatedStoreKitSession() throws {
        XCTAssertNotNil(
            Bundle.main.url(forResource: "AppStoreCommerceKit", withExtension: "storekit")
        )
        let session = try SKTestSession(configurationFileNamed: "AppStoreCommerceKit")
        session.resetToDefaultState()
        session.disableDialogs = true
    }
}
