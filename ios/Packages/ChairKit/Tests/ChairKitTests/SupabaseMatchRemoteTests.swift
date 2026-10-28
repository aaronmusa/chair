//
//  SupabaseMatchRemoteTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport
import Supabase

final class SupabaseMatchRemoteTests: XCTestCase {
    private static func client(signedInAs email: String) async throws -> SupabaseClient {
        let environment = ProcessInfo.processInfo.environment
        guard let url = environment["CHAIR_SUPABASE_URL"].flatMap(URL.init(string:)),
              let key = environment["CHAIR_SUPABASE_ANON_KEY"] else {
            throw XCTSkip("set CHAIR_SUPABASE_URL and CHAIR_SUPABASE_ANON_KEY to run against the local stack")
        }
        let client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(auth: .init(storage: InMemoryAuthStorage(), emitLocalSessionAsInitialSession: true))
        )
        try await client.auth.signIn(email: email, password: "chair-local")
        return client
    }

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
                payload: row.payload
            )
        })

        try await remote.upsert(record)
        let stored = try await remote.match(id: record.id)
        XCTAssertEqual(stored, record)

        let changes = try await remote.matches(updatedSince: Fixtures.matchDay.addingTimeInterval(-1))
        XCTAssertTrue(changes.contains { $0.id == record.id })

        record.status = .completed
        record.updatedAt = record.updatedAt.addingTimeInterval(60)
        record.points.removeLast()
        try await remote.upsert(record)
        let edited = try await remote.match(id: record.id)
        XCTAssertEqual(edited, record)

        let stranger = try await SupabaseMatchRemote(client: Self.client(signedInAs: "juan@chair.test"))
        let seenByStranger = try await stranger.match(id: record.id)
        XCTAssertNil(seenByStranger, "RLS hides another user's match")

        try await remote.delete(id: record.id)
        let deleted = try await remote.match(id: record.id)
        XCTAssertNil(deleted)
    }
}

private final class InMemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
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
