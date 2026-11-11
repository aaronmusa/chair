//
//  SyncCoordinator.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import Network
import Observation

public protocol NetworkMonitor: Sendable {
    func reachability() -> AsyncStream<Bool>
}

public final class SystemNetworkMonitor: NetworkMonitor {
    public init() {}

    public func reachability() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                continuation.yield(path.status == .satisfied)
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "chair.network"))
        }
    }
}

@MainActor
@Observable
public final class SyncCoordinator {
    public private(set) var lastSyncedAt: Date?
    public private(set) var pendingCount = 0
    public private(set) var isOnline = false
    public private(set) var isSyncing = false
    public private(set) var lastError: String?

    private let repository: SyncingMatchRepository
    private let courts: SyncingSavedCourtRepository?
    private let auth: any AuthService
    private let network: any NetworkMonitor
    private let clock: any ClockProvider
    private let migration: AccountMigration?
    private var watching: Task<Void, Never>?

    public init(
        repository: SyncingMatchRepository,
        auth: any AuthService,
        network: any NetworkMonitor,
        clock: any ClockProvider = SystemClock(),
        migration: AccountMigration? = nil,
        courts: SyncingSavedCourtRepository? = nil
    ) {
        self.repository = repository
        self.courts = courts
        self.auth = auth
        self.network = network
        self.clock = clock
        self.migration = migration
    }

    public func start() {
        refreshPending()
        guard watching == nil else { return }
        let reachability = network.reachability()
        watching = Task { [weak self] in
            for await online in reachability {
                guard let self else { return }
                isOnline = online
                if online {
                    await syncNow()
                }
            }
        }
    }

    public func stop() {
        watching?.cancel()
        watching = nil
    }

    public func syncNow() async {
        refreshPending()
        guard isOnline, !isSyncing, let session = await auth.currentSession() else { return }
        guard (try? migration?.pendingPrompt(for: session.userID)) == nil else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await repository.sync(as: session.userID)
            try await courts?.sync(as: session.userID)
            lastSyncedAt = clock.now
            lastError = nil
        } catch {
            lastError = "Couldn't sync. Chair will try again."
        }
        refreshPending()
    }

    public func refreshPending() {
        guard let matches = try? repository.pendingCount() else { return }
        pendingCount = matches + ((try? courts?.pendingCount()) ?? 0)
    }
}
