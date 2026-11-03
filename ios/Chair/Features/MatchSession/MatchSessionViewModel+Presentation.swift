//
//  MatchSessionViewModel+Presentation.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import ChairKit

extension MatchSessionViewModel {
    var formatter: AnnouncementFormatter {
        AnnouncementFormatter(names: PlayerNames(names, doubles: state?.doublesOrder != nil))
    }

    var announcementText: String {
        guard let state else { return "" }
        return announcements.isEmpty ? formatter.score(state) : formatter.text(announcements, after: state)
    }

    var spokenText: String {
        guard let state else { return "" }
        let spoken = AnnouncementFormatter(names: formatter.names, verbosity: verbosity)
            .spoken(EngineOutput(state: state, announcements: announcements))
        return spoken.isEmpty ? announcementText : spoken
    }

    var playerNames: PlayerNames {
        formatter.names
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

    private var teamNames: [Side: String] {
        let doubles = state?.doublesOrder != nil
        let name = { (slot: PlayerSlot) in self.names[slot] ?? "Player \(slot.rawValue)" }
        guard doubles else { return [.a: name(.a1), .b: name(.b1)] }
        return [.a: "\(name(.a1)) and \(name(.a2))", .b: "\(name(.b1)) and \(name(.b2))"]
    }
}
