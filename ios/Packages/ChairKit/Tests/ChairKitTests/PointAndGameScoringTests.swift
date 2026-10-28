//
//  PointAndGameScoringTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/28/26.
//

import XCTest

import ChairKit

final class PointAndGameScoringTests: XCTestCase {
    func testFourStraightPointsWinTheGameWithServerFirstCalls() throws {
        let (state, calls) = try play([.a, .a, .a, .a])

        XCTAssertEqual(state.currentSet, SetScore(a: 1, b: 0))
        XCTAssertEqual(state.currentGame, .loveAll)
        XCTAssertEqual(calls, [
            .score(a: .fifteen, b: .love, serverSide: .a),
            .score(a: .thirty, b: .love, serverSide: .a),
            .score(a: .forty, b: .love, serverSide: .a),
            .game(.a),
            .changeEnds,
        ])
    }

    func testAdvantageLostReturnsToDeuce() throws {
        let (state, calls) = try play([.a, .a, .a, .b, .b, .b, .a, .b])

        XCTAssertEqual(state.currentGame, .standard(a: .forty, b: .forty))
        XCTAssertEqual(calls.suffix(3), [.deuce, .advantage(.a), .deuce])
    }

    func testAdvantageThenPointWinsTheGame() throws {
        let (state, calls) = try play([.a, .a, .a, .b, .b, .b, .b, .b])

        XCTAssertEqual(state.currentSet, SetScore(a: 0, b: 1))
        XCTAssertEqual(calls.suffix(3), [.advantage(.b), .game(.b), .changeEnds])
    }

    func testNoAdDecidingPointWinsTheGame() throws {
        let rules = MatchRules(deuce: .noAd)
        let (atDeuce, deuceCalls) = try play([.a, .a, .a, .b, .b, .b], rules: rules)
        XCTAssertEqual(deuceCalls.suffix(2), [.deuce, .receiverChoosesSide])

        let (state, calls) = try ScoringEngine.apply(.pointWon(by: .b, outcome: nil, ending: nil), to: atDeuce)

        XCTAssertEqual(state.currentSet, SetScore(a: 0, b: 1))
        XCTAssertEqual(calls, [.game(.b), .changeEnds])
    }

    func testAPointOnACompleteMatchThrowsAndChangesNothing() {
        var complete = MatchState.initial(rules: MatchRules())
        complete.phase = .complete(winner: .a)

        XCTAssertThrowsError(try ScoringEngine.apply(.pointWon(by: .b, outcome: nil, ending: nil), to: complete)) { error in
            XCTAssertEqual(error as? EngineError, .matchOver)
        }
        XCTAssertEqual(complete.phase, .complete(winner: .a))
    }

    func testTheFirstPointStartsTheMatch() throws {
        let (state, _) = try play([.b])

        XCTAssertEqual(state.phase, .inProgress)
    }

    func testScoresReadServerFirst() throws {
        let (_, serverLeads) = try play([.a], rules: MatchRules(firstServer: .a))
        let (_, receiverLeads) = try play([.b], rules: MatchRules(firstServer: .a))
        let (_, bServing) = try play([.a], rules: MatchRules(firstServer: .b))

        XCTAssertEqual(serverLeads.first?.serverFirstScores?.server, .fifteen)
        XCTAssertEqual(serverLeads.first?.serverFirstScores?.receiver, .love)
        XCTAssertEqual(receiverLeads.first?.serverFirstScores?.server, .love)
        XCTAssertEqual(receiverLeads.first?.serverFirstScores?.receiver, .fifteen)
        XCTAssertEqual(bServing.first?.serverFirstScores?.server, .love)
        XCTAssertEqual(bServing.first?.serverFirstScores?.receiver, .fifteen)
    }

    func testEventsNotYetHandledAreRefused() {
        let state = MatchState.initial(rules: MatchRules())

        XCTAssertThrowsError(try ScoringEngine.apply(.undo, to: state)) { error in
            XCTAssertEqual(error as? EngineError, .unsupported(.undo))
        }
    }

    private func play(
        _ winners: [Side],
        rules: MatchRules = MatchRules()
    ) throws -> (MatchState, [Announcement]) {
        var state = MatchState.initial(rules: rules)
        var calls: [Announcement] = []
        for winner in winners {
            let (next, announced) = try ScoringEngine.apply(.pointWon(by: winner, outcome: nil, ending: nil), to: state)
            state = next
            calls += announced
        }
        return (state, calls)
    }
}
