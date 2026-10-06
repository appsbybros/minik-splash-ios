import SwiftUI

@MainActor
final class RecordsLeaderboardViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded(RemoteRecordsSnapshot)
        case notConfigured
        case failed
    }

    @Published private(set) var state: State = .idle
    private let repository: (any RecordsRepository)?

    init(repository: (any RecordsRepository)?) {
        self.repository = repository
    }

    func load() async {
        guard let repository else {
            state = .notConfigured
            return
        }
        state = .loading
        do {
            state = .loaded(try await repository.loadTopRecords())
        } catch {
            state = .failed
        }
    }
}

struct RecordsLeaderboardView: View {
    let onClose: () -> Void
    private let highlightedPlacements: [RemoteRecordPlacement]
    @StateObject private var model: RecordsLeaderboardViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Grows with the text so two-digit ranks (10-20) stay on one line; a fixed
    /// 30-point column wrapped them digit by digit at larger text sizes.
    @ScaledMetric(relativeTo: .headline) private var rankColumnWidth: CGFloat = 30

    @MainActor
    init(
        product: ProductVariant,
        repository: (any RecordsRepository)? = nil,
        highlightedPlacements: [RemoteRecordPlacement] = [],
        onClose: @escaping () -> Void
    ) {
        self.onClose = onClose
        self.highlightedPlacements = highlightedPlacements
        let resolvedRepository = repository ?? ProductionRecordsRepositoryFactory.make(for: product)
        _model = StateObject(wrappedValue: RecordsLeaderboardViewModel(repository: resolvedRepository))
    }

