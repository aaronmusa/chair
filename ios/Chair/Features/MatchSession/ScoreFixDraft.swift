//
//  ScoreFixDraft.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import ChairKit

struct ScoreFixDraft: Equatable {
    var sets: [SetScore]
    var currentSet: SetScore
    var pointsA: GameScore
    var pointsB: GameScore
    var tiebreakA: Int
    var tiebreakB: Int
    var server: PlayerSlot

    let rules: MatchRules
    let isDoubles: Bool

    init(state: MatchState) {
        sets = state.sets
        currentSet = state.currentSet
        server = state.server
        rules = state.rules
        isDoubles = state.doublesOrder != nil
        switch state.currentGame {
        case let .standard(a, b):
            (pointsA, pointsB, tiebreakA, tiebreakB) = (a, b, 0, 0)
        case let .tiebreak(a, b, _):
            (pointsA, pointsB, tiebreakA, tiebreakB) = (.love, .love, a, b)
        }
    }

    var isTiebreak: Bool {
        guard currentSet == SetScore(a: 6, b: 6) else { return false }
        return !(isDecidingSet && rules.finalSet == .advantage)
    }

    var servers: [PlayerSlot] {
        isDoubles ? [.a1, .a2, .b1, .b2] : [.a1, .b1]
    }

    var snapshot: ScoreSnapshot {
        let game: GameState = isTiebreak
            ? .tiebreak(a: tiebreakA, b: tiebreakB, target: tiebreakTarget)
            : .standard(a: pointsA, b: pointsB)
        return ScoreSnapshot(sets: sets, currentSet: currentSet, currentGame: game, server: server)
    }

    private var isDecidingSet: Bool {
        sets.count == (rules.sets == .bestOf3 ? 2 : 4)
    }

    private var tiebreakTarget: Int {
        isDecidingSet && rules.finalSet == .tiebreak10 ? 10 : 7
    }
}
