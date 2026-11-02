//
//  ScoreFixTests.swift
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
final class ScoreFixTests: XCTestCase {
    private var container: ModelContainer!
    private var repository: LocalMatchRepository!

    override func setUp() async throws {
        try await super.setUp()
        container = try InMemoryModelContainer()
        repository = LocalMatchRepository(context: container.mainContext, clock: FixedClock(Fixtures.matchDay))
    }

    func testFixingTwoThreeToThreeAllReadsCorrection() async throws {
        let viewModel = try makeViewModel()
        for winner in [Side.b, .a, .b, .a, .b] {
            await game(for: winner, viewModel)
        }
        XCTAssertEqual(viewModel.scoreboard?.rows.map(\.games), [[2], [3]])
        var draft = try ScoreFixDraft(state: XCTUnwrap(viewModel.state))
        draft.currentSet = SetScore(a: 3, b: 3)
        draft.server = .a1

        let error = await viewModel.fixScore(draft.snapshot)

        XCTAssertNil(error)
        XCTAssertEqual(viewModel.scoreboard?.rows.map(\.games), [[3], [3]])
        XCTAssertEqual(viewModel.announcementText, "Correction")
    }

    func testSwapSidesReadsChangeEndsAndFlipsTheEnds() async throws {
        let viewModel = try makeViewModel()
        let before = try XCTUnwrap(viewModel.state?.ends)

        await viewModel.apply(.swapEnds)

        XCTAssertEqual(viewModel.announcementText, "Change ends")
        XCTAssertEqual(viewModel.state?.ends[.a], before[.b])
        XCTAssertEqual(viewModel.state?.ends[.b], before[.a])
    }

    func testAdvantageUnderNoAdIsRefusedInlineAndNothingChanges() async throws {
        let viewModel = try makeViewModel(MatchDefaults(deuce: .noAd))
        let before = viewModel.state
        var draft = try ScoreFixDraft(state: XCTUnwrap(before))
        draft.pointsA = .advantage
        draft.pointsB = .forty

        let error = await viewModel.fixScore(draft.snapshot)

        XCTAssertEqual(error, "Advantage is not allowed under no-ad rules")
        XCTAssertEqual(viewModel.state, before)
    }

    func testSixAllIsATiebreakToSevenAndTheDecidingSetToTen() {
        var draft = ScoreFixDraft(state: .initial(rules: MatchRules(finalSet: .tiebreak10)))
        XCTAssertFalse(draft.isTiebreak)

        draft.currentSet = SetScore(a: 6, b: 6)
        XCTAssertEqual(draft.snapshot.currentGame, .tiebreak(a: 0, b: 0, target: 7))

        draft.sets = [SetScore(a: 6, b: 4), SetScore(a: 4, b: 6)]
        XCTAssertEqual(draft.snapshot.currentGame, .tiebreak(a: 0, b: 0, target: 10))
    }

    func testAnAdvantageFinalSetHasNoTiebreak() {
        var draft = ScoreFixDraft(state: .initial(rules: MatchRules(finalSet: .advantage)))
        draft.sets = [SetScore(a: 6, b: 4), SetScore(a: 4, b: 6)]
        draft.currentSet = SetScore(a: 6, b: 6)

        XCTAssertFalse(draft.isTiebreak)
    }

    private func makeViewModel(_ defaults: MatchDefaults = MatchDefaults()) throws -> MatchSessionViewModel {
        var setup = NewMatchSetup(defaults: MatchDefaults(
            sets: defaults.sets,
            deuce: defaults.deuce,
            finalSet: defaults.finalSet,
            playerName: "Aaron"
        ))
        setup.names[.b1] = "Juan"
        let match = try setup.makeMatch(at: Fixtures.matchDay)
        try repository.save(match)
        let viewModel = MatchSessionViewModel(
            matchID: match.remoteID,
            repository: repository,
            clock: FixedClock(Fixtures.matchDay),
            asksHowPointEnded: false
        )
        viewModel.load()
        return viewModel
    }

    private func game(
        for side: Side,
        _ viewModel: MatchSessionViewModel
    ) async {
        for _ in 0 ..< 4 {
            await viewModel.pointWon(by: side)
        }
    }
}
