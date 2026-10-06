import SwiftUI

@main
struct MinikApp: App {
    @UIApplicationDelegateAdaptor(MinikAppDelegate.self) private var appDelegate
    private let configuration = ProductConfiguration.configuration(for: .current)

    var body: some Scene {
        WindowGroup {
            #if MINIK_RETRO_PING_PONG
            BounceRootView()
            #else
            RootView(configuration: configuration)
            #endif
        }
    }
}

extension ProductVariant {
    static var current: ProductVariant {
        #if MINIK_PLUS
        .minikPlus
        #elseif MINIK_PLUS_ENGLISH
        .minikPlusEnglish
        #elseif MINIK_MATH
        .minikMath
        #elseif MINIK_PING_PONG || MINIK_RETRO_PING_PONG
        .minikPingPong
        #else
        #error("A Minik product compilation condition must be configured.")
        #endif
    }
}
