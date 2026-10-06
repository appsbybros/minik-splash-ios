import XCTest
@testable import MinikMultiPingPong

final class MultiPongAppTests: XCTestCase {
    func testHostIsTheMultiPingPongApp() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.appsbybros.minik.crosspong")
        XCTAssertEqual(ProductVariant.current, .minikPingPong)
    }
}
