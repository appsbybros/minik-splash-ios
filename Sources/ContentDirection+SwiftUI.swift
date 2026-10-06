import SwiftUI

extension ContentDirection {
    var layoutDirection: LayoutDirection {
        switch self {
        case .leftToRight:
            .leftToRight
        case .rightToLeft:
            .rightToLeft
        }
    }
}
