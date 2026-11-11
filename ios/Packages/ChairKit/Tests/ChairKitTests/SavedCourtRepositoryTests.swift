//
//  SavedCourtRepositoryTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/11/26.
//

import Foundation
import SwiftData
import XCTest

import ChairKit
import ChairTestSupport
import Supabase

@MainActor
final class SavedCourtRepositoryTests: XCTestCase {
    private let me = UUID()
    private var containers: [ModelContainer] = []

    func testACourtKeepsItsCalibrationAfterARefetch() throws {
        let container = try InMemoryModelContainer()
        let court = Self.court(name: "Riverside 3")
        try LocalSavedCourtRepository(context: container.mainContext).save(court)

        let refetched = try XCTUnwrap(LocalSavedCourtRepository(context: ModelContext(container)).fetch().first)

        XCTAssertEqual(refetched.name, "Riverside 3")
        XCTAssertEqual(refetched.placement, "netPost")
        XCTAssertEqual(refetched.calibration, court.calibration)
        XCTAssertEqual(refetched.calibration?.keypoints.count, 8)
    }

    func testACourtWrittenOfflineUploadsWhenTheDeviceIsOnline() async throws {
        let remote = FakeSavedCourtRemote()
        await remote.setOnline(false)
        let device = try device(remote: remote)
        let court = Self.court(name: "Home")

        try device.save(court)
        do {
            try await device.sync(as: me)
            XCTFail("sync should fail while offline")
        } catch {}
        XCTAssertEqual(try device.pendingCount(), 1)

        await remote.setOnline(true)
        try await device.sync(as: me)

        let stored = await remote.rows[court.remoteID]
        XCTAssertEqual(stored?.name, "Home")
        XCTAssertEqual(stored?.ownerID, me)
        XCTAssertEqual(stored?.calibration, court.calibration)
        XCTAssertEqual(try device.pendingCount(), 0)
    }

    func testTheNewerEditWinsOnBothDevices() async throws {
        let remote = FakeSavedCourtRemote()
        let first = try device(remote: remote, clock: FixedClock(Fixtures.matchDay.addingTimeInterval(60)))
        let second = try device(remote: remote, clock: FixedClock(Fixtures.matchDay.addingTimeInterval(120)))
        let court = Self.court(name: "Court 1")
        try first.save(court)
        try await first.sync(as: me)
        try await second.sync(as: me)

        let copy = try XCTUnwrap(second.fetch().first)
        copy.name = "Riverside 3"
        try second.save(copy)
        court.name = "Older edit"
        try first.save(court)
        try await second.sync(as: me)
        try await first.sync(as: me)
        try await second.sync(as: me)

        XCTAssertEqual(try first.fetch().map(\.name), ["Riverside 3"])
        XCTAssertEqual(try second.fetch().map(\.name), ["Riverside 3"])
        let stored = await remote.rows[court.remoteID]
        XCTAssertEqual(stored?.name, "Riverside 3")
    }

    func testADeleteIsATombstoneUntilItSyncsThenLeavesTheOtherDevice() async throws {
        let remote = FakeSavedCourtRemote()
        let first = try device(remote: remote)
        let second = try device(remote: remote)
        let court = Self.court(name: "Home")
        try first.save(court)
        try await first.sync(as: me)
        try await second.sync(as: me)

        try first.delete(court)

        XCTAssertTrue(try first.fetch().isEmpty)
        XCTAssertEqual(try first.pendingCount(), 1)
        let stillStored = await remote.rows[court.remoteID]
        XCTAssertNotNil(stillStored)
        try await first.sync(as: me)
        try await second.sync(as: me)
        let stored = await remote.rows[court.remoteID]
        XCTAssertNil(stored)
        XCTAssertTrue(try second.fetch().isEmpty)
    }

    func testAnotherAccountNeverSeesTheFirstAccountsCourts() async throws {
        let remote = FakeSavedCourtRemote()
        let device = try device(remote: remote)
        try device.save(Self.court(name: "Home"))
        try await device.sync(as: me)
        await remote.setOnline(false)

        do {
            try await device.sync(as: UUID())
        } catch {}

        XCTAssertTrue(try device.fetch().isEmpty)
    }

    func testReplacingTheLocalDataOnAnAccountSwitchClearsSavedCourts() throws {
        let container = try InMemoryModelContainer()
        containers.append(container)
        let courts = SyncingSavedCourtRepository(context: container.mainContext, remote: FakeSavedCourtRemote())
        let migration = AccountMigration(
            repository: SyncingMatchRepository(context: container.mainContext, remote: FakeMatchRemote()),
            store: InMemoryAccountStore(lastUserID: me),
            courts: courts
        )
        try courts.save(Self.court(name: "Home"))

        try migration.replace(for: UUID())

        XCTAssertTrue(try courts.fetch().isEmpty)
    }

    func testTheFakeRepositoryPublishesItsCourts() async throws {
        let repository = FakeSavedCourtRepository()
        var updates = repository.observe().makeAsyncIterator()
        let first = await updates.next()
        XCTAssertEqual(first?.count, 0)

        try repository.save(Self.court(name: "Home"))

        let second = await updates.next()
        XCTAssertEqual(second?.map(\.name), ["Home"])
        try repository.clearLocal()
        XCTAssertTrue(try repository.fetch().isEmpty)
    }

    func testTwoDevicesSignedInAsTheSeedUserShareASavedCourt() async throws {
        let first = try await SupabaseMatchRemoteTests.client(signedInAs: "test@chair.local")
        let second = try await SupabaseMatchRemoteTests.client(signedInAs: "test@chair.local")
        let userID = try XCTUnwrap(first.auth.currentUser?.id)
        let firstDevice = try device(remote: SupabaseSavedCourtRemote(client: first))
        let secondDevice = try device(remote: SupabaseSavedCourtRemote(client: second))
        let court = Self.court(name: "Riverside \(Int.random(in: 1 ... 999))")
        court.latitude = -33.86
        court.longitude = 151.21

        try firstDevice.save(court)
        try await firstDevice.sync(as: userID)
        try await secondDevice.sync(as: userID)

        let copy = try XCTUnwrap(secondDevice.fetch().first { $0.remoteID == court.remoteID })
        XCTAssertEqual(copy.name, court.name)
        XCTAssertEqual(copy.calibration?.keypoints, court.calibration?.keypoints)
        XCTAssertEqual(copy.latitude, -33.86)
        XCTAssertNil(copy.thumbnailFile)

        try firstDevice.delete(court)
        try await firstDevice.sync(as: userID)
        try await secondDevice.sync(as: userID)
        XCTAssertNil(try secondDevice.fetch().first { $0.remoteID == court.remoteID })
    }

    private func device(
        remote: any SavedCourtRemote,
        clock: any ClockProvider = FixedClock(Fixtures.matchDay)
    ) throws -> SyncingSavedCourtRepository {
        let container = try InMemoryModelContainer()
        containers.append(container)
        return SyncingSavedCourtRepository(context: container.mainContext, remote: remote, clock: clock)
    }

    static func court(name: String) -> SavedCourt {
        let camera = PinholeCamera.netPost
        let calibration = CourtCalibration(
            keypoints: camera.keypoints(CameraPlacement.netPost.keypoints),
            placement: .netPost,
            frameSize: camera.size,
            date: Fixtures.matchDay
        )
        return SavedCourt(name: name, calibration: calibration!, createdAt: Fixtures.matchDay, updatedAt: Fixtures.matchDay)
    }
}
