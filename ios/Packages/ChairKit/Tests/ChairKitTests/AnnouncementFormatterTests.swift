//
//  AnnouncementFormatterTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import XCTest

import ChairKit

final class AnnouncementFormatterTests: XCTestCase {
    private let formatter = AnnouncementFormatter(names: [.a: "Aaron", .b: "Juan"])

    func testScoresAreCalledWithTheServerFirst() {
        XCTAssertEqual(formatter.text(.score(a: .fifteen, b: .thirty, serverSide: .a)), "Fifteen–thirty")
        XCTAssertEqual(formatter.text(.score(a: .fifteen, b: .thirty, serverSide: .b)), "Thirty–fifteen")
    }

    func testLevelScoresAreAll() {
        XCTAssertEqual(formatter.text(.score(a: .love, b: .love, serverSide: .a)), "Love–all")
        XCTAssertEqual(formatter.text(.score(a: .thirty, b: .thirty, serverSide: .b)), "Thirty–all")
    }

    func testNamedCallsUseThePlayersName() {
        XCTAssertEqual(formatter.text(.advantage(.b)), "Advantage Juan")
        XCTAssertEqual(formatter.text(.game(.a)), "Game Aaron")
        XCTAssertEqual(formatter.text(.gameAndSet(.b, SetScore(a: 4, b: 6))), "Game and set Juan, 6–4")
        XCTAssertEqual(formatter.text(.gameSetMatch(.a, [])), "Game, set and match Aaron")
        XCTAssertEqual(formatter.text(.retired(.b)), "Juan retires")
    }

    func testTiebreakScoresAreNumbersWithTheServerFirst() {
        XCTAssertEqual(formatter.text(.tiebreakScore(a: 2, b: 5, serverSide: .b)), "5–2")
        XCTAssertEqual(formatter.text(.tiebreakScore(a: 3, b: 3, serverSide: .a)), "3–all")
    }

    func testSeveralCallsAreJoinedInOrder() {
        let calls: [Announcement] = [.out, .score(a: .love, b: .fifteen, serverSide: .a)]

        XCTAssertEqual(formatter.text(calls), "Out. Love–fifteen")
    }

    func testEveryOtherCallHasText() {
        XCTAssertEqual(formatter.text(.ace), "Ace")
        XCTAssertEqual(formatter.text(.net), "Net")
        XCTAssertEqual(formatter.text(.deuce), "Deuce")
        XCTAssertEqual(formatter.text(.fault), "Fault")
        XCTAssertEqual(formatter.text(.doubleFault), "Double fault")
        XCTAssertEqual(formatter.text(.let(firstServe: false)), "Let, second serve")
        XCTAssertEqual(formatter.text(.changeEnds), "Change ends")
        XCTAssertEqual(formatter.text(.receiverChoosesSide), "Deciding point, receiver chooses")
        XCTAssertEqual(formatter.text(.chooseServer(.a)), "Aaron to choose the server")
        let snapshot = ScoreSnapshot(sets: [], currentSet: SetScore(a: 0, b: 0), currentGame: .loveAll, server: .a1)
        XCTAssertEqual(formatter.text(.correction(snapshot)), "Correction")
    }

    func testTheCurrentScoreReadsFromTheState() throws {
        var log = try MatchLog(rules: MatchRules())
        let day = Date(timeIntervalSince1970: 0)
        try log.append(TimedEvent(.pointWon(by: .a, outcome: nil, ending: nil), at: day))
        try log.append(TimedEvent(.pointWon(by: .b, outcome: nil, ending: nil), at: day))
        try log.append(TimedEvent(.pointWon(by: .b, outcome: nil, ending: nil), at: day))

        XCTAssertEqual(formatter.score(log.state), "Fifteen–thirty")
        XCTAssertEqual(try formatter.score(MatchLog(rules: MatchRules()).state), "Love–all")
    }
}
