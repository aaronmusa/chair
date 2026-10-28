//
//  EngineTypes.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/28/26.
//

import Foundation

public enum CourtSide: String, Codable, Sendable, CaseIterable {
    case deuce
    case ad
}

public enum CourtEnd: String, Codable, Sendable, CaseIterable {
    case near
    case far
}

public enum PointEnding: String, Codable, Sendable, CaseIterable {
    case out
    case net
}

public enum EventSource: Codable, Equatable, Sendable {
    case manual
    case camera(confidence: Double)
    case shout
    case gesture
    case referee
    case watch
}

public enum MatchEvent: Codable, Equatable, Sendable {
    case pointWon(by: Side, outcome: PointOutcome?, ending: PointEnding?)
    case fault
    case `let`
    case undo
    case setScore(ScoreSnapshot)
    case swapServer
    case swapReceivers(Side)
    case swapEnds
    case retire(Side)
}

public struct TimedEvent: Codable, Equatable, Sendable {
    public var event: MatchEvent
    public var at: Date
    public var source: EventSource
    public var undone: Bool

    public init(
        _ event: MatchEvent,
        at: Date,
        source: EventSource = .manual,
        undone: Bool = false
    ) {
        self.event = event
        self.at = at
        self.source = source
        self.undone = undone
    }
}

public enum GameScore: String, Codable, Sendable, CaseIterable {
    case love
    case fifteen
    case thirty
    case forty
    case advantage
}

public typealias TiebreakScore = Int

public enum GameState: Codable, Equatable, Sendable {
    case standard(a: GameScore, b: GameScore)
    case tiebreak(a: TiebreakScore, b: TiebreakScore, target: Int)

    public static let loveAll = GameState.standard(a: .love, b: .love)
}

public enum MatchPhase: Codable, Equatable, Sendable {
    case notStarted
    case inProgress
    case complete(winner: Side)
}

public struct DoublesOrder: Codable, Equatable, Sendable {
    public var serving: [PlayerSlot]
    public var deuceReceivers: [Side: PlayerSlot]

    public init(
        serving: [PlayerSlot],
        deuceReceivers: [Side: PlayerSlot]
    ) {
        self.serving = serving
        self.deuceReceivers = deuceReceivers
    }

    public static func starting(with side: Side) -> DoublesOrder {
        let serving: [PlayerSlot] = side == .a ? [.a1, .b1, .a2, .b2] : [.b1, .a1, .b2, .a2]
        return DoublesOrder(serving: serving, deuceReceivers: [.a: .a1, .b: .b1])
    }
}

public struct ScoreSnapshot: Codable, Equatable, Sendable {
    public var sets: [SetScore]
    public var currentSet: SetScore
    public var currentGame: GameState
    public var server: PlayerSlot

    public init(
        sets: [SetScore],
        currentSet: SetScore,
        currentGame: GameState,
        server: PlayerSlot
    ) {
        self.sets = sets
        self.currentSet = currentSet
        self.currentGame = currentGame
        self.server = server
    }
}

public struct MatchState: Codable, Equatable, Sendable {
    public var rules: MatchRules
    public var sets: [SetScore]
    public var completedTiebreaks: [TiebreakSummary?]
    public var currentSet: SetScore
    public var currentGame: GameState
    public var server: PlayerSlot
    public var receiver: PlayerSlot
    public var serverCourtSide: CourtSide
    public var ends: [Side: CourtEnd]
    public var faultCount: Int
    public var phase: MatchPhase
    public var doublesOrder: DoublesOrder?
    public var tiebreakOpeningReceiver: PlayerSlot?

    public static func initial(
        rules: MatchRules,
        format: MatchFormat = .singles
    ) -> MatchState {
        let first = rules.firstServer
        return MatchState(
            rules: rules,
            sets: [],
            completedTiebreaks: [],
            currentSet: SetScore(a: 0, b: 0),
            currentGame: .loveAll,
            server: first == .a ? .a1 : .b1,
            receiver: first == .a ? .b1 : .a1,
            serverCourtSide: .deuce,
            ends: [.a: .near, .b: .far],
            faultCount: 0,
            phase: .notStarted,
            doublesOrder: format == .doubles ? .starting(with: first) : nil,
            tiebreakOpeningReceiver: nil
        )
    }
}
