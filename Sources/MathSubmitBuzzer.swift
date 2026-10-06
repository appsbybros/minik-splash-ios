import SwiftUI

struct MathSubmitBuzzer: View {
    let action: () -> Void
    var isEnabled = true
    @State private var feedbackTrigger = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            feedbackTrigger.toggle()
            action()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 112, height: 78)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.78, blue: 0.76),
                            Color(red: 0.06, green: 0.57, blue: 0.62)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white, Color(red: 0.58, green: 0.64, blue: 0.68)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 5
                        )
                }
                .shadow(color: .black.opacity(0.2), radius: 3, y: 7)
        }
        .buttonStyle(MathBuzzerPressStyle(reduceMotion: reduceMotion))
        .disabled(!isEnabled)
        .sensoryFeedback(.impact(weight: .medium), trigger: feedbackTrigger)
        .accessibilityLabel(String(localized: "Check answer"))
        .accessibilityHint(String(localized: "Checks the amount you built"))
    }
}

private struct MathBuzzerPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .offset(y: configuration.isPressed ? 5 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
