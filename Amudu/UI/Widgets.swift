import SwiftUI

extension Color {
    /// Android ARGB int (0xAARRGGBB).
    init(argb: UInt32) {
        self.init(.sRGB,
                  red: Double((argb >> 16) & 0xff) / 255,
                  green: Double((argb >> 8) & 0xff) / 255,
                  blue: Double(argb & 0xff) / 255,
                  opacity: Double((argb >> 24) & 0xff) / 255)
    }
}

/// Android `label(s, size, color)`: bold, centered, 9/7 padding.
struct AmuduLabel: View {
    let text: String
    var size: CGFloat = 18
    var color: UInt32 = 0xffffffff

    init(_ text: String, size: CGFloat = 18, color: UInt32 = 0xffffffff) {
        self.text = text
        self.size = size
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold))
            .foregroundColor(Color(argb: color))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
    }
}

/// Android `button(s, color)`: 54 dp, 18 dp corners, dark bold text.
struct AmuduButton: View {
    let title: String
    var color: UInt32 = 0xffb8f3dc
    let action: () -> Void

    init(_ title: String, color: UInt32 = 0xffb8f3dc, action: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(argb: 0xff12324a))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(argb: color)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
    }
}

/// Android `page(title)`: the arena picture at 40% over navy, a scrolling column and a 28 sp title.
struct AmuduPage<Content: View>: View {
    let title: String
    let background: UIImage
    let content: Content

    init(_ title: String, background: UIImage, @ViewBuilder content: () -> Content) {
        self.title = title
        self.background = background
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color(argb: 0xff0b2036).ignoresSafeArea()
            GeometryReader { geo in
                Image(uiImage: background)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .opacity(0.40)
            }
            .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    AmuduLabel(title, size: 28)
                    content
                }
                .padding(EdgeInsets(top: 12, leading: 20, bottom: 24, trailing: 20))
            }
        }
    }
}

private struct StarShape: Shape {
    let index: Int

    func path(in rect: CGRect) -> Path {
        let step = rect.width / 5
        let r = min(step * 0.44, rect.height * 0.43)
        let x = step * (CGFloat(index) + 0.5)
        let y = rect.height / 2
        var outline = Path()
        for j in 0..<10 {
            let a = -Double.pi / 2 + Double(j) * Double.pi / 5
            let radius = j % 2 == 0 ? r : r * 0.44
            let point = CGPoint(x: x + CGFloat(cos(a)) * radius, y: y + CGFloat(sin(a)) * radius)
            if j == 0 { outline.move(to: point) } else { outline.addLine(to: point) }
        }
        outline.closeSubpath()
        return outline
    }
}

/// Android `SkillStars`: five stars, filled gold up to the rating, thin grey outlines after it.
struct SkillStars: View {
    let value: Int

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                if i < value {
                    StarShape(index: i).fill(Color(argb: 0xffffdd63))
                } else {
                    StarShape(index: i).stroke(Color(argb: 0xffb7bdc8), lineWidth: 1)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(value) / 5")
    }
}

private struct ChevronShape: Shape {
    let right: Bool

    func path(in rect: CGRect) -> Path {
        let sign: CGFloat = right ? 1 : -1
        let cx = rect.midX
        let cy = rect.midY
        var outline = Path()
        outline.move(to: CGPoint(x: cx - sign * 10, y: cy - 19))
        outline.addLine(to: CGPoint(x: cx + sign * 10, y: cy))
        outline.addLine(to: CGPoint(x: cx - sign * 10, y: cy + 19))
        return outline
    }
}

/// Android `AvatarArrow`: a thick rounded chevron in a 64x72 touch target.
struct AvatarArrow: View {
    let right: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ChevronShape(right: right)
                .stroke(Color(argb: 0xffb8f3dc), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                .frame(width: 64, height: 72)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppText.t(right ? "Next avatar" : "Previous avatar"))
    }
}

/// Android `ic_dropdown` vector (24x24 viewport).
private struct DropdownShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 24
        let sy = rect.height / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { return CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var outline = Path()
        outline.move(to: p(5.4, 8.6))
        outline.addLine(to: p(12, 15.2))
        outline.addLine(to: p(18.6, 8.6))
        outline.addLine(to: p(20, 10))
        outline.addLine(to: p(12, 18))
        outline.addLine(to: p(4, 10))
        outline.closeSubpath()
        return outline
    }
}

/// Android `Spinner` choice: a label above a light rounded field with a dropdown chevron.
struct ChoiceMenu: View {
    let title: String
    let items: [String]
    let selected: Int
    let change: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            AmuduLabel(title, size: 17)
            Menu {
                ForEach(items.indices, id: \.self) { i in
                    Button {
                        change(i)
                    } label: {
                        if i == selected {
                            Label(items[i], systemImage: "checkmark")
                        } else {
                            Text(items[i])
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selected >= 0 && selected < items.count ? items[selected] : "")
                        .font(.system(size: 16))
                        .foregroundColor(Color(argb: 0xff14324a))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DropdownShape()
                        .fill(Color(argb: 0xff14324a))
                        .frame(width: 28, height: 28)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: items.contains(where: { $0.count > 44 }) ? 82 : 54)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color(argb: 0xffe3f4ff)))
                .contentShape(Rectangle())
            }
        }
    }
}

/// Android `CheckBox` row: white 17 sp text, cyan accent, disabled for the player's own avatar.
struct HouseCheck: View {
    let title: String
    let checked: Bool
    let enabled: Bool
    let toggle: (Bool) -> Void

    var body: some View {
        Button {
            toggle(!checked)
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(checked ? Color(argb: 0xff00e5ff) : Color.white, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if checked {
                        RoundedRectangle(cornerRadius: 3).fill(Color(argb: 0xff00e5ff)).frame(width: 20, height: 20)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(argb: 0xff0b2036))
                    }
                }
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}

/// Android `Toast`.
struct ToastView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.black.opacity(0.78)))
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
    }
}
