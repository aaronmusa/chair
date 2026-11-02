//
//  MatchRecord.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import SwiftData

public struct MatchRecord: Codable, Equatable, Sendable {
    public struct Player: Codable, Equatable, Sendable {
        public var slot: PlayerSlot
        public var name: String
        public var userID: UUID?
        public var linkStatus: LinkStatus
        public var invitedAt: Date?
        public var respondedAt: Date?
        public var updatedAt: Date?

        public init(
            slot: PlayerSlot,
            name: String,
            userID: UUID? = nil,
            linkStatus: LinkStatus = .none,
            invitedAt: Date? = nil,
            respondedAt: Date? = nil,
            updatedAt: Date? = nil
        ) {
            self.slot = slot
            self.name = name
            self.userID = userID
            self.linkStatus = linkStatus
            self.invitedAt = invitedAt
            self.respondedAt = respondedAt
            self.updatedAt = updatedAt
        }
    }

    public struct Point: Codable, Equatable, Sendable {
        public var id: UUID
        public var index: Int
        public var at: Date
        public var winnerSide: Side?
        public var outcome: PointOutcome?
        public var source: String
        public var confidence: Double?
        public var corrected: Bool
        public var clipPath: String?
        public var eventKind: String
        public var undone: Bool
        public var payload: Data?
        public var updatedAt: Date?

        public init(
            id: UUID,
            index: Int,
            at: Date,
            winnerSide: Side?,
            outcome: PointOutcome?,
            source: String,
            confidence: Double?,
            corrected: Bool,
            clipPath: String?,
            eventKind: String = "point",
            undone: Bool = false,
            payload: Data? = nil,
            updatedAt: Date? = nil
        ) {
            self.id = id
            self.index = index
            self.at = at
            self.winnerSide = winnerSide
            self.outcome = outcome
            self.source = source
            self.confidence = confidence
            self.corrected = corrected
            self.clipPath = clipPath
            self.eventKind = eventKind
            self.undone = undone
            self.payload = payload
            self.updatedAt = updatedAt
        }
    }

    public var id: UUID
    public var playedAt: Date
    public var format: MatchFormat
    public var rules: MatchRules
    public var status: MatchStatus
    public var inputMode: String
    public var refereeMode: String
    public var sets: [SetScore]
    public var createdAt: Date
    public var updatedAt: Date
    public var players: [Player]
    public var points: [Point]
    public var ownerID: UUID?
    public var localUserSlot: PlayerSlot?

    public var mySide: Side {
        (localUserSlot ?? .a1).side
    }

    public var isReadOnly: Bool {
        guard let ownerID, let me = players.first(where: { $0.slot == localUserSlot }), let myID = me.userID else { return false }
        return myID != ownerID
    }
}

public extension Match {
    var record: MatchRecord {
        MatchRecord(
            id: remoteID,
            playedAt: playedAt,
            format: format,
            rules: rules,
            status: status,
            inputMode: inputMode,
            refereeMode: refereeMode,
            sets: sets,
            createdAt: createdAt,
            updatedAt: updatedAt,
            players: orderedPlayers.map(\.recordPlayer),
            points: orderedPoints.map {
                MatchRecord.Point(
                    id: $0.remoteID,
                    index: $0.index,
                    at: $0.at,
                    winnerSide: $0.winnerSide,
                    outcome: $0.outcome,
                    source: $0.source,
                    confidence: $0.confidence,
                    corrected: $0.corrected,
                    clipPath: $0.clipPath,
                    eventKind: $0.eventKind,
                    undone: $0.undone,
                    payload: $0.payload,
                    updatedAt: $0.updatedAt
                )
            },
            ownerID: ownerID,
            localUserSlot: localUserSlot
        )
    }

    func perspective(for userID: UUID?) -> Side {
        players.first { $0.userID != nil && $0.userID == userID }?.slot.side ?? localUserSlot.side
    }

    convenience init(record: MatchRecord) {
        self.init(
            remoteID: record.id,
            playedAt: record.playedAt,
            format: record.format,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            syncState: .synced,
            ownerID: record.ownerID
        )
    }

