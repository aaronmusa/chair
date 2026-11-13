//
//  ScoreboardModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import ChairKit

struct ScoreboardModel: Equatable {
    struct Row: Equatable {
        let side: Side
        let name: String
        let games: [Int]
        let points: String
        let isServing: Bool
    }

    let rows: [Row]
    let setLabel: String
    let setsLead: String

    var headline: String {
        let server = rows.first(where: \.isServing) ?? rows[0]
        let receiver = rows.first { $0.side != server.side } ?? rows[0]
        return "\(server.points)–\(receiver.points)"
    }

    init(
        state: MatchState,
        names: [Side: String]
    ) {
        let allSets = state.sets + [state.currentSet]
        rows = Side.allCases.map { side in
            Row(
                side: side,
                name: names[side] ?? "Player \(side.rawValue)",
                games: allSets.map { side == .a ? $0.a : $0.b },
                points: Self.points(state.currentGame, side: side),
                isServing: state.server.side == side
            )
        }
        let game = state.currentSet.a + state.currentSet.b + 1
        setLabel = "Set \(state.sets.count + 1) · Game \(game)"
        let won = state.sets.reduce(into: (a: 0, b: 0)) { total, set in
            if set.a > set.b { total.a += 1 } else { total.b += 1 }
        }
        setsLead = "Sets \(won.a)–\(won.b)"
    }

    private static func points(
        _ game: GameState,
        side: Side
    ) -> String {
        switch game {
        case let .standard(a, b):
            switch side == .a ? a : b {
            case .love: "0"
            case .fifteen: "15"
            case .thirty: "30"
            case .forty: "40"
            case .advantage: "AD"
            }
        case let .tiebreak(a, b, _):
            "\(side == .a ? a : b)"
        }
    }
}
