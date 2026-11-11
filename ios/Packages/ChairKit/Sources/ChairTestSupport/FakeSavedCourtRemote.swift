//
//  FakeSavedCourtRemote.swift
//  ChairTestSupport
//
//  Created by Aaron Musa on 11/11/26.
//

#if DEBUG
    import Foundation

    import ChairKit

    public actor FakeSavedCourtRemote: SavedCourtRemote {
        public struct Offline: Error {}

        public private(set) var rows: [UUID: SavedCourtRecord] = [:]
        public var isOnline = true

        public init() {}

        public func setOnline(_ online: Bool) {
            isOnline = online
        }

        public func store(_ record: SavedCourtRecord) {
            rows[record.id] = record
        }

        public func court(id: UUID) async throws -> SavedCourtRecord? {
            try requireOnline()
            return rows[id]
        }

        public func upsert(_ record: SavedCourtRecord) async throws {
            try requireOnline()
            rows[record.id] = record
        }

        public func delete(id: UUID) async throws {
            try requireOnline()
            rows[id] = nil
        }

        public func courts(updatedSince: Date?) async throws -> [SavedCourtRecord] {
            try requireOnline()
            return rows.values.filter { record in updatedSince.map { record.updatedAt > $0 } ?? true }
        }

        public func visibleCourtIDs() async throws -> Set<UUID> {
            try requireOnline()
            return Set(rows.keys)
        }

        private func requireOnline() throws {
            guard isOnline else { throw Offline() }
        }
    }
#endif
