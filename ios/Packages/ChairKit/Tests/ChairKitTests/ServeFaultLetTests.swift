//
//  ServeFaultLetTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/28/26.
//

import XCTest

import ChairKit

final class ServeFaultLetTests: XCTestCase {
    private let start = MatchState.initial(rules: MatchRules(firstServer: .a))

    func testTwoFaultsGiveTheReceiverTheDoubleFaultPoint() throws {
        let (afterFirst, firstCalls) = try ScoringEngine.apply(.fault, to: start)
        XCTAssertEqual(afterFirst.faultCount, 1)
        XCTAssertEqual(firstCalls, [.fault])

        let (state, calls) = try ScoringEngine.apply(.fault, to: afterFirst)

        XCTAssertEqual(state.currentGame, .standard(a: .love, b: .fifteen))
        XCTAssertEqual(state.faultCount, 0)
        XCTAssertEqual(calls, [.doubleFault, .score(a: .love, b: .fifteen, serverSide: .a)])
    }

    func testALetOnSecondServeKeepsTheFault() throws {
        let (afterFault, _) = try ScoringEngine.apply(.fault, to: start)

        let (state, calls) = try ScoringEngine.apply(.let, to: afterFault)

        XCTAssertEqual(calls, [.let(firstServe: false)])
        XCTAssertEqual(state, afterFault)
    }

    func testALetOnFirstServeChangesNothing() throws {
        let (state, calls) = try ScoringEngine.apply(.let, to: start)

        XCTAssertEqual(calls, [.let(firstServe: true)])
        XCTAssertEqual(state, start)
    }

    func testAnyPointResetsTheFaultCount() throws {
        let (afterFault, _) = try ScoringEngine.apply(.fault, to: start)

        let (state, _) = try ScoringEngine.apply(.pointWon(by: .a, outcome: .ace, ending: nil), to: afterFault)

        XCTAssertEqual(state.faultCount, 0)
    }

    func testServeSideFollowsThePointsPlayed() throws {
        var state = start
        var sides: [CourtSide] = [state.serverCourtSide]
        for winner: Side in [.a, .b, .a, .b, .b, .a, .a] {
            state = try ScoringEngine.apply(.pointWon(by: winner, outcome: nil, ending: nil), to: state).0
            sides.append(state.serverCourtSide)
        }

        XCTAssertEqual(sides, [.deuce, .ad, .deuce, .ad, .deuce, .ad, .deuce, .ad])
        XCTAssertEqual(state.currentGame, .standard(a: .advantage, b: .forty))
    }

    func testThirtyFifteenServesFromTheAdSide() throws {
        var state = start
        for winner: Side in [.a, .b, .a] {
            state = try ScoringEngine.apply(.pointWon(by: winner, outcome: nil, ending: nil), to: state).0
        }

        XCTAssertEqual(state.currentGame, .standard(a: .thirty, b: .fifteen))
        XCTAssertEqual(state.serverCourtSide, .ad)
    }

    func testANewGameServesFromTheDeuceSide() throws {
        var state = start
        for _ in 0 ..< 4 {
            state = try ScoringEngine.apply(.pointWon(by: .a, outcome: nil, ending: nil), to: state).0
        }

        XCTAssertEqual(state.serverCourtSide, .deuce)
    }

    func testFaultsAndLetsAreRefusedOnACompleteMatch() {
        var complete = start
        complete.phase = .complete(winner: .a)

        for event in [MatchEvent.fault, .let] {
            XCTAssertThrowsError(try ScoringEngine.apply(event, to: complete)) { error in
                XCTAssertEqual(error as? EngineError, .matchOver)
            }
        }
    }
}
