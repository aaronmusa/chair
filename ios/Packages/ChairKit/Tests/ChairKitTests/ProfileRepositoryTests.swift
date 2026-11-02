//
//  ProfileRepositoryTests.swift
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
final class ProfileRepositoryTests: XCTestCase {
    private var container: ModelContainer?

    func testSyncFillsTheLocalProfileFromTheServer() async throws {
        let repository = try makeRepository(remote: FakeProfileRemote())

        try await repository.sync()

        XCTAssertEqual(try repository.current(), FakeProfileRemote.sampleProfile)
    }

    func testAnOfflineEditIsKeptAndUploadsOnTheNextSync() async throws {
        let remote = FakeProfileRemote()
        let repository = try makeRepository(remote: remote)
        try await repository.sync()
        await remote.setOnline(false)

        var edited = try XCTUnwrap(repository.current())
        edited.displayName = "Aaron Musa"
        edited.hand = .right
        try repository.save(edited)
        do {
            try await repository.sync()
            XCTFail("sync should fail offline")
        } catch {}

        XCTAssertEqual(try repository.current()?.displayName, "Aaron Musa")
        await remote.setOnline(true)
        try await repository.sync()
        let updates = await remote.updates
        XCTAssertEqual(updates, [edited])
        XCTAssertEqual(try repository.current(), edited)
    }

    func testClearRemovesTheLocalProfile() async throws {
        let repository = try makeRepository(remote: FakeProfileRemote())
        try await repository.sync()

        try repository.clear()

        XCTAssertNil(try repository.current())
    }

    private func makeRepository(remote: FakeProfileRemote) throws -> ProfileRepository {
        let container = try InMemoryModelContainer()
        self.container = container
        return ProfileRepository(context: container.mainContext, remote: remote)
    }
}
