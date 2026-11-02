//
//  NewMatchSetup.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation

public enum PlayerNameError: Equatable, Sendable {
    case empty
    case duplicate
}

public struct NewMatchSetup: Equatable, Sendable {
    public var format: MatchFormat
    public var rules: MatchRules
    public var names: [PlayerSlot: String]
    public var firstServers: [Side: PlayerSlot]
    public var deuceReceivers: [Side: PlayerSlot]

    public init(defaults: MatchDefaults) {
        format = defaults.format
        rules = defaults.rules
        names = [.a1: defaults.playerAName, .a2: "", .b1: "", .b2: ""]
        firstServers = [.a: .a1, .b: .b1]
        deuceReceivers = [.a: .a1, .b: .b1]
    }

    public var slots: [PlayerSlot] {
        format == .doubles ? [.a1, .a2, .b1, .b2] : [.a1, .b1]
    }

    public var nameErrors: [PlayerSlot: PlayerNameError] {
        var errors: [PlayerSlot: PlayerNameError] = [:]
        var seen: [String: PlayerSlot] = [:]
        for slot in slots {
            let key = trimmedName(slot).lowercased()
            if key.isEmpty {
                errors[slot] = .empty
            } else if let first = seen[key] {
                errors[first] = .duplicate
                errors[slot] = .duplicate
            } else {
                seen[key] = slot
            }
        }
        return errors
    }

    public var isValid: Bool {
        nameErrors.isEmpty
    }

    public func makeMatch(at date: Date) throws -> Match {
        let seats = seating
        var log = try MatchLog(rules: rules, format: format)
        for event in preRallyEvents(seats: seats) {
            try log.append(TimedEvent(event, at: date))
        }
        let match = Match(
            playedAt: date,
            format: format,
            rules: rules,
            status: .inProgress,
            inputMode: InputMode.manual.rawValue,
            createdAt: date,
            updatedAt: date
        )
        match.players = slots.map { slot in
            MatchPlayer(slot: slot, name: trimmedName(seats[slot] ?? slot), updatedAt: date)
        }
        match.points = log.pointEvents(updatedAt: date)
        return match
    }

    private var receivingSide: Side {
        rules.firstServer == .a ? .b : .a
    }

    private var seating: [PlayerSlot: PlayerSlot] {
        var seats = Dictionary(uniqueKeysWithValues: slots.map { ($0, $0) })
        guard format == .doubles, firstServers[receivingSide] == second(of: receivingSide) else { return seats }
        seats[first(of: receivingSide)] = second(of: receivingSide)
        seats[second(of: receivingSide)] = first(of: receivingSide)
        return seats
    }

    private func preRallyEvents(seats: [PlayerSlot: PlayerSlot]) -> [MatchEvent] {
        guard format == .doubles else { return [] }
        var events: [MatchEvent] = []
        if firstServers[rules.firstServer] == second(of: rules.firstServer) {
            events.append(.swapServer)
        }
        for side in [Side.a, .b] {
            let chosen = deuceReceivers[side] ?? first(of: side)
            if seats[first(of: side)] != chosen {
                events.append(.swapReceivers(side))
            }
        }
        return events
    }

    private func trimmedName(_ slot: PlayerSlot) -> String {
        (names[slot] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func first(of side: Side) -> PlayerSlot {
        side == .a ? .a1 : .b1
    }

    private func second(of side: Side) -> PlayerSlot {
        side == .a ? .a2 : .b2
    }
}
