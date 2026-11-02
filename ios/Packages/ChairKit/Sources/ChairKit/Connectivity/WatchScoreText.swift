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
            mySide: record.mySide,
            score: log.snapshot,
            serverCourtSide: state.serverCourtSide,
            serve: state.preRally.serve,
            phase: phase
        )
    }
}
