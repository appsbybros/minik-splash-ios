import SwiftUI

struct MathQuantityView: View {
    let quantity: Int
    let mode: MathQuantityLayoutMode
    let theme: MathObjectTheme?
    let groupingAsset: MathObjectAsset?
    let emphasized: Bool

    init(
        quantity: Int,
        mode: MathQuantityLayoutMode = .individual,
        theme: MathObjectTheme? = nil,
        groupingAsset: MathObjectAsset? = nil,
        emphasized: Bool = false
    ) {
        self.quantity = quantity
        self.mode = mode
        self.theme = theme
        self.groupingAsset = groupingAsset
        self.emphasized = emphasized
    }

    var body: some View {
        if quantity == 0 {
            emptyQuantity
        } else {
            GeometryReader { proxy in
                let result = MathQuantityLayout().layout(
                    count: quantity,
                    inWidth: proxy.size.width,
                    height: proxy.size.height,
                    mode: mode
                )
                ZStack(alignment: .topLeading) {
                    if let groupingAsset {
                        Image(groupingAsset.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .accessibilityHidden(true)
                    }
                    if let result {
                        ForEach(result.items, id: \.itemIndex) { item in
                            object(at: item.itemIndex)
                                .frame(width: item.diameter, height: item.diameter)
                                .position(x: item.centerX, y: item.centerY)
                        }
                    }
                }
            }
            .frame(maxWidth: emphasized ? 420 : 360, minHeight: 96, maxHeight: emphasized ? 280 : 220)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(
                format: String(localized: "Quantity of %lld"),
                Int64(quantity)
            ))
        }
    }

    @ViewBuilder
    private var emptyQuantity: some View {
        if let asset = theme?.emptyStateAsset {
            Image(asset.assetName)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("Empty quantity")
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 3, dash: [8, 7])
                )
                .frame(width: emphasized ? 132 : 104, height: emphasized ? 92 : 72)
                .accessibilityLabel("Empty quantity")
        }
    }

    @ViewBuilder
    private func object(at index: Int) -> some View {
        if let asset = theme?.object(forItemAt: index) {
            Image(asset.assetName)
                .resizable()
                .scaledToFit()
        } else {
            // Missing-resource/debug fallback. Production MinikMath ships MathObjects.xcassets.
            Circle()
                .fill(Color.accentColor)
        }
    }
}
