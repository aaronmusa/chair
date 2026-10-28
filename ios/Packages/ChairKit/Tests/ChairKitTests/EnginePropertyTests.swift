//
//  EnginePropertyTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/28/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

final class EnginePropertyTests: XCTestCase {
    func testAThousandRandomLogsReplayExactly() throws {
        var completed = 0
        var tiebreaks = 0
        for seed in UInt64(1) ... 1000 {
            var generator = SplitMix(seed: seed)
            let log: MatchLog
            do {
                log = try Self.randomLog(using: &generator)
            } catch {
                XCTFail("seed \(seed): a valid event threw \(error)")
                continue
            }
            if case .complete = log.state.phase {
                completed += 1
            }
            tiebreaks += log.state.completedTiebreaks.count { $0 != nil }
            let replayed = try MatchLog.replay(rules: log.rules, format: log.format, events: log.events)
            XCTAssertEqual(replayed, log.state, "seed \(seed): replay differs")
            if seed.isMultiple(of: 50) {
                let decoded = try JSONDecoder().decode(MatchLog.self, from: JSONEncoder().encode(log))
                XCTAssertEqual(decoded, log, "seed \(seed): Codable round trip differs")
            }
            for (index, set) in log.state.summary.enumerated() where Self.isTiebreakSet(index, rules: log.rules) {
                XCTAssertLessThanOrEqual(max(set.a, set.b), 7, "seed \(seed): set \(index + 1) is \(set.a)–\(set.b)")
            }
        }
        XCTAssertGreaterThan(completed, 100, "the generator should finish a good share of matches")
        XCTAssertGreaterThan(tiebreaks, 50, "the generator should reach tiebreaks")
    }

    private static func randomLog(using generator: inout SplitMix) throws -> MatchLog {
        let rules = MatchRules(
            sets: MatchRules.Sets.allCases.randomElement(using: &generator) ?? .bestOf3,
            deuce: MatchRules.Deuce.allCases.randomElement(using: &generator) ?? .advantage,
            finalSet: MatchRules.FinalSet.allCases.randomElement(using: &generator) ?? .tiebreak7,
            firstServer: Side.allCases.randomElement(using: &generator) ?? .a
        )
        let format = MatchFormat.allCases.randomElement(using: &generator) ?? .singles
        var log = try MatchLog(rules: rules, format: format)
        var lastWasUndoableInSet = false
        for second in 0 ..< Int.random(in: 1 ... 400, using: &generator) {
            if case .complete = log.state.phase {
                break
            }
            let event = nextEvent(for: log.state, canUndo: lastWasUndoableInSet, using: &generator)
            let setsBefore = log.state.sets.count
            try log.append(TimedEvent(event, at: Fixtures.matchDay.addingTimeInterval(TimeInterval(second))))
            lastWasUndoableInSet = event.isPointOrServe && log.state.sets.count == setsBefore
        }
        return log
    }

    private static func nextEvent(
        for state: MatchState,
        canUndo: Bool,
        using generator: inout SplitMix
    ) -> MatchEvent {
        let setStart = state.currentSet == SetScore(a: 0, b: 0) && state.currentGame == .loveAll && state.faultCount == 0
        let roll = Int.random(in: 0 ..< 100, using: &generator)
        switch roll {
        case 0 ..< 4 where setStart: return .swapServer
        case 4 ..< 8 where setStart: return .swapReceivers(Side.allCases.randomElement(using: &generator) ?? .a)
        case 8 ..< 12 where canUndo: return .undo
        case 12 ..< 22: return .fault
        case 22 ..< 25: return .let
        case 25 ..< 27: return .swapEnds
        default:
            return .pointWon(
                by: Side.allCases.randomElement(using: &generator) ?? .a,
                outcome: [nil, .ace, .winner, .unforcedError].randomElement(using: &generator).flatMap(\.self),
                ending: [nil, .out, .net].randomElement(using: &generator).flatMap(\.self)
            )
        }
    }

    private static func isTiebreakSet(
        _ index: Int,
        rules: MatchRules
    ) -> Bool {
        let decidingIndex = rules.sets == .bestOf3 ? 2 : 4
        return !(index == decidingIndex && rules.finalSet == .advantage)
    }
}

private extension MatchEvent {
    var isPointOrServe: Bool {
        switch self {
        case .pointWon, .fault, .let: true
        default: false
        }
    }
}

private struct SplitMix: RandomNumberGenerator {
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
