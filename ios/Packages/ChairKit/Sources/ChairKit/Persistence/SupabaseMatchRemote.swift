//
//  SupabaseMatchRemote.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation

import Supabase

public struct SupabaseMatchRemote: MatchRemote {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func match(id: UUID) async throws -> MatchRecord? {
        let rows: [MatchRow] = try await client.from("matches")
            .select(MatchRow.columns)
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return rows.first?.record
    }

    public func upsert(_ record: MatchRecord) async throws {
        try await client.from("matches").upsert(MatchFields(record)).execute()
        if !record.players.isEmpty {
            try await client.from("match_players")
                .upsert(record.players.map { PlayerUpload(match: record.id, owner: record.ownerID, $0) }, onConflict: "match_id,slot")
                .execute()
        }
        if !record.points.isEmpty {
            try await client.from("point_events")
                .upsert(
                    record.points.map { PointRow(match: record.id, $0, fallbackUpdatedAt: record.updatedAt) },
                    onConflict: "match_id,index"
                )
                .execute()
        }
    }

    public func delete(id: UUID) async throws {
        try await client.from("matches").delete().eq("id", value: id).execute()
    }

    public func matches(updatedSince: Date?) async throws -> [MatchRecord] {
        var query = client.from("matches").select(MatchRow.columns)
        if let updatedSince {
            query = query.gt("updated_at", value: updatedSince)
        }
        let rows: [MatchRow] = try await query.execute().value
        return rows.map(\.record)
    }

    public func visibleMatchIDs() async throws -> Set<UUID> {
        let rows: [VisibleRow] = try await client.from("my_matches").select("id").execute().value
        return Set(rows.map(\.id))
    }
}

private struct VisibleRow: Decodable {
    let id: UUID
}

private struct MatchRow: Decodable {
    static let columns = "*, match_players(*), point_events(*)"

    let id: UUID
    let ownerID: UUID
    let playedAt: Date
    let format: MatchFormat
    let rules: MatchRules
    let status: MatchStatus
    let inputMode: String
    let refereeMode: String
    let sets: [SetScore]
    let createdAt: Date
    let updatedAt: Date
    let players: [PlayerRow]
    let points: [PointRow]

    enum CodingKeys: String, CodingKey {
        case id, format, rules, status, sets
        case ownerID = "owner_id"
        case playedAt = "played_at"
        case inputMode = "input_mode"
        case refereeMode = "referee_mode"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case players = "match_players"
        case points = "point_events"
    }

    var record: MatchRecord {
        MatchRecord(
            id: id,
            playedAt: playedAt,
            format: format,
            rules: rules,
            status: status,
            inputMode: inputMode,
            refereeMode: refereeMode,
            sets: sets,
            createdAt: createdAt,
            updatedAt: updatedAt,
            players: players.sorted { $0.slot < $1.slot }.map(\.player),
            points: points.sorted { $0.index < $1.index }.map(\.point),
            ownerID: ownerID
        )
    }
}

private struct MatchFields: Encodable {
    let id: UUID
    let ownerID: UUID?
    let playedAt: Date
    let format: MatchFormat
    let rules: MatchRules
    let status: MatchStatus
    let inputMode: String
    let refereeMode: String
    let sets: [SetScore]
    let createdAt: Date
    let updatedAt: Date

    init(_ record: MatchRecord) {
        id = record.id
        ownerID = record.ownerID
        playedAt = record.playedAt
        format = record.format
        rules = record.rules
        status = record.status
        inputMode = record.inputMode
        refereeMode = record.refereeMode
        sets = record.sets
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, format, rules, status, sets
        case ownerID = "owner_id"
        case playedAt = "played_at"
        case inputMode = "input_mode"
        case refereeMode = "referee_mode"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(ownerID, forKey: .ownerID)
        try container.encode(playedAt, forKey: .playedAt)
        try container.encode(format, forKey: .format)
        try container.encode(rules, forKey: .rules)
        try container.encode(status, forKey: .status)
        try container.encode(inputMode, forKey: .inputMode)
        try container.encode(refereeMode, forKey: .refereeMode)
        try container.encode(sets, forKey: .sets)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

private struct PlayerUpload: Encodable {
    let matchID: UUID
    let slot: PlayerSlot
    let name: String
    let userID: UUID?
    let linkStatus: LinkStatus
    let invitedAt: Date?
    let ownRespondedAt: Date?

    init(
        match: UUID,
        owner: UUID?,
        _ player: MatchRecord.Player
    ) {
        matchID = match
        slot = player.slot
        name = player.name
        userID = player.userID
        linkStatus = player.linkStatus
        invitedAt = player.invitedAt
        ownRespondedAt = player.userID != nil && player.userID == owner ? player.respondedAt : nil
    }

    enum CodingKeys: String, CodingKey {
        case slot, name
        case matchID = "match_id"
        case userID = "user_id"
        case linkStatus = "link_status"
        case invitedAt = "invited_at"
        case respondedAt = "responded_at"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(matchID, forKey: .matchID)
        try container.encode(slot, forKey: .slot)
        try container.encode(name, forKey: .name)
        try container.encode(userID, forKey: .userID)
        try container.encode(linkStatus, forKey: .linkStatus)
        try container.encode(invitedAt, forKey: .invitedAt)
        try container.encode(ownRespondedAt, forKey: .respondedAt)
    }
}

private struct PlayerRow: Decodable {
    let slot: PlayerSlot
    let name: String
    let userID: UUID?
    let linkStatus: LinkStatus
    let invitedAt: Date?
    let respondedAt: Date?
    let updatedAt: Date?

    var player: MatchRecord.Player {
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

    enum CodingKeys: String, CodingKey {
        case slot, name
        case userID = "user_id"
        case linkStatus = "link_status"
        case invitedAt = "invited_at"
        case respondedAt = "responded_at"
        case updatedAt = "updated_at"
    }
}

private struct PointRow: Codable {
    let id: UUID
    let matchID: UUID
    let index: Int
    let at: Date
    let winnerSide: Side?
    let outcome: PointOutcome?
    let source: String
    let confidence: Double?
    let corrected: Bool
    let clipPath: String?
    let eventKind: String
    let undone: Bool
    let payload: AnyJSON?
    let updatedAt: Date?

    init(
        match: UUID,
        _ point: MatchRecord.Point,
        fallbackUpdatedAt: Date
    ) {
        id = point.id
        matchID = match
        index = point.index
        at = point.at
        winnerSide = point.winnerSide
        outcome = point.outcome
        source = point.source
        confidence = point.confidence
        corrected = point.corrected
        clipPath = point.clipPath
        eventKind = point.eventKind
        undone = point.undone
        payload = point.payload.flatMap { try? JSONDecoder().decode(AnyJSON.self, from: $0) }
        updatedAt = point.updatedAt ?? fallbackUpdatedAt
    }

    var point: MatchRecord.Point {
        MatchRecord.Point(
            id: id,
            index: index,
            at: at,
            winnerSide: winnerSide,
            outcome: outcome,
            source: source,
            confidence: confidence,
            corrected: corrected,
            clipPath: clipPath,
            eventKind: eventKind,
            undone: undone,
            payload: payload.flatMap { try? PayloadCoding.encoder.encode($0) },
            updatedAt: updatedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, index, at, outcome, source, confidence, corrected, undone, payload
        case matchID = "match_id"
        case winnerSide = "winner_side"
        case clipPath = "clip_path"
        case eventKind = "event_kind"
        case updatedAt = "updated_at"
    }
}
