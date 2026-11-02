//
//  NewMatchViewModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import Observation

import ChairKit

@MainActor
@Observable
final class NewMatchViewModel {
    var setup: NewMatchSetup
    private(set) var showsErrors = false
    private(set) var startError: String?

    private let repository: (any MatchRepository)?
    private let clock: any ClockProvider

    init(
        defaults: MatchDefaults,
        repository: (any MatchRepository)?,
        clock: any ClockProvider
    ) {
        setup = NewMatchSetup(defaults: defaults)
        self.repository = repository
        self.clock = clock
    }

    var isDoubles: Bool {
        setup.format == .doubles
    }

    func label(for slot: PlayerSlot) -> String {
        guard isDoubles else { return slot.side == .a ? "Player A" : "Player B" }
        return "Player \(slot.rawValue)"
    }

    func displayName(for slot: PlayerSlot) -> String {
        let name = (setup.names[slot] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? label(for: slot) : name
    }

    func error(for slot: PlayerSlot) -> String? {
        guard showsErrors else { return nil }
        switch setup.nameErrors[slot] {
        case .empty: return "Enter a name"
        case .duplicate: return "Each player needs a different name"
        case nil: return nil
        }
    }

    func start() -> UUID? {
        showsErrors = true
        startError = nil
        guard setup.isValid else { return nil }
        guard let repository else {
            startError = "Matches can't be saved right now. Try again."
            return nil
        }
        do {
            let match = try setup.makeMatch(at: clock.now)
            try repository.save(match)
            return match.remoteID
        } catch {
            startError = "Couldn't start the match. Try again."
            return nil
        }
    }
}

extension PlayerSlot {
    var side: Side {
        self == .a1 || self == .a2 ? .a : .b
    }
}
