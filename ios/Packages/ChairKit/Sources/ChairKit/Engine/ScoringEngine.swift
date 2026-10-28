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
        case .swapServer:
            return try swapServer(in: state)
        case let .swapReceivers(side):
            return try swapReceivers(of: side, in: state)
        case .swapEnds:
            try requireInPlay(state)
            var next = state
            Rotation.changeEnds(in: &next)
            return (next, [.changeEnds])
        case let .retire(side):
            try requireInPlay(state)
            var next = state
            next.phase = .complete(winner: side.opponent)
            return (next, [.retired(side)])
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

    static func requireSetNotStarted(_ state: MatchState) throws {
        try requireInPlay(state)
        guard state.currentSet == SetScore(a: 0, b: 0), state.currentGame == .loveAll, state.faultCount == 0 else {
            throw EngineError.setInProgress
        }
    }

    static func swapServer(in state: MatchState) throws -> (MatchState, [Announcement]) {
        try requireSetNotStarted(state)
        var next = state
        let partner = state.server.partner
        if var order = state.doublesOrder,
           let serverIndex = order.serving.firstIndex(of: state.server),
           let partnerIndex = order.serving.firstIndex(of: partner) {
            order.serving.swapAt(serverIndex, partnerIndex)
            next.doublesOrder = order
            next.server = partner
        } else {
            next.server = state.receiver
        }
        next.receiver = Rotation.receiver(serving: next.server, from: next.serverCourtSide, in: next)
        return (next, [])
    }

    static func swapReceivers(
        of side: Side,
        in state: MatchState
    ) throws -> (MatchState, [Announcement]) {
        try requireSetNotStarted(state)
        guard var order = state.doublesOrder, let deuceReceiver = order.deuceReceivers[side] else { return (state, []) }
        var next = state
        order.deuceReceivers[side] = deuceReceiver.partner
        next.doublesOrder = order
        next.receiver = Rotation.receiver(serving: next.server, from: next.serverCourtSide, in: next)
        return (next, [])
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
            return tiebreakPoint(to: winner, from: state, into: next)
        }
        switch GameRules.advance(a: a, b: b, winner: winner, noAd: state.rules.deuce == .noAd) {
        case let .continues(newA, newB):
            next.currentGame = .standard(a: newA, b: newB)
            next.serverCourtSide = GameRules.servingSide(a: newA, b: newB)
            next.receiver = Rotation.receiver(serving: state.server, from: next.serverCourtSide, in: next)
            return (next, GameRules.calls(a: newA, b: newB, serverSide: state.server.side, noAd: state.rules.deuce == .noAd))
        case .won:
            let calls = [.game(winner)] + winGame(for: winner, in: &next)
            return (next, calls)
        }
    }

    static func tiebreakPoint(
        to winner: Side,
        from state: MatchState,
        into next: MatchState
    ) -> (MatchState, [Announcement]) {
        guard case let .tiebreak(a, b, target) = state.currentGame else { return (next, []) }
        var next = next
        let (newA, newB) = winner == .a ? (a + 1, b) : (a, b + 1)
        let (mine, theirs) = winner == .a ? (newA, newB) : (newB, newA)
        let opening = state.tiebreakOpeningReceiver ?? state.receiver

        if mine >= target, mine - theirs >= 2 {
            if winner == .a {
                next.currentSet.a += 1
            } else {
                next.currentSet.b += 1
            }
            next.faultCount = 0
            next.serverCourtSide = .deuce
            next.tiebreakOpeningReceiver = nil
            let setCalls = closeSet(won: winner, tiebreak: TiebreakSummary(a: newA, b: newB), in: &next)
            if case .complete = next.phase {
                return (next, [.game(winner)] + setCalls)
            }
            Rotation.changeEnds(in: &next)
            next.server = opening
            next.receiver = Rotation.receiver(serving: opening, from: .deuce, in: next)
            return (next, [.game(winner), .changeEnds] + setCalls + choosingServer(in: next))
        }

        let played = newA + newB
        next.currentGame = .tiebreak(a: newA, b: newB, target: target)
        next.tiebreakOpeningReceiver = opening
        if !played.isMultiple(of: 2) {
            next.server = Rotation.nextServer(after: state.server, in: state)
        }
        next.serverCourtSide = played.isMultiple(of: 2) ? .deuce : .ad
        next.receiver = Rotation.receiver(serving: next.server, from: next.serverCourtSide, in: next)
        var calls: [Announcement] = [.tiebreakScore(a: newA, b: newB, serverSide: next.server.side)]
        if played.isMultiple(of: 6) {
            Rotation.changeEnds(in: &next)
            calls.append(.changeEnds)
        }
        return (next, calls)
    }

    static func winGame(
        for winner: Side,
        in state: inout MatchState
    ) -> [Announcement] {
        let gameServer = state.server
        if winner == .a {
            state.currentSet.a += 1
        } else {
            state.currentSet.b += 1
        }
        let gamesInSet = state.currentSet.a + state.currentSet.b
        let setsBefore = state.sets.count
        state.currentGame = .loveAll
        state.faultCount = 0
        state.serverCourtSide = .deuce
        let setCalls = settleSet(after: winner, in: &state)
        if case .complete = state.phase {
            return setCalls
        }
        var calls: [Announcement] = []
        if !gamesInSet.isMultiple(of: 2) {
            Rotation.changeEnds(in: &state)
            calls.append(.changeEnds)
        }
        state.server = Rotation.nextServer(after: gameServer, in: state)
        state.receiver = Rotation.receiver(serving: state.server, from: .deuce, in: state)
        calls += setCalls
        if state.sets.count > setsBefore {
            calls += choosingServer(in: state)
        }
        return calls
    }

    static func choosingServer(in state: MatchState) -> [Announcement] {
        state.doublesOrder == nil ? [] : [.chooseServer(state.server.side)]
    }

    static func settleSet(
        after winner: Side,
        in state: inout MatchState
    ) -> [Announcement] {
        let set = state.currentSet
        let (mine, theirs) = winner == .a ? (set.a, set.b) : (set.b, set.a)
        let playsAdvantageSet = state.isDecidingSet && state.rules.finalSet == .advantage
        if mine == 6, theirs == 6, !playsAdvantageSet {
            let target = state.isDecidingSet && state.rules.finalSet == .tiebreak10 ? 10 : 7
            state.currentGame = .tiebreak(a: 0, b: 0, target: target)
            return []
        }
        guard mine >= 6, mine - theirs >= 2 else { return [] }
        return closeSet(won: winner, tiebreak: nil, in: &state)
    }

    static func closeSet(
        won winner: Side,
        tiebreak: TiebreakSummary?,
        in state: inout MatchState
    ) -> [Announcement] {
        let set = state.currentSet
        state.sets.append(set)
        state.completedTiebreaks.append(tiebreak)
        state.currentSet = SetScore(a: 0, b: 0)
        state.currentGame = .loveAll
        guard state.setsWon(by: winner) == state.setsToWin else {
            return [.gameAndSet(winner, set)]
        }
        state.phase = .complete(winner: winner)
        return [.gameSetMatch(winner, state.summary)]
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
