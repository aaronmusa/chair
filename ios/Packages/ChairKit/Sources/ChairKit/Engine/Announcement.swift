//
//  Announcement.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/28/26.
//

public enum Announcement: Codable, Equatable, Sendable {
    case score(a: GameScore, b: GameScore, serverSide: Side)
    case deuce
    case advantage(Side)
    case game(Side)
    case receiverChoosesSide
    case fault
    case doubleFault
    case `let`(firstServe: Bool)
    case gameAndSet(Side, SetScore)
    case gameSetMatch(Side, [SetSummary])
    case retired(Side)
    case tiebreakScore(a: Int, b: Int, serverSide: Side)
    case changeEnds
    case chooseServer(Side)
    case correction(ScoreSnapshot)

    public var serverFirstScores: (server: GameScore, receiver: GameScore)? {
        guard case let .score(a, b, serverSide) = self else { return nil }
        return serverSide == .a ? (a, b) : (b, a)
    }
}

public enum EngineError: Error, Equatable, Sendable {
    case matchOver
    case setInProgress
    case undoLimit
    case unsupported(MatchEvent)
}

public extension PlayerSlot {
    var side: Side {
        self == .a1 || self == .a2 ? .a : .b
    }
}

public extension Side {
    var opponent: Side {
        self == .a ? .b : .a
    }
}
