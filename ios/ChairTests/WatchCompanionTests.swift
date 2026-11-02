//
//  WatchCompanionTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftData
import XCTest

import ChairKit
import ChairTestSupport

@testable import Chair

@MainActor
final class WatchCompanionTests: XCTestCase {
    private struct Subject {
        let companion: WatchCompanion
        let router: AppRouter
        let repository: LocalMatchRepository
        let session: FakeWCSession
    }

    private var container: ModelContainer?

    func testNewMatchFromTheWatchWaitsForTheNextForeground() async throws {
        let subject = try makeSubject()

        await subject.companion.handle(.openNewMatch)

        XCTAssertEqual(subject.router.pendingRoute, .newMatch)
        XCTAssertTrue(subject.router.playPath.isEmpty)

        subject.router.applyPendingRoute()

        XCTAssertEqual(subject.router.playPath, [.newMatch])
        XCTAssertEqual(subject.router.selectedSection, .play)
        XCTAssertNil(subject.router.pendingRoute)
    }

    func testNewMatchOpensRightAwayWhenChairIsInFront() async throws {
        let subject = try makeSubject()
        subject.companion.isActive = true

        await subject.companion.handle(.openNewMatch)

        XCTAssertEqual(subject.router.playPath, [.newMatch])
        XCTAssertNil(subject.router.pendingRoute)
    }

    func testAnInProgressMatchIsSentWithItsScore() throws {
        let subject = try makeSubject()
        let match = Match.sample()
        try subject.repository.save(match)

        guard case let .state(state) = subject.companion.currentState() else {
            return XCTFail("expected a state")
        }

        XCTAssertEqual(state.matchID, match.remoteID)
        XCTAssertEqual(state.title, "Musa v Reyes")
        XCTAssertEqual(state.pointsLine, "30–15")
        XCTAssertEqual(state.phase, .rally)
    }

    func testWithNoLiveMatchTheLastResultIsSent() throws {
        let subject = try makeSubject()
        let match = Match.sample()
        match.status = .completed
        match.sets = [SetScore(a: 6, b: 4), SetScore(a: 6, b: 3)]
        try subject.repository.save(match)

        XCTAssertEqual(subject.companion.currentState(), .idle(lastResult: "vs Reyes · 6–4 6–3"))
    }

    func testALinkedMatchTheUserDoesNotOwnIsNeverOffered() throws {
        let subject = try makeSubject()
        let match = Match.sample()
        match.ownerID = UUID()
        match.localUserSlot = .b1
        match.players.first { $0.slot == .b1 }?.userID = UUID()
        try subject.repository.save(match)

        XCTAssertEqual(subject.companion.currentState(), .idle(lastResult: nil))
    }

    func testFinishingTheLiveMatchTellsTheWatchItEnded() async throws {
        let subject = try makeSubject()
        let match = Match.sample()
        try subject.repository.save(match)
        await subject.companion.follow([match.record])
        XCTAssertTrue(subject.session.sent.isEmpty)

        match.status = .completed
        await subject.companion.follow([match.record])

        XCTAssertEqual(subject.session.sent, [.matchEnded])
    }

    private func makeSubject() throws -> Subject {
        let container = try InMemoryModelContainer()
        self.container = container
        let repository = LocalMatchRepository(context: container.mainContext)
        let router = AppRouter()
        let session = FakeWCSession()
        let companion = WatchCompanion(
            link: WatchLink(transport: session),
            router: router,
            repository: repository
        )
        return Subject(companion: companion, router: router, repository: repository, session: session)
    }
}