    var body: some View {
        // The layout of MinikHomeScreen (a scroll view with the artwork as its
        // background), plus a reader around the scroll view so the row holding a
        // new record can be scrolled into view.
        GeometryReader { geometry in
            let metrics = MinikHomeLayoutMetrics(containerWidth: geometry.size.width)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: metrics.compact ? 18 : 24) {
                        header(compact: metrics.compact)
                        content(metrics: metrics)
                    }
                    .frame(maxWidth: metrics.contentMaxWidth)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.vertical, metrics.verticalPadding)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: model.state) { _, newState in
                    scrollToHighlightedRow(in: newState, using: proxy)
                }
            }
        }
        // A fill background never sizes the layout (see MinikHomeScreen). As a
        // ZStack sibling the artwork pushed the scroll view down, so the last
        // rows could not be scrolled into view.
        .background {
            MinikArtworkBackground()
                .ignoresSafeArea()
        }
        .task { await model.load() }
    }

    private func header(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            MinikArtworkImage(name: MinikVisualAsset.trophy)
                .frame(width: compact ? 62 : 76, height: compact ? 76 : 92)
                .accessibilityHidden(true)

            Text(headerTitle)
                .font(compact ? .title.bold() : .largeTitle.bold())
                .foregroundStyle(Color(red: 0.11, green: 0.36, blue: 0.45))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onClose) {
                MinikArtworkImage(name: MinikVisualAsset.close)
                    .frame(width: compact ? 46 : 56, height: compact ? 46 : 56)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Done"))
        }
    }

    @ViewBuilder
    private func content(metrics: MinikHomeLayoutMetrics) -> some View {
        switch model.state {
        case .idle, .loading:
            MinikHomeSectionCard(compact: metrics.compact) {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .accessibilityLabel(String(localized: "Loading records"))
            }
        case .notConfigured:
            unavailableCard(
                message: String(localized: "Remote records are not configured for this build."),
                compact: metrics.compact,
                canRetry: false
            )
        case .failed:
            unavailableCard(
                message: String(localized: "The records could not be loaded."),
                compact: metrics.compact,
                canRetry: true
            )
        case .loaded(let snapshot):
            if snapshot.isFromCache {
                Label("Showing saved records while offline.", systemImage: "wifi.slash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.33, green: 0.45, blue: 0.52))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if snapshot.isEmpty {
                MinikHomeSectionCard(compact: metrics.compact) {
                    ContentUnavailableView {
                        Label("No records yet", systemImage: "trophy")
                    } description: {
                        Text("New records will appear here.")
                    }
                }
            } else if showsBoardsSideBySide(metrics) {
                // On an iPad in portrait the two boards fit beside each other, so
                // both Top 20 lists show on one screen at the default text size.
                HStack(alignment: .top, spacing: 16) {
                    scoreCard(snapshot, compact: metrics.compact)
                    streakCard(snapshot, compact: metrics.compact)
                }
            } else {
                scoreCard(snapshot, compact: metrics.compact)
                streakCard(snapshot, compact: metrics.compact)
            }
        }
    }

    /// Side by side only where each board keeps a comfortable width (iPad), and
    /// not at accessibility text sizes, whose rows need the full width.
    private func showsBoardsSideBySide(_ metrics: MinikHomeLayoutMetrics) -> Bool {
        !metrics.compact && !dynamicTypeSize.isAccessibilitySize && metrics.contentMaxWidth >= 680
    }

    private func scoreCard(_ snapshot: RemoteRecordsSnapshot, compact: Bool) -> some View {
        recordCard(
            title: String(localized: "Scores"),
            systemImage: "star.fill",
            type: .score,
            rows: scoreRows(in: snapshot),
            compact: compact
        )
    }

    private func streakCard(_ snapshot: RemoteRecordsSnapshot, compact: Bool) -> some View {
        recordCard(
            title: String(localized: "Best streaks"),
            systemImage: "flame.fill",
            type: .correctAnswersStreak,
            rows: streakRows(in: snapshot),
            compact: compact
        )
    }

    private func scoreRows(in snapshot: RemoteRecordsSnapshot) -> [RecordRow] {
        recordRows(
            type: .score,
            entries: snapshot.scoreRecords.map {
                (publicAlias: $0.publicAlias, avatarID: $0.avatarID, value: $0.score)
            }
        )
    }

    private func streakRows(in snapshot: RemoteRecordsSnapshot) -> [RecordRow] {
        recordRows(
            type: .correctAnswersStreak,
            entries: snapshot.streakRecords.map {
                (publicAlias: $0.publicAlias, avatarID: $0.avatarID, value: $0.correctAnswersInRow)
            }
        )
    }

    /// A new record often ranks below the first screenful (with larger text an
    /// iPad mini shows little more than the first dozen ranks), so its
    /// highlighted row is scrolled into view once the boards load.
    private func scrollToHighlightedRow(
        in state: RecordsLeaderboardViewModel.State,
        using proxy: ScrollViewProxy
    ) {
        guard case .loaded(let snapshot) = state,
              let target = highlightedRowScrollID(in: snapshot) else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) {
            proxy.scrollTo(target, anchor: .center)
        }
    }

    private func highlightedRowScrollID(in snapshot: RemoteRecordsSnapshot) -> String? {
        if let row = scoreRows(in: snapshot).first(where: { $0.isHighlighted }) {
            return rowScrollID(type: .score, row: row)
        }
        if let row = streakRows(in: snapshot).first(where: { $0.isHighlighted }) {
            return rowScrollID(type: .correctAnswersStreak, row: row)
        }
        return nil
    }

    private func rowScrollID(type: RemoteRecordType, row: RecordRow) -> String {
        "\(type.rawValue).\(row.position)"
    }

    private func unavailableCard(message: String, compact: Bool, canRetry: Bool) -> some View {
        MinikHomeSectionCard(compact: compact) {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.system(size: compact ? 38 : 46, weight: .bold))
                    .foregroundStyle(Color(red: 0.96, green: 0.61, blue: 0.26))
                    .accessibilityHidden(true)
                Text(message)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(red: 0.28, green: 0.47, blue: 0.56))
                    .multilineTextAlignment(.center)
                if canRetry {
                    Button("Try again") {
                        Task { await model.load() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 160)
        }
    }

    private func recordCard(
        title: String,
        systemImage: String,
        type: RemoteRecordType,
        rows: [RecordRow],
        compact: Bool
    ) -> some View {
        MinikHomeSectionCard(compact: compact) {
            Label(title, systemImage: systemImage)
                .font(.title3.bold())
                .foregroundStyle(Color(red: 0.14, green: 0.39, blue: 0.49))

            // Rows sit closer together than the card's sections so more of the
            // Top 20 fits on one screen.
            VStack(spacing: 4) {
                ForEach(rows) { row in
                    recordRow(row)
                        .id(rowScrollID(type: type, row: row))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func recordRow(_ row: RecordRow) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // At accessibility sizes the value moves under the name, so the
                // rank, the name and the value each keep a readable width.
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        rankText(row)
                        nameLabel(row, maximumLines: 2)
                    }
                    valueText(row)
                        .padding(.leading, rankColumnWidth + 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 12) {
                    rankText(row)
                    nameLabel(row, maximumLines: 1)
                    Spacer(minLength: 8)
                    valueText(row)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            row.isHighlighted
                ? Color(red: 1.0, green: 0.92, blue: 0.56).opacity(0.72)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: row))
    }

    private func rankText(_ row: RecordRow) -> some View {
        Text(row.rank.formatted())
            .font(.headline.monospacedDigit())
            .foregroundStyle(Color(red: 0.34, green: 0.59, blue: 0.68))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(width: rankColumnWidth, alignment: .trailing)
    }

    private func nameLabel(_ row: RecordRow, maximumLines: Int) -> some View {
        HStack(spacing: 8) {
            if let avatar = row.avatar {
                Image(systemName: avatar.symbolName)
                    .foregroundStyle(Color(red: 0.55, green: 0.35, blue: 0.82))
                    .accessibilityHidden(true)
            }
            Text(displayName(for: row))
                .font(.headline)
                .foregroundStyle(Color(red: 0.13, green: 0.35, blue: 0.44))
                .lineLimit(maximumLines)
                .minimumScaleFactor(0.7)
        }
    }

    /// The value is never wrapped or cut; the name gives way instead.
    private func valueText(_ row: RecordRow) -> some View {
        Text(row.value.formatted())
            .font(.headline.monospacedDigit())
            .foregroundStyle(Color(red: 0.55, green: 0.35, blue: 0.82))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    /// Public names arrive as published by either platform (PublicLeaderboardAlias.validatedRemoteAlias);
    /// only an empty or unsafe name shows as "Player".
    private func displayName(for row: RecordRow) -> String {
        row.publicAlias.isEmpty ? String(localized: "Player") : row.publicAlias
    }

    private var headerTitle: String {
        let types = Set(highlightedPlacements.map(\.type))
        if types == [.score, .correctAnswersStreak] {
            return String(localized: "Two new records!")
        }
        if types == [.score] {
            return String(localized: "New score record!")
        }
        if types == [.correctAnswersStreak] {
            return String(localized: "New streak record!")
        }
        return String(localized: "Top 20 records")
    }

    /// Equal values share a rank, the same way a new placement's position is
    /// computed, so the highlight lands on the row that holds the new record.
    private func recordRows(
        type: RemoteRecordType,
        entries: [(publicAlias: String, avatarID: String?, value: Int64)]
    ) -> [RecordRow] {
        entries.enumerated().map { index, entry in
            let rank = entries.filter { $0.value > entry.value }.count + 1
            return RecordRow(
                position: index,
                rank: rank,
                publicAlias: entry.publicAlias,
                avatarID: entry.avatarID,
                value: entry.value,
                isHighlighted: highlightedPlacements.contains {
                    $0.type == type && $0.position == rank && $0.value == entry.value
                }
            )
        }
    }

    private func accessibilityLabel(for row: RecordRow) -> String {
        String(
            format: String(localized: "Rank %lld: %@, %lld"),
            Int64(row.rank),
            displayName(for: row),
            row.value
        )
    }
}

private struct RecordRow: Identifiable {
    let position: Int
    let rank: Int
    let publicAlias: String
    let avatarID: String?
    let value: Int64
    let isHighlighted: Bool

    var id: Int { position }
    var avatar: PublicLeaderboardAvatar? {
        avatarID.flatMap(PublicLeaderboardAvatar.init(rawValue:))
    }
}
