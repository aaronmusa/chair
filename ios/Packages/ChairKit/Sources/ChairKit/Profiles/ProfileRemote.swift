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

public protocol ProfileRemote: Sendable {
    func ownProfile() async throws -> ProfileRecord?
    func claimDisplayName(_ name: String) async throws
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
}
