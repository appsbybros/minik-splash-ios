import Foundation
import SwiftUI

/// Android `KnockoutBracketView`: a sideways-scrolling redraw tree. One column per round, then the winner card.
/// Connectors follow actual winners, including random byes. Coordinates are laid out left to right and mirrored
/// for Hebrew exactly as on Android (`he` there); the cards, titles and player rows read right to left in Hebrew and
/// Arabic (Android `AppText.rtl`, working tree on 828c6fc, 2026-10-04).
struct MPKnockoutBracketView: View {
    let session: MPSession
    let hebrew: Bool
    private static let cardWidth: CGFloat = 222, cardHeight: CGFloat = 116, columnStride: CGFloat = 268, header: CGFloat = 66
    private struct Node { var column: Int; var y: CGFloat; var people: [String]; var match: MPFixture?; var bye: Bool }
    private struct Layout { var counts: [Int]; var nodes: [Node]; var width: CGFloat; var height: CGFloat }

    private var layout: Layout {
        let counts = MPKnockout.bracketColumns(session)
        let width = Self.columnStride * CGFloat(counts.count) + Self.cardWidth + 24
        let height = Self.header + CGFloat(((counts.first ?? 2) + 1) / 2) * (Self.cardHeight + 20) + 16
        var nodes: [Node] = []
        for (column, countHere) in counts.enumerated() {
            let rowCount = (countHere + 1) / 2
            let players = session.rounds[column]?.players ?? []
            for row in 0..<rowCount {
                let pair = Array(players.dropFirst(row * 2).prefix(2))
                let y = Self.header + (height - Self.header - 16) * (CGFloat(row) + 0.5) / CGFloat(rowCount) - Self.cardHeight / 2
                nodes.append(Node(column: column, y: y, people: pair, match: session.matches[MPKnockout.id(session.code, column, row)], bye: pair.count == 1))
            }
        }
        return Layout(counts: counts, nodes: nodes, width: width, height: height)
    }
    private func x(_ column: Int, _ layout: Layout) -> CGFloat {
        hebrew ? layout.width - 12 - CGFloat(column) * Self.columnStride - Self.cardWidth : 12 + CGFloat(column) * Self.columnStride
    }
    var body: some View {
        let layout = self.layout
        ZStack(alignment: .topLeading) {
            connectors(layout).stroke(Color(red: 139 / 255, green: 125 / 255, blue: 198 / 255), lineWidth: 2)
            ForEach(Array(layout.counts.enumerated()), id: \.offset) { item in
                title(MPKnockout.stage(players: item.element, hebrew: hebrew) + "\n" + MPText.t("\(item.element) players", "\(item.element) שחקנים", hebrew))
                    .environment(\.layoutDirection, MPText.rtl ? .rightToLeft : .leftToRight)
                    .frame(width: Self.cardWidth, height: 60)
                    .offset(x: x(item.offset, layout), y: 0)
            }
            ForEach(Array(layout.nodes.enumerated()), id: \.offset) { item in
                card(item.element).offset(x: x(item.element.column, layout), y: item.element.y)
            }
            winnerCard.offset(x: x(layout.counts.count, layout), y: Self.header + (layout.height - Self.header) / 2 - 58)
        }
        .frame(width: layout.width, height: layout.height, alignment: .topLeading)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(MPText.t("Knockout bracket. Swipe sideways to see every round.", "עץ טורניר נוקאאוט. מחליקים לצדדים לצפייה בכל השלבים.", hebrew))
    }
    private func connectors(_ layout: Layout) -> Path {
        var path = Path()
        func connect(_ from: Node, _ column: Int, _ y: CGFloat) {
            let start = x(from.column, layout) + (hebrew ? 0 : Self.cardWidth)
            let end = x(column, layout) + (hebrew ? Self.cardWidth : 0)
            let startY = from.y + Self.cardHeight / 2, middle = (start + end) / 2
            path.move(to: CGPoint(x: start, y: startY))
            path.addCurve(to: CGPoint(x: end, y: y), control1: CGPoint(x: middle, y: startY), control2: CGPoint(x: middle, y: y))
        }
        for node in layout.nodes where node.column > 0 {
            for id in node.people {
                let previous = layout.nodes.first { $0.column == node.column - 1 && $0.people.contains(id) && ($0.bye || $0.match?.winner == id) }
                if let previous { connect(previous, node.column, node.y + Self.cardHeight / 2) }
            }
        }
        if let winner = MPKnockout.winner(session),
           let last = layout.nodes.first(where: { $0.column == layout.counts.count - 1 && $0.people.contains(winner) }) {
            connect(last, layout.counts.count, Self.header + (layout.height - Self.header) / 2)
        }
        return path
    }
    private func card(_ node: Node) -> some View {
        VStack(spacing: 0) {
            if node.people.isEmpty {
                title(MPText.t("Awaiting the next draw", "ממתינים להגרלה הבאה", hebrew), size: 14).frame(maxHeight: .infinity)
            } else {
                ForEach(node.people, id: \.self) { id in player(id, node.match, bye: node.bye).frame(height: 37) }
                title(status(node), size: 12).frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 7).padding(.vertical, 5)
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .background(surface(node.bye ? Color(red: 232 / 255, green: 223 / 255, blue: 1) : Color(red: 229 / 255, green: 249 / 255, blue: 242 / 255)))
        .environment(\.layoutDirection, MPText.rtl ? .rightToLeft : .leftToRight)
    }
    private func status(_ node: Node) -> String {
        if node.bye { return MPText.t("Bye · advances", "עלייה אוטומטית", hebrew) }
        switch node.match?.phase {
        case .finished?: return MPText.t("Finished", "הסתיים", hebrew)
        case .cancelled?: return MPText.t("Walkover", "עלייה עקב פרישה", hebrew)
        case .playing?: return MPText.t("Playing now", "משחקים עכשיו", hebrew)
        case .ready?: return MPText.t("Ready", "מוכנים", hebrew)
        default: return MPText.t("Not started", "טרם התחיל", hebrew)
        }
    }
    private var winnerCard: some View {
        let winner = MPKnockout.winner(session)
        return VStack(spacing: 0) {
            title(MPText.t("🏆 Winner!", "🏆 המנצח!", hebrew)).frame(height: 42)
            if let winner { player(winner, nil, bye: true).frame(height: 54) }
            else { title(MPText.t("Who will win?", "מי ינצח?", hebrew)).frame(height: 42) }
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .background(surface(Color(red: 1, green: 239 / 255, blue: 187 / 255)))
        .environment(\.layoutDirection, MPText.rtl ? .rightToLeft : .leftToRight)
    }
    private func surface(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 14).fill(color)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(red: 180 / 255, green: 167 / 255, blue: 216 / 255), lineWidth: 1))
    }
    private func title(_ value: String, size: CGFloat = 16) -> some View {
        Text(value).font(.system(size: size, weight: .bold)).foregroundStyle(MPStyle.ink)
            .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .frame(maxWidth: .infinity)
    }
    private func player(_ id: String, _ m: MPFixture?, bye: Bool) -> some View {
        let p = session.participants[id]
        let character = p?.bot?.characterId ?? p?.identity.characterId ?? ""
        let score: String
        if bye { score = "★" }
        else if let m, m.phase == .finished { score = String(id == m.a ? m.scoreA : m.scoreB) }
        else { score = "–" }
        let eliminated = m.map { $0.terminal && $0.winner != id } ?? false
        return HStack(spacing: 4) {
            Group {
                if !character.isEmpty { MPAvatar(character: character, icon: 0) }
                else { Text(MPNames.icons[max(0, p?.identity.avatar ?? 0) % MPNames.icons.count]).font(.system(size: 22)) }
            }.frame(width: 34, height: 34)
            Text(p?.name(hebrew: hebrew) ?? "").font(.system(size: 13, weight: .bold)).foregroundStyle(MPStyle.ink)
                .lineLimit(2).truncationMode(.tail).frame(maxWidth: .infinity).opacity(eliminated ? 0.55 : 1)
            Text(score).font(.system(size: 16, weight: .bold)).foregroundStyle(MPStyle.ink).frame(width: 25)
        }
    }
}

