//
//  ScoringEngine.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/28/26.
//

public enum ScoringEngine {
    public static func apply(
        _ event: MatchEvent,
        to state: MatchState
    ) throws -> (MatchState, [Announcement]) {
        switch event {
        case let .pointWon(winner, _, _):
            return try point(to: winner, in: state)
        case .fault:
            return try fault(in: state)
        case .let:
            try requireInPlay(state)
            return (state, [.let(firstServe: state.faultCount == 0)])
        default:
            throw EngineError.unsupported(event)
        }
    }

    static func requireInPlay(_ state: MatchState) throws {
        if case .complete = state.phase {
            throw EngineError.matchOver
        }
    }

    static func fault(in state: MatchState) throws -> (MatchState, [Announcement]) {
        try requireInPlay(state)
        guard state.faultCount == 1 else {
            var next = state
            next.phase = .inProgress
            next.faultCount = 1
            return (next, [.fault])
        }
        let (next, calls) = try point(to: state.receiver.side, in: state)
        return (next, [.doubleFault] + calls)
    }

    static func point(
        to winner: Side,
        in state: MatchState
    ) throws -> (MatchState, [Announcement]) {
        try requireInPlay(state)
        var next = state
        next.phase = .inProgress
        next.faultCount = 0

        guard case let .standard(a, b) = state.currentGame else {
            return (next, [])
        }
        switch GameRules.advance(a: a, b: b, winner: winner, noAd: state.rules.deuce == .noAd) {
        case let .continues(newA, newB):
            next.currentGame = .standard(a: newA, b: newB)
            next.serverCourtSide = GameRules.servingSide(a: newA, b: newB)
            return (next, GameRules.calls(a: newA, b: newB, serverSide: state.server.side, noAd: state.rules.deuce == .noAd))
        case .won:
            winGame(for: winner, in: &next)
            return (next, [.game(winner)])
        }
    }

    static func winGame(
        for winner: Side,
        in state: inout MatchState
    ) {
        if winner == .a {
            state.currentSet.a += 1
        } else {
            state.currentSet.b += 1
        }
        state.currentGame = .loveAll
        state.faultCount = 0
        state.serverCourtSide = .deuce
    }
}

enum GameRules {
    enum Result: Equatable {
        case continues(a: GameScore, b: GameScore)
        case won
    }

    static func advance(
        a: GameScore,
        b: GameScore,
        winner: Side,
        noAd: Bool
    ) -> Result {
        let (mine, theirs) = winner == .a ? (a, b) : (b, a)
        let (newMine, newTheirs): (GameScore, GameScore)
        switch (mine, theirs) {
        case (.forty, .forty) where noAd,
             (.forty, .love), (.forty, .fifteen), (.forty, .thirty),
             (.advantage, _):
            return .won
        case (.forty, .forty):
            (newMine, newTheirs) = (.advantage, .forty)
        case (.forty, .advantage):
            (newMine, newTheirs) = (.forty, .forty)
        default:
            (newMine, newTheirs) = (mine.next, theirs)
        }
        return winner == .a ? .continues(a: newMine, b: newTheirs) : .continues(a: newTheirs, b: newMine)
    }

    static func servingSide(
        a: GameScore,
        b: GameScore
    ) -> CourtSide {
        (a.pointsWon + b.pointsWon).isMultiple(of: 2) ? .deuce : .ad
    }

    static func calls(
        a: GameScore,
        b: GameScore,
        serverSide: Side,
        noAd: Bool
    ) -> [Announcement] {
        switch (a, b) {
        case (.forty, .forty):
            noAd ? [.deuce, .receiverChoosesSide] : [.deuce]
        case (.advantage, _):
            [.advantage(.a)]
        case (_, .advantage):
            [.advantage(.b)]
        default:
            [.score(a: a, b: b, serverSide: serverSide)]
        }
    }
}

extension GameScore {
    var pointsWon: Int {
        switch self {
        case .love: 0
        case .fifteen: 1
        case .thirty: 2
        case .forty: 3
        case .advantage: 4
        }
    }

    var next: GameScore {
        switch self {
        case .love: .fifteen
        case .fifteen: .thirty
        case .thirty: .forty
        case .forty, .advantage: .advantage
        }
    }
}
