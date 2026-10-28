//
//  MatchLogMapping.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/28/26.
//

import Foundation

enum PayloadCoding {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()
}

public enum PointEventKind: String, Codable, Sendable, CaseIterable {
    case point
    case fault
    case `let`
    case undo
    case setScore = "set_score"
    case swapServer = "swap_server"
    case swapEnds = "swap_ends"
    case swapReceivers = "swap_receivers"
    case retire
}

public enum MatchLogMappingError: Error, Equatable {
    case unknownKind(String)
    case missingPayload(index: Int)
    case missingWinner(index: Int)
}

public extension MatchLog {
    func pointEvents(updatedAt: Date) -> [PointEvent] {
        Self.pointEvents(events, updatedAt: updatedAt)
    }

    init(
        rules: MatchRules,
        format: MatchFormat = .singles,
        pointEvents: [PointEvent]
    ) throws {
        try self.init(rules: rules, format: format, events: Self.events(from: pointEvents))
    }

    static func pointEvents(
        _ events: [TimedEvent],
        updatedAt: Date
    ) -> [PointEvent] {
        events.enumerated().map { index, timed in
            let (kind, payload) = Self.columns(for: timed.event)
            let (source, confidence) = Self.columns(for: timed.source)
            return PointEvent(
                index: index,
                at: timed.at,
                winnerSide: timed.event.winner,
                outcome: timed.event.pointOutcome,
                source: source,
                confidence: confidence,
                eventKind: kind.rawValue,
                undone: timed.undone,
                payload: payload,
                updatedAt: updatedAt,
                syncState: .pendingUpload
            )
        }
    }

    static func events(from pointEvents: [PointEvent]) throws -> [TimedEvent] {
        try pointEvents.sorted { $0.index < $1.index }.map(timedEvent(from:))
    }

    private static func columns(for event: MatchEvent) -> (PointEventKind, Data?) {
        switch event {
        case let .pointWon(_, _, ending): (.point, ending.flatMap(encode))
        case .fault: (.fault, nil)
        case .let: (.let, nil)
        case .undo: (.undo, nil)
        case let .setScore(snapshot): (.setScore, encode(snapshot))
        case .swapServer: (.swapServer, nil)
        case .swapEnds: (.swapEnds, nil)
        case let .swapReceivers(side): (.swapReceivers, encode(side))
        case let .retire(side): (.retire, encode(side))
        }
    }

    private static func columns(for source: EventSource) -> (String, Double?) {
        switch source {
        case .manual: ("manual", nil)
        case let .camera(confidence): ("camera", confidence)
        case .shout: ("shout", nil)
        case .gesture: ("gesture", nil)
        case .referee: ("referee", nil)
        case .watch: ("watch", nil)
        }
    }

    private static func timedEvent(from row: PointEvent) throws -> TimedEvent {
        guard let kind = PointEventKind(rawValue: row.eventKind) else {
            throw MatchLogMappingError.unknownKind(row.eventKind)
        }
        return try TimedEvent(event(kind, row), at: row.at, source: source(row), undone: row.undone)
    }

    private static func event(
        _ kind: PointEventKind,
        _ row: PointEvent
    ) throws -> MatchEvent {
        switch kind {
        case .point: try pointWon(row)
        case .fault: .fault
        case .let: .let
        case .undo: .undo
        case .setScore: try .setScore(require(ScoreSnapshot.self, row))
        case .swapServer: .swapServer
        case .swapEnds: .swapEnds
        case .swapReceivers: try .swapReceivers(require(Side.self, row))
        case .retire: try .retire(require(Side.self, row))
        }
    }

    private static func pointWon(_ row: PointEvent) throws -> MatchEvent {
        guard let winner = row.winnerSide else {
            throw MatchLogMappingError.missingWinner(index: row.index)
        }
        return .pointWon(by: winner, outcome: row.outcome, ending: row.payload.flatMap { decode(PointEnding.self, $0) })
    }

    private static func source(_ row: PointEvent) -> EventSource {
        switch row.source {
        case "camera": .camera(confidence: row.confidence ?? 0)
        case "shout": .shout
        case "gesture": .gesture
        case "referee": .referee
        case "watch": .watch
        default: .manual
        }
    }

    private static func encode(_ value: some Encodable) -> Data? {
        try? PayloadCoding.encoder.encode(value)
    }

    private static func decode<T: Decodable>(
        _: T.Type,
        _ data: Data
    ) -> T? {
        try? JSONDecoder().decode(T.self, from: data)
    }

    private static func require<T: Decodable>(
        _ type: T.Type,
        _ row: PointEvent
    ) throws -> T {
        guard let data = row.payload, let value = decode(type, data) else {
            throw MatchLogMappingError.missingPayload(index: row.index)
        }
        return value
    }
}

private extension MatchEvent {
    var winner: Side? {
        if case let .pointWon(by, _, _) = self {
            return by
        }
        return nil
    }

    var pointOutcome: PointOutcome? {
        if case let .pointWon(_, outcome, _) = self {
            return outcome
        }
        return nil
    }
}
