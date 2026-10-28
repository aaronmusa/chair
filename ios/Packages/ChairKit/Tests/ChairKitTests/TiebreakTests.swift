//
//  TiebreakTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/28/26.
//

import XCTest

import ChairKit

final class TiebreakTests: XCTestCase {
    func testWinningSevenFiveTakesTheSetAndRecordsTheTiebreak() throws {
        var state = tiebreak()
        for winner: Side in [.a, .b, .a, .b, .a, .b, .a, .b, .a, .b, .a, .a] {
            state = try point(winner, state).0
        }

        XCTAssertEqual(state.sets, [SetScore(a: 7, b: 6)])
        XCTAssertEqual(state.summary, [SetSummary(a: 7, b: 6, tiebreak: TiebreakSummary(a: 7, b: 5))])
        XCTAssertEqual(state.currentGame, .loveAll)
    }

    func testSixPointsAllNeedsATwoPointLead() throws {
        var state = tiebreak()
        state.currentGame = .tiebreak(a: 6, b: 6, target: 7)

        let (next, calls) = try point(.a, state)

        XCTAssertEqual(next.currentGame, .tiebreak(a: 7, b: 6, target: 7))
        XCTAssertTrue(next.sets.isEmpty)
        XCTAssertEqual(calls.first, .tiebreakScore(a: 7, b: 6, serverSide: next.server.side))
    }

    func testServiceAlternatesAfterTheFirstPointThenEveryTwo() throws {
        var state = tiebreak()
        var servers = [(state.server, state.serverCourtSide)]
        for winner: Side in [.a, .b, .a, .b] {
            state = try point(winner, state).0
            servers.append((state.server, state.serverCourtSide))
        }

        XCTAssertEqual(servers.map(\.0), [.a1, .b1, .b1, .a1, .a1])
        XCTAssertEqual(servers.map(\.1), [.deuce, .ad, .deuce, .ad, .deuce])
    }

    func testAfterThreePointsTheFirstServerServesFromTheAdSide() throws {
        var state = tiebreak()
        for winner: Side in [.a, .b, .b] {
            state = try point(winner, state).0
        }

        XCTAssertEqual(state.server, .a1)
        XCTAssertEqual(state.serverCourtSide, .ad)
    }

    func testEndsChangeAfterSixPoints() throws {
        var state = tiebreak()
        var changes = 0
        for winner: Side in [.a, .b, .a, .b, .a, .b] {
            let (next, calls) = try point(winner, state)
            state = next
            changes += calls.count(where: { $0 == .changeEnds })
        }

        XCTAssertEqual(changes, 1)
        XCTAssertEqual(state.ends, [.a: .far, .b: .near])
    }

    func testTheTiebreaksFirstReceiverServesTheNextSet() throws {
        var state = tiebreak()
        for _ in 0 ..< 7 {
            state = try point(.a, state).0
        }

        XCTAssertEqual(state.sets, [SetScore(a: 7, b: 6)])
        XCTAssertEqual(state.server, .b1)
        XCTAssertEqual(state.receiver, .a1)
        XCTAssertEqual(state.serverCourtSide, .deuce)
    }

    func testDoublesTiebreakFollowsTheSetsServingOrder() throws {
        var state = tiebreak(format: .doubles)
        var servers = [state.server]
        for winner: Side in [.a, .b, .a, .b, .a] {
            state = try point(winner, state).0
            servers.append(state.server)
        }

        XCTAssertEqual(servers, [.a1, .b1, .b1, .a2, .a2, .b2])
    }

    private func tiebreak(format: MatchFormat = .singles) -> MatchState {
        var state = MatchState.initial(rules: MatchRules(firstServer: .a), format: format)
        state.phase = .inProgress
        state.currentSet = SetScore(a: 6, b: 6)
        state.currentGame = .tiebreak(a: 0, b: 0, target: 7)
        return state
    }

    private func point(
        _ winner: Side,
        _ state: MatchState
    ) throws -> (MatchState, [Announcement]) {
        try ScoringEngine.apply(.pointWon(by: winner, outcome: nil, ending: nil), to: state)
    }
}
