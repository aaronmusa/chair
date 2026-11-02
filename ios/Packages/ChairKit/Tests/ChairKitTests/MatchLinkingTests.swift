//
//  MatchLinkingTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import SwiftData
import XCTest

import ChairKit
import ChairTestSupport

@MainActor
final class MatchLinkingTests: XCTestCase {
    private let juan = UUID()
    private var containers: [ModelContainer] = []

    func testLinkingAPlayerMakesItPendingAndQueuesTheUpload() throws {
        let repository = try repository(remote: FakeMatchRemote())
        let match = Match.sample()
        try repository.save(match)
        match.syncState = .synced
        match.players.forEach { $0.syncState = .synced }

        match.link(.b1, to: juan, at: Fixtures.matchDay)
        try repository.save(match)

        let opponent = try XCTUnwrap(match.players.first { $0.slot == .b1 })
        XCTAssertEqual(opponent.userID, juan)
        XCTAssertEqual(opponent.linkStatus, .pending)
        XCTAssertEqual(opponent.invitedAt, Fixtures.matchDay)
        XCTAssertEqual(opponent.name, "Reyes")
        XCTAssertEqual(opponent.syncState, .pendingUpload)
        XCTAssertEqual(match.syncState, .pendingUpload)
        XCTAssertGreaterThan(try repository.pendingCount(), 0)
    }

    func testTheLocalUsersRowCannotBeLinked() {
        let match = Match.sample()

        match.link(.a1, to: juan, at: Fixtures.matchDay)

        XCTAssertNil(match.players.first { $0.slot == .a1 }?.userID)
    }

    func testUnlinkMakesTheRowFreeTextAgain() {
        let match = Match.sample()
        match.link(.b1, to: juan, at: Fixtures.matchDay)

        match.unlink(.b1, at: Fixtures.matchDay)

        let opponent = match.players.first { $0.slot == .b1 }
        XCTAssertNil(opponent?.userID)
        XCTAssertEqual(opponent?.linkStatus, LinkStatus.none)
        XCTAssertEqual(opponent?.name, "Reyes")
    }

    func testALinkPickedOnNewMatchFollowsTheNameThroughReseating() throws {
        var setup = NewMatchSetup(defaults: MatchDefaults(format: .doubles))
        setup.names[.a2] = "Bea"
        setup.names[.b1] = "Juan"
        setup.names[.b2] = "Lia"
        setup.firstServers[.b] = .b2
        setup.links[.b1] = juan

        let match = try setup.makeMatch(at: Fixtures.matchDay)

        let linked = try XCTUnwrap(match.players.first { $0.userID == juan })
        XCTAssertEqual(linked.name, "Juan")
        XCTAssertEqual(linked.slot, .b2)
        XCTAssertEqual(linked.linkStatus, .pending)
    }

    func testASyncedMatchTheServerNoLongerShowsIsPrunedButAPendingOneIsKept() async throws {
        let remote = FakeMatchRemote()
        let mine = try repository(remote: remote)
        let shared = Match.sample()
        try mine.save(shared)
        try await mine.sync()

        let other = try repository(remote: remote)
        try await other.sync()
        XCTAssertEqual(try other.fetch().count, 1)
        let unsent = Match.sample()
        try other.save(unsent)

        try await remote.delete(id: shared.remoteID)
        await remote.setOnline(false)
        do { try await other.sync() } catch {}
        await remote.setOnline(true)
        try await other.sync()

        XCTAssertEqual(try other.fetch().map(\.remoteID), [unsent.remoteID])
    }

    private func repository(remote: FakeMatchRemote) throws -> SyncingMatchRepository {
        let container = try InMemoryModelContainer()
        containers.append(container)
        return SyncingMatchRepository(context: container.mainContext, remote: remote)
    }
}
