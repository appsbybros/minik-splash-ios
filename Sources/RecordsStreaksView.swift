import SwiftUI

struct RecordsStreaksView: View {
    let model: LocalRecordsReadModel
    let onBack: () -> Void

    var body: some View {
        MinikHomeScreen { metrics in
            VStack(alignment: .leading, spacing: metrics.compact ? 18 : 24) {
                header(compact: metrics.compact)
                localOnlyNotice(compact: metrics.compact)

                if model.hasRecordedState {
                    streaks(compact: metrics.compact)
                } else {
                    emptyState(compact: metrics.compact)
                }
            }
        }
    }

    private func header(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Records & Streaks")
                    .font(compact ? .title.bold() : .largeTitle.bold())
                    .foregroundStyle(Color(red: 0.11, green: 0.36, blue: 0.45))
                Text("A record of streaks already earned on this device.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(red: 0.31, green: 0.49, blue: 0.57))
            }
            Spacer(minLength: 12)
            Button(action: onBack) {
                Image(systemName: "chevron.backward.circle.fill")
                    .font(.system(size: compact ? 34 : 40, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: compact ? 44 : 48, height: compact ? 44 : 48)
            }
            .accessibilityLabel("Back to Parent Area")
            .accessibilityHint("Returns to learning settings")
        }
    }

    private func localOnlyNotice(compact: Bool) -> some View {
        MinikHomeSectionCard(compact: compact) {
            Label("Stored on this device", systemImage: "iphone")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.18, green: 0.43, blue: 0.52))
                .accessibilityHint("These records are not synchronized to the cloud")
        }
    }

    private func streaks(compact: Bool) -> some View {
        MinikHomeSectionCard(compact: compact) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Local streak record", systemImage: "flame.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(red: 0.14, green: 0.39, blue: 0.49))
                LabeledContent("Current streak", value: model.currentStreak.formatted())
                LabeledContent("Best streak", value: model.bestStreak.formatted())
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func emptyState(compact: Bool) -> some View {
        MinikHomeSectionCard(compact: compact) {
            ContentUnavailableView {
                Label("No local records yet", systemImage: "trophy")
            } description: {
                Text("Earned streak records will appear here when they are available.")
            }
        }
    }
}
