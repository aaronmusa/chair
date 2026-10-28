//
//  ScoreFix.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/28/26.
//

enum ScoreFix {
    static func apply(
        _ snapshot: ScoreSnapshot,
        to state: MatchState
    ) throws -> MatchState {
        var next = state
        next.sets = snapshot.sets
        next.completedTiebreaks = snapshot.sets.indices.map { keptTiebreak(at: $0, from: state, sets: snapshot.sets) }
        next.currentSet = snapshot.currentSet
        next.currentGame = snapshot.currentGame
        next.faultCount = 0
        let winner = try validateSets(in: next)
        try validateCurrentSet(in: next, matchOver: winner != nil)
        try validateGame(in: next)
        try place(snapshot.server, from: state, in: &next)
        next.phase = phase(of: next, winner: winner)
        return next
    }

    private static func keptTiebreak(
        at index: Int,
        from state: MatchState,
        sets: [SetScore]
    ) -> TiebreakSummary? {
        guard state.sets.indices.contains(index), state.sets[index] == sets[index],
              state.completedTiebreaks.indices.contains(index) else { return nil }
        return state.completedTiebreaks[index]
    }

    private static func validateSets(in state: MatchState) throws -> Side? {
        var probe = state
        for (index, set) in state.sets.enumerated() {
            probe.sets = Array(state.sets[..<index])
            guard winner(of: probe) == nil else { throw invalid("a set is listed after the match was won") }
            guard isFinished(set, advantageSet: playsAdvantageSet(probe)) else {
                throw invalid("\(set.a)–\(set.b) is not a finished set")
            }
        }
        return winner(of: state)
    }

    private static func validateCurrentSet(
        in state: MatchState,
        matchOver: Bool
    ) throws {
        let set = state.currentSet
        guard set.a >= 0, set.b >= 0 else { throw invalid("games can't be negative") }
        if matchOver {
            guard set == SetScore(a: 0, b: 0), state.currentGame == .loveAll else {
                throw invalid("the match is already won")
            }
            return
        }
        let (high, low) = (max(set.a, set.b), min(set.a, set.b))
        let inProgress = playsAdvantageSet(state) ? high < 6 || high - low <= 1 : high <= 6 && !(high == 6 && low <= 4)
        guard inProgress else { throw invalid("\(set.a)–\(set.b) is a finished set") }
        guard case .tiebreak = state.currentGame else {
            if set == SetScore(a: 6, b: 6), !playsAdvantageSet(state) {
                throw invalid("6–6 is played as a tiebreak")
            }
            return
        }
        guard set == SetScore(a: 6, b: 6), !playsAdvantageSet(state) else { throw invalid("a tiebreak is only played at 6–6") }
    }

    private static func validateGame(in state: MatchState) throws {
        switch state.currentGame {
        case let .standard(a, b):
            if state.rules.deuce == .noAd, a == .advantage || b == .advantage {
                throw invalid("there's no advantage in a no-ad game")
            }
            if (a == .advantage && b != .forty) || (b == .advantage && a != .forty) {
                throw invalid("advantage needs the other side on forty")
            }
        case let .tiebreak(a, b, target):
            guard target == tiebreakTarget(state) else { throw invalid("this tiebreak is played to \(tiebreakTarget(state))") }
            let (high, low) = (max(a, b), min(a, b))
            guard low >= 0, high < target || high - low < 2 else { throw invalid("\(a)–\(b) is a finished tiebreak") }
        }
    }

    private static func place(
        _ server: PlayerSlot,
        from state: MatchState,
        in next: inout MatchState
    ) throws {
        if next.doublesOrder == nil, server != .a1, server != .b1 {
            throw invalid("\(server.rawValue) isn't playing singles")
        }
        next.server = server
        let (anchorGames, anchorSide) = gameServer(of: state)
        let (games, side) = gameServer(of: next)
        let expected = (games - anchorGames).isMultiple(of: 2) ? anchorSide : anchorSide.opponent
        guard side == expected else {
            throw invalid("\(expected.rawValue) serves this game")
        }
        next.serverCourtSide = courtSide(of: next.currentGame)
        next.receiver = Rotation.receiver(serving: server, from: next.serverCourtSide, in: next)
        next.tiebreakOpeningReceiver = openingReceiver(serving: server, in: next)
    }

