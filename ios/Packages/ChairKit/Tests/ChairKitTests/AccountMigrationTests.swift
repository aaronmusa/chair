//
//  AccountMigrationTests.swift
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
final class AccountMigrationTests: XCTestCase {
    private let userA = FakeAuthService.sampleSession.userID
    private let userB = UUID()
    private var containers: [ModelContainer] = []

    func testLocalMatchesAskToBeKeptAndThenUploadAsTheUsersOwn() async throws {
        let remote = FakeMatchRemote()
        let repository = try repository(remote: remote)
        let matches = [Match.sample(), Match.sample()]
        try matches.forEach(repository.save)
        let migration = AccountMigration(repository: repository, store: InMemoryAccountStore())

        XCTAssertEqual(try migration.pendingPrompt(for: userA), .keepLocal(count: 2))
        migration.keep(for: userA)
        XCTAssertNil(try migration.pendingPrompt(for: userA))
        try await repository.sync(as: userA)

        let rows = await remote.rows
        for match in matches {
            let stored = try XCTUnwrap(rows[match.remoteID])
            XCTAssertEqual(stored.ownerID, userA)
            let me = try XCTUnwrap(stored.players.first { $0.slot == .a1 })
            XCTAssertEqual(me.userID, userA)
            XCTAssertEqual(me.linkStatus, .accepted)
            XCTAssertNotNil(me.respondedAt)
        }
    }

    func testDiscardDeletesTheLocalMatches() throws {
        let repository = try repository(remote: FakeMatchRemote())
        try repository.save(Match.sample())
        let migration = AccountMigration(repository: repository, store: InMemoryAccountStore())

        try migration.discard(for: userA)

        XCTAssertTrue(try repository.fetch().isEmpty)
        XCTAssertNil(try migration.pendingPrompt(for: userA))
    }

    func testADifferentUserIsAskedToReplaceAndTheCacheIsEmptyBeforeTheFirstPull() async throws {
        let remote = FakeMatchRemote()
        let repository = try repository(remote: remote)
        try repository.save(Match.sample())
        let store = InMemoryAccountStore(lastUserID: userA)
        try await repository.sync(as: userA)
        let migration = AccountMigration(repository: repository, store: store)

        XCTAssertEqual(try migration.pendingPrompt(for: userB), .replaceLocal)
        try migration.replace(for: userB)

        XCTAssertTrue(try repository.fetch().isEmpty)
        XCTAssertEqual(store.lastUserID, userB)
        XCTAssertNil(try migration.pendingPrompt(for: userB))
    }

    func testTheSameUserSigningBackInIsNotAsked() throws {
        let repository = try repository(remote: FakeMatchRemote())
        try repository.save(Match.sample())
        let migration = AccountMigration(repository: repository, store: InMemoryAccountStore(lastUserID: userA))

        XCTAssertNil(try migration.pendingPrompt(for: userA))
    }

    func testNothingUploadsWhileTheQuestionIsOpen() async throws {
        let remote = FakeMatchRemote()
        let repository = try repository(remote: remote)
        try repository.save(Match.sample())
        let migration = AccountMigration(repository: repository, store: InMemoryAccountStore())
        let coordinator = SyncCoordinator(
            repository: repository,
            auth: FakeAuthService(signedIn: true),
            network: FakeNetworkMonitor(),
            migration: migration
        )
        coordinator.start()
        defer { coordinator.stop() }
        for _ in 0 ..< 100 where !coordinator.isOnline {
            try await Task.sleep(for: .milliseconds(10))
        }

        await coordinator.syncNow()
        let before = await remote.upsertCount
        migration.keep(for: userA)
        await coordinator.syncNow()
        let after = await remote.upsertCount

        XCTAssertEqual(before, 0)
        XCTAssertEqual(after, 1)
    }

    private func repository(remote: FakeMatchRemote) throws -> SyncingMatchRepository {
        let container = try InMemoryModelContainer()
        containers.append(container)
        return SyncingMatchRepository(context: container.mainContext, remote: remote)
    }
}
