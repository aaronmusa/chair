//
//  MatchLogTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/28/26.
//

import XCTest

import ChairKit
import ChairTestSupport

final class MatchLogTests: XCTestCase {
    private let rules = MatchRules(firstServer: .a)

    func testFiftyRandomEventsMatchAFreshReplay() throws {
        var generator = SeededGenerator(seed: 44)
        var log = try MatchLog(rules: rules)
        let pool: [MatchEvent] = [
            .pointWon(by: .a, outcome: .winner, ending: nil),
            .pointWon(by: .b, outcome: .unforcedError, ending: .net),
            .pointWon(by: .a, outcome: nil, ending: .out),
            .pointWon(by: .b, outcome: nil, ending: nil),
            .fault,
            .let,
            .undo,
            .swapEnds,
        ]
        var appended = 0
        while appended < 50 {
            let event = try XCTUnwrap(pool.randomElement(using: &generator))
            guard (try? log.append(timed(event, appended))) != nil else { continue }
            appended += 1
        }

        XCTAssertEqual(log.state, try MatchLog.replay(rules: rules, events: log.events))
        XCTAssertEqual(log.events.count, 50)
    }

    func testUndoAtThirtyFifteenGoesBackToFifteenAllWithACorrection() throws {
        var log = try MatchLog(rules: rules)
        for winner: Side in [.a, .b, .a] {
            try log.append(point(winner))
        }

        let calls = try log.append(timed(.undo))

        let fifteenAll = GameState.standard(a: .fifteen, b: .fifteen)
        XCTAssertEqual(log.state.currentGame, fifteenAll)
        XCTAssertEqual(calls, [.correction(log.snapshot)])
        XCTAssertEqual(log.snapshot.currentGame, fifteenAll)
        XCTAssertEqual(log.events.map(\.undone), [false, false, true, false])
    }

    func testRepeatedUndosStepBackOneScoringEventEach() throws {
        var log = try MatchLog(rules: rules)
        try log.append(point(.a))
        try log.append(timed(.fault))
        try log.append(timed(.undo))
        XCTAssertEqual(log.state.faultCount, 0)
        XCTAssertEqual(log.state.currentGame, .standard(a: .fifteen, b: .love))

        try log.append(timed(.undo))

        XCTAssertEqual(log.state, .initial(rules: rules))
    }

    func testUndoAtTheStartOfASetIsRefused() throws {
        var log = try MatchLog(rules: rules)
        for _ in 0 ..< 24 {
            try log.append(point(.a))
        }
        XCTAssertEqual(log.state.sets, [SetScore(a: 6, b: 0)])
        let before = log

        XCTAssertThrowsError(try log.append(timed(.undo))) {
            XCTAssertEqual($0 as? EngineError, .undoLimit)
        }
        XCTAssertEqual(log, before)
    }

    func testUndoWithNothingToUndoIsRefused() throws {
        var log = try MatchLog(rules: rules)

        XCTAssertThrowsError(try log.append(timed(.undo))) {
            XCTAssertEqual($0 as? EngineError, .undoLimit)
        }
    }

    func testAnUndoneEventSurvivesTheRoundTripToPointEvents() throws {
        var log = try MatchLog(rules: rules)
        try log.append(TimedEvent(.pointWon(by: .a, outcome: .ace, ending: nil), at: Fixtures.matchDay, source: .camera(confidence: 0.9)))
        try log.append(point(.b, ending: .out))
        try log.append(timed(.fault, 2))
        try log.append(timed(.undo, 3))
        try log.append(timed(.swapEnds, 4))

        let rows = log.pointEvents(updatedAt: Fixtures.matchDay)
        let restored = try MatchLog(rules: rules, pointEvents: rows.reversed())

        XCTAssertEqual(rows.map(\.eventKind), ["point", "point", "fault", "undo", "swap_ends"])
        XCTAssertEqual(rows.map(\.undone), [false, false, true, false, false])
        XCTAssertEqual(restored, log)
        XCTAssertEqual(restored.state, log.state)
    }

    func testPayloadsRoundTripForEveryKind() throws {
        let snapshot = ScoreSnapshot(
            sets: [SetScore(a: 6, b: 4)],
            currentSet: SetScore(a: 2, b: 1),
            currentGame: .standard(a: .thirty, b: .love),
            server: .b1
        )
        let events: [TimedEvent] = [
            timed(.setScore(snapshot), 0),
            timed(.swapServer, 1),
            timed(.swapReceivers(.b), 2),
            timed(.let, 3),
            timed(.retire(.b), 4),
        ]
        let rows = MatchLog.pointEvents(events, updatedAt: Fixtures.matchDay)

        let restored = try MatchLog.events(from: rows)

        XCTAssertEqual(restored, events)
        XCTAssertEqual(rows.map(\.eventKind), ["set_score", "swap_server", "swap_receivers", "let", "retire"])
    }

    func testAnUnknownKindIsRejected() {
        let row = PointEvent(
            index: 0,
            at: Fixtures.matchDay,
            winnerSide: nil,
            outcome: nil,
            eventKind: "smash",
            updatedAt: Fixtures.matchDay
        )

        XCTAssertThrowsError(try MatchLog(rules: rules, pointEvents: [row])) {
            XCTAssertEqual($0 as? MatchLogMappingError, .unknownKind("smash"))
        }
    }

    private func point(
        _ winner: Side,
        ending: PointEnding? = nil
    ) -> TimedEvent {
        timed(.pointWon(by: winner, outcome: nil, ending: ending))
    }

    private func timed(
        _ event: MatchEvent,
        _ second: Int = 0
    ) -> TimedEvent {
        TimedEvent(event, at: Fixtures.matchDay.addingTimeInterval(TimeInterval(second)))
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
