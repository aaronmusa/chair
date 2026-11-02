//
//  WatchBridgeTests.swift
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
final class WatchBridgeTests: XCTestCase {
    private struct Subject {
        let bridge: WatchBridge
        let router: AppRouter
        let repository: LocalMatchRepository
        let session: FakeWCSession
    }

    private var container: ModelContainer?

    func testNewMatchFromTheWatchWaitsForTheNextForeground() async throws {
        let subject = try makeSubject()

        await subject.bridge.handle(.openNewMatch)

        XCTAssertEqual(subject.router.pendingRoute, .newMatch)
        XCTAssertTrue(subject.router.playPath.isEmpty)

        subject.router.applyPendingRoute()

        XCTAssertEqual(subject.router.playPath, [.newMatch])
        XCTAssertEqual(subject.router.selectedSection, .play)
        XCTAssertNil(subject.router.pendingRoute)
    }

    func testNewMatchOpensRightAwayWhenChairIsInFront() async throws {
        let subject = try makeSubject()
        subject.bridge.isActive = true

        await subject.bridge.handle(.openNewMatch)

        XCTAssertEqual(subject.router.playPath, [.newMatch])
        XCTAssertNil(subject.router.pendingRoute)
    }

    func testAnInProgressMatchIsSentWithItsScore() throws {
        let subject = try makeSubject()
        let match = Match.sample()
        try subject.repository.save(match)

        guard case let .state(state) = subject.bridge.currentState() else {
            return XCTFail("expected a state")
        }

        XCTAssertEqual(state.matchID, match.remoteID)
        XCTAssertEqual(state.title, "Musa v Reyes")
        XCTAssertEqual(state.pointsLine, "30–15")
        XCTAssertEqual(state.phase, .getSet)
    }

    func testWithNoLiveMatchTheLastResultIsSent() throws {
        let subject = try makeSubject()
        let match = Match.sample()
        match.status = .completed
        match.sets = [SetScore(a: 6, b: 4), SetScore(a: 6, b: 3)]
        try subject.repository.save(match)

        XCTAssertEqual(subject.bridge.currentState(), .idle(lastResult: "vs Reyes · 6–4 6–3"))
    }

    func testFinishingTheLiveMatchTellsTheWatchItEnded() async throws {
        let subject = try makeSubject()
        let match = Match.sample()
        try subject.repository.save(match)
        await subject.bridge.follow([match.record])
        XCTAssertTrue(subject.session.sent.isEmpty)

        match.status = .completed
        await subject.bridge.follow([match.record])

        XCTAssertEqual(subject.session.sent, [.matchEnded])
    }

    func testAWatchPointOnTheLiveScreenIsAppliedPersistedAndAcked() async throws {
        let subject = try makeSubject()
        let match = Match.sample()
        try subject.repository.save(match)
        subject.router.presentSession(for: match.remoteID)
        let screen = subject.bridge.session(for: match.remoteID)
        let input = WatchInput(.point(.b), matchID: match.remoteID)

        await subject.bridge.receive(input)

        XCTAssertEqual(screen.scoreboard?.rows.map(\.points), ["30", "30"])
        let stored = try XCTUnwrap(subject.repository.fetch().first?.orderedPoints.last)
        XCTAssertEqual(stored.source, "watch")
        XCTAssertEqual(stored.winnerSide, .b)
        XCTAssertEqual(subject.session.sent, [.ack(inputID: input.id)])
    }

    func testPointsSentWhileInTheBackgroundAreOnTheScreenWhenItOpens() async throws {
        let subject = try makeSubject()
        let match = Match.sample()
        try subject.repository.save(match)
        let sides: [Side] = [.b, .b, .a]

        for side in sides {
            await subject.bridge.receive(WatchInput(.point(side), matchID: match.remoteID))
        }
        subject.router.presentSession(for: match.remoteID)
        let screen = subject.bridge.session(for: match.remoteID)

        XCTAssertTrue(screen === subject.bridge.session)
        XCTAssertEqual(screen.scoreboard?.rows.map(\.points), ["40", "40"])
        let winners = try XCTUnwrap(subject.repository.fetch().first).orderedPoints.suffix(3).map(\.winnerSide)
        XCTAssertEqual(winners, sides)
    }

