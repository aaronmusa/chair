//
//  ProfileRemote.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation

import Supabase

public enum Hand: String, Codable, Sendable, CaseIterable {
    case left
    case right
}

public enum Level: String, Codable, Sendable, CaseIterable {
    case beginner
    case intermediate
    case advanced
}

public struct ProfileRecord: Codable, Equatable, Sendable {
    public static let defaultDisplayName = "Player"

    public var id: UUID
    public var handle: String
    public var displayName: String
    public var homeCourt: String?
    public var hand: Hand?
    public var level: Level?

    public init(
        id: UUID,
        handle: String,
        displayName: String,
        homeCourt: String? = nil,
        hand: Hand? = nil,
        level: Level? = nil
    ) {
        self.id = id
        self.handle = handle
        self.displayName = displayName
        self.homeCourt = homeCourt
        self.hand = hand
        self.level = level
    }

    enum CodingKeys: String, CodingKey {
        case id, handle, hand, level
        case displayName = "display_name"
        case homeCourt = "home_court"
    }
}

public struct PublicProfile: Codable, Equatable, Sendable {
    public var id: UUID
    public var handle: String
    public var displayName: String
    public var level: Level?

    public init(
        id: UUID,
        handle: String,
        displayName: String,
        level: Level? = nil
    ) {
        self.id = id
        self.handle = handle
        self.displayName = displayName
        self.level = level
    }

    enum CodingKeys: String, CodingKey {
        case id, handle, level
        case displayName = "display_name"
    }
}

public protocol ProfileRemote: Sendable {
    func ownProfile() async throws -> ProfileRecord?
    func claimDisplayName(_ name: String) async throws
    func update(_ profile: ProfileRecord) async throws
    func handleAvailable(_ handle: String) async throws -> Bool
    func publicProfile(handle: String) async throws -> PublicProfile?
    func linkedMatchCount(with userID: UUID) async throws -> Int
    func search(_ query: String) async throws -> [PublicProfile]
}

public struct SupabaseProfileRemote: ProfileRemote {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func ownProfile() async throws -> ProfileRecord? {
        let userID = try await client.auth.session.user.id
        let rows: [ProfileRecord] = try await client.from("profiles")
            .select("id, handle, display_name, home_court, hand, level")
            .eq("id", value: userID)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    public func claimDisplayName(_ name: String) async throws {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !trimmed.isEmpty else { return }
        let userID = try await client.auth.session.user.id
        try await client.from("profiles")
            .update(["display_name": trimmed])
            .eq("id", value: userID)
            .eq("display_name", value: ProfileRecord.defaultDisplayName)
            .execute()
    }

    public func update(_ profile: ProfileRecord) async throws {
        try await client.from("profiles")
            .update(ProfileUpdate(profile))
            .eq("id", value: profile.id)
            .execute()
    }

    public func handleAvailable(_ handle: String) async throws -> Bool {
        try await client.rpc("handle_available", params: ["h": handle]).execute().value
    }

    public func publicProfile(handle: String) async throws -> PublicProfile? {
        let rows: [PublicProfile] = try await client.from("public_profiles")
            .select("id, handle, display_name, level")
            .eq("handle", value: handle)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    public func linkedMatchCount(with userID: UUID) async throws -> Int {
        let response = try await client.from("match_players")
            .select("match_id", head: true, count: .exact)
            .eq("user_id", value: userID)
            .eq("link_status", value: LinkStatus.accepted.rawValue)
            .execute()
        return response.count ?? 0
    }

    public func search(_ query: String) async throws -> [PublicProfile] {
        try await client.rpc("profiles_search", params: ["q": query]).execute().value
    }
}

private struct ProfileUpdate: Encodable {
    let profile: ProfileRecord

    init(_ profile: ProfileRecord) {
        self.profile = profile
    }

    enum CodingKeys: String, CodingKey {
        case handle, hand, level
        case displayName = "display_name"
        case homeCourt = "home_court"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profile.handle, forKey: .handle)
        try container.encode(profile.displayName, forKey: .displayName)
        try container.encode(profile.homeCourt, forKey: .homeCourt)
        try container.encode(profile.hand, forKey: .hand)
        try container.encode(profile.level, forKey: .level)
    }
}
