import Foundation

enum FreemiumAccess {
    static let unlockStorageKey = "freemium.isPlusUnlocked"
    static let freeEpisodeLimit = 25
    static let isEnforcementEnabled = false
    static let productDisplayName = "HörspielLog Plus"

    static func planName(isPlusUnlocked: Bool) -> String {
        isPlusUnlocked ? productDisplayName : "Free"
    }

    static func canCreateEpisode(currentEpisodeCount: Int, isPlusUnlocked: Bool) -> Bool {
        !isEnforcementEnabled || isPlusUnlocked || currentEpisodeCount < freeEpisodeLimit
    }

    static func freePlanUsageText(currentEpisodeCount: Int, isPlusUnlocked: Bool) -> String {
        if isPlusUnlocked {
            return "Unbegrenzt"
        }

        return "\(min(currentEpisodeCount, freeEpisodeLimit)) von \(freeEpisodeLimit)"
    }

    static func limitReachedMessage() -> String {
        "Der Free-Plan ist auf \(freeEpisodeLimit) Folgen vorbereitet. Die Freischaltung wird später über StoreKit ergänzt."
    }
}
