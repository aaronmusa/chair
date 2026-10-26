//
//  MatchRepositoryTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import SwiftData
import XCTest

import ChairKit
import ChairTestSupport

@MainActor
final class MatchRepositoryTests: XCTestCase {
    func testMatchKeepsItsPlayersAndPointsInOrderAfterARefetch() throws {
        let container = try InMemoryModelContainer()
        try LocalMatchRepository(context: container.mainContext).save(Match.sample())

        let refetched = try XCTUnwrap(LocalMatchRepository(context: ModelContext(container)).fetch().first)

        XCTAssertEqual(refetched.orderedPlayers.map(\.name), ["Musa", "Reyes"])
        XCTAssertEqual(refetched.orderedPlayers.map(\.slot), [.a1, .b1])
        XCTAssertEqual(refetched.orderedPoints.map(\.index), [0, 1, 2])
        XCTAssertEqual(refetched.orderedPoints.map(\.outcome), [.ace, .unforcedError, .winner])
        XCTAssertTrue(refetched.orderedPlayers.allSatisfy { $0.match === refetched })
    }

    func testOfflineSaveIsPendingThenUploadsOnceWhenTheNetworkReturns() async throws {
        let remote = FakeMatchRemote()
        await remote.setOnline(false)
        let repository = try device(remote: remote)
        let match = Match.sample()

        try repository.save(match)
        do {
            try await repository.sync()
            XCTFail("sync should fail while offline")
        } catch {}

        XCTAssertEqual(match.syncState, .pendingUpload)
        XCTAssertEqual(try repository.fetch().map(\.remoteID), [match.remoteID])

        await remote.setOnline(true)
        try await repository.sync()
        try await repository.sync()

        XCTAssertEqual(match.syncState, .synced)
        let uploads = await remote.upsertCount
        XCTAssertEqual(uploads, 1)
        let stored = await remote.rows[match.remoteID]
        XCTAssertEqual(stored, match.record)
    }

    func testTheLaterEditWinsAcrossTwoDevicesWithNoDuplicate() async throws {
        let remote = FakeMatchRemote()
        var clockA = FixedClock(Fixtures.matchDay)
        let deviceA = try device(remote: remote, clock: clockA)
        let match = Match.sample()
        try deviceA.save(match)
        try await deviceA.sync()

        let clockB = FixedClock(Fixtures.matchDay.addingTimeInterval(120))
        let deviceB = try device(remote: remote, clock: clockB)
        try await deviceB.sync()
        let copyOnB = try XCTUnwrap(deviceB.fetch().first)

        clockA.advance(by: 60)
        let deviceAEdit = try device(remote: remote, clock: clockA, sharing: deviceA)
        match.status = .abandoned
        try deviceAEdit.save(match)
        copyOnB.status = .completed
        try deviceB.save(copyOnB)

        try await deviceB.sync()
        try await deviceAEdit.sync()
        try await deviceB.sync()

        XCTAssertEqual(match.status, .completed, "device A takes B's later edit")
        XCTAssertEqual(copyOnB.status, .completed)
        let rows = await remote.rows
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[match.remoteID]?.status, .completed)
        XCTAssertEqual(try deviceA.fetch().count, 1)
        XCTAssertEqual(try deviceB.fetch().count, 1)
    }

    func testPendingUploadsSurviveARelaunch() async throws {
        let remote = FakeMatchRemote()
        await remote.setOnline(false)
        let container = try InMemoryModelContainer()
        let match = Match.sample()
        try SyncingMatchRepository(context: container.mainContext, remote: remote).save(match)

        await remote.setOnline(true)
        try await SyncingMatchRepository(context: container.mainContext, remote: remote).sync()

        let uploads = await remote.upsertCount
        XCTAssertEqual(uploads, 1)
    }

    func testDeleteHidesTheMatchAndRemovesItRemotelyOnSync() async throws {
        let remote = FakeMatchRemote()
        let repository = try device(remote: remote)
        let match = Match.sample()
        try repository.save(match)
        try await repository.sync()

        try repository.delete(match)
        XCTAssertTrue(try repository.fetch().isEmpty)

        try await repository.sync()
        let rows = await remote.rows
        XCTAssertTrue(rows.isEmpty)
    }

    func testObserveEmitsTheCurrentMatchesAndEverySave() async throws {
        let container = try InMemoryModelContainer()
        let repository = LocalMatchRepository(context: container.mainContext)
        var iterator = repository.observe().makeAsyncIterator()

        let first = await iterator.next()
        XCTAssertEqual(first?.count, 0)

        try repository.save(Match.sample())
        let second = await iterator.next()
        XCTAssertEqual(second?.count, 1)
    }

    private var containers: [ObjectIdentifier: ModelContainer] = [:]

    private func device(
        remote: FakeMatchRemote,
        clock: FixedClock = FixedClock(Fixtures.matchDay),
        sharing other: SyncingMatchRepository? = nil
    ) throws -> SyncingMatchRepository {
        if let other, let container = containers[ObjectIdentifier(other)] {
            let repository = SyncingMatchRepository(context: container.mainContext, remote: remote, clock: clock)
            containers[ObjectIdentifier(repository)] = container
            return repository
        }
        let container = try InMemoryModelContainer()
        let repository = SyncingMatchRepository(context: container.mainContext, remote: remote, clock: clock)
        containers[ObjectIdentifier(repository)] = container
        return repository
    }
}
