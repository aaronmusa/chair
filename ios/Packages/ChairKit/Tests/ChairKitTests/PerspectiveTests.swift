//
//  PerspectiveTests.swift
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
final class PerspectiveTests: XCTestCase {
    private let owner = UUID()
    private let invitee = UUID()
    private var containers: [ModelContainer] = []

    func testTheOwnersOwnMatchIsSeenFromSideAAndIsEditable() throws {
        let record = try ownedMatch().record

        XCTAssertEqual(record.mySide, .a)
        XCTAssertEqual(record.opponentNames, "Reyes")
        XCTAssertFalse(record.isReadOnly)
    }

    func testAPulledLinkedMatchIsSeenFromTheInviteesSideAndIsReadOnly() async throws {
        let remote = FakeMatchRemote()
        try await remote.upsert(ownedMatch().record)
        let device = try repository(remote: remote)

        try await device.sync(as: invitee)

        let copy = try XCTUnwrap(device.fetch().first)
        XCTAssertEqual(copy.localUserSlot, .b1)
        XCTAssertEqual(copy.perspective(for: invitee), .b)
        XCTAssertEqual(copy.record.mySide, .b)
        XCTAssertEqual(copy.record.opponentNames, "Musa")
        XCTAssertTrue(copy.record.isReadOnly)
    }

    func testALinkedMatchIsNeverUploadedByTheInvitee() async throws {
        let remote = FakeMatchRemote()
        try await remote.upsert(ownedMatch().record)
        let device = try repository(remote: remote)
        try await device.sync(as: invitee)
        let before = await remote.upsertCount

        let copy = try XCTUnwrap(device.fetch().first)
        copy.status = .abandoned
        try device.save(copy)
        try device.delete(copy)
        try await device.sync(as: invitee)

        let after = await remote.upsertCount
        let rows = await remote.rows
        XCTAssertEqual(after, before)
        XCTAssertEqual(rows.count, 1)
    }

    private func ownedMatch() throws -> Match {
        let match = Match.sample()
        match.ownerID = owner
        match.players.first { $0.slot == .a1 }?.userID = owner
        match.players.first { $0.slot == .a1 }?.linkStatus = .accepted
        match.players.first { $0.slot == .b1 }?.userID = invitee
        match.players.first { $0.slot == .b1 }?.linkStatus = .accepted
        return match
    }

    private func repository(remote: FakeMatchRemote) throws -> SyncingMatchRepository {
        let container = try InMemoryModelContainer()
        containers.append(container)
        return SyncingMatchRepository(context: container.mainContext, remote: remote)
    }
}
