//
//  ScoreFixTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/28/26.
//

import XCTest

import ChairKit
import ChairTestSupport

final class ScoreFixTests: XCTestCase {
    private let rules = MatchRules(firstServer: .a)

    func testFixingTwoThreeToThreeAllWithAServing() throws {
        var log = try MatchLog(rules: rules)
        for winner: Side in [.a, .b, .a, .b, .b] {
            try game(winner, in: &log)
        }
        XCTAssertEqual(log.state.currentSet, SetScore(a: 2, b: 3))
        let fix = ScoreSnapshot(sets: [], currentSet: SetScore(a: 3, b: 3), currentGame: .loveAll, server: .a1)

        let calls = try log.append(timed(.setScore(fix)))

        XCTAssertEqual(log.snapshot, fix)
        XCTAssertEqual(calls, [.correction(fix)])
        XCTAssertEqual(log.state.receiver, .b1)
        XCTAssertEqual(log.state.serverCourtSide, .deuce)
        XCTAssertEqual(log.state.phase, .inProgress)
    }

    func testAdvantageIsRejectedUnderNoAd() throws {
        let log = try MatchLog(rules: MatchRules(deuce: .noAd, firstServer: .a))
        let fix = ScoreSnapshot(
            sets: [],
            currentSet: SetScore(a: 0, b: 0),
            currentGame: .standard(a: .advantage, b: .forty),
            server: .a1
        )

        XCTAssertThrowsError(try ScoringEngine.apply(.setScore(fix), to: log.state)) {
            guard case .invalidScore = $0 as? EngineError else { return XCTFail("\($0)") }
        }
    }

    func testUndoingAFixRestoresThePreFixState() throws {
        var log = try MatchLog(rules: rules)
        for winner: Side in [.a, .b, .a] {
            try log.append(point(winner))
        }
        let before = log.state
        let fix = ScoreSnapshot(sets: [SetScore(a: 6, b: 4)], currentSet: SetScore(a: 0, b: 0), currentGame: .loveAll, server: .a1)
        try log.append(timed(.setScore(fix)))
        XCTAssertEqual(log.state.sets, [SetScore(a: 6, b: 4)])

        let calls = try log.append(timed(.undo))

        XCTAssertEqual(log.state, before)
        XCTAssertEqual(calls, [.correction(before.snapshot)])
    }

    func testAServerWhoShouldBeReceivingIsRejected() throws {
        let log = try MatchLog(rules: rules)
        let fix = ScoreSnapshot(sets: [], currentSet: SetScore(a: 1, b: 0), currentGame: .loveAll, server: .a1)

        XCTAssertThrowsError(try ScoringEngine.apply(.setScore(fix), to: log.state)) {
            XCTAssertEqual($0 as? EngineError, .invalidScore(reason: "B serves this game"))
        }
    }

    func testUnreachableSetsAreRejected() throws {
        let start = MatchState.initial(rules: rules)
        let cases: [ScoreSnapshot] = [
            snapshot([SetScore(a: 8, b: 6)], SetScore(a: 0, b: 0), .loveAll),
            snapshot([SetScore(a: 6, b: 5)], SetScore(a: 0, b: 0), .loveAll),
            snapshot([], SetScore(a: 7, b: 5), .loveAll),
            snapshot([], SetScore(a: 6, b: 6), .loveAll),
            snapshot([], SetScore(a: 5, b: 4), .tiebreak(a: 0, b: 0, target: 7)),
            snapshot([], SetScore(a: 6, b: 6), .tiebreak(a: 7, b: 5, target: 7)),
            snapshot([], SetScore(a: 0, b: 0), .standard(a: .advantage, b: .thirty)),
            snapshot([SetScore(a: 6, b: 0), SetScore(a: 6, b: 0), SetScore(a: 0, b: 6)], SetScore(a: 0, b: 0), .loveAll),
            snapshot([SetScore(a: 6, b: 0), SetScore(a: 6, b: 0)], SetScore(a: 1, b: 0), .loveAll),
        ]
        for fix in cases {
            XCTAssertThrowsError(try ScoringEngine.apply(.setScore(fix), to: start), "\(fix)") {
                guard case .invalidScore = $0 as? EngineError else { return XCTFail("\($0)") }
            }
        }
    }

