//
//  ProfileRepository.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import SwiftData

@MainActor
public final class ProfileRepository {
    private let context: ModelContext
    private let remote: (any ProfileRemote)?
    private let clock: any ClockProvider

    public init(
        context: ModelContext,
        remote: (any ProfileRemote)?,
        clock: any ClockProvider = SystemClock()
    ) {
        self.context = context
        self.remote = remote
        self.clock = clock
    }

    public func current() throws -> ProfileRecord? {
        try stored()?.record
    }

    public func save(_ record: ProfileRecord) throws {
        let profile = try stored() ?? insert(record.id)
        profile.apply(record)
        profile.updatedAt = clock.now
        profile.syncState = .pendingUpload
        try context.save()
    }

    public func sync() async throws {
        guard let remote else { return }
        if let pending = try stored(), pending.syncState == .pendingUpload {
            try await remote.update(pending.record)
            pending.syncState = .synced
            try context.save()
        }
        guard let fetched = try await remote.ownProfile() else { return }
        let profile = try stored() ?? insert(fetched.id)
        guard profile.syncState == .synced || profile.remoteID != fetched.id else { return }
        profile.remoteID = fetched.id
        profile.apply(fetched)
        profile.syncState = .synced
        try context.save()
    }

    public func clear() throws {
        try context.fetch(FetchDescriptor<Profile>()).forEach(context.delete)
        try context.save()
    }

    private func stored() throws -> Profile? {
        var descriptor = FetchDescriptor<Profile>()
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func insert(_ id: UUID) -> Profile {
        let profile = Profile(remoteID: id, displayName: ProfileRecord.defaultDisplayName, updatedAt: clock.now, syncState: .synced)
        context.insert(profile)
        return profile
    }
}

extension Profile {
    var record: ProfileRecord {
        ProfileRecord(
            id: remoteID,
            handle: handle ?? "",
            displayName: displayName,
            homeCourt: homeCourt,
            hand: hand.flatMap(Hand.init(rawValue:)),
            level: level.flatMap(Level.init(rawValue:))
        )
    }

    func apply(_ record: ProfileRecord) {
        handle = record.handle
        displayName = record.displayName
        homeCourt = record.homeCourt
        hand = record.hand?.rawValue
        level = record.level?.rawValue
    }
}
