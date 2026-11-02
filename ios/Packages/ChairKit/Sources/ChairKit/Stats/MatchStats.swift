//
//  MatchStats.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation

public struct SideStats: Equatable, Sendable {
    public var pointsWon = 0
    public var aces = 0
    public var doubleFaults = 0
    public var winners = 0
    public var unforcedErrors = 0
    public var forcedErrors = 0
    public var servePoints = 0
    public var firstServesIn = 0
    public var firstServePointsWon = 0
    public var breakPointsFaced = 0
    public var breakPointsSaved = 0
    public var breakPointChances = 0
    public var breakPointsWon = 0

    public init() {}
}

public struct PlayedPoint: Equatable, Sendable {
    public let number: Int
    public let set: Int
    public let game: Int
    public let winner: Side
    public let server: Side
    public let outcome: PointOutcome?
    public let ending: PointEnding?
    public let scoreBefore: GameState
    public let setBefore: SetScore
}

public struct MatchStats: Equatable, Sendable {
    public private(set) var sides: [Side: SideStats] = [.a: SideStats(), .b: SideStats()]
    public private(set) var points: [PlayedPoint] = []
    public private(set) var longestGame = 0
    public private(set) var duration: TimeInterval = 0
    public private(set) var hasTaggedData = false

    public init(log: MatchLog) {
        let effective = log.events.filter(\.isEffective)
        if let first = effective.first, let last = effective.last {
            duration = last.at.timeIntervalSince(first.at)
        }
        var state = MatchState.initial(rules: log.rules, format: log.format)
        var gameLength = 0
        for timed in effective {
            guard let next = try? ScoringEngine.apply(timed.event, to: state).0 else { continue }
            if let point = rallyResult(timed.event, in: state) {
                record(point, before: state)
                gameLength += 1
                if GameKey(next) != GameKey(state) {
                    longestGame = max(longestGame, gameLength)
                    gameLength = 0
                }
            }
            if case .fault = timed.event {
                hasTaggedData = true
            }
            state = next
        }
        longestGame = max(longestGame, gameLength)
    }

    public subscript(side: Side) -> SideStats {
        sides[side] ?? SideStats()
    }

    private struct RallyResult {
        let winner: Side
        let outcome: PointOutcome?
        let ending: PointEnding?
    }

    private func rallyResult(
        _ event: MatchEvent,
        in state: MatchState
    ) -> RallyResult? {
        switch event {
        case let .pointWon(winner, outcome, ending):
            RallyResult(winner: winner, outcome: outcome, ending: ending)
        case .fault where state.faultCount == 1:
            RallyResult(winner: state.server.side.opponent, outcome: .doubleFault, ending: nil)
        default:
            nil
        }
    }

    private mutating func record(
        _ point: RallyResult,
        before state: MatchState
    ) {
        if point.outcome != nil {
            hasTaggedData = true
        }
        sides[point.winner, default: SideStats()].pointsWon += 1
        recordOutcome(point, server: state.server.side)
        recordServe(point, before: state)
        recordBreakPoint(point, before: state)
        points.append(PlayedPoint(
            number: points.count + 1,
            set: state.sets.count + 1,
            game: state.currentSet.a + state.currentSet.b + 1,
            winner: point.winner,
            server: state.server.side,
            outcome: point.outcome,
            ending: point.ending,
            scoreBefore: state.currentGame,
            setBefore: state.currentSet
        ))
    }

    private mutating func recordOutcome(
        _ point: RallyResult,
        server: Side
    ) {
        let loser = point.winner.opponent
        switch point.outcome {
        case .ace: sides[server, default: SideStats()].aces += 1
        case .doubleFault: sides[server, default: SideStats()].doubleFaults += 1
        case .winner: sides[point.winner, default: SideStats()].winners += 1
        case .unforcedError: sides[loser, default: SideStats()].unforcedErrors += 1
        case .forcedError: sides[loser, default: SideStats()].forcedErrors += 1
        case .let, nil: break
        }
    }

    private mutating func recordServe(
        _ point: RallyResult,
        before state: MatchState
    ) {
        let server = state.server.side
        sides[server, default: SideStats()].servePoints += 1
        guard state.faultCount == 0, point.outcome != .doubleFault else { return }
        sides[server, default: SideStats()].firstServesIn += 1
        if point.winner == server {
            sides[server, default: SideStats()].firstServePointsWon += 1
        }
    }

    private mutating func recordBreakPoint(
        _ point: RallyResult,
        before state: MatchState
    ) {
        guard Self.isBreakPoint(state) else { return }
        let server = state.server.side
        let receiver = server.opponent
        sides[server, default: SideStats()].breakPointsFaced += 1
        sides[receiver, default: SideStats()].breakPointChances += 1
        if point.winner == server {
            sides[server, default: SideStats()].breakPointsSaved += 1
        } else {
            sides[receiver, default: SideStats()].breakPointsWon += 1
        }
    }

    private static func isBreakPoint(_ state: MatchState) -> Bool {
        guard case let .standard(a, b) = state.currentGame else { return false }
        let (serverScore, receiverScore) = state.server.side == .a ? (a, b) : (b, a)
        if receiverScore == .advantage {
            return true
        }
        guard receiverScore == .forty else { return false }
        return serverScore != .advantage && (serverScore != .forty || state.rules.deuce == .noAd)
    }
}
