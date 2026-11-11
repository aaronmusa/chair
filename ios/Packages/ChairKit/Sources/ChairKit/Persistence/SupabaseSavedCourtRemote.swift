//
//  SupabaseSavedCourtRemote.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/11/26.
//

import Foundation

import Supabase

public struct SupabaseSavedCourtRemote: SavedCourtRemote {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func court(id: UUID) async throws -> SavedCourtRecord? {
        let rows: [SavedCourtRow] = try await client.from("saved_courts")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value
        return rows.first?.record
    }

    public func upsert(_ record: SavedCourtRecord) async throws {
        try await client.from("saved_courts").upsert(SavedCourtRow(record)).execute()
    }

    public func delete(id: UUID) async throws {
        try await client.from("saved_courts").delete().eq("id", value: id).execute()
    }

    public func courts(updatedSince: Date?) async throws -> [SavedCourtRecord] {
        var query = client.from("saved_courts").select()
        if let updatedSince {
            query = query.gt("updated_at", value: updatedSince)
        }
        let rows: [SavedCourtRow] = try await query.execute().value
        return rows.map(\.record)
    }

    public func visibleCourtIDs() async throws -> Set<UUID> {
        let rows: [VisibleCourtRow] = try await client.from("saved_courts").select("id").execute().value
        return Set(rows.map(\.id))
    }
}

private struct VisibleCourtRow: Decodable {
    let id: UUID
}

struct SavedCourtRow: Codable {
    let id: UUID
    let ownerID: UUID?
    let name: String
    let calibration: CourtCalibration
    let placement: CameraPlacement
    let lastUsedAt: Date?
    let latitude: Double?
    let longitude: Double?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, calibration, placement, latitude, longitude
        case ownerID = "owner_id"
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(_ record: SavedCourtRecord) {
        id = record.id
        ownerID = record.ownerID
        name = record.name
        calibration = record.calibration
        placement = record.calibration.placement
        lastUsedAt = record.lastUsedAt
        latitude = record.latitude
        longitude = record.longitude
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(ownerID, forKey: .ownerID)
        try container.encode(name, forKey: .name)
        try container.encode(calibration, forKey: .calibration)
        try container.encode(placement, forKey: .placement)
        try container.encode(lastUsedAt, forKey: .lastUsedAt)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    var record: SavedCourtRecord {
        SavedCourtRecord(
            id: id,
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
