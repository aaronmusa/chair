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
        try await client.from("match_players").delete().eq("match_id", value: record.id).execute()
        try await client.from("point_events").delete().eq("match_id", value: record.id).execute()
        if !record.players.isEmpty {
            try await client.from("match_players").insert(record.players.map { PlayerRow(match: record.id, $0) }).execute()
        }
        if !record.points.isEmpty {
            try await client.from("point_events").insert(record.points.map { PointRow(match: record.id, $0) }).execute()
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
}

private struct MatchRow: Decodable {
    static let columns = "*, match_players(*), point_events(*)"

    let id: UUID
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
            points: points.sorted { $0.index < $1.index }.map(\.point)
        )
    }
}

private struct MatchFields: Encodable {
    let id: UUID
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
        case playedAt = "played_at"
        case inputMode = "input_mode"
        case refereeMode = "referee_mode"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

private struct PlayerRow: Codable {
    let matchID: UUID
    let slot: PlayerSlot
    let name: String
    let userID: UUID?
    let linkStatus: LinkStatus

    init(
        match: UUID,
        _ player: MatchRecord.Player
    ) {
        matchID = match
        slot = player.slot
        name = player.name
        userID = player.userID
        linkStatus = player.linkStatus
    }

    var player: MatchRecord.Player {
        MatchRecord.Player(slot: slot, name: name, userID: userID, linkStatus: linkStatus)
    }

    enum CodingKeys: String, CodingKey {
        case slot, name
        case matchID = "match_id"
        case userID = "user_id"
        case linkStatus = "link_status"
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

    init(
        match: UUID,
        _ point: MatchRecord.Point
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
            clipPath: clipPath
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, index, at, outcome, source, confidence, corrected
        case matchID = "match_id"
        case winnerSide = "winner_side"
        case clipPath = "clip_path"
    }
}
