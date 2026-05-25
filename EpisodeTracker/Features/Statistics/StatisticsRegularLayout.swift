import SwiftUI

struct StatisticsRegularLayout {
    let contentWidth: CGFloat
    let horizontalPadding: CGFloat
    let summaryColumns: [GridItem]
    let detailColumns: [GridItem]

    init(containerWidth: CGFloat) {
        let safeWidth = max(containerWidth, 320)
        let usesTwoDetailColumns = safeWidth >= 920

        if usesTwoDetailColumns {
            contentWidth = min(1100, safeWidth - 64)
            summaryColumns = [
                GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)
            ]
            detailColumns = [
                GridItem(.flexible(minimum: 320, maximum: 520), spacing: 16),
                GridItem(.flexible(minimum: 320, maximum: 520), spacing: 16)
            ]
        } else {
            contentWidth = min(760, safeWidth - 48)
            summaryColumns = [
                GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
            ]
            detailColumns = [
                GridItem(.flexible(minimum: 320, maximum: 760), spacing: 16)
            ]
        }

        horizontalPadding = max(24, (safeWidth - contentWidth) / 2)
    }
}
