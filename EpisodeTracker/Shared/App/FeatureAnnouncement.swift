import Foundation

/// Identity of the current in-app feature announcement.
///
/// Shared by the announcement banner (which decides whether to show it) and the
/// bootstrapper (which pre-dismisses it for fresh installs, so that "new" feature
/// banners only reach users who actually updated from an older version).
enum FeatureAnnouncement {
    static let storageKey = "dismissedFeatureAnnouncementFingerprint"

    /// Bump this whenever a new feature should be announced to existing users.
    /// Changing it makes the banner reappear once for everyone who updates.
    static let currentFingerprint = "v1.11-app-icons"

    /// Marks the current announcement as already seen (e.g. for a fresh install).
    static func markSeen(in userDefaults: UserDefaults) {
        userDefaults.set(currentFingerprint, forKey: storageKey)
    }

    /// Whether the current announcement still needs to be shown on this device.
    static func isPending(in userDefaults: UserDefaults) -> Bool {
        userDefaults.string(forKey: storageKey) != currentFingerprint
    }
}
