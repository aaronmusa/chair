//
//  FullMatchFixtureTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/28/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

final class FullMatchFixtureTests: XCTestCase {
    func testTheSinglesFixtureReplaysToItsSummaryAndServers() throws {
        try assertFixture(named: "full_singles_bo3")
    }

    func testTheDoublesFixtureReplaysToItsSummaryAndServers() throws {
        try assertFixture(named: "full_doubles_bo3")
    }

    func testTheSinglesAnnouncementsMatchTheGoldenFile() throws {
        let played = try FixtureMatch.play(named: "full_singles_bo3")
        let transcript = played.transcript.joined(separator: "\n") + "\n"
        let golden = "full_singles_bo3.announcements.txt"

        if ProcessInfo.processInfo.environment["CHAIR_RECORD_GOLDEN"] == "1" {
            let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/\(golden)")
            try transcript.write(to: url, atomically: true, encoding: .utf8)
            XCTFail("recorded \(golden); rerun without CHAIR_RECORD_GOLDEN")
            return
        }
        let expected = try XCTUnwrap(String(data: TestBundle.data(named: golden, in: .module), encoding: .utf8))
        XCTAssertEqual(transcript, expected, "announcements changed; rerun with CHAIR_RECORD_GOLDEN=1 if intended")
    }

    private func assertFixture(named name: String) throws {
        let played = try FixtureMatch.play(named: name)

        XCTAssertEqual(FixtureMatch.scoreline(played.log.state.summary), played.fixture.summary)
        XCTAssertEqual(played.log.state.phase, .complete(winner: played.fixture.winner))
        XCTAssertEqual(played.gameServers, played.fixture.gameServers)
        let replayed = try MatchLog.replay(rules: played.fixture.rules, format: played.fixture.format, events: played.fixture.events)
        XCTAssertEqual(replayed, played.log.state)
    }
}

struct FixtureMatch: Decodable {
    struct Played {
        let fixture: FixtureMatch
        let log: MatchLog
        let gameServers: [PlayerSlot]
        let transcript: [String]
    }

    let rules: MatchRules
    let format: MatchFormat
    let summary: String
    let winner: Side
    let gameServers: [PlayerSlot]
    let events: [TimedEvent]

    static func play(named name: String) throws -> Played {
        let fixture = try TestBundle.decode(FixtureMatch.self, named: name, in: .module)
        var log = try MatchLog(rules: fixture.rules, format: fixture.format)
        var servers: [PlayerSlot] = []
        var transcript: [String] = []
        var lastGame: [Int]?
        for (index, timed) in fixture.events.enumerated() {
            let game = [log.state.sets.count, log.state.currentSet.a + log.state.currentSet.b]
            if timed.event.startsARally, game != lastGame {
                servers.append(log.state.server)
                lastGame = game
            }
            let calls = try log.append(timed)
            transcript.append("\(index) \(text(timed.event)): \(calls.map(text).joined(separator: ", "))")
        }
        return Played(fixture: fixture, log: log, gameServers: servers, transcript: transcript)
    }

    static func scoreline(_ sets: [SetSummary]) -> String {
        sets.map { set in
            let games = "\(set.a)–\(set.b)"
            guard let tiebreak = set.tiebreak else { return games }
            return games + "(\(tiebreak.a)–\(tiebreak.b))"
        }.joined(separator: " ")
    }

    static func text(_ event: MatchEvent) -> String {
        switch event {
        case let .pointWon(winner, outcome, ending):
            (["point", winner.rawValue] + [outcome?.rawValue, ending?.rawValue].compactMap(\.self)).joined(separator: " ")
        case .fault: "fault"
        case .let: "let"
        case .undo: "undo"
        case .setScore: "set score"
        case .swapServer: "swap server"
        case let .swapReceivers(side): "swap receivers \(side.rawValue)"
        case .swapEnds: "swap ends"
        case let .retire(side): "retire \(side.rawValue)"
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func text(_ call: Announcement) -> String {
        switch call {
        case .ace: "ace"
        case .out: "out"
        case .net: "net"
        case let .score(a, b, serverSide): "score \(a.rawValue)-\(b.rawValue) server \(serverSide.rawValue)"
        case .deuce: "deuce"
        case let .advantage(side): "advantage \(side.rawValue)"
        case let .game(side): "game \(side.rawValue)"
        case .receiverChoosesSide: "receiver chooses side"
        case .fault: "fault"
        case .doubleFault: "double fault"
        case let .let(firstServe): firstServe ? "let first serve" : "let second serve"
        case let .gameAndSet(side, set): "game and set \(side.rawValue) \(set.a)-\(set.b)"
        case let .gameSetMatch(side, sets): "game set match \(side.rawValue) \(scoreline(sets))"
        case let .retired(side): "retired \(side.rawValue)"
        case let .tiebreakScore(a, b, serverSide): "tiebreak \(a)-\(b) server \(serverSide.rawValue)"
        case .changeEnds: "change ends"
        case let .chooseServer(side): "choose server \(side.rawValue)"
        case let .correction(snapshot): "correction \(scoreline(snapshot.sets.map { SetSummary(a: $0.a, b: $0.b) }))"
        }
    }
}

private extension MatchEvent {
    var startsARally: Bool {
        switch self {
        case .pointWon, .fault: true
        default: false
        }
    }
}
