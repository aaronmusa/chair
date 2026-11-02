//
//  MatchRepository.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import SwiftData

@MainActor
public protocol MatchRepository: AnyObject {
    func save(_ match: Match) throws
    func fetch() throws -> [Match]
    func observe() -> AsyncStream<[MatchRecord]>
    func delete(_ match: Match) throws
}

@MainActor
public final class LocalMatchRepository: MatchRepository {
    public let context: ModelContext
    private let clock: any ClockProvider

    public init(
        context: ModelContext,
        clock: any ClockProvider = SystemClock()
    ) {
        self.context = context
        self.clock = clock
    }

    public func save(_ match: Match) throws {
        if match.modelContext == nil {
            context.insert(match)
        }
        match.updatedAt = clock.now
        match.syncState = .pendingUpload
        try context.save()
    }

    public func fetch() throws -> [Match] {
        let descriptor = FetchDescriptor<Match>(sortBy: [SortDescriptor(\.playedAt, order: .reverse)])
        return try context.fetch(descriptor).filter { $0.syncState != .pendingDelete }
    }

    public func observe() -> AsyncStream<[MatchRecord]> {
        let (stream, continuation) = AsyncStream.makeStream(of: [MatchRecord].self)
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

    private func snapshot() -> [MatchRecord] {
        ((try? fetch()) ?? []).map(\.record)
    }

    public func delete(_ match: Match) throws {
        context.delete(match)
        try context.save()
    }

    func match(remoteID: UUID) throws -> Match? {
        var descriptor = FetchDescriptor<Match>(predicate: #Predicate { $0.remoteID == remoteID })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func allMatches() throws -> [Match] {
        try context.fetch(FetchDescriptor<Match>())
    }
}

@MainActor
public final class SyncingMatchRepository: MatchRepository {
    private let local: LocalMatchRepository
    private let remote: any MatchRemote
    private let clock: any ClockProvider
    private var lastPulledAt: Date?

    public init(
        context: ModelContext,
        remote: any MatchRemote,
        clock: any ClockProvider = SystemClock()
    ) {
        local = LocalMatchRepository(context: context, clock: clock)
        self.remote = remote
        self.clock = clock
    }

    public func save(_ match: Match) throws {
        try local.save(match)
    }

    public func fetch() throws -> [Match] {
        try local.fetch()
    }

    public func observe() -> AsyncStream<[MatchRecord]> {
        local.observe()
    }

    public func delete(_ match: Match) throws {
        match.updatedAt = clock.now
        match.syncState = .pendingDelete
        try local.context.save()
    }

    public func pendingCount() throws -> Int {
        try local.allMatches().reduce(0) { count, match in
            let rows = [match.syncState] + match.players.map(\.syncState) + match.points.map(\.syncState)
            return count + rows.count { $0 != .synced }
        }
    }

    public func sync(as userID: UUID? = nil) async throws {
        try await pushDeletes()
        try await pushUploads(as: userID)
        try await pull()
    }

    private func pushDeletes() async throws {
        for match in try local.allMatches() where match.syncState == .pendingDelete {
            try await remote.delete(id: match.remoteID)
            local.context.delete(match)
            try local.context.save()
        }
    }

    private func pushUploads(as userID: UUID?) async throws {
        for match in try local.allMatches() where match.syncState == .pendingUpload {
            match.ownerID = match.ownerID ?? userID
            let stored = try await remote.match(id: match.remoteID)
            if let stored, stored.updatedAt > match.updatedAt {
                match.apply(stored, in: local.context)
            } else {
                if let stored {
                    match.merge(
                        stored.players,
                        fallbackUpdatedAt: stored.updatedAt,
                        in: local.context
                    )
                }
                try await remote.upsert(match.record)
                match.syncState = .synced
                match.players.forEach { $0.syncState = .synced }
                match.points.forEach { $0.syncState = .synced }
            }
            try local.context.save()
        }
    }

    private func pull() async throws {
        let changes = try await remote.matches(updatedSince: lastPulledAt)
        for record in changes {
            if let existing = try local.match(remoteID: record.id) {
                guard existing.syncState == .synced, record.updatedAt > existing.updatedAt else { continue }
                existing.apply(record, in: local.context)
            } else {
                let match = Match(record: record)
                local.context.insert(match)
                match.apply(record, in: local.context)
            }
        }
        try local.context.save()
        lastPulledAt = changes.map(\.updatedAt).max() ?? lastPulledAt
    }
}

public extension MatchRepository {
    func matchesUsed() throws -> Int {
        try FreeTier.matchesUsed(in: fetch().map(\.status))
    }
}
