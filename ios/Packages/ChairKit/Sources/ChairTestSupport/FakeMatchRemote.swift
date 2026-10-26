//
//  FakeMatchRemote.swift
//  ChairTestSupport
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation

import ChairKit

public actor FakeMatchRemote: MatchRemote {
    public struct Offline: Error {}

    public private(set) var rows: [UUID: MatchRecord] = [:]
    public private(set) var upsertCount = 0
    public var isOnline = true

    public init() {}

    public func setOnline(_ online: Bool) {
        isOnline = online
    }

    public func match(id: UUID) async throws -> MatchRecord? {
        try requireOnline()
        return rows[id]
    }

    public func upsert(_ record: MatchRecord) async throws {
        try requireOnline()
        upsertCount += 1
        rows[record.id] = record
    }

    public func delete(id: UUID) async throws {
        try requireOnline()
        rows[id] = nil
    }

    public func matches(updatedSince: Date?) async throws -> [MatchRecord] {
        try requireOnline()
        return rows.values.filter { record in updatedSince.map { record.updatedAt > $0 } ?? true }
    }

    private func requireOnline() throws {
        guard isOnline else { throw Offline() }
    }
}
