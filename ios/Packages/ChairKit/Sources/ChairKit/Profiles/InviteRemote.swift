//
//  InviteRemote.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation

import Supabase

public struct Invite: Codable, Equatable, Identifiable, Sendable {
    public var matchID: UUID
    public var ownerHandle: String
    public var ownerDisplayName: String
    public var playedAt: Date
    public var format: MatchFormat
    public var status: MatchStatus
    public var sets: [SetScore]

    public var id: UUID {
        matchID
    }

    public init(
        matchID: UUID,
        ownerHandle: String,
        ownerDisplayName: String,
        playedAt: Date,
        format: MatchFormat,
        status: MatchStatus,
        sets: [SetScore]
    ) {
        self.matchID = matchID
        self.ownerHandle = ownerHandle
        self.ownerDisplayName = ownerDisplayName
        self.playedAt = playedAt
        self.format = format
        self.status = status
        self.sets = sets
    }

    enum CodingKeys: String, CodingKey {
        case format, status, sets
        case matchID = "match_id"
        case ownerHandle = "owner_handle"
        case ownerDisplayName = "owner_display_name"
        case playedAt = "played_at"
    }
}

public protocol InviteRemote: Sendable {
    func pendingInvites() async throws -> [Invite]
    func respond(
        to matchID: UUID,
        accept: Bool
    ) async throws
}

public struct SupabaseInviteRemote: InviteRemote {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func pendingInvites() async throws -> [Invite] {
        try await client.from("pending_invites")
            .select("match_id, owner_handle, owner_display_name, played_at, format, status, sets")
            .order("played_at", ascending: false)
            .execute()
            .value
    }

    public func respond(
        to matchID: UUID,
        accept: Bool
    ) async throws {
        try await client.rpc("respond_to_invite", params: Answer(matchID: matchID, accept: accept)).execute()
    }
}

private struct Answer: Encodable {
    let matchID: UUID
    let accept: Bool

    enum CodingKeys: String, CodingKey {
        case accept
        case matchID = "p_match_id"
    }
}
