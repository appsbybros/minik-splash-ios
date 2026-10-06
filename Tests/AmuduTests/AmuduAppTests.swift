import XCTest
@testable import MinikAmudu

final class AmuduAppTests: XCTestCase {
    func testHostIsTheAmuduApp() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.appsbybros.minik.spud")
    }
}
