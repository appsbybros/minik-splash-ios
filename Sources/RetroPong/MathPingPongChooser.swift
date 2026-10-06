import SwiftUI

/// Math's two game entries share their standalone implementations, not the retired renderer.
struct MathPingPongChooser: View {
    let commerce: MinikCommerceController
    /// Called once when a Modern match finishes, so Math can count it like Android Math.
    var onCompletedMatch: () -> Void = {}
    let onExit: () -> Void
    @Environment(\.locale) private var locale
    @State private var selected: PingPongVisualStyle?
    private var he: Bool { locale.language.languageCode?.identifier == "he" }
    var body: some View {
        Group {
            switch selected {
            case .modern: ModernPongView(experience: .simple, commerce: commerce) { result in if result != nil { onCompletedMatch() }; onExit() }
            case .retro: RetroPongView(onExit: onExit, onMatchFinished: { done in onCompletedMatch(); done() })
            case nil:
                VStack(spacing: 24) {
                    ZStack {
                        Text(he ? "פינג פונג" : "Ping Pong").font(.title.bold())
                        HStack { Button(action: onExit) { Image(systemName: he ? "arrow.right" : "arrow.left").font(.system(size: 27, weight: .heavy)).frame(width: 48, height: 48) }.foregroundStyle(Color(red: 233/255, green: 30/255, blue: 99/255)).accessibilityLabel(he ? "חזרה" : "Back"); Spacer() }
                    }
                    ScrollView {
                        VStack(spacing: 20) {
                            Image("mp_app_icon").resizable().scaledToFit().frame(maxWidth: 210, maxHeight: 210).accessibilityHidden(true)
                            choice(he ? "מודרני" : "MODERN", symbol: "figure.table.tennis", color: Color(red: 0.72, green: 0.95, blue: 0.85), style: .modern)
                            choice(he ? "בסגנון שנות ה־80" : "80’s STYLE", symbol: "sparkles", color: Color(red: 0.90, green: 0.84, blue: 1), style: .retro)
                        }.frame(maxWidth: 520).frame(maxWidth: .infinity).padding(.bottom, 24)
                    }
                }.padding(.horizontal, 20).padding(.top, 8).background(Color(red: 0.97, green: 0.97, blue: 1)).foregroundStyle(Color(red: 0.15, green: 0.17, blue: 0.30))
            }
        }.environment(\.layoutDirection, he ? .rightToLeft : .leftToRight).preferredColorScheme(.light)
    }
    private func choice(_ title: String, symbol: String, color: Color, style: PingPongVisualStyle) -> some View {
        Button { selected = style } label: { Label(title, systemImage: symbol).font(.title3.bold()).frame(maxWidth: .infinity, minHeight: 64).background(color, in: RoundedRectangle(cornerRadius: 18)) }.buttonStyle(.plain)
    }
}
