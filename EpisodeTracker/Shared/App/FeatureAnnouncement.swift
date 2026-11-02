import Foundation

/// Identity of the current in-app feature announcement, plus the rule for
/// whether its banner should render right now.
///
/// Two independent facts gate visibility, both tracked in `UserDefaults`:
/// - `storageKey`: whether this fingerprint was already dismissed.
/// - `establishedInstallKey`: recorded once, at the device's very first
///   bootstrap, by `AppDataBootstrapper` — true for upgraders who already had
///   a tracked schema version or existing data at that point. Established
///   installs see a pending announcement immediately even with an empty
///   library; genuinely fresh installs wait until they've added their first
///   item, so the banner never appears on an empty pre-onboarding screen.
enum FeatureAnnouncement {
    static let storageKey = "dismissedFeatureAnnouncementFingerprint"
    static let establishedInstallKey = "featureAnnouncementEstablishedInstall"
    /// Fingerprint und Zeitpunkt, zu dem das Banner zum ersten Mal sichtbar
    /// war. Danach läuft es nach `visibleDuration` von selbst ab (Design
    /// Review 2026-11, Befund 1).
    static let firstShownFingerprintKey = "featureAnnouncementFirstShownFingerprint"
    static let firstShownAtKey = "featureAnnouncementFirstShownAt"
    static let visibleDuration: TimeInterval = 7 * 24 * 60 * 60

    /// Bump this whenever a new feature should be announced to existing users.
    /// Changing it makes the banner reappear once for everyone who updates.
    static let currentFingerprint = "v1.16-personalization"

    /// Records, once per install, whether the device already had a tracked
    /// schema version or existing data at its very first bootstrap. No-op on
    /// every later call, since later bootstraps always see a non-zero schema
    /// version and must not overwrite the original fact with it.
    static func recordInstallOriginIfNeeded(
        lastSchemaVersion: Int,
        libraryIsEmpty: Bool,
        in userDefaults: UserDefaults
    ) {
        guard userDefaults.object(forKey: establishedInstallKey) == nil else { return }
        let isEstablished = lastSchemaVersion != 0 || !libraryIsEmpty
        userDefaults.set(isEstablished, forKey: establishedInstallKey)
    }

    /// Whether a pending announcement should render given the current
    /// dismissal, library, and install-origin state. Pure so it can be unit
    /// tested without SwiftUI.
    static func shouldShow(
        isPending: Bool,
        libraryIsEmpty: Bool,
        isEstablishedInstall: Bool,
        firstShownAt: Date? = nil,
        now: Date = .now
    ) -> Bool {
        guard isPending else { return false }
        if let firstShownAt, now.timeIntervalSince(firstShownAt) >= visibleDuration { return false }
        guard libraryIsEmpty else { return true }
        return isEstablishedInstall
    }
}
