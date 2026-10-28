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
        default:
            throw EngineError.unsupported(event)
        }
    }

    static func point(
        to winner: Side,
        in state: MatchState
    ) throws -> (MatchState, [Announcement]) {
        if case .complete = state.phase {
            throw EngineError.matchOver
        }
        var next = state
        next.phase = .inProgress
        next.faultCount = 0

        guard case let .standard(a, b) = state.currentGame else {
            return (next, [])
        }
        switch GameRules.advance(a: a, b: b, winner: winner, noAd: state.rules.deuce == .noAd) {
        case let .continues(newA, newB):
            next.currentGame = .standard(a: newA, b: newB)
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
    var next: GameScore {
        switch self {
        case .love: .fifteen
        case .fifteen: .thirty
        case .thirty: .forty
        case .forty, .advantage: .advantage
        }
    }
}
