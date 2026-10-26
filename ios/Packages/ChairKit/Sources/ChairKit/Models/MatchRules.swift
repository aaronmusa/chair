//
//  MatchRules.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

public enum MatchFormat: String, Codable, Sendable, CaseIterable {
    case singles
    case doubles
}

public enum MatchStatus: String, Codable, Sendable, CaseIterable {
    case inProgress = "in_progress"
    case completed
    case abandoned
}

public enum Side: String, Codable, Sendable, CaseIterable {
    case a = "A"
    case b = "B"
}

public struct MatchRules: Codable, Hashable, Sendable {
    public enum Sets: String, Codable, Sendable, CaseIterable {
        case bestOf3
        case bestOf5
    }

    public enum Deuce: String, Codable, Sendable, CaseIterable {
        case advantage
        case noAd
    }

    public enum FinalSet: String, Codable, Sendable, CaseIterable {
        case tiebreak7
        case tiebreak10
        case advantage
    }

    public var sets: Sets
    public var deuce: Deuce
    public var finalSet: FinalSet
    public var firstServer: Side

    public init(
        sets: Sets = .bestOf3,
        deuce: Deuce = .advantage,
        finalSet: FinalSet = .tiebreak7,
        firstServer: Side = .a
    ) {
        self.sets = sets
        self.deuce = deuce
        self.finalSet = finalSet
        self.firstServer = firstServer
    }
}

public enum PointOutcome: String, Codable, Sendable, CaseIterable {
    case ace
    case doubleFault
    case winner
    case unforcedError
    case forcedError
    case `let`
}

public struct SetScore: Codable, Hashable, Sendable {
    public var a: Int
    public var b: Int

    public init(
        a: Int,
        b: Int
    ) {
        self.a = a
        self.b = b
    }
}

public enum SyncState: String, Codable, Sendable {
    case synced
    case pendingUpload
    case pendingDelete
}
