//
//  RotationTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/28/26.
//

import XCTest

import ChairKit

final class RotationTests: XCTestCase {
    func testSinglesServerAlternatesAndEndsChangeAfterGameOne() throws {
        let start = MatchState.initial(rules: MatchRules(firstServer: .a))

        let (state, calls) = try game(for: .a, from: start)

        XCTAssertEqual(state.server, .b1)
        XCTAssertEqual(state.receiver, .a1)
        XCTAssertEqual(state.ends, [.a: .far, .b: .near])
        XCTAssertEqual(calls.suffix(2), [.game(.a), .changeEnds])
    }

    func testEndsChangeAfterEveryOddGame() throws {
        var state = MatchState.initial(rules: MatchRules())
        var changes: [Bool] = []
        for winner: Side in [.a, .b, .a, .b, .a] {
            let (next, calls) = try game(for: winner, from: state)
            state = next
            changes.append(calls.contains(.changeEnds))
        }

        XCTAssertEqual(changes, [true, false, true, false, true])
    }

    func testDoublesServingOrderComesBackToTheFirstServerInGameFive() throws {
        var state = MatchState.initial(rules: MatchRules(firstServer: .a), format: .doubles)
        var servers = [state.server]
        for winner: Side in [.a, .b, .a, .b] {
            state = try game(for: winner, from: state).0
            servers.append(state.server)
        }

        XCTAssertEqual(servers, [.a1, .b1, .a2, .b2, .a1])
    }

    func testSwapServerAtTheStartOfSetTwoFlipsThePartners() throws {
        var state = MatchState.initial(rules: MatchRules(firstServer: .a), format: .doubles)
        state.phase = .inProgress
        state.sets = [SetScore(a: 6, b: 4)]
        state.completedTiebreaks = [nil]

        let (next, _) = try ScoringEngine.apply(.swapServer, to: state)

        XCTAssertEqual(next.server, .a2)
        XCTAssertEqual(next.doublesOrder?.serving, [.a2, .b1, .a1, .b2])
    }

    func testSwapServerInSinglesHandsTheServeToTheReceiver() throws {
        let state = MatchState.initial(rules: MatchRules(firstServer: .a))

        let (next, _) = try ScoringEngine.apply(.swapServer, to: state)

        XCTAssertEqual(next.server, .b1)
        XCTAssertEqual(next.receiver, .a1)
    }

    func testASetEndingOnAnEvenTotalKeepsEndsUntilAfterGameOne() throws {
        var state = MatchState.initial(rules: MatchRules())
        state.phase = .inProgress
        state.currentSet = SetScore(a: 5, b: 4)
        let endsBefore = state.ends

        let (afterSet, setCalls) = try game(for: .a, from: state)
        XCTAssertEqual(afterSet.sets, [SetScore(a: 6, b: 4)])
        XCTAssertEqual(afterSet.ends, endsBefore)
        XCTAssertFalse(setCalls.contains(.changeEnds))

        let (afterGameOne, calls) = try game(for: .b, from: afterSet)
        XCTAssertNotEqual(afterGameOne.ends, endsBefore)
        XCTAssertTrue(calls.contains(.changeEnds))
    }

    func testATiebreakSetChangesEndsAtTheSetsEnd() throws {
        var state = MatchState.initial(rules: MatchRules())
        state.phase = .inProgress
        state.currentSet = SetScore(a: 6, b: 6)
        state.currentGame = .tiebreak(a: 6, b: 0, target: 7)
        let endsBefore = state.ends

        let (next, calls) = try ScoringEngine.apply(.pointWon(by: .a, outcome: nil, ending: nil), to: state)

        XCTAssertEqual(next.sets, [SetScore(a: 7, b: 6)])
        XCTAssertNotEqual(next.ends, endsBefore)
        XCTAssertEqual(Array(calls.prefix(2)), [.game(.a), .changeEnds])
    }

    func testDoublesReceiverFollowsTheServingSide() throws {
        var state = MatchState.initial(rules: MatchRules(firstServer: .a), format: .doubles)
        for winner: Side in [.a, .b, .a] {
            state = try point(winner, state).0
        }

        XCTAssertEqual(state.currentGame, .standard(a: .thirty, b: .fifteen))
        XCTAssertEqual(state.positions.receiver, .b2)
        XCTAssertEqual(state.positions.serverPartner, .a2)
        XCTAssertEqual(state.positions.receiverPartner, .b1)
        XCTAssertEqual(state.positions.ends[.a2], .near)
    }

    func testSwapsBeforeSetOnesFirstPointChooseServerAndReceiver() throws {
        let start = MatchState.initial(rules: MatchRules(firstServer: .a), format: .doubles)

        let swapped = try ScoringEngine.apply(.swapServer, to: start).0
        let state = try ScoringEngine.apply(.swapReceivers(.b), to: swapped).0

        XCTAssertEqual(state.server, .a2)
        XCTAssertEqual(state.receiver, .b2)
        XCTAssertEqual(state.serverCourtSide, .deuce)
    }

    func testSwapsAreRefusedOnceTheSetHasStarted() throws {
        let start = MatchState.initial(rules: MatchRules(firstServer: .a), format: .doubles)
        let (state, _) = try point(.a, start)

        for event in [MatchEvent.swapServer, .swapReceivers(.b)] {
            XCTAssertThrowsError(try ScoringEngine.apply(event, to: state)) { error in
                XCTAssertEqual(error as? EngineError, .setInProgress)
            }
        }
    }

    func testEachLaterDoublesSetPromptsTheServingTeamToChoose() throws {
        var state = MatchState.initial(rules: MatchRules(firstServer: .a), format: .doubles)
        state.phase = .inProgress
        state.currentSet = SetScore(a: 5, b: 3)

        let (next, calls) = try game(for: .a, from: state)

        XCTAssertEqual(calls.last, .chooseServer(next.server.side))
    }

    func testSinglesSetsDoNotPromptForAServer() throws {
        var state = MatchState.initial(rules: MatchRules())
        state.phase = .inProgress
        state.currentSet = SetScore(a: 5, b: 3)

        let (_, calls) = try game(for: .a, from: state)

        XCTAssertFalse(calls.contains { if case .chooseServer = $0 { true } else { false } })
    }

    func testSwapEndsFlipsTheEnds() throws {
        let start = MatchState.initial(rules: MatchRules())

        let (state, calls) = try ScoringEngine.apply(.swapEnds, to: start)

        XCTAssertEqual(state.ends, [.a: .far, .b: .near])
        XCTAssertEqual(calls, [.changeEnds])
    }

    private func point(
        _ winner: Side,
        _ state: MatchState
    ) throws -> (MatchState, [Announcement]) {
        try ScoringEngine.apply(.pointWon(by: winner, outcome: nil, ending: nil), to: state)
    }

    private func game(
        for winner: Side,
        from state: MatchState
    ) throws -> (MatchState, [Announcement]) {
        var state = state
        var calls: [Announcement] = []
        for _ in 0 ..< 4 {
            let (next, announced) = try point(winner, state)
            state = next
            calls += announced
        }
        return (state, calls)
    }
}
