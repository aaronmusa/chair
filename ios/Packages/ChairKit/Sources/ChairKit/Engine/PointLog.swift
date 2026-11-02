//
//  PointLog.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/2/26.
//

public enum FlipError: Error, Equatable, Sendable {
    case notAPoint
    case aceOrDoubleFault
    case otherSet
    case changedSince
}

public struct LoggedPoint: Equatable, Sendable {
    public let index: Int
    public let number: Int
    public let winner: Side
    public let outcome: PointOutcome?
    public let ending: PointEnding?
}

public extension MatchLog {
    var currentGamePoints: [LoggedPoint] {
        var state = MatchState.initial(rules: rules, format: format)
        var points: [LoggedPoint] = []
        for (index, timed) in events.enumerated() where timed.isEffective {
            let gameBefore = GameKey(state)
            guard let next = try? ScoringEngine.apply(timed.event, to: state).0 else { continue }
            state = next
            guard case let .pointWon(winner, outcome, ending) = timed.event else { continue }
            if GameKey(state) != gameBefore {
                points = []
                continue
            }
            points.append(LoggedPoint(index: index, number: points.count + 1, winner: winner, outcome: outcome, ending: ending))
        }
        return points
    }

    func flipEvents(at index: Int) throws -> [MatchEvent] {
        guard events.indices.contains(index), events[index].isEffective,
              case let .pointWon(winner, outcome, ending) = events[index].event else {
            throw FlipError.notAPoint
        }
        guard outcome != .ace, outcome != .doubleFault else {
            throw FlipError.aceOrDoubleFault
        }
        let before = try Self.replay(rules: rules, format: format, events: Array(events[..<index]))
        guard before.sets.count == state.sets.count else {
            throw FlipError.otherSet
        }
        let later = events[(index + 1)...].filter(\.isEffective).map(\.event)
        guard later.allSatisfy(\.isReplayable) else {
            throw FlipError.changedSince
        }
        let replayed = later.filter(\.isUndoable)
        let flipped = MatchEvent.pointWon(by: winner.opponent, outcome: outcome, ending: ending)
        return Array(repeating: .undo, count: replayed.count + 1) + [flipped] + replayed
    }
}

struct GameKey: Equatable {
    let sets: Int
    let currentSet: SetScore

    init(_ state: MatchState) {
        sets = state.sets.count
        currentSet = state.currentSet
    }
}

private extension MatchEvent {
    var isReplayable: Bool {
        switch self {
        case .pointWon, .fault, .let, .swapEnds: true
        default: false
        }
    }
}
