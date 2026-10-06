import AVFoundation
import UIKit

final class MinikAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = FirebaseBootstrap.configureIfAvailable(for: .current)
        // Spoken words and game sounds are part of the lesson, so they play even
        // when the device is set to silent, as on Android, and mix with other audio.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        return true
    }
}
