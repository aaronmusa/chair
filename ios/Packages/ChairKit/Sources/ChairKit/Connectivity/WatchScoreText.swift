//
//  WatchScoreText.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation

public extension WatchState {
    var theirSide: Side {
        mySide == .a ? .b : .a
    }

    var title: String {
        "\(names(of: mySide)) v \(names(of: theirSide))"
    }

    func names(of side: Side) -> String {
        let slots = PlayerSlot.allCases.filter { $0.side == side }
        let found = slots.compactMap { names[$0] }.filter { !$0.isEmpty }
        return found.isEmpty ? (side == mySide ? "You" : "Them") : found.joined(separator: " + ")
    }

    var setsLine: String {
        (score.sets + [score.currentSet])
            .map { "\(games($0, mySide))–\(games($0, theirSide))" }
            .joined(separator: " ")
    }

    var pointsLine: String {
        "\(points(for: mySide))–\(points(for: theirSide))"
    }

    var setGameLabel: String {
        let set = "Set \(score.sets.count + 1)"
        if case .tiebreak = score.currentGame {
            return "\(set) · Tiebreak"
        }
        return "\(set) · Game \(score.currentSet.a + score.currentSet.b + 1)"
    }

    var isDoubles: Bool {
        names.keys.contains { $0 == .a2 || $0 == .b2 }
    }

    func rowName(for side: Side) -> String {
        let slots = PlayerSlot.allCases.filter { $0.side == side && names[$0] != nil }
        let labels = slots.map { $0 == mySlot ? "You" : Self.short(names[$0] ?? "") }
        return labels.isEmpty ? (side == mySide ? "You" : "Them") : labels.joined(separator: " + ")
    }

    func games(for side: Side) -> [Int] {
        (score.sets + [score.currentSet]).map { games($0, side) }
    }

    var isSetStart: Bool {
        phase == .getSet && score.currentSet == SetScore(a: 0, b: 0) && score.currentGame == .loveAll
    }

    var resultText: String {
        let played = score.currentSet == SetScore(a: 0, b: 0) ? score.sets : score.sets + [score.currentSet]
        let sets = played.map { "\(games($0, mySide))–\(games($0, theirSide))" }.joined(separator: " ")
        let lead = switch winner {
        case mySide: "You won"
        case theirSide: "You lost"
        default: "Match ended"
        }
        return sets.isEmpty ? lead : "\(lead) \(sets)"
    }

    func name(of slot: PlayerSlot) -> String {
        slot == mySlot ? "You" : (names[slot] ?? "Partner")
    }

    var serveStrip: String {
        let who = server == mySlot ? "You serve" : "\(Self.short(names[server] ?? "Them")) serves"
        let serveNote = serve == .second ? " · 2nd serve" : ""
        return "\(who) · \(serverCourtSide.rawValue)\(serveNote)"
    }

    func points(for side: Side) -> String {
        switch score.currentGame {
        case let .standard(a, b):
            Self.text(side == .a ? a : b)
        case let .tiebreak(a, b, _):
            "\(side == .a ? a : b)"
        }
    }

    private func games(
        _ set: SetScore,
        _ side: Side
    ) -> Int {
        side == .a ? set.a : set.b
    }

    private static func short(_ name: String) -> String {
        name.count > 8 ? String(name.prefix(8)) : name
    }

    private static func text(_ score: GameScore) -> String {
        switch score {
        case .love: "0"
        case .fifteen: "15"
        case .thirty: "30"
        case .forty: "40"
        case .advantage: "AD"
        }
    }
}

public extension WatchState {
    init(
        record: MatchRecord,
        log: MatchLog
    ) {
        let state = log.state
        let phase: WatchPhase = switch state.phase {
        case .notStarted: .getSet
        case .inProgress: .rally
        case .complete: .complete
        }
        self.init(
            matchID: record.id,
            names: Dictionary(record.players.map { ($0.slot, $0.name) }, uniquingKeysWith: { first, _ in first }),
            mySlot: record.localUserSlot ?? .a1,
            score: log.snapshot,
            serverCourtSide: state.serverCourtSide,
            serve: state.preRally.serve,
            phase: phase,
            deuceReceiver: state.doublesOrder?.deuceReceivers[(record.localUserSlot ?? .a1).side],
            winner: state.phase.winner
        )
    }
}

public extension MatchPhase {
    var winner: Side? {
        guard case let .complete(winner) = self else { return nil }
        return winner
    }
}
