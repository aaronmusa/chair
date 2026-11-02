//
//  MatchModels.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import SwiftData

public enum PlayerSlot: String, Codable, Sendable, CaseIterable, Comparable, Identifiable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"

    public var id: String {
        rawValue
    }

    public static func < (
        lhs: PlayerSlot,
        rhs: PlayerSlot
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum LinkStatus: String, Codable, Sendable {
    case none
    case pending
    case accepted
    case declined
}

@Model
public final class Match {
    @Attribute(.unique) public var remoteID: UUID
    public var playedAt: Date
    public var format: MatchFormat
    public var rules: MatchRules
    public var status: MatchStatus
    public var inputMode: String
    public var refereeMode: String
    public var sets: [SetScore]
    public var createdAt: Date
    public var updatedAt: Date
    public var syncState: SyncState
    public var ownerID: UUID?
    public var localUserSlot: PlayerSlot = PlayerSlot.a1

    @Relationship(deleteRule: .cascade, inverse: \MatchPlayer.match)
    public var players: [MatchPlayer] = []

    @Relationship(deleteRule: .cascade, inverse: \PointEvent.match)
    public var points: [PointEvent] = []

    public init(
        remoteID: UUID = UUID(),
        playedAt: Date,
        format: MatchFormat,
        rules: MatchRules = MatchRules(),
        status: MatchStatus = .inProgress,
        inputMode: String = "manual",
        refereeMode: String = "none",
        sets: [SetScore] = [],
        createdAt: Date,
        updatedAt: Date,
        syncState: SyncState = .pendingUpload,
        ownerID: UUID? = nil,
        localUserSlot: PlayerSlot = .a1
    ) {
        self.remoteID = remoteID
        self.playedAt = playedAt
        self.format = format
        self.rules = rules
        self.status = status
        self.inputMode = inputMode
        self.refereeMode = refereeMode
        self.sets = sets
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncState = syncState
        self.ownerID = ownerID
        self.localUserSlot = localUserSlot
    }

    public var orderedPlayers: [MatchPlayer] {
        players.sorted { $0.slot < $1.slot }
    }

    public var orderedPoints: [PointEvent] {
        points.sorted { $0.index < $1.index }
    }
}

@Model
public final class MatchPlayer {
    public var remoteID: UUID
    public var slot: PlayerSlot
    public var name: String
    public var userID: UUID?
    public var linkStatus: LinkStatus
    public var invitedAt: Date?
    public var respondedAt: Date?
    public var updatedAt: Date
    public var syncState: SyncState
    public var match: Match?

    public init(
        remoteID: UUID = UUID(),
        slot: PlayerSlot,
        name: String,
        userID: UUID? = nil,
        linkStatus: LinkStatus = .none,
        invitedAt: Date? = nil,
        respondedAt: Date? = nil,
        updatedAt: Date,
        syncState: SyncState = .pendingUpload
    ) {
        self.remoteID = remoteID
        self.slot = slot
        self.name = name
        self.userID = userID
        self.linkStatus = linkStatus
        self.invitedAt = invitedAt
        self.respondedAt = respondedAt
        self.updatedAt = updatedAt
        self.syncState = syncState
    }
}

@Model
public final class PointEvent {
    public var remoteID: UUID
    public var index: Int
    public var at: Date
    public var winnerSide: Side?
    public var outcome: PointOutcome?
    public var source: String
    public var confidence: Double?
    public var corrected: Bool
    public var clipPath: String?
    public var eventKind: String = "point"
    public var undone: Bool = false
    public var payload: Data?
    public var updatedAt: Date
    public var syncState: SyncState
    public var match: Match?

    public init(
        remoteID: UUID = UUID(),
        index: Int,
        at: Date,
        winnerSide: Side?,
        outcome: PointOutcome?,
        source: String = "manual",
        confidence: Double? = nil,
        corrected: Bool = false,
        clipPath: String? = nil,
        eventKind: String = "point",
        undone: Bool = false,
        payload: Data? = nil,
        updatedAt: Date,
        syncState: SyncState = .pendingUpload
    ) {
        self.remoteID = remoteID
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
        self.syncState = syncState
    }
}