    func testAWatchPointClosesTheOutcomeSheetAndIsLoggedWithNoOutcome() async throws {
        let subject = try makeSubject()
        let match = Match.sample()
        try subject.repository.save(match)
        subject.router.presentSession(for: match.remoteID)
        let screen = subject.bridge.session(for: match.remoteID)
        await screen.pointWon(by: .a)
        XCTAssertEqual(screen.pendingPoint, .a)

        await subject.bridge.receive(WatchInput(.point(.b), matchID: match.remoteID))

        XCTAssertNil(screen.pendingPoint)
        let stored = try XCTUnwrap(subject.repository.fetch().first?.orderedPoints.last)
        XCTAssertEqual(stored.winnerSide, .b)
        XCTAssertNil(stored.outcome)
    }

    func testAnInputForAnOldMatchIsRefusedAndTheWatchResyncs() async throws {
        let subject = try makeSubject()
        let match = Match.sample()
        try subject.repository.save(match)
        let input = WatchInput(.point(.b), matchID: UUID())

        await subject.bridge.receive(input)

        XCTAssertEqual(try subject.repository.fetch().first?.points.count, 3)
        XCTAssertEqual(subject.session.sent.first, .refused(inputID: input.id))
        guard case let .state(state) = subject.session.sent.last else {
            return XCTFail("expected the current state")
        }
        XCTAssertEqual(state.matchID, match.remoteID)
    }

    func testALinkedMatchTheUserDoesNotOwnIsNeverOfferedAndItsInputsAreRefused() async throws {
        let subject = try makeSubject()
        let match = Match.sample()
        match.ownerID = UUID()
        match.localUserSlot = .b1
        match.players.first { $0.slot == .b1 }?.userID = UUID()
        try subject.repository.save(match)
        let input = WatchInput(.point(.a), matchID: match.remoteID)

        XCTAssertEqual(subject.bridge.currentState(), .idle(lastResult: nil))
        await subject.bridge.receive(input)

        XCTAssertEqual(try subject.repository.fetch().first?.points.count, 3)
        XCTAssertEqual(subject.session.sent, [.refused(inputID: input.id), .idle(lastResult: nil)])
    }

    func testEveryEngineOutputPushesTheStateToTheWatch() async throws {
        let subject = try makeSubject()
        let match = Match.sample()
        try subject.repository.save(match)
        let screen = subject.bridge.session(for: match.remoteID)

        await screen.apply(.fault)
        await screen.apply(.fault)
        for _ in 0 ..< 50 where !subject.session.sent.contains(where: \.isState) {
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(subject.session.sent.count { $0.isState }, 1)
        XCTAssertEqual(subject.session.sent.last, .announcement(text: screen.announcementText))
    }

    private func makeSubject() throws -> Subject {
        let container = try InMemoryModelContainer()
        self.container = container
        let repository = LocalMatchRepository(context: container.mainContext)
        let router = AppRouter()
        let session = FakeWCSession()
        let bridge = WatchBridge(
            link: WatchLink(transport: session),
            router: router,
            repository: repository,
            statePushDelay: .milliseconds(20),
            makeSession: sessionFactory(repository)
        )
        return Subject(bridge: bridge, router: router, repository: repository, session: session)
    }

    private func sessionFactory(_ repository: LocalMatchRepository) -> WatchBridge.SessionFactory {
        { matchID in
            MatchSessionViewModel(matchID: matchID, repository: repository, clock: FixedClock(Fixtures.matchDay))
        }
    }
}

private extension WatchMessage {
    var isState: Bool {
        guard case .state = self else { return false }
        return true
    }
}
