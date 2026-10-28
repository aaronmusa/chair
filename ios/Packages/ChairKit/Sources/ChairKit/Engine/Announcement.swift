//
//  Announcement.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/28/26.
//

public enum Announcement: Codable, Equatable, Sendable {
    case ace
    case out
    case net
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

    static func calls(
        for outcome: PointOutcome?,
        ending: PointEnding?
    ) -> [Announcement] {
        let call: [Announcement] = switch outcome {
        case .ace: [.ace]
        case .doubleFault: [.doubleFault]
        default: []
        }
        return switch ending {
        case .out: call + [.out]
        case .net: call + [.net]
        case nil: call
        }
    }

    public var serverFirstScores: (server: GameScore, receiver: GameScore)? {
        guard case let .score(a, b, serverSide) = self else { return nil }
        return serverSide == .a ? (a, b) : (b, a)
    }
}

public enum EngineError: Error, Equatable, Sendable {
    case matchOver
    case setInProgress
    case undoLimit
    case invalidScore(reason: String)
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
