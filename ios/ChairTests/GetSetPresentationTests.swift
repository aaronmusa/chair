//
//  GetSetPresentationTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/2/26.
//

import XCTest

import ChairKit
import ChairTestSupport
import ChairUI

@testable import Chair

@MainActor
final class GetSetPresentationTests: XCTestCase {
    private let names: [PlayerSlot: String] = [.a1: "Aaron", .a2: "Bea", .b1: "Juan", .b2: "Lia"]

    func testAtFifteenThirtyTheServerIsOnAsEndOnTheAdSide() throws {
        var log = try MatchLog(rules: MatchRules())
        try point(.a, &log)
        try point(.b, &log)
        let calls = try point(.b, &log)

        let presentation = GetSetPresentation(state: log.state, names: names, announcements: calls)

        let server = try XCTUnwrap(presentation.markers.first { $0.role == .server })
        let aEnd = try XCTUnwrap(log.state.ends[.a])
        XCTAssertEqual(server.id, "Aaron")
        XCTAssertEqual(server.side, aEnd)
        XCTAssertEqual(server.position, .behindBaseline(aEnd, on: .ad, by: 1))
        XCTAssertEqual(presentation.strip, "Fifteen–thirty")
        XCTAssertEqual(presentation.serveLabel, "Aaron serves · ad court · first serve")
    }

    func testVoiceOverReadsServerSideAndScoreAsOneSentence() throws {
        var log = try MatchLog(rules: MatchRules())
        try point(.a, &log)
        try log.append(TimedEvent(.fault, at: Fixtures.matchDay))

        let presentation = GetSetPresentation(state: log.state, names: names)

        XCTAssertEqual(presentation.accessibilitySentence, "Aaron serves from the ad side, second serve. Fifteen–love")
    }

    func testInDoublesSwapServerShowsTheOtherPartnerServing() throws {
        var log = try MatchLog(rules: MatchRules(), format: .doubles)
        XCTAssertTrue(GetSetPresentation(state: log.state, names: names).canSwapServer)

        try log.append(TimedEvent(.swapServer, at: Fixtures.matchDay))
        let swapped = GetSetPresentation(state: log.state, names: names)

        XCTAssertEqual(swapped.serverName, "Bea")
        XCTAssertEqual(swapped.markers.first { $0.role == .server }?.id, "Bea")
        XCTAssertEqual(swapped.markers.count, 4)
    }

    func testAfterOnePointTheSwapsAreDisabled() throws {
        var log = try MatchLog(rules: MatchRules(), format: .doubles)
        try point(.a, &log)

        let presentation = GetSetPresentation(state: log.state, names: names)

        XCTAssertFalse(presentation.canSwapServer)
        XCTAssertFalse(presentation.canSwapReceivers)
        XCTAssertTrue(presentation.canSwapSides)
    }

    func testSinglesHidesTheReceiverSwap() throws {
        let presentation = try GetSetPresentation(state: MatchLog(rules: MatchRules()).state, names: names)

        XCTAssertFalse(presentation.isDoubles)
        XCTAssertFalse(presentation.canSwapReceivers)
        XCTAssertEqual(presentation.markers.count, 2)
    }

    func testDoublesNamesTheTeamInCalls() throws {
        let presentation = try GetSetPresentation(
            state: MatchLog(rules: MatchRules(), format: .doubles).state,
            names: names,
            announcements: [.game(.b)]
        )

        XCTAssertEqual(presentation.strip, "Game, Juan–Lia")
    }

    @discardableResult
    private func point(
        _ side: Side,
        _ log: inout MatchLog
    ) throws -> [Announcement] {
        try log.append(TimedEvent(.pointWon(by: side, outcome: nil, ending: nil), at: Fixtures.matchDay))
    }
}
