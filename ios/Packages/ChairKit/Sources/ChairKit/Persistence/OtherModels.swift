//
//  OtherModels.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import SwiftData

@Model
public final class SavedCourt {
    @Attribute(.unique) public var remoteID: UUID
    public var ownerID: UUID?
    public var name: String
    public var calibrationData = Data()
    public var placement: String
    public var lastUsedAt: Date?
    public var latitude: Double?
    public var longitude: Double?
    public var thumbnailFile: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var syncState: SyncState

    public init(
        remoteID: UUID = UUID(),
        ownerID: UUID? = nil,
        name: String,
        calibration: CourtCalibration,
        lastUsedAt: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        createdAt: Date,
        updatedAt: Date,
        syncState: SyncState = .pendingUpload
    ) {
        self.remoteID = remoteID
        self.ownerID = ownerID
        self.name = name
        calibrationData = (try? JSONEncoder().encode(calibration)) ?? Data()
        placement = calibration.placement.rawValue
        self.lastUsedAt = lastUsedAt
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncState = syncState
    }

    public var calibration: CourtCalibration? {
        get { try? JSONDecoder().decode(CourtCalibration.self, from: calibrationData) }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else { return }
            calibrationData = data
            placement = newValue.placement.rawValue
        }
    }
}

@Model
public final class TrainingSession {
    @Attribute(.unique) public var remoteID: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var syncState: SyncState

    public init(
        remoteID: UUID = UUID(),
        createdAt: Date,
        updatedAt: Date,
        syncState: SyncState = .pendingUpload
    ) {
        self.remoteID = remoteID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncState = syncState
    }
}

@Model
public final class Profile {
    @Attribute(.unique) public var remoteID: UUID
    public var handle: String?
    public var displayName: String
    public var avatarURL: URL?
    public var homeCourt: String?
    public var hand: String?
    public var level: String?
    public var updatedAt: Date
    public var syncState: SyncState

    public init(
        remoteID: UUID,
        handle: String? = nil,
        displayName: String,
        avatarURL: URL? = nil,
        homeCourt: String? = nil,
        hand: String? = nil,
        level: String? = nil,
        updatedAt: Date,
        syncState: SyncState = .pendingUpload
    ) {
        self.remoteID = remoteID
        self.handle = handle
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.homeCourt = homeCourt
        self.hand = hand
        self.level = level
        self.updatedAt = updatedAt
        self.syncState = syncState
    }
}

public enum ChairContainer {
    public static let models: [any PersistentModel.Type] = [
        Match.self, MatchPlayer.self, PointEvent.self, SavedCourt.self, TrainingSession.self, Profile.self,
    ]

    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: Schema(models), isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: Schema(models), configurations: configuration)
    }
}
