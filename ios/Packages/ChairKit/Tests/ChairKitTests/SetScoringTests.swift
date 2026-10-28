//
//  SetScoringTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/28/26.
//

import XCTest

import ChairKit

final class SetScoringTests: XCTestCase {
    func testWinningTheTenthGameAtFiveFourTakesTheSet() throws {
        let (state, calls) = try game(for: .a, from: at(games: (5, 4)))

        XCTAssertEqual(state.sets, [SetScore(a: 6, b: 4)])
        XCTAssertEqual(state.currentSet, SetScore(a: 0, b: 0))
        XCTAssertEqual(calls.suffix(2), [.game(.a), .gameAndSet(.a, SetScore(a: 6, b: 4))])
    }

    func testSixFiveToSixAllStartsASevenPointTiebreak() throws {
        let (state, calls) = try game(for: .b, from: at(games: (6, 5)))

        XCTAssertEqual(state.currentSet, SetScore(a: 6, b: 6))
        XCTAssertEqual(state.currentGame, .tiebreak(a: 0, b: 0, target: 7))
        XCTAssertTrue(state.sets.isEmpty)
        XCTAssertEqual(calls.last, .game(.b))
    }

    func testTheDecidingSetUsesATenPointTiebreak() throws {
        let rules = MatchRules(finalSet: .tiebreak10)
        let (deciding, _) = try game(for: .b, from: at(games: (6, 5), sets: [SetScore(a: 6, b: 3), SetScore(a: 2, b: 6)], rules: rules))
        let (earlier, _) = try game(for: .b, from: at(games: (6, 5), sets: [SetScore(a: 6, b: 3)], rules: rules))

        XCTAssertEqual(deciding.currentGame, .tiebreak(a: 0, b: 0, target: 10))
        XCTAssertEqual(earlier.currentGame, .tiebreak(a: 0, b: 0, target: 7))
    }

    func testAnAdvantageFinalSetPlaysOnToATwoGameLead() throws {
        let rules = MatchRules(finalSet: .advantage)
        let decidingSets = [SetScore(a: 6, b: 3), SetScore(a: 2, b: 6)]
        let (sixAll, _) = try game(for: .b, from: at(games: (6, 5), sets: decidingSets, rules: rules))
        XCTAssertEqual(sixAll.currentGame, .loveAll)

        let (sevenSix, _) = try game(for: .a, from: sixAll)
        XCTAssertEqual(sevenSix.currentSet, SetScore(a: 7, b: 6))
        XCTAssertEqual(sevenSix.phase, .inProgress)

        let (state, calls) = try game(for: .a, from: sevenSix)
        XCTAssertEqual(state.phase, .complete(winner: .a))
        XCTAssertEqual(state.sets.last, SetScore(a: 8, b: 6))
        XCTAssertEqual(calls.last, .gameSetMatch(.a, state.summary))
    }

    func testWinningTheSecondSetFromOneLoveWinsBestOfThree() throws {
        let (state, calls) = try game(for: .a, from: at(games: (5, 2), sets: [SetScore(a: 6, b: 4)]))

        XCTAssertEqual(state.phase, .complete(winner: .a))
        XCTAssertEqual(state.summary, [SetSummary(a: 6, b: 4), SetSummary(a: 6, b: 2)])
        XCTAssertEqual(calls.suffix(2), [.game(.a), .gameSetMatch(.a, [SetSummary(a: 6, b: 4), SetSummary(a: 6, b: 2)])])
    }

    func testBestOfFiveNeedsThreeSets() throws {
        let rules = MatchRules(sets: .bestOf5)
        let (state, calls) = try game(for: .a, from: at(games: (5, 2), sets: [SetScore(a: 6, b: 4)], rules: rules))

        XCTAssertEqual(state.phase, .inProgress)
        XCTAssertEqual(calls.last, .gameAndSet(.a, SetScore(a: 6, b: 2)))
    }

    func testRetiringMidSetEndsTheMatchAndKeepsThePartialSet() throws {
        let (state, calls) = try ScoringEngine.apply(.retire(.b), to: at(games: (3, 2), sets: [SetScore(a: 4, b: 6)]))

        XCTAssertEqual(state.phase, .complete(winner: .a))
        XCTAssertEqual(state.summary, [SetSummary(a: 4, b: 6), SetSummary(a: 3, b: 2)])
        XCTAssertEqual(calls, [.retired(.b)])
    }

    func testSummaryLeavesOutAnUnstartedSet() throws {
        let (state, _) = try game(for: .a, from: at(games: (5, 4)))

        XCTAssertEqual(state.summary, [SetSummary(a: 6, b: 4)])
    }

    private func at(
        games: (Int, Int),
        sets: [SetScore] = [],
        rules: MatchRules = MatchRules()
    ) -> MatchState {
        var state = MatchState.initial(rules: rules)
        state.phase = .inProgress
        state.sets = sets
        state.completedTiebreaks = sets.map { _ in nil }
        state.currentSet = SetScore(a: games.0, b: games.1)
        return state
    }

    private func game(
        for winner: Side,
        from state: MatchState
    ) throws -> (MatchState, [Announcement]) {
        var state = state
        var calls: [Announcement] = []
        for _ in 0 ..< 4 {
            let (next, announced) = try ScoringEngine.apply(.pointWon(by: winner, outcome: nil, ending: nil), to: state)
            state = next
            calls += announced
        }
        return (state, calls)
    }
}