    private static func gameServer(of state: MatchState) -> (games: Int, side: Side) {
        let games = gamesPlayed(in: state)
        guard winner(of: state) != nil else {
            return (games, flipped(state.server.side, times: tiebreakFlips(in: state.currentGame)))
        }
        let finalTiebreak = state.completedTiebreaks.last.flatMap(\.self)
        return (games - 1, flipped(state.server.side, times: finalTiebreak.map { ($0.a + $0.b) / 2 } ?? 0))
    }

    private static func openingReceiver(
        serving server: PlayerSlot,
        in state: MatchState
    ) -> PlayerSlot? {
        guard case let .tiebreak(a, b, _) = state.currentGame, a + b > 0 else { return nil }
        var opener = server
        for _ in 0 ..< tiebreakFlips(in: state.currentGame) {
            opener = previousServer(before: opener, in: state)
        }
        return Rotation.receiver(serving: opener, from: .deuce, in: state)
    }

    private static func previousServer(
        before server: PlayerSlot,
        in state: MatchState
    ) -> PlayerSlot {
        guard let order = state.doublesOrder?.serving, let index = order.firstIndex(of: server) else {
            return server.side == .a ? .b1 : .a1
        }
        return order[(index + order.count - 1) % order.count]
    }

    private static func phase(
        of state: MatchState,
        winner: Side?
    ) -> MatchPhase {
        if let winner {
            return .complete(winner: winner)
        }
        let untouched = state.sets.isEmpty && state.currentSet == SetScore(a: 0, b: 0) && state.currentGame == .loveAll
        return untouched ? .notStarted : .inProgress
    }

    private static func isFinished(
        _ set: SetScore,
        advantageSet: Bool
    ) -> Bool {
        let (high, low) = (max(set.a, set.b), min(set.a, set.b))
        guard low >= 0 else { return false }
        if high == 6, low <= 4 {
            return true
        }
        return advantageSet ? high > 6 && high - low == 2 : high == 7 && (low == 5 || low == 6)
    }

    private static func winner(of state: MatchState) -> Side? {
        Side.allCases.first { state.setsWon(by: $0) >= state.setsToWin }
    }

    private static func playsAdvantageSet(_ state: MatchState) -> Bool {
        state.isDecidingSet && state.rules.finalSet == .advantage
    }

    private static func tiebreakTarget(_ state: MatchState) -> Int {
        state.isDecidingSet && state.rules.finalSet == .tiebreak10 ? 10 : 7
    }

    private static func gamesPlayed(in state: MatchState) -> Int {
        state.sets.reduce(state.currentSet.a + state.currentSet.b) { $0 + $1.a + $1.b }
    }

    private static func tiebreakFlips(in game: GameState) -> Int {
        guard case let .tiebreak(a, b, _) = game else { return 0 }
        return (a + b + 1) / 2
    }

    private static func courtSide(of game: GameState) -> CourtSide {
        switch game {
        case let .standard(a, b): GameRules.servingSide(a: a, b: b)
        case let .tiebreak(a, b, _): (a + b).isMultiple(of: 2) ? .deuce : .ad
        }
    }

    private static func flipped(
        _ side: Side,
        times: Int
    ) -> Side {
        times.isMultiple(of: 2) ? side : side.opponent
    }

    private static func invalid(_ reason: String) -> EngineError {
        .invalidScore(reason: reason)
    }
}

public extension MatchState {
    var snapshot: ScoreSnapshot {
        ScoreSnapshot(sets: sets, currentSet: currentSet, currentGame: currentGame, server: server)
    }
}
