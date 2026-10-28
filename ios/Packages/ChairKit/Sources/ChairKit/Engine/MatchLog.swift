//
//  MatchLog.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/28/26.
//

public struct MatchLog: Codable, Equatable, Sendable {
    public let rules: MatchRules
    public let format: MatchFormat
    public private(set) var events: [TimedEvent]
    public private(set) var state: MatchState

    public init(
        rules: MatchRules,
        format: MatchFormat = .singles,
        events: [TimedEvent] = []
    ) throws {
        self.rules = rules
        self.format = format
        self.events = events
        state = try Self.replay(rules: rules, format: format, events: events)
    }

    public static func replay(
        rules: MatchRules,
        format: MatchFormat = .singles,
        events: [TimedEvent]
    ) throws -> MatchState {
        try events.filter(\.isEffective).reduce(MatchState.initial(rules: rules, format: format)) { state, timed in
            try ScoringEngine.apply(timed.event, to: state).0
        }
    }

    @discardableResult
    public mutating func append(_ timed: TimedEvent) throws -> [Announcement] {
        if case .undo = timed.event {
            return try undo(timed)
        }
        let (next, calls) = try ScoringEngine.apply(timed.event, to: state)
        events.append(timed)
        state = next
        return calls
    }

    public var snapshot: ScoreSnapshot {
        ScoreSnapshot(sets: state.sets, currentSet: state.currentSet, currentGame: state.currentGame, server: state.server)
    }

    private mutating func undo(_ timed: TimedEvent) throws -> [Announcement] {
        guard let target = events.lastIndex(where: { $0.isEffective && $0.event.isUndoable }),
              try setsPlayed(before: target) == state.sets.count else {
            throw EngineError.undoLimit
        }
        var updated = events
        updated[target].undone = true
        let replayed = try Self.replay(rules: rules, format: format, events: updated)
        updated.append(timed)
        events = updated
        state = replayed
        return [.correction(snapshot)]
    }

    private func setsPlayed(before index: Int) throws -> Int {
        try Self.replay(rules: rules, format: format, events: Array(events[..<index])).sets.count
    }

    enum CodingKeys: String, CodingKey {
        case rules, format, events
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            rules: container.decode(MatchRules.self, forKey: .rules),
            format: container.decode(MatchFormat.self, forKey: .format),
            events: container.decode([TimedEvent].self, forKey: .events)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rules, forKey: .rules)
        try container.encode(format, forKey: .format)
        try container.encode(events, forKey: .events)
    }
}

extension TimedEvent {
    var isEffective: Bool {
        guard !undone else { return false }
        if case .undo = event {
            return false
        }
        return true
    }
}

extension MatchEvent {
    var isUndoable: Bool {
        switch self {
        case .pointWon, .fault, .let, .swapServer, .swapReceivers: true
        case .undo, .setScore, .swapEnds, .retire: false
        }
    }
}
