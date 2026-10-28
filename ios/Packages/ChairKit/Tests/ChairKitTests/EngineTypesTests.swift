//
//  EngineTypesTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/28/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

final class EngineTypesTests: XCTestCase {
    func testEveryEngineTypeRoundTripsThroughJSON() throws {
        let snapshot = ScoreSnapshot(
            sets: [SetScore(a: 6, b: 4)],
            currentSet: SetScore(a: 2, b: 3),
            currentGame: .standard(a: .thirty, b: .forty),
            server: .b1
        )
        let events: [MatchEvent] = [
            .pointWon(by: .a, outcome: .ace, ending: nil),
            .pointWon(by: .b, outcome: .forcedError, ending: .out),
            .pointWon(by: .a, outcome: nil, ending: .net),
            .fault, .let, .undo, .setScore(snapshot), .swapServer, .swapEnds, .retire(.b),
        ]
        let sources: [EventSource] = [.manual, .camera(confidence: 0.82), .shout, .gesture, .referee, .watch]
        for (index, event) in events.enumerated() {
            try assertRoundTrip(TimedEvent(event, at: Fixtures.matchDay, source: sources[index % sources.count]))
        }
        try assertRoundTrip(sources)
        try assertRoundTrip(CourtSide.allCases)
        try assertRoundTrip(CourtEnd.allCases)
        try assertRoundTrip(PointEnding.allCases)
        try assertRoundTrip(GameScore.allCases)
        try assertRoundTrip([GameState.loveAll, .standard(a: .forty, b: .advantage), .tiebreak(a: 6, b: 5, target: 10)])
        try assertRoundTrip([MatchPhase.notStarted, .inProgress, .complete(winner: .a)])
        try assertRoundTrip(DoublesOrder.starting(with: .b))
        try assertRoundTrip(snapshot)
        try assertRoundTrip(MatchState.initial(
            rules: MatchRules(sets: .bestOf5, deuce: .noAd, finalSet: .tiebreak10, firstServer: .b),
            format: .doubles
        ))
    }

    func testInitialStateIsLoveAllWithTheRulesFirstServerOnTheDeuceSide() {
        let state = MatchState.initial(rules: MatchRules(firstServer: .b))

        XCTAssertEqual(state.phase, .notStarted)
        XCTAssertEqual(state.currentGame, .standard(a: .love, b: .love))
        XCTAssertEqual(state.currentSet, SetScore(a: 0, b: 0))
        XCTAssertTrue(state.sets.isEmpty)
        XCTAssertEqual(state.server, .b1)
        XCTAssertEqual(state.receiver, .a1)
        XCTAssertEqual(state.serverCourtSide, .deuce)
        XCTAssertEqual(state.faultCount, 0)
        XCTAssertNil(state.doublesOrder)
    }

    func testDoublesStartsWithTheFirstServingTeamThenAlternatesTeams() {
        let state = MatchState.initial(rules: MatchRules(firstServer: .a), format: .doubles)

        XCTAssertEqual(state.doublesOrder?.serving, [.a1, .b1, .a2, .b2])
        XCTAssertEqual(state.doublesOrder?.deuceReceivers, [.a: .a1, .b: .b1])
        XCTAssertEqual(state.server, .a1)
        XCTAssertEqual(state.receiver, .b1)
    }

    private func assertRoundTrip<T: Codable & Equatable>(
        _ value: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let data = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(T.self, from: data), value, file: file, line: line)
    }
}
