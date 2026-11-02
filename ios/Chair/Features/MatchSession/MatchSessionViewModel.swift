//
//  MatchSessionViewModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import Observation

import ChairKit

enum SessionPhase: Equatable {
    case loading
    case getSet
    case rally
    case complete
    case failed(String)
}

@MainActor
@Observable
final class MatchSessionViewModel {
    private(set) var phase = SessionPhase.loading
    private(set) var state: MatchState?
    private(set) var announcements: [Announcement] = []
    private(set) var announcementID = 0
    private(set) var names: [PlayerSlot: String] = [:]
    private(set) var errorMessage: String?

    let matchID: UUID
    private let repository: (any MatchRepository)?
    private let clock: any ClockProvider
    private var match: Match?
    private var session: MatchSession?

    init(
        matchID: UUID,
        repository: (any MatchRepository)?,
        clock: any ClockProvider
    ) {
        self.matchID = matchID
        self.repository = repository
        self.clock = clock
    }

    var formatter: AnnouncementFormatter {
        AnnouncementFormatter(names: teamNames)
    }

    var announcementText: String {
        guard let state else { return "" }
        return announcements.isEmpty ? formatter.score(state) : formatter.text(announcements)
    }

    var getSet: GetSetPresentation? {
        state.map { GetSetPresentation(state: $0, names: names, announcements: announcements) }
    }

    var scoreboard: ScoreboardModel? {
        state.map { ScoreboardModel(state: $0, names: teamNames) }
    }

    func name(of side: Side) -> String {
        teamNames[side] ?? (side == .a ? "Player A" : "Player B")
    }

    func load() {
        guard phase == .loading else { return }
        do {
            guard let match = try repository?.fetch().first(where: { $0.remoteID == matchID }) else {
                phase = .failed("This match couldn't be found.")
                return
            }
            let log = try MatchLog(rules: match.rules, format: match.format, pointEvents: match.points)
            self.match = match
            names = Dictionary(uniqueKeysWithValues: match.players.map { ($0.slot, $0.name) })
            session = MatchSession(log: log)
            show(log.state, announcements: [])
        } catch {
            phase = .failed("This match couldn't be opened.")
        }
    }

    func playPoint() {
        guard phase == .getSet else { return }
        phase = .rally
    }

    func backToGetSet() {
        guard phase == .rally else { return }
        phase = .getSet
    }

    func pointWon(by side: Side) async {
        await apply(.pointWon(by: side, outcome: nil, ending: nil))
    }

    func apply(_ event: MatchEvent) async {
        guard let session, let match else { return }
        errorMessage = nil
        do {
            let output = try await session.apply(TimedEvent(event, at: clock.now))
            await match.update(from: session.log, at: clock.now)
            try repository?.save(match)
            show(output.state, announcements: output.announcements)
        } catch EngineError.undoLimit {
            errorMessage = "Nothing to undo in this set."
        } catch EngineError.setInProgress {
            errorMessage = "That can only change before the set's first point."
        } catch {
            errorMessage = "That couldn't be saved. Try again."
        }
    }

    private func show(
        _ state: MatchState,
        announcements: [Announcement]
    ) {
        self.state = state
        self.announcements = announcements
        announcementID += 1
        if case .complete = state.phase {
            phase = .complete
        } else {
            phase = .getSet
        }
    }

    private var teamNames: [Side: String] {
        let doubles = state?.doublesOrder != nil
        let name = { (slot: PlayerSlot) in self.names[slot] ?? "Player \(slot.rawValue)" }
        guard doubles else { return [.a: name(.a1), .b: name(.b1)] }
        return [.a: "\(name(.a1)) and \(name(.a2))", .b: "\(name(.b1)) and \(name(.b2))"]
    }
}
