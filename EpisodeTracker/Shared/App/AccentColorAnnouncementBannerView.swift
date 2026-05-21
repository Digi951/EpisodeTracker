import SwiftUI

enum AccentColorAnnouncementBannerStyle {
    case phone
    case sidebar
}

struct AccentColorAnnouncementBannerRow: View {
    static let fingerprint = "v1.7-accent-color"

    let style: AccentColorAnnouncementBannerStyle

    @AppStorage("dismissedAccentColorBannerFingerprint") private var dismissedBannerFingerprint = ""

    var body: some View {
        if dismissedBannerFingerprint != Self.fingerprint {
            AccentColorAnnouncementBannerView(style: style) {
                withAnimation { dismissedBannerFingerprint = Self.fingerprint }
            }
            .listRowInsets(style == .sidebar
                ? EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10)
                : EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }
}

private struct AccentColorAnnouncementBannerView: View {
    let style: AccentColorAnnouncementBannerStyle
    let onDismiss: () -> Void

    private var isSidebar: Bool {
        style == .sidebar
    }

    var body: some View {
        HStack(alignment: .center, spacing: isSidebar ? 10 : 12) {
            Image(systemName: "paintpalette")
                .font(isSidebar ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: isSidebar ? 30 : 36, height: isSidebar ? 30 : 36)
                .background(.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: isSidebar ? 3 : 5) {
                Text("Neu: Akzentfarbe")
                    .font(isSidebar ? .subheadline.weight(.semibold) : .headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("Wähle deine Akzentfarbe in den Einstellungen.")
                    .font(isSidebar ? .caption : .footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
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
