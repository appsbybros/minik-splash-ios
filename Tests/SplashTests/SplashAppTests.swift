import XCTest
@testable import MinikSplash

final class SplashAppTests: XCTestCase {
    func testHostIsTheSplashApp() {
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.appsbybros.minik.splash")
    }
}
