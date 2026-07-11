import SwiftUI

enum FeatureAnnouncementBannerStyle {
    case phone
    case sidebar
}

/// In-app announcement for a newly added feature. Only shown while the current
/// announcement is still pending (i.e. not yet dismissed and not pre-dismissed
/// for a fresh install).
struct FeatureAnnouncementBannerRow: View {
    let style: FeatureAnnouncementBannerStyle

    @AppStorage(FeatureAnnouncement.storageKey) private var dismissedFingerprint = ""

    var body: some View {
        if dismissedFingerprint != FeatureAnnouncement.currentFingerprint {
            FeatureAnnouncementBannerView(style: style) {
                withAnimation { dismissedFingerprint = FeatureAnnouncement.currentFingerprint }
            }
            .listRowInsets(style == .sidebar
                ? EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10)
                : EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }
}

private struct FeatureAnnouncementBannerView: View {
    let style: FeatureAnnouncementBannerStyle
    let onDismiss: () -> Void

    private var isSidebar: Bool {
        style == .sidebar
    }

    var body: some View {
        HStack(alignment: .center, spacing: isSidebar ? 10 : 12) {
            Image(systemName: "paintpalette.fill")
                .font(isSidebar ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: isSidebar ? 30 : 36, height: isSidebar ? 30 : 36)
                .background(.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: isSidebar ? 3 : 5) {
                Text("Neu: Farbe & Icon")
                    .font(isSidebar ? .subheadline.weight(.semibold) : .headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("Personalisiere App-Icon und Akzentfarbe in den Einstellungen.")
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
