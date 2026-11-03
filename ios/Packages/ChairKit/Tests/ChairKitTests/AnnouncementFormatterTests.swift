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
    private let names = PlayerNames([.a1: "Musa", .b1: "Cruz"], doubles: false)
    private lazy var formatter = AnnouncementFormatter(names: names)

    func testScoresAreCalledWithTheServerFirst() {
        XCTAssertEqual(formatter.text(.score(a: .fifteen, b: .love, serverSide: .a)), "Fifteen–love")
        XCTAssertEqual(formatter.text(.score(a: .fifteen, b: .love, serverSide: .b)), "Love–fifteen")
        XCTAssertEqual(formatter.text(.score(a: .forty, b: .thirty, serverSide: .b)), "Thirty–forty")
    }

    func testLevelScoresAreAllAndFortyAllIsDeuce() {
        XCTAssertEqual(formatter.text(.score(a: .fifteen, b: .fifteen, serverSide: .a)), "Fifteen–all")
        XCTAssertEqual(formatter.text(.score(a: .thirty, b: .thirty, serverSide: .b)), "Thirty–all")
        XCTAssertEqual(formatter.text(.deuce), "Deuce")
    }

    func testAdvantageAndGameNameThePlayer() {
        XCTAssertEqual(formatter.text(.advantage(.b)), "Advantage Cruz")
        XCTAssertEqual(formatter.text(.game(.a)), "Game, Musa")
    }

    func testTiebreakScoresAreWordsWithTheServerNamed() {
        XCTAssertEqual(formatter.text(.tiebreakScore(a: 5, b: 6, serverSide: .a)), "Five–six, Musa")
        XCTAssertEqual(formatter.text(.tiebreakScore(a: 2, b: 3, serverSide: .b)), "Three–two, Cruz")
        XCTAssertEqual(formatter.text(.tiebreakScore(a: 6, b: 6, serverSide: .a)), "Six–all")
        XCTAssertEqual(formatter.text(.tiebreakScore(a: 0, b: 21, serverSide: .a)), "Zero–twenty-one, Musa")
    }

    func testSetAndMatchCallsReadTheGamesFromTheWinner() {
        XCTAssertEqual(formatter.text(.gameAndSet(.a, SetScore(a: 6, b: 4)), setNumber: 1), "Game and first set, Musa, six games to four")
        XCTAssertEqual(formatter.text(.gameAndSet(.b, SetScore(a: 3, b: 6))), "Game and set, Cruz, six games to three")
        let sets = [SetSummary(a: 6, b: 4), SetSummary(a: 3, b: 6), SetSummary(a: 7, b: 6, tiebreak: TiebreakSummary(a: 7, b: 3))]
        XCTAssertEqual(formatter.text(.gameSetMatch(.a, sets)), "Game, set and match, Musa, six–four, three–six, seven–six")
        XCTAssertEqual(formatter.text(.gameSetMatch(.b, [SetSummary(a: 0, b: 6)])), "Game, set and match, Cruz, six–love")
        XCTAssertEqual(formatter.text(.retired(.a)), "Musa retires; game, set and match, Cruz")
    }

    func testASetPointCallsTheSetOnceThenChangeOfEnds() {
        let calls: [Announcement] = [.net, .game(.b), .changeEnds, .gameAndSet(.b, SetScore(a: 3, b: 6))]

        XCTAssertEqual(formatter.text(calls), "Net. Game and set, Cruz, six games to three. Change of ends")
    }

    func testDoublesNameTheTeam() {
        let doubles = AnnouncementFormatter(names: PlayerNames([.a1: "Musa", .a2: "Cruz", .b1: "Nguyen", .b2: "Siobhan"], doubles: true))

        XCTAssertEqual(doubles.text(.game(.a)), "Game, Musa–Cruz")
        XCTAssertEqual(doubles.text(.chooseServer(.b)), "Nguyen–Siobhan, who serves?")
    }

    func testTheSpokenNameOverridesTheDisplayName() {
        let names = PlayerNames([.a1: "Siobhan", .b1: "Cruz"], doubles: false, spokenNames: [.a1: "Shiv-awn"])

        XCTAssertEqual(AnnouncementFormatter.text(for: .game(.a), names: names, verbosity: .normal), "Game, Shiv-awn")
    }

    func testEveryCallHasItsUmpireText() {
        XCTAssertEqual(formatter.text(.ace), "Ace!")
        XCTAssertEqual(formatter.text(.doubleFault), "Double fault")
        XCTAssertEqual(formatter.text(.out), "Out")
        XCTAssertEqual(formatter.text(.net), "Net")
        XCTAssertEqual(formatter.text(.fault), "Fault")
        XCTAssertEqual(formatter.text(.let(firstServe: true)), "Let, first serve")
        XCTAssertEqual(formatter.text(.let(firstServe: false)), "Let, second serve")
        XCTAssertEqual(formatter.text(.changeEnds), "Change of ends")
        XCTAssertEqual(formatter.text(.receiverChoosesSide), "Deciding point; receiver's choice")
        XCTAssertEqual(formatter.text(.chooseServer(.a)), "Musa, who serves?")
    }

    func testACorrectionReadsTheScoreFromTheSnapshot() {
        let game = GameState.standard(a: .thirty, b: .fifteen)
        let snapshot = ScoreSnapshot(sets: [], currentSet: SetScore(a: 2, b: 3), currentGame: game, server: .b1)

        XCTAssertEqual(formatter.text(.correction(snapshot)), "Correction, fifteen–thirty")
    }

    func testCallsAfterAnExclamationAreNotDoubledUp() {
        let calls: [Announcement] = [.ace, .score(a: .fifteen, b: .love, serverSide: .a), .out]

        XCTAssertEqual(formatter.text(calls), "Ace! Fifteen–love. Out")
    }

    func testMinimalSaysOnlyScoresAndResults() {
        let minimal = AnnouncementFormatter(names: names, verbosity: .minimal)
        let calls: [Announcement] = [.out, .game(.a), .changeEnds]

        XCTAssertEqual(minimal.text(calls), "Game, Musa")
        XCTAssertEqual(minimal.text(.fault), "")
    }

    func testPreRallyFollowsTheVerbosity() throws {
        var log = try MatchLog(rules: MatchRules())
        let start = try output(&log, .pointWon(by: .a, outcome: nil, ending: nil))
        let normal = formatter
        let full = AnnouncementFormatter(names: names, verbosity: .full)
        let minimal = AnnouncementFormatter(names: names, verbosity: .minimal)

        XCTAssertNil(normal.preRally(start))
        XCTAssertEqual(full.preRally(start), "Musa to serve, ad side")
        let fault = try output(&log, .fault)
        XCTAssertEqual(normal.spoken(fault), "Fault. Second serve")
        XCTAssertNil(minimal.preRally(fault))
        for _ in 0 ..< 3 {
            _ = try output(&log, .pointWon(by: .a, outcome: nil, ending: nil))
        }
        let game = try XCTUnwrap(log.state).currentGame
        XCTAssertEqual(game, .loveAll)
        XCTAssertEqual(normal.preRally(EngineOutput(state: log.state, announcements: [.game(.a)])), "Cruz to serve, deuce side")
    }

    func testTheCurrentScoreReadsFromTheState() throws {
        var log = try MatchLog(rules: MatchRules())
        _ = try output(&log, .pointWon(by: .a, outcome: nil, ending: nil))
        _ = try output(&log, .pointWon(by: .b, outcome: nil, ending: nil))
        _ = try output(&log, .pointWon(by: .b, outcome: nil, ending: nil))

        XCTAssertEqual(formatter.score(log.state), "Fifteen–thirty")
        XCTAssertEqual(try formatter.score(MatchLog(rules: MatchRules()).state), "Love–all")
    }

    private func output(
        _ log: inout MatchLog,
        _ event: MatchEvent
    ) throws -> EngineOutput {
        let calls = try log.append(TimedEvent(event, at: Date(timeIntervalSince1970: 0)))
        return EngineOutput(state: log.state, announcements: calls)
    }
}
