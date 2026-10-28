//
//  MatchSessionTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/28/26.
//

import XCTest

import ChairKit
import ChairTestSupport

final class MatchSessionTests: XCTestCase {
    private let rules = MatchRules(firstServer: .a)

    func testAnAceAtFortyThirtyCallsTheAceThenTheGameThenChangeOfEnds() async throws {
        let session = try MatchSession(rules: rules)
        try await play([.a, .b, .a, .a], in: session)

        let output = try await session.apply(point(.a, outcome: .ace))

        XCTAssertEqual(output.announcements, [.ace, .game(.a), .changeEnds])
    }

    func testAnEvenGameTotalHasNoChangeOfEnds() async throws {
        let session = try MatchSession(rules: rules)
        try await play([.a, .a, .a, .a], in: session)
        try await play([.b, .b, .a, .b], in: session)

        let output = try await session.apply(point(.b, outcome: .ace))

        XCTAssertEqual(output.announcements, [.ace, .game(.b)])
    }

    func testTheCallComesBeforeTheScore() async throws {
        let session = try MatchSession(rules: rules)

        let ace = try await session.apply(point(.a, outcome: .ace))
        let out = try await session.apply(point(.a, ending: .out))
        let net = try await session.apply(point(.b, outcome: .doubleFault, ending: .net))

        XCTAssertEqual(ace.announcements, [.ace, .score(a: .fifteen, b: .love, serverSide: .a)])
        XCTAssertEqual(out.announcements, [.out, .score(a: .thirty, b: .love, serverSide: .a)])
        XCTAssertEqual(net.announcements, [.doubleFault, .net, .score(a: .thirty, b: .fifteen, serverSide: .a)])
    }

    func testPreRallyAfterGameTwoHasTheOriginalServerOnTheDeuceSide() async throws {
        let session = try MatchSession(rules: rules)
        try await play([.a, .a, .a, .a], in: session)

        let output = try await session.apply(point(.b))
        try await play([.b, .b, .b], in: session)
        let preRally = await session.state.preRally

        XCTAssertEqual(output.preRally.server, .b1)
        XCTAssertEqual(preRally.server, .a1)
        XCTAssertEqual(preRally.serverNameIndex, 0)
        XCTAssertEqual(preRally.receiver, .b1)
        XCTAssertEqual(preRally.serverCourtSide, .deuce)
        XCTAssertEqual(preRally.serve, .first)
        XCTAssertEqual(preRally.ends, [.a: .far, .b: .near])
    }

    func testASecondServeShowsInPreRally() async throws {
        let session = try MatchSession(rules: rules)

        let output = try await session.apply(TimedEvent(.fault, at: Fixtures.matchDay))

        XCTAssertEqual(output.preRally.serve, .second)
    }

    func testConcurrentCallersKeepEveryEventInOrder() async throws {
        let session = try MatchSession(rules: rules)
        let events: [MatchEvent] = (0 ..< 100).map { $0.isMultiple(of: 2) ? .let : .swapEnds }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, event) in events.enumerated() {
                group.addTask {
                    try await session.apply(TimedEvent(event, at: Fixtures.matchDay.addingTimeInterval(TimeInterval(index))))
                }
            }
            try await group.waitForAll()
        }
        let logged = await session.log.events
        var streamed: [EngineOutput] = []
        for await output in session.outputs.prefix(100) {
            streamed.append(output)
        }

        XCTAssertEqual(logged.count, 100)
        XCTAssertEqual(Set(logged.map(\.at)).count, 100)
        let swaps = logged.count { $0.event == .swapEnds }
        XCTAssertEqual(swaps, 50)
        let callsInOrder = streamed.map(\.announcements)
        let expected = logged.map { $0.event == .swapEnds ? [Announcement.changeEnds] : [.let(firstServe: true)] }
        XCTAssertEqual(callsInOrder, expected)
        let finalState = await session.state
        XCTAssertEqual(streamed.last?.state, finalState)
    }

    private func play(
        _ winners: [Side],
        in session: MatchSession
    ) async throws {
        for winner in winners {
            try await session.apply(point(winner))
        }
    }

    private func point(
        _ winner: Side,
        outcome: PointOutcome? = nil,
        ending: PointEnding? = nil
    ) -> TimedEvent {
        TimedEvent(.pointWon(by: winner, outcome: outcome, ending: ending), at: Fixtures.matchDay)
    }
}
