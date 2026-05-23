import CoreData
import Foundation
import os.log
import SwiftData
import Combine

private let logger = Logger(subsystem: "com.Digi.EpisodeTracker", category: "SyncCoordinator")

@MainActor
@Observable
final class SyncCoordinator {
    private let container: ModelContainer
    private let isEnabled: Bool

    private var isRepairing = false
    private var pendingRepairTask: Task<Void, Never>?
    private var remoteChangeSubscription: AnyCancellable?

    init(container: ModelContainer, isEnabled: Bool) {
        self.container = container
        self.isEnabled = isEnabled

        if isEnabled {
            observeRemoteChanges()
            logger.info("SyncCoordinator: initialized with remote change observation")
        } else {
            logger.info("SyncCoordinator: initialized (sync disabled, no observation)")
        }
    }

    // MARK: - Public Triggers

    func handleBootstrapComplete() {
        scheduleRepair(reason: "bootstrap")
    }

    func handleSceneActivation() {
        scheduleRepair(reason: "scenePhase.active")
    }

    // MARK: - Remote Change Observation

    private func observeRemoteChanges() {
        remoteChangeSubscription = NotificationCenter.default
            .publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleRepair(reason: "remoteChange")
            }
    }

    // MARK: - Debounced Repair

    private func scheduleRepair(reason: String) {
        guard isEnabled else { return }

        pendingRepairTask?.cancel()
        pendingRepairTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.repairIfNeeded(reason: reason)
        }
    }

    private func repairIfNeeded(reason: String) {
        guard !isRepairing else {
            logger.info("SyncCoordinator: skipping repair (already running), trigger=\(reason, privacy: .public)")
            return
        }

        isRepairing = true
        logger.info("SyncCoordinator: starting repair, trigger=\(reason, privacy: .public)")

        let summary = SyncPreparation.prepare(context: container.mainContext)
        if summary.hasChanges {
            logger.info("SyncCoordinator: repair completed with changes (\(summary.logDescription, privacy: .public))")
        }

        isRepairing = false
    }
}
