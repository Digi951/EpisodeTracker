import Foundation

struct BootstrapReport: Sendable {
    var seededMoods = false
    var seededCollections = false
    var assignedOrphanEpisodes = 0
    var repairedPostMigrationIDs = 0
    var syncPreparationSummary: SyncPreparation.ChangeSummary?
    var cloudMigrationStatus: String?

    var logDescription: String {
        var parts: [String] = []
        if seededMoods { parts.append("seededMoods") }
        if seededCollections { parts.append("seededCollections") }
        if assignedOrphanEpisodes > 0 { parts.append("assignedOrphans=\(assignedOrphanEpisodes)") }
        if repairedPostMigrationIDs > 0 { parts.append("repairedIDs=\(repairedPostMigrationIDs)") }
        if let sync = syncPreparationSummary, sync.hasChanges {
            parts.append("syncRepairs=(\(sync.logDescription))")
        }
        if let migration = cloudMigrationStatus {
            parts.append("cloudMigration=\(migration)")
        }
        return parts.isEmpty ? "no changes" : parts.joined(separator: ", ")
    }
}
