import SwiftUI

struct ParentalGateChallenge: Equatable, Sendable {
    let left: Int
    let right: Int

    var answer: Int { left + right }

    /// Accepts Western and other Unicode decimal digits, such as Arabic-Indic
    /// digits typed on an Arabic keyboard.
    func accepts(_ response: String) -> Bool {
        let digits = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !digits.isEmpty, digits.count <= 4 else { return false }
        var value = 0
        for character in digits {
            guard let digit = character.wholeNumberValue, (0...9).contains(digit) else { return false }
            value = value * 10 + digit
        }
        return value == answer
    }

    static func random() -> ParentalGateChallenge {
        ParentalGateChallenge(
            left: Int.random(in: 24...59),
            right: Int.random(in: 16...47)
        )
    }
}

struct ParentalGateView: View {
    let challenge: ParentalGateChallenge
    let onCancel: () -> Void
    let onUnlock: () -> Void

    @State private var response = ""
    @State private var showsError = false
    @FocusState private var answerFocused: Bool

    init(
        challenge: ParentalGateChallenge = .random(),
        onCancel: @escaping () -> Void,
        onUnlock: @escaping () -> Void
    ) {
        self.challenge = challenge
        self.onCancel = onCancel
        self.onUnlock = onUnlock
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("This action is for a grown-up.")
                        .font(.headline)
                    Text("Solve this to continue.")
                        .foregroundStyle(.secondary)
                    Text(String(
                        format: String(localized: "%lld + %lld"),
                        Int64(challenge.left),
                        Int64(challenge.right)
                    ))
                    .font(.largeTitle.monospacedDigit().bold())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityLabel(String(
                        format: String(localized: "%lld plus %lld"),
                        Int64(challenge.left),
                        Int64(challenge.right)
                    ))

                    TextField("Answer", text: $response)
                        .keyboardType(.numberPad)
                        .focused($answerFocused)
                        .onSubmit(validate)

                    if showsError {
                        Text("Not quite. Try again.")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Grown-ups only")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue", action: validate)
                        .disabled(response.isEmpty)
                }
            }
            .onAppear { answerFocused = true }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    private func validate() {
        guard challenge.accepts(response) else {
            showsError = true
            response = ""
            answerFocused = true
            return
        }
        onUnlock()
    }
}