    func testAFixIntoATiebreakKeepsTheRotation() throws {
        let fix = ScoreSnapshot(
            sets: [],
            currentSet: SetScore(a: 6, b: 6),
            currentGame: .tiebreak(a: 2, b: 1, target: 7),
            server: .a1
        )
        var log = try MatchLog(rules: rules)
        try log.append(timed(.setScore(fix)))

        try log.append(point(.a))

        XCTAssertEqual(log.state.currentGame, .tiebreak(a: 3, b: 1, target: 7))
        XCTAssertEqual(log.state.server, .a1)
        XCTAssertEqual(log.state.tiebreakOpeningReceiver, .b1)
    }

    func testAFixThatWinsTheMatchCompletesIt() throws {
        let fix = ScoreSnapshot(
            sets: [SetScore(a: 6, b: 3), SetScore(a: 7, b: 6)],
            currentSet: SetScore(a: 0, b: 0),
            currentGame: .loveAll,
            server: .b1
        )

        let (state, _) = try ScoringEngine.apply(.setScore(fix), to: .initial(rules: rules))

        XCTAssertEqual(state.phase, .complete(winner: .a))
        XCTAssertThrowsError(try ScoringEngine.apply(.pointWon(by: .a, outcome: nil, ending: nil), to: state))
    }

    func testAFinishedMatchCanBeReopened() throws {
        var log = try MatchLog(rules: rules)
        for _ in 0 ..< 48 {
            try log.append(point(.a))
        }
        XCTAssertEqual(log.state.phase, .complete(winner: .a))
        XCTAssertEqual(log.snapshot.server, .b1)
        let reopened = ScoreSnapshot(
            sets: [SetScore(a: 6, b: 0)],
            currentSet: SetScore(a: 5, b: 0),
            currentGame: .standard(a: .forty, b: .love),
            server: .b1
        )

        try log.append(timed(.setScore(reopened)))
        try log.append(point(.b))

        XCTAssertEqual(log.state.phase, .inProgress)
        XCTAssertEqual(log.state.currentGame, .standard(a: .forty, b: .fifteen))
    }

    func testTheAdvantageFinalSetHasNoTiebreak() throws {
        let rules = MatchRules(finalSet: .advantage, firstServer: .a)
        let fix = ScoreSnapshot(
            sets: [SetScore(a: 6, b: 3), SetScore(a: 3, b: 6)],
            currentSet: SetScore(a: 8, b: 7),
            currentGame: .loveAll,
            server: .b1
        )

        let (state, _) = try ScoringEngine.apply(.setScore(fix), to: .initial(rules: rules))

        XCTAssertEqual(state.currentSet, SetScore(a: 8, b: 7))
    }

    func testReachableFixesAreAccepted() throws {
        for reachable in ReachableFix.all {
            let (state, _) = try ScoringEngine.apply(.setScore(reachable.fix), to: .initial(rules: reachable.rules))
            XCTAssertEqual(state.snapshot, reachable.fix)
            XCTAssertEqual(state.phase, reachable.phase)
        }
    }

    func testNoAdRejectsAdvantageToEitherSide() throws {
        let start = MatchState.initial(rules: MatchRules(deuce: .noAd, firstServer: .a))
        let fix = ScoreSnapshot(sets: [], currentSet: SetScore(a: 0, b: 0), currentGame: .standard(a: .forty, b: .advantage), server: .a1)

        XCTAssertThrowsError(try ScoringEngine.apply(.setScore(fix), to: start))
    }

    func testAMatchWonInATiebreakCanBeReopenedInsideIt() throws {
        var log = try MatchLog(rules: MatchRules(finalSet: .tiebreak10, firstServer: .a))
        try log.append(timed(.setScore(ScoreSnapshot(
            sets: [SetScore(a: 6, b: 4), SetScore(a: 3, b: 6)],
            currentSet: SetScore(a: 6, b: 6),
            currentGame: .tiebreak(a: 9, b: 7, target: 10),
            server: .b1
        ))))
        try log.append(point(.a))
        XCTAssertEqual(log.state.phase, .complete(winner: .a))

        try log.append(timed(.setScore(ScoreSnapshot(
            sets: [SetScore(a: 6, b: 4), SetScore(a: 3, b: 6)],
            currentSet: SetScore(a: 6, b: 6),
            currentGame: .tiebreak(a: 9, b: 7, target: 10),
            server: .b1
        ))))

        XCTAssertEqual(log.state.phase, .inProgress)
        XCTAssertEqual(log.state.currentGame, .tiebreak(a: 9, b: 7, target: 10))
    }

