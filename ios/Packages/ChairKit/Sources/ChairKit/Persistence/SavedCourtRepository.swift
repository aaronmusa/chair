//
//  SavedCourtRepository.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/11/26.
//

import Foundation
import SwiftData

public struct SavedCourtRecord: Equatable, Sendable {
    public let id: UUID
    public let ownerID: UUID?
    public let name: String
    public let calibration: CourtCalibration
    public let lastUsedAt: Date?
    public let latitude: Double?
    public let longitude: Double?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        ownerID: UUID?,
        name: String,
        calibration: CourtCalibration,
        lastUsedAt: Date?,
        latitude: Double?,
        longitude: Double?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.ownerID = ownerID
        self.name = name
        self.calibration = calibration
        self.lastUsedAt = lastUsedAt
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public protocol SavedCourtRemote: Sendable {
    func court(id: UUID) async throws -> SavedCourtRecord?
    func upsert(_ record: SavedCourtRecord) async throws
    func delete(id: UUID) async throws
    func courts(updatedSince: Date?) async throws -> [SavedCourtRecord]
    func visibleCourtIDs() async throws -> Set<UUID>
}

@MainActor
public protocol SavedCourtRepository: AnyObject {
    func save(_ court: SavedCourt) throws
    func fetch() throws -> [SavedCourt]
    func observe() -> AsyncStream<[SavedCourtRecord]>
    func delete(_ court: SavedCourt) throws
    func clearLocal() throws
}

public extension SavedCourt {
    var record: SavedCourtRecord? {
        calibration.map { calibration in
            SavedCourtRecord(
                id: remoteID,
                ownerID: ownerID,
                name: name,
                calibration: calibration,
                lastUsedAt: lastUsedAt,
                latitude: latitude,
                longitude: longitude,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    convenience init(record: SavedCourtRecord) {
        self.init(
            remoteID: record.id,
            ownerID: record.ownerID,
            name: record.name,
            calibration: record.calibration,
            lastUsedAt: record.lastUsedAt,
            latitude: record.latitude,
            longitude: record.longitude,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            syncState: .synced
        )
    }

    func apply(_ record: SavedCourtRecord) {
        ownerID = record.ownerID
        name = record.name
        calibration = record.calibration
        lastUsedAt = record.lastUsedAt
        latitude = record.latitude
        longitude = record.longitude
        createdAt = record.createdAt
        updatedAt = record.updatedAt
        syncState = .synced
    }
}

@MainActor
public final class LocalSavedCourtRepository: SavedCourtRepository {
    public let context: ModelContext
    private let clock: any ClockProvider

    public init(
        context: ModelContext,
        clock: any ClockProvider = SystemClock()
    ) {
        self.context = context
        self.clock = clock
    }

    public func save(_ court: SavedCourt) throws {
        if court.modelContext == nil {
            context.insert(court)
        }
        court.updatedAt = clock.now
        court.syncState = .pendingUpload
        try context.save()
    }

    public func fetch() throws -> [SavedCourt] {
        try allCourts()
            .filter { $0.syncState != .pendingDelete }
            .sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
    }

    public func observe() -> AsyncStream<[SavedCourtRecord]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [SavedCourtRecord].self)
        continuation.yield(snapshot())
        let task = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) {
                guard let self else { break }
                continuation.yield(snapshot())
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    public func delete(_ court: SavedCourt) throws {
        context.delete(court)
        try context.save()
    }

    public func clearLocal() throws {
        try allCourts().forEach(context.delete)
        try context.save()
    }

    func court(remoteID: UUID) throws -> SavedCourt? {
        var descriptor = FetchDescriptor<SavedCourt>(predicate: #Predicate { $0.remoteID == remoteID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func allCourts() throws -> [SavedCourt] {
        try context.fetch(FetchDescriptor<SavedCourt>())
    }

    private func snapshot() -> [SavedCourtRecord] {
        ((try? fetch()) ?? []).compactMap(\.record)
    }
}

@MainActor
public final class SyncingSavedCourtRepository: SavedCourtRepository {
    private let local: LocalSavedCourtRepository
    private let remote: any SavedCourtRemote
    private let clock: any ClockProvider
    private var lastPulledAt: Date?

    public init(
        context: ModelContext,
        remote: any SavedCourtRemote,
        clock: any ClockProvider = SystemClock()
    ) {
        local = LocalSavedCourtRepository(context: context, clock: clock)
        self.remote = remote
        self.clock = clock
    }

    public func save(_ court: SavedCourt) throws {
        try local.save(court)
    }

    public func fetch() throws -> [SavedCourt] {
        try local.fetch()
    }

    public func observe() -> AsyncStream<[SavedCourtRecord]> {
        local.observe()
    }

    public func delete(_ court: SavedCourt) throws {
        court.updatedAt = clock.now
        court.syncState = .pendingDelete
        try local.context.save()
    }

    public func clearLocal() throws {
        try local.clearLocal()
        lastPulledAt = nil
    }

    public func pendingCount() throws -> Int {
        try local.allCourts().count { $0.syncState != .synced }
    }

    public func sync(as userID: UUID) async throws {
        try dropOtherAccounts(keeping: userID)
        try await pushDeletes()
        try await pushUploads(as: userID)
        try await pull()
    }

    private func dropOtherAccounts(keeping userID: UUID) throws {
        let others = try local.allCourts().filter { $0.ownerID.map { $0 != userID } ?? false }
        guard !others.isEmpty else { return }
        others.forEach(local.context.delete)
        try local.context.save()
        lastPulledAt = nil
    }

    private func pushDeletes() async throws {
        for court in try local.allCourts() where court.syncState == .pendingDelete {
            try await remote.delete(id: court.remoteID)
            local.context.delete(court)
            try local.context.save()
        }
    }

    private func pushUploads(as userID: UUID) async throws {
        for court in try local.allCourts() where court.syncState == .pendingUpload {
            court.ownerID = userID
            let stored = try await remote.court(id: court.remoteID)
            if let stored, stored.updatedAt > court.updatedAt {
                court.apply(stored)
            } else if let record = court.record {
                try await remote.upsert(record)
                court.syncState = .synced
            }
            try local.context.save()
        }
    }

    private func pull() async throws {
        let changes = try await remote.courts(updatedSince: lastPulledAt)
        for record in changes {
            if let existing = try local.court(remoteID: record.id) {
                guard existing.syncState == .synced, record.updatedAt > existing.updatedAt else { continue }
                existing.apply(record)
            } else {
                local.context.insert(SavedCourt(record: record))
            }
        }
        try local.context.save()
        lastPulledAt = changes.map(\.updatedAt).max() ?? lastPulledAt
        let visible = try await remote.visibleCourtIDs()
        for court in try local.allCourts() where court.syncState == .synced && !visible.contains(court.remoteID) {
            local.context.delete(court)
        }
        try local.context.save()
    }
}
