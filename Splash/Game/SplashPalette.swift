import SwiftUI
import UIKit

/// Android ARGB colour literals (0xAARRGGBB) for UIKit drawing and SwiftUI menus.
enum SplashPalette {
    static let balloonColors: [UInt32] = [0xffff7900, 0xffffea00, 0xff76ff03, 0xff2979ff, 0xffe91e63, 0xff00e5ff]
    static let sky: UInt32 = 0xff091b32
    static let white: UInt32 = 0xffffffff
    static let ink: UInt32 = 0xff0b243d

    static func ui(_ argb: UInt32) -> UIColor {
        return UIColor(red: CGFloat((argb >> 16) & 0xff) / 255.0,
                       green: CGFloat((argb >> 8) & 0xff) / 255.0,
                       blue: CGFloat(argb & 0xff) / 255.0,
                       alpha: CGFloat((argb >> 24) & 0xff) / 255.0)
    }

    /// The colour with Android `Paint.setAlpha` applied (0-255).
    static func ui(_ argb: UInt32, alpha: Int) -> UIColor {
        let clamped = min(max(alpha, 0), 255)
        return ui((argb & 0x00ffffff) | (UInt32(clamped) << 24))
    }

    static func color(_ argb: UInt32) -> Color {
        return Color(uiColor: ui(argb))
    }
}