    func testASinglesFixRejectsASecondPlayer() throws {
        let fix = ScoreSnapshot(sets: [], currentSet: SetScore(a: 0, b: 0), currentGame: .loveAll, server: .a2)

        XCTAssertThrowsError(try ScoringEngine.apply(.setScore(fix), to: .initial(rules: rules))) {
            XCTAssertEqual($0 as? EngineError, .invalidScore(reason: "A2 isn't playing singles"))
        }
    }

    func testADoublesFixIntoATiebreakFindsTheOpeningReceiver() throws {
        let start = MatchState.initial(rules: rules, format: .doubles)
        let fix = ScoreSnapshot(
            sets: [],
            currentSet: SetScore(a: 6, b: 6),
            currentGame: .tiebreak(a: 1, b: 2, target: 7),
            server: .a2
        )

        let (state, _) = try ScoringEngine.apply(.setScore(fix), to: start)

        XCTAssertEqual(state.server, .a2)
        XCTAssertEqual(state.tiebreakOpeningReceiver, .b1)
        XCTAssertEqual(state.serverCourtSide, .ad)
    }

    private func snapshot(
        _ sets: [SetScore],
        _ current: SetScore,
        _ game: GameState
    ) -> ScoreSnapshot {
        ScoreSnapshot(sets: sets, currentSet: current, currentGame: game, server: .a1)
    }

    private func game(
        _ winner: Side,
        in log: inout MatchLog
    ) throws {
        for _ in 0 ..< 4 {
            try log.append(point(winner))
        }
    }

    private func point(_ winner: Side) -> TimedEvent {
        timed(.pointWon(by: winner, outcome: nil, ending: nil))
    }

    private func timed(_ event: MatchEvent) -> TimedEvent {
        TimedEvent(event, at: Fixtures.matchDay)
    }
}

private struct ReachableFix {
    let rules: MatchRules
    let fix: ScoreSnapshot
    let phase: MatchPhase

    static let all: [ReachableFix] = [
        ReachableFix(
            rules: MatchRules(firstServer: .a),
            fix: ScoreSnapshot(
                sets: [],
                currentSet: SetScore(a: 0, b: 0),
                currentGame: .standard(a: .thirty, b: .fifteen),
                server: .a1
            ),
            phase: .inProgress
        ),
        ReachableFix(
            rules: MatchRules(firstServer: .a),
            fix: ScoreSnapshot(
                sets: [],
                currentSet: SetScore(a: 0, b: 0),
                currentGame: .standard(a: .forty, b: .advantage),
                server: .a1
            ),
            phase: .inProgress
        ),
        ReachableFix(
            rules: MatchRules(finalSet: .advantage, firstServer: .a),
            fix: ScoreSnapshot(
                sets: [SetScore(a: 6, b: 3), SetScore(a: 3, b: 6), SetScore(a: 8, b: 6)],
                currentSet: SetScore(a: 0, b: 0),
                currentGame: .loveAll,
                server: .b1
            ),
            phase: .complete(winner: .a)
        ),
        ReachableFix(
            rules: MatchRules(finalSet: .tiebreak10, firstServer: .a),
            fix: ScoreSnapshot(
                sets: [SetScore(a: 7, b: 5), SetScore(a: 6, b: 7)],
                currentSet: SetScore(a: 6, b: 6),
                currentGame: .tiebreak(a: 4, b: 3, target: 10),
                server: .b1
            ),
            phase: .inProgress
        ),
        ReachableFix(
            rules: MatchRules(firstServer: .a),
            fix: ScoreSnapshot(
                sets: [SetScore(a: 7, b: 5), SetScore(a: 5, b: 7)],
                currentSet: SetScore(a: 6, b: 6),
                currentGame: .tiebreak(a: 0, b: 0, target: 7),
                server: .a1
            ),
            phase: .inProgress
        ),
    ]
}
