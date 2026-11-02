//
//  SyncCoordinatorTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import SwiftData
import XCTest

import ChairKit
import ChairTestSupport
import Supabase

@MainActor
final class SyncCoordinatorTests: XCTestCase {
    private var containers: [ModelContainer] = []

    func testOfflineEventsStayPendingThenDrainWhenTheNetworkReturns() async throws {
        let remote = FakeMatchRemote()
        let network = FakeNetworkMonitor(online: false)
        let repository = try repository(remote: remote)
        let coordinator = SyncCoordinator(repository: repository, auth: FakeAuthService(signedIn: true), network: network)
        coordinator.start()
        defer { coordinator.stop() }

        let match = try scoredMatch(points: 12)
        try repository.save(match)
        await coordinator.syncNow()

        XCTAssertTrue(match.points.allSatisfy { $0.syncState == .pendingUpload })
        XCTAssertEqual(coordinator.pendingCount, 1 + match.players.count + match.points.count)
        let offlineRows = await remote.rows
        XCTAssertTrue(offlineRows.isEmpty)

        network.setOnline(true)
        try await waitUntil { coordinator.pendingCount == 0 }

        let rows = await remote.rows
        XCTAssertEqual(rows[match.remoteID]?.points.count, 12)
        XCTAssertNotNil(coordinator.lastSyncedAt)
    }

    func testWithoutASessionNothingSyncs() async throws {
        let remote = FakeMatchRemote()
        let repository = try repository(remote: remote)
        let coordinator = SyncCoordinator(repository: repository, auth: FakeAuthService(signedIn: false), network: FakeNetworkMonitor())
        try repository.save(scoredMatch(points: 3))

        coordinator.start()
        defer { coordinator.stop() }
        await coordinator.syncNow()

        let upserts = await remote.upsertCount
        XCTAssertEqual(upserts, 0)
        XCTAssertNil(coordinator.lastSyncedAt)
        XCTAssertGreaterThan(coordinator.pendingCount, 0)
    }

    func testWithoutASessionNoRequestLeavesTheApp() async throws {
        RecordingURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingURLProtocol.self]
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1:9"))
        let client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: "anon",
            options: SupabaseClientOptions(
                auth: .init(storage: InMemoryAuthStorage(), autoRefreshToken: false, emitLocalSessionAsInitialSession: true),
                global: .init(session: URLSession(configuration: configuration))
            )
        )
        let repository = try repository(remote: SupabaseMatchRemote(client: client))
        try repository.save(scoredMatch(points: 3))
        let coordinator = SyncCoordinator(repository: repository, auth: SupabaseAuthService(client: client), network: FakeNetworkMonitor())

        coordinator.start()
        defer { coordinator.stop() }
        await coordinator.syncNow()
        try await Task.sleep(for: .milliseconds(200))

        XCTAssertEqual(RecordingURLProtocol.requests, [])
        XCTAssertNil(coordinator.lastSyncedAt)
    }

    func testANewerRemotePointReplacesAPendingOneAndAnOlderOneDoesNot() throws {
        let match = try scoredMatch(points: 2)
        let local = try XCTUnwrap(match.orderedPoints.last)
        local.updatedAt = Fixtures.matchDay.addingTimeInterval(10)
        var record = match.record
        record.updatedAt = Fixtures.matchDay.addingTimeInterval(20)
        record.points[1].undone = true
        record.points[1].updatedAt = Fixtures.matchDay.addingTimeInterval(5)
        let container = try InMemoryModelContainer()
        containers.append(container)
        container.mainContext.insert(match)

        match.apply(record, in: container.mainContext)
        XCTAssertFalse(local.undone)

        record.points[1].updatedAt = Fixtures.matchDay.addingTimeInterval(30)
        match.apply(record, in: container.mainContext)
        XCTAssertTrue(local.undone)
        XCTAssertEqual(local.syncState, .synced)
    }

    func testMatchesUsedCountsCompletedAndAbandoned() throws {
        let container = try InMemoryModelContainer()
        containers.append(container)
        let repository = LocalMatchRepository(context: container.mainContext)
        for status in [MatchStatus.completed, .abandoned, .inProgress, .completed] {
            let day = Fixtures.matchDay
            try repository.save(Match(playedAt: day, format: .singles, status: status, createdAt: day, updatedAt: day))
        }

        XCTAssertEqual(try repository.matchesUsed(), 3)
    }

    private func repository(remote: any MatchRemote) throws -> SyncingMatchRepository {
        let container = try InMemoryModelContainer()
        containers.append(container)
        return SyncingMatchRepository(context: container.mainContext, remote: remote)
    }

    private func scoredMatch(points: Int) throws -> Match {
        let match = Match(playedAt: Fixtures.matchDay, format: .singles, createdAt: Fixtures.matchDay, updatedAt: Fixtures.matchDay)
        match.players = [MatchPlayer.sample(.a1, name: "Aaron"), MatchPlayer.sample(.b1, name: "Juan")]
        var log = try MatchLog(rules: MatchRules())
        for index in 0 ..< points {
            try log.append(TimedEvent(.pointWon(by: index.isMultiple(of: 3) ? .b : .a, outcome: nil, ending: nil), at: Fixtures.matchDay))
        }
        match.update(from: log, at: Fixtures.matchDay)
        return match
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0 ..< 100 where !condition() {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(condition())
    }
}

class RecordingURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var recorded: [String] = []

    static var requests: [String] {
        lock.withLock { recorded }
    }

    static func reset() {
        lock.withLock { recorded = [] }
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.withLock { Self.recorded.append(request.url?.absoluteString ?? "") }
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}
