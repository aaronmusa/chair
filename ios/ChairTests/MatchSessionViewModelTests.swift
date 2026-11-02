//
//  MatchSessionViewModelTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftData
import XCTest

import ChairKit
import ChairTestSupport

@testable import Chair

@MainActor
final class MatchSessionViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: LocalMatchRepository!
    private var matchID: UUID!

    override func setUp() async throws {
        try await super.setUp()
        container = try InMemoryModelContainer()
        repository = LocalMatchRepository(context: container.mainContext, clock: FixedClock(Fixtures.matchDay))
        var setup = NewMatchSetup(defaults: MatchDefaults(playerName: "Aaron"))
        setup.names[.b1] = "Juan"
        let match = try setup.makeMatch(at: Fixtures.matchDay)
        try repository.save(match)
        matchID = match.remoteID
    }

    func testItLoadsTheMatchOnGetSetAtLoveAll() {
        let viewModel = makeViewModel()

        viewModel.load()

        XCTAssertEqual(viewModel.phase, .getSet)
        XCTAssertEqual(viewModel.announcementText, "Love–all")
        XCTAssertEqual(viewModel.name(of: .a), "Aaron")
    }

    func testAPointForAaronReadsFifteenLoveIsSavedAndReturnsToGetSet() async throws {
        let viewModel = makeViewModel()
        viewModel.load()
        viewModel.playPoint()
        XCTAssertEqual(viewModel.phase, .rally)

        await viewModel.pointWon(by: .a)

        XCTAssertEqual(viewModel.phase, .getSet)
        XCTAssertEqual(viewModel.scoreboard?.rows.map(\.points), ["15", "0"])
        XCTAssertEqual(viewModel.announcementText, "Fifteen–love")
        let saved = try XCTUnwrap(repository.fetch().first)
        XCTAssertEqual(saved.points.count, 1)
        XCTAssertEqual(saved.points.first?.winnerSide, .a)
    }

    func testReopeningTheMatchRestoresTheScoreFromTheSavedLog() async {
        let first = makeViewModel()
        first.load()
        await first.pointWon(by: .a)
        await first.pointWon(by: .b)
        await first.pointWon(by: .a)

        let reopened = MatchSessionViewModel(
            matchID: matchID,
            repository: LocalMatchRepository(context: container.mainContext, clock: FixedClock(Fixtures.matchDay)),
            clock: FixedClock(Fixtures.matchDay),
            asksHowPointEnded: false
        )
        reopened.load()

        XCTAssertEqual(reopened.scoreboard?.rows.map(\.points), ["30", "15"])
        XCTAssertEqual(reopened.state, first.state)
    }

    func testUndoLastRemovesThePoint() async {
        let viewModel = makeViewModel()
        viewModel.load()
        await viewModel.pointWon(by: .a)

        await viewModel.apply(.undo)

        XCTAssertEqual(viewModel.scoreboard?.rows.map(\.points), ["0", "0"])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testUndoWithNothingToUndoShowsAMessage() async {
        let viewModel = makeViewModel()
        viewModel.load()

        await viewModel.apply(.undo)

        XCTAssertEqual(viewModel.errorMessage, "Nothing to undo in this set.")
    }

    func testAnUnknownMatchFailsToLoad() {
        let viewModel = MatchSessionViewModel(matchID: UUID(), repository: repository, clock: FixedClock(Fixtures.matchDay))

        viewModel.load()

        XCTAssertEqual(viewModel.phase, .failed("This match couldn't be found."))
    }

    func testTheScoreboardLabelsTheSetAndGame() async {
        let viewModel = makeViewModel()
        viewModel.load()
        for _ in 0 ..< 4 {
            await viewModel.pointWon(by: .a)
        }

        XCTAssertEqual(viewModel.scoreboard?.setLabel, "Set 1 · Game 2")
        XCTAssertEqual(viewModel.scoreboard?.rows.map(\.games), [[1], [0]])
        XCTAssertEqual(viewModel.scoreboard?.rows.map(\.isServing), [false, true])
    }

    func testWhenAskingAPointWaitsForItsOutcome() async throws {
        let viewModel = makeViewModel(asking: true)
        viewModel.load()

        await viewModel.pointWon(by: .a)
        XCTAssertEqual(viewModel.pendingPoint, .a)
        XCTAssertTrue(try XCTUnwrap(repository.fetch().first).points.isEmpty)

        await viewModel.recordPendingPoint(outcome: .winner, ending: .net)

        XCTAssertNil(viewModel.pendingPoint)
        let saved = try XCTUnwrap(repository.fetch().first?.points.first)
        XCTAssertEqual(saved.outcome, .winner)
        XCTAssertEqual(viewModel.pointLog.map(\.ending), [.net])
    }

    func testWithAskingOffThePointIsLoggedWithNoOutcome() async throws {
        let viewModel = makeViewModel(asking: false)
        viewModel.load()

        await viewModel.pointWon(by: .b)

        XCTAssertNil(viewModel.pendingPoint)
        XCTAssertEqual(viewModel.pointLog.map(\.winner), [.b])
        XCTAssertNil(try XCTUnwrap(repository.fetch().first?.points.first).outcome)
    }

    func testFlippingPointTwoSwapsOnlyItsWinner() async throws {
        let viewModel = makeViewModel()
        viewModel.load()
        await viewModel.pointWon(by: .a)
        await viewModel.pointWon(by: .a)
        await viewModel.pointWon(by: .b)
        let second = try XCTUnwrap(viewModel.pointLog.dropFirst().first)

        await viewModel.flip(pointIndex: second.index)

        XCTAssertEqual(viewModel.pointLog.map(\.winner), [.a, .b, .b])
        XCTAssertEqual(viewModel.scoreboard?.rows.map(\.points), ["15", "30"])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testFlippingAnAceShowsAnAlertAndLeavesTheLog() async {
        let viewModel = makeViewModel(asking: true)
        viewModel.load()
        await viewModel.pointWon(by: .a)
        await viewModel.recordPendingPoint(outcome: .ace, ending: nil)
        let before = viewModel.log

        await viewModel.flip(pointIndex: 0)

        XCTAssertEqual(viewModel.log, before)
        XCTAssertEqual(viewModel.errorMessage, "An ace or double fault can't change hands. Undo the point and enter it again.")
    }

    func testAPointForTheReceiverDisablesAceAndEnablesDoubleFault() {
        let viewModel = makeViewModel()
        viewModel.load()

        let serverWinning = viewModel.isServer(.b)

        XCTAssertFalse(OutcomeSheet.isEnabled(.ace, serverWinning: serverWinning))
        XCTAssertTrue(OutcomeSheet.isEnabled(.doubleFault, serverWinning: serverWinning))
        XCTAssertTrue(OutcomeSheet.isEnabled(.winner, serverWinning: serverWinning))
    }

    private func makeViewModel(asking: Bool = false) -> MatchSessionViewModel {
        MatchSessionViewModel(
            matchID: matchID,
            repository: repository,
            clock: FixedClock(Fixtures.matchDay),
            asksHowPointEnded: asking
        )
    }
}
