import SwiftUI

/// Standalone Modern. The legacy 80's implementation is not reachable here.
struct PingPongOnlyRootView: View {
    let commerce: MinikCommerceController
    var body: some View { ModernPongView(experience: .full, commerce: commerce) }
}
