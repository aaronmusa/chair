//
//  SupabaseMatchRemoteTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import SwiftData
import XCTest

import ChairKit
import ChairTestSupport
import Supabase

final class SupabaseMatchRemoteTests: XCTestCase {
    private static func client(signedInAs email: String) async throws -> SupabaseClient {
        let client = try client()
        try await client.auth.signIn(email: email, password: "chair-local")
        return client
    }

    private static func client() throws -> SupabaseClient {
        let environment = ProcessInfo.processInfo.environment
        guard let url = environment["CHAIR_SUPABASE_URL"].flatMap(URL.init(string:)),
              let key = environment["CHAIR_SUPABASE_ANON_KEY"] else {
            throw XCTSkip("set CHAIR_SUPABASE_URL and CHAIR_SUPABASE_ANON_KEY to run against the local stack")
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(auth: .init(storage: InMemoryAuthStorage(), emitLocalSessionAsInitialSession: true))
        )
    }

    @MainActor
    func testTwoDevicesSignedInAsTheSeedUserShareAMatchAndItsUndo() async throws {
        let first = try await Self.device(signedInAs: "test@chair.local")
        let second = try await Self.device(signedInAs: "test@chair.local")
        let match = Match(playedAt: .now, format: .singles, createdAt: .now, updatedAt: .now)
        match.players = [MatchPlayer.sample(.a1, name: "Aaron"), MatchPlayer.sample(.b1, name: "Juan")]
        var log = try MatchLog(rules: MatchRules())
        for side in [Side.a, .b, .a] {
            try log.append(TimedEvent(.pointWon(by: side, outcome: nil, ending: nil), at: .now))
        }
        match.update(from: log, at: .now)
        try first.repository.save(match)

        try await first.repository.sync()
        try await second.repository.sync()
        let copy = try XCTUnwrap(second.repository.fetch().first { $0.remoteID == match.remoteID })
        XCTAssertEqual(copy.orderedPoints.count, 3)
        XCTAssertFalse(copy.orderedPoints[2].undone)

        try log.append(TimedEvent(.undo, at: .now))
        match.update(from: log, at: .now)
        try first.repository.save(match)
        try await first.repository.sync()
        try await second.repository.sync()

        let synced = try XCTUnwrap(second.repository.fetch().first { $0.remoteID == match.remoteID })
        XCTAssertTrue(synced.orderedPoints[2].undone)
        XCTAssertEqual(synced.orderedPoints.count, 4)
        try await first.remote.delete(id: match.remoteID)
    }

    @MainActor
    private static func device(signedInAs email: String) async throws -> (repository: SyncingMatchRepository, remote: SupabaseMatchRemote) {
        let client = try client()
        _ = try await SupabaseAuthService(client: client).signIn(email: email, password: "chair-local")
        let container = try InMemoryModelContainer()
        containers.append(container)
        let remote = SupabaseMatchRemote(client: client)
        return (SyncingMatchRepository(context: container.mainContext, remote: remote), remote)
    }

    @MainActor private static var containers: [ModelContainer] = []

    @MainActor
    func testARecordRoundTripsThroughTheLocalStack() async throws {
        let remote = try await SupabaseMatchRemote(client: Self.client(signedInAs: "aaron@chair.test"))
        var record = Match.sample().record
        let snapshot = ScoreSnapshot(sets: [], currentSet: SetScore(a: 1, b: 0), currentGame: .loveAll, server: .b1)
        record.points[1].undone = true
        record.points.append(contentsOf: MatchLog.pointEvents(
            [TimedEvent(.setScore(snapshot), at: Fixtures.matchDay), TimedEvent(.retire(.b), at: Fixtures.matchDay)],
            updatedAt: Fixtures.matchDay
        ).enumerated().map { offset, row in
            MatchRecord.Point(
                id: UUID(),
                index: 3 + offset,
                at: row.at,
                winnerSide: nil,
                outcome: nil,
                source: row.source,
                confidence: nil,
                corrected: false,
                clipPath: nil,
                eventKind: row.eventKind,
                payload: row.payload,
                updatedAt: row.updatedAt
            )
        })

        try await remote.upsert(record)
        let stored = try await remote.match(id: record.id)
        XCTAssertEqual(stored, record)

        let changes = try await remote.matches(updatedSince: Fixtures.matchDay.addingTimeInterval(-1))
        XCTAssertTrue(changes.contains { $0.id == record.id })

        record.status = .completed
        record.updatedAt = record.updatedAt.addingTimeInterval(60)
        record.points[0].undone = true
        try await remote.upsert(record)
        let fetched = try await remote.match(id: record.id)
        let edited = try XCTUnwrap(fetched)
        XCTAssertEqual(edited.status, .completed)
        XCTAssertTrue(edited.points[0].undone)
        XCTAssertGreaterThan(try XCTUnwrap(edited.points[0].updatedAt), try XCTUnwrap(record.points[0].updatedAt))
        XCTAssertEqual(edited.points[1], record.points[1], "an unchanged point keeps its updated_at")

        let stranger = try await SupabaseMatchRemote(client: Self.client(signedInAs: "juan@chair.test"))
        let seenByStranger = try await stranger.match(id: record.id)
        XCTAssertNil(seenByStranger, "RLS hides another user's match")

        try await remote.delete(id: record.id)
        let deleted = try await remote.match(id: record.id)
        XCTAssertNil(deleted)
    }
}

final class InMemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func store(
        key: String,
        value: Data
    ) throws {
        lock.withLock { values[key] = value }
    }

    func retrieve(key: String) throws -> Data? {
        lock.withLock { values[key] }
    }

    func remove(key: String) throws {
        lock.withLock { values[key] = nil }
    }
}
