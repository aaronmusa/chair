//
//  UmpireCall.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

public enum CallPriority: Int, Codable, Sendable, Comparable {
    case score
    case call
    case structural

    public init(_ announcements: [Announcement]) {
        self = announcements.map(Self.priority).max() ?? .score
    }

    public static func < (
        lhs: CallPriority,
        rhs: CallPriority
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    private static func priority(_ announcement: Announcement) -> CallPriority {
        switch announcement {
        case .game, .gameAndSet, .gameSetMatch, .retired, .changeEnds, .correction: .structural
        case .ace, .out, .net, .fault, .doubleFault, .let, .receiverChoosesSide, .chooseServer: .call
        case .score, .deuce, .advantage, .tiebreakScore: .score
        }
    }
}

public struct UmpireCall: Codable, Equatable, Sendable {
    public let cue: CueKind?
    public let text: String
    public let priority: CallPriority

    public init(
        cue: CueKind?,
        text: String,
        priority: CallPriority
    ) {
        self.cue = cue
        self.text = text
        self.priority = priority
    }
}