/// Android `VictoryConfetti`: a brief (2.8 s), noninteractive celebration over the whole screen.
/// Skipped when the person has asked iOS to reduce motion.
struct MPVictoryConfetti: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var began = Date()
    @State private var finished = false
    private static let colors: [Color] = [
        Color(red: 1, green: 206 / 255, blue: 70 / 255), Color(red: 1, green: 100 / 255, blue: 177 / 255),
        Color(red: 107 / 255, green: 227 / 255, blue: 195 / 255), Color(red: 115 / 255, green: 161 / 255, blue: 1), .white
    ]
    var body: some View {
        Group {
            if !finished && !reduceMotion {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let elapsed = timeline.date.timeIntervalSince(began)
                        guard elapsed <= 2.8 else { return }
                        let width = Double(size.width), height = Double(size.height)
                        let fade = 1 - min(max(elapsed - 2, 0), 0.8) / 0.8
                        for i in 0..<75 {
                            let x = Double(i * 73 % 101) / 101 * width + sin(elapsed * 2 + Double(i)) * 14
                            let y = -height * 0.20 + Double(i * 37 % 101) / 101 * height * 0.4 + elapsed * height * 0.45
                            var piece = context
                            piece.opacity = fade
                            piece.translateBy(x: CGFloat(x), y: CGFloat(y))
                            piece.rotate(by: .degrees(elapsed * Double(80 + i % 7 * 13)))
                            piece.fill(Path(CGRect(x: 0, y: 0, width: 5, height: 10)), with: .color(Self.colors[i % Self.colors.count]))
                        }
                    }
                }
                .task {
                    try? await Task.sleep(nanoseconds: 2_800_000_000)
                    finished = true
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
