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
    func testAnAcceptedInviteSurvivesTheOwnersStaleReUploadAndReachesTheOwner() async throws {
        let owner = try await Self.device(signedInAs: "aaron@chair.test")
        let inviteeClient = try await Self.client(signedInAs: "juan@chair.test")
        let match = Match(playedAt: .now, format: .singles, createdAt: .now, updatedAt: .now)
        let opponent = MatchPlayer(
            slot: .b1,
            name: "Juan",
            userID: Self.juan,
            linkStatus: .pending,
            invitedAt: .now,
            updatedAt: .now
        )
        match.players = [MatchPlayer.sample(.a1, name: "Aaron", at: .now), opponent]
        try owner.repository.save(match)
        try await owner.repository.sync(as: Self.aaron)

        let hiddenWhilePending: [IDRow] = try await inviteeClient.from("matches")
            .select("id")
            .eq("id", value: match.remoteID)
            .execute()
            .value
        XCTAssertTrue(hiddenWhilePending.isEmpty)
        try await inviteeClient.rpc("respond_to_invite", params: InviteAnswer(matchID: match.remoteID, accept: true)).execute()

        match.status = .abandoned
        match.updatedAt = .now
        try owner.repository.save(match)
        try await owner.repository.sync(as: Self.aaron)

        let stored = try await owner.remote.match(id: match.remoteID)
        XCTAssertEqual(stored?.status, .abandoned)
        XCTAssertEqual(stored?.players.first { $0.slot == .b1 }?.linkStatus, .accepted)
        XCTAssertEqual(opponent.linkStatus, .accepted)
        XCTAssertNotNil(opponent.respondedAt)
        let linked: [IDRow] = try await inviteeClient.from("my_matches").select("id").eq("role", value: "linked").execute().value
        XCTAssertEqual(linked.map(\.id), [match.remoteID])

        try await owner.remote.delete(id: match.remoteID)
    }

    private func assertStored(
        _ stored: MatchRecord?,
        matches record: MatchRecord
    ) throws {
        let stored = try XCTUnwrap(stored)
        XCTAssertEqual(stored.ownerID, Self.aaron)
        XCTAssertEqual(stored.players.map(\.name), record.players.map(\.name))
        XCTAssertEqual(stored.players.map(\.linkStatus), record.players.map(\.linkStatus))
        XCTAssertTrue(stored.players.allSatisfy { $0.updatedAt != nil })
        var expected = record
        expected.ownerID = stored.ownerID
        expected.players = stored.players
        XCTAssertEqual(stored, expected)
    }

    @MainActor
    func testTwoKeptLocalMatchesReachTheStackAsTheUsersOwnAndAppearInMyMatches() async throws {
        let client = try Self.client()
        let session = try await SupabaseAuthService(client: client).signIn(email: "test@chair.local", password: "chair-local")
        let container = try InMemoryModelContainer()
        Self.containers.append(container)
        let repository = SyncingMatchRepository(context: container.mainContext, remote: SupabaseMatchRemote(client: client))
        let matches = [Match.sample(at: .now), Match.sample(at: .now)]
        try matches.forEach(repository.save)
        let migration = AccountMigration(repository: repository, store: InMemoryAccountStore())

        XCTAssertEqual(try migration.pendingPrompt(for: session.userID), .keepLocal(count: 2))
        migration.keep(for: session.userID)
        try await repository.sync(as: session.userID)

        let ids = matches.map(\.remoteID)
        let mine: [OwnedRow] = try await client.from("my_matches")
            .select("id, owner_id, role")
            .in("id", values: ids)
            .execute()
            .value
        XCTAssertEqual(Set(mine.map(\.id)), Set(ids))
        XCTAssertTrue(mine.allSatisfy { $0.ownerID == session.userID && $0.role == "owner" })
        let stored = try await SupabaseMatchRemote(client: client).match(id: ids[0])
        let me = stored?.players.first { $0.slot == .a1 }
        XCTAssertEqual(me?.userID, session.userID)
        XCTAssertEqual(me?.linkStatus, .accepted)
        XCTAssertNotNil(me?.respondedAt)

        for id in ids {
            try await SupabaseMatchRemote(client: client).delete(id: id)
        }
    }

    @MainActor
    func testUnlinkingAnAcceptedLinkRemovesTheMatchFromTheOtherPlayerAndPrunesTheirCopy() async throws {
        let owner = try await Self.device(signedInAs: "aaron@chair.test")
        let invitee = try await Self.device(signedInAs: "juan@chair.test")
        let inviteeClient = try await Self.client(signedInAs: "juan@chair.test")
        let match = Match(playedAt: .now, format: .singles, createdAt: .now, updatedAt: .now)
        match.players = [MatchPlayer.sample(.a1, name: "Aaron", at: .now), MatchPlayer.sample(.b1, name: "Juan", at: .now)]
        match.link(.b1, to: Self.juan, at: .now)
        try owner.repository.save(match)
        try await owner.repository.sync(as: Self.aaron)
        try await inviteeClient.rpc("respond_to_invite", params: InviteAnswer(matchID: match.remoteID, accept: true)).execute()
        try await invitee.repository.sync(as: Self.juan)
        XCTAssertTrue(try invitee.repository.fetch().contains { $0.remoteID == match.remoteID })

        match.unlink(.b1, at: .now)
        try owner.repository.save(match)
        try await owner.repository.sync(as: Self.aaron)
        try await invitee.repository.sync(as: Self.juan)

        let stored = try await owner.remote.match(id: match.remoteID)
        XCTAssertNil(stored?.players.first { $0.slot == .b1 }?.userID)
        XCTAssertEqual(stored?.players.first { $0.slot == .b1 }?.name, "Juan")
        let listed: [IDRow] = try await inviteeClient.from("my_matches").select("id").eq("id", value: match.remoteID).execute().value
        XCTAssertTrue(listed.isEmpty)
        XCTAssertFalse(try invitee.repository.fetch().contains { $0.remoteID == match.remoteID })

        try await owner.remote.delete(id: match.remoteID)
    }

    func testSearchIsAPrefixMatchOnHandleThatLeavesOutTheCaller() async throws {
        let client = try await Self.client(signedInAs: "aaron@chair.test")
        let profiles = SupabaseProfileRemote(client: client)

        let fromAaron = try await profiles.search("aar")
        let fromJuan = try await SupabaseProfileRemote(client: Self.client(signedInAs: "juan@chair.test")).search("AAR")

        XCTAssertFalse(fromAaron.contains { $0.id == Self.aaron })
        XCTAssertTrue(fromJuan.contains { $0.handle == "aaron" })
        XCTAssertTrue(fromJuan.allSatisfy { $0.handle.lowercased().hasPrefix("aar") })
    }

    private static let aaron = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    private static let juan = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!

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
        try assertStored(stored, matches: record)

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

private struct OwnedRow: Decodable {
    let id: UUID
    let ownerID: UUID
    let role: String

    enum CodingKeys: String, CodingKey {
        case id, role
        case ownerID = "owner_id"
    }
}

private struct IDRow: Decodable {
    let id: UUID
}

private struct InviteAnswer: Encodable {
    let matchID: UUID
    let accept: Bool

    enum CodingKeys: String, CodingKey {
        case accept
        case matchID = "p_match_id"
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
