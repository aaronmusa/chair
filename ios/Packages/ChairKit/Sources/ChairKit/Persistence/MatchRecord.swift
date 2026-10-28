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

        public init(
            slot: PlayerSlot,
            name: String,
            userID: UUID? = nil,
            linkStatus: LinkStatus = .none
        ) {
            self.slot = slot
            self.name = name
            self.userID = userID
            self.linkStatus = linkStatus
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
            payload: Data? = nil
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
            players: orderedPlayers.map {
                MatchRecord.Player(slot: $0.slot, name: $0.name, userID: $0.userID, linkStatus: $0.linkStatus)
            },
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
                    payload: $0.payload
                )
            }
        )
    }

    convenience init(record: MatchRecord) {
        self.init(
            remoteID: record.id,
            playedAt: record.playedAt,
            format: record.format,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            syncState: .synced
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

        players.forEach(context.delete)
        points.forEach(context.delete)
        players = record.players.map {
            MatchPlayer(
                slot: $0.slot,
                name: $0.name,
                userID: $0.userID,
                linkStatus: $0.linkStatus,
                updatedAt: record.updatedAt,
                syncState: .synced
            )
        }
        points = record.points.map {
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
                updatedAt: record.updatedAt,
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
}