    func apply(
        _ record: MatchRecord,
        in context: ModelContext
    ) {
        playedAt = record.playedAt
        format = record.format
        rules = record.rules
        status = record.status
        inputMode = record.inputMode
        refereeMode = record.refereeMode
        sets = record.sets
        createdAt = record.createdAt
        updatedAt = record.updatedAt
        syncState = .synced
        ownerID = record.ownerID ?? ownerID

        merge(
            record.players,
            fallbackUpdatedAt: record.updatedAt,
            in: context
        )
        merge(record.pointEvents)
    }

    func merge(
        _ incoming: [MatchRecord.Player],
        fallbackUpdatedAt: Date,
        in context: ModelContext
    ) {
        let local = Dictionary(players.map { ($0.slot, $0) }, uniquingKeysWith: { first, _ in first })
        for row in incoming {
            let rowUpdatedAt = row.updatedAt ?? fallbackUpdatedAt
            guard let existing = local[row.slot] else {
                players.append(MatchPlayer(row, updatedAt: rowUpdatedAt))
                continue
            }
            guard existing.syncState == .synced || rowUpdatedAt > existing.updatedAt else { continue }
            existing.copy(from: row, updatedAt: rowUpdatedAt)
        }
        let incomingSlots = Set(incoming.map(\.slot))
        for stale in players where !incomingSlots.contains(stale.slot) && stale.syncState == .synced {
            players.removeAll { $0 === stale }
            context.delete(stale)
        }
    }

    private func merge(_ incoming: [PointEvent]) {
        let local = Dictionary(points.map { ($0.index, $0) }, uniquingKeysWith: { first, _ in first })
        for row in incoming {
            guard let existing = local[row.index] else {
                points.append(row)
                continue
            }
            guard existing.syncState == .synced || row.updatedAt > existing.updatedAt else { continue }
            existing.copy(from: row)
        }
    }
}

extension MatchPlayer {
    convenience init(
        _ row: MatchRecord.Player,
        updatedAt: Date
    ) {
        self.init(
            slot: row.slot,
            name: row.name,
            userID: row.userID,
            linkStatus: row.linkStatus,
            invitedAt: row.invitedAt,
            respondedAt: row.respondedAt,
            updatedAt: updatedAt,
            syncState: .synced
        )
    }

    var recordPlayer: MatchRecord.Player {
        MatchRecord.Player(
            slot: slot,
            name: name,
            userID: userID,
            linkStatus: linkStatus,
            invitedAt: invitedAt,
            respondedAt: respondedAt,
            updatedAt: updatedAt
        )
    }

    func copy(
        from row: MatchRecord.Player,
        updatedAt rowUpdatedAt: Date
    ) {
        name = row.name
        userID = row.userID
        linkStatus = row.linkStatus
        invitedAt = row.invitedAt
        respondedAt = row.respondedAt
        updatedAt = rowUpdatedAt
        syncState = .synced
    }
}

extension PointEvent {
    func copy(from row: PointEvent) {
        remoteID = row.remoteID
        at = row.at
        winnerSide = row.winnerSide
        outcome = row.outcome
        source = row.source
        confidence = row.confidence
        corrected = row.corrected
        clipPath = row.clipPath
        eventKind = row.eventKind
        undone = row.undone
        payload = row.payload
        updatedAt = row.updatedAt
        syncState = .synced
    }
}

public extension MatchRecord {
    var pointEvents: [PointEvent] {
        points.map {
            PointEvent(
                remoteID: $0.id,
                index: $0.index,
                at: $0.at,
                winnerSide: $0.winnerSide,
                outcome: $0.outcome,
                source: $0.source,
                confidence: $0.confidence,
                corrected: $0.corrected,
                clipPath: $0.clipPath,
                eventKind: $0.eventKind,
                undone: $0.undone,
                payload: $0.payload,
                updatedAt: $0.updatedAt ?? updatedAt,
                syncState: .synced
            )
        }
    }
}

public protocol MatchRemote: Sendable {
    func match(id: UUID) async throws -> MatchRecord?
    func upsert(_ record: MatchRecord) async throws
    func delete(id: UUID) async throws
    func matches(updatedSince: Date?) async throws -> [MatchRecord]
    func visibleMatchIDs() async throws -> Set<UUID>
}
