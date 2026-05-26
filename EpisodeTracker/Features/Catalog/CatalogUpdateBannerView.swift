import SwiftUI

enum CatalogUpdateBannerStyle {
    case phone
    case sidebar
}

struct CatalogUpdateBannerRow: View {
    let recommendation: CatalogUpdateBannerRecommendation?
    let style: CatalogUpdateBannerStyle

    @AppStorage("dismissedCatalogBannerFingerprint") private var dismissedBannerFingerprint = ""

    var body: some View {
        if let recommendation, recommendation.fingerprint != dismissedBannerFingerprint {
            CatalogUpdateBannerView(recommendation: recommendation, style: style) {
                withAnimation { dismissedBannerFingerprint = recommendation.fingerprint }
            }
            .listRowInsets(style == .sidebar
                ? EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10)
                : EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }
}

struct CatalogUpdateBannerView: View {
    let recommendation: CatalogUpdateBannerRecommendation
    let style: CatalogUpdateBannerStyle
    let onDismiss: () -> Void

    private var isSidebar: Bool {
        style == .sidebar
    }

    private var iconColor: Color {
        switch recommendation.iconColorName {
        case "orange": .orange
        default: .green
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: isSidebar ? 10 : 12) {
            Image(systemName: recommendation.iconName)
                .font(isSidebar ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                .foregroundStyle(iconColor)
                .frame(width: isSidebar ? 30 : 36, height: isSidebar ? 30 : 36)
                .background(iconColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: isSidebar ? 3 : 5) {
                Text(recommendation.title)
                    .font(isSidebar ? .subheadline.weight(.semibold) : .headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(recommendation.message)
                    .font(isSidebar ? .caption : .footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(.secondary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(isSidebar ? 12 : 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Banner – neue Kataloge") {
    List {
        CatalogUpdateBannerRow(
            recommendation: CatalogUpdateBannerRecommendation.previewNewCatalogs,
            style: .phone
        )
        CatalogUpdateBannerRow(
            recommendation: CatalogUpdateBannerRecommendation.previewNewCatalogs,
            style: .sidebar
        )
    }
}

#Preview("Banner – neue Folgen") {
    List {
        CatalogUpdateBannerRow(
            recommendation: CatalogUpdateBannerRecommendation.previewNewEpisodes,
            style: .phone
        )
        CatalogUpdateBannerRow(
            recommendation: CatalogUpdateBannerRecommendation.previewNewEpisodes,
            style: .sidebar
        )
    }
}
#endif
