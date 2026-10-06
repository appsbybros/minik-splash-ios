import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// App Store screenshot captures launch a Simulator build with
/// `-MinikScreenshotScene <scene>` and, for landscape-only screens,
/// `-MinikScreenshotOrientation landscape` (see `appstore/screenshots.json`).
/// Normal launches never set these arguments, so every hook is inert for users.
enum StoreScreenshotScene {
    static var name: String? {
        guard let value = UserDefaults.standard.string(forKey: "MinikScreenshotScene")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    static var wantsLandscape: Bool {
        UserDefaults.standard.string(forKey: "MinikScreenshotOrientation") == "landscape"
    }

    /// The part after a `prefix.` scene name, e.g. "wordCards" for "language.wordCards".
    static func value(after prefix: String) -> String? {
        guard let name, name.hasPrefix(prefix + ".") else { return nil }
        return String(name.dropFirst(prefix.count + 1))
    }

    /// Turns an iPhone interface to landscape for landscape-only screens.
    @MainActor
    static func applyOrientation() {
        #if canImport(UIKit)
        guard wantsLandscape,
              let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first else {
            return
        }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight)) { _ in }
        #endif
    }
}
