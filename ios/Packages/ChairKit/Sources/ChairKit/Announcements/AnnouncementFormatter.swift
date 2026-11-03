//
//  AnnouncementFormatter.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/2/26.
//

public struct AnnouncementFormatter: Sendable {
    public let names: PlayerNames
    public let verbosity: Verbosity

    public init(
        names: PlayerNames,
        verbosity: Verbosity = .normal
    ) {
        self.names = names
        self.verbosity = verbosity
    }

    public static func text(
        for announcement: Announcement,
        names: PlayerNames,
        verbosity: Verbosity
    ) -> String {
        AnnouncementFormatter(names: names, verbosity: verbosity).text(announcement)
    }

    public func text(
        _ announcement: Announcement,
        setNumber: Int? = nil
    ) -> String {
        guard verbosity != .minimal || Self.isScoreOrResult(announcement) else { return "" }
        return phrase(announcement, setNumber: setNumber)
    }

    public func text(
        _ announcements: [Announcement],
        after state: MatchState? = nil
    ) -> String {
        Self.sentence(Self.umpireOrder(announcements).map { text($0, setNumber: state?.sets.count) })
    }

    public func spoken(_ output: EngineOutput) -> String {
        let calls = Self.umpireOrder(output.announcements).map { text($0, setNumber: output.state.sets.count) }
        return Self.sentence(calls + [preRally(output) ?? ""])
    }

    public func preRally(_ output: EngineOutput) -> String? {
        guard verbosity != .minimal,
              !Self.isOver(output.state),
              !output.announcements.contains(where: Self.holdsTheServe) else { return nil }
        if output.preRally.serve == .second {
            return "Second serve"
        }
        guard verbosity == .full || Self.isGameStart(output.state.currentGame) else { return nil }
        let side = output.preRally.serverCourtSide == .deuce ? "deuce" : "ad"
        return "\(names.spokenName(output.preRally.server)) to serve, \(side) side"
    }

    public func score(_ state: MatchState) -> String {
        score(state.currentGame, serverSide: state.server.side)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func phrase(
        _ announcement: Announcement,
        setNumber: Int?
    ) -> String {
        switch announcement {
        case .ace: "Ace!"
        case .out: "Out"
        case .net: "Net"
        case let .score(a, b, serverSide): gameScore(a: a, b: b, serverSide: serverSide)
        case .deuce: "Deuce"
        case let .advantage(side): "Advantage \(names.team(side))"
        case let .game(side): "Game, \(names.team(side))"
        case .receiverChoosesSide: "Deciding point; receiver's choice"
        case .fault: "Fault"
        case .doubleFault: "Double fault"
        case let .let(firstServe): firstServe ? "Let, first serve" : "Let, second serve"
        case let .gameAndSet(side, set): gameAndSet(side, set: set, number: setNumber)
        case let .gameSetMatch(side, sets): "Game, set and match, \(names.team(side)), \(setsLine(sets, winner: side))"
        case let .retired(side): "\(names.team(side)) retires; game, set and match, \(names.team(side.opponent))"
        case let .tiebreakScore(a, b, serverSide): tiebreakScore(a: a, b: b, serverSide: serverSide)
        case .changeEnds: "Change of ends"
        case let .chooseServer(side): "\(names.team(side)), who serves?"
        case let .correction(snapshot): "Correction, \(Self.lowercasedFirst(score(snapshot.currentGame, serverSide: snapshot.server.side)))"
        }
    }

    private func score(
        _ game: GameState,
        serverSide: Side
    ) -> String {
        switch game {
        case let .standard(a, b):
            if a == .advantage || b == .advantage {
                return "Advantage \(names.team(a == .advantage ? .a : .b))"
            }
            return gameScore(a: a, b: b, serverSide: serverSide)
        case let .tiebreak(a, b, _):
            return tiebreakScore(a: a, b: b, serverSide: serverSide)
        }
    }

    private func gameScore(
        a: GameScore,
        b: GameScore,
        serverSide: Side
    ) -> String {
        let (server, receiver) = serverSide == .a ? (a, b) : (b, a)
        if server == receiver {
            return server == .forty ? "Deuce" : "\(Self.word(server))–all"
        }
        return "\(Self.word(server))–\(Self.word(receiver).lowercased())"
    }

    private func tiebreakScore(
        a: Int,
        b: Int,
        serverSide: Side
    ) -> String {
        let (server, receiver) = serverSide == .a ? (a, b) : (b, a)
        let level = SpokenNumber.words(server).capitalizedFirst
        guard server != receiver else { return "\(level)–all" }
        return "\(level)–\(SpokenNumber.words(receiver)), \(names.team(serverSide))"
    }

    private func gameAndSet(
        _ side: Side,
        set: SetScore,
        number: Int?
    ) -> String {
        let (won, lost) = side == .a ? (set.a, set.b) : (set.b, set.a)
        let which = number.flatMap(SpokenNumber.ordinal).map { "\($0) set" } ?? "set"
        return "Game and \(which), \(names.team(side)), \(SpokenNumber.games(won)) games to \(SpokenNumber.games(lost))"
    }

    private func setsLine(
        _ sets: [SetSummary],
        winner: Side
    ) -> String {
        sets.map { set in
            let (won, lost) = winner == .a ? (set.a, set.b) : (set.b, set.a)
            return "\(SpokenNumber.games(won))–\(SpokenNumber.games(lost))"
        }.joined(separator: ", ")
    }

    private static func umpireOrder(_ announcements: [Announcement]) -> [Announcement] {
        let closesASet = announcements.contains { isSetResult($0) }
        let calls = announcements.filter { !(closesASet && isGame($0)) }
        return calls.filter { $0 != .changeEnds } + calls.filter { $0 == .changeEnds }
    }

    private static func isSetResult(_ announcement: Announcement) -> Bool {
        switch announcement {
        case .gameAndSet, .gameSetMatch: true
        default: false
        }
    }

    private static func isGame(_ announcement: Announcement) -> Bool {
        if case .game = announcement {
            return true
        }
        return false
    }

    private static func isScoreOrResult(_ announcement: Announcement) -> Bool {
        switch announcement {
        case .score, .deuce, .advantage, .game, .gameAndSet, .gameSetMatch, .retired, .tiebreakScore, .correction: true
        case .ace, .out, .net, .receiverChoosesSide, .fault, .doubleFault, .let, .changeEnds, .chooseServer: false
        }
    }

    private static func holdsTheServe(_ announcement: Announcement) -> Bool {
        switch announcement {
        case .let, .chooseServer: true
        default: false
        }
    }

    private static func isOver(_ state: MatchState) -> Bool {
        if case .complete = state.phase {
            return true
        }
        return false
    }

    private static func isGameStart(_ game: GameState) -> Bool {
        switch game {
        case let .standard(a, b): a == .love && b == .love
        case let .tiebreak(a, b, _): a == 0 && b == 0
        }
    }

    private static func sentence(_ parts: [String]) -> String {
        parts.filter { !$0.isEmpty }.reduce("") { text, part in
            guard let last = text.last else { return part }
            return text + (last == "!" || last == "?" ? " " : ". ") + part
        }
    }

    private static func word(_ score: GameScore) -> String {
        switch score {
        case .love: "Love"
        case .fifteen: "Fifteen"
        case .thirty: "Thirty"
        case .forty: "Forty"
        case .advantage: "Advantage"
        }
    }

    private static func lowercasedFirst(_ text: String) -> String {
        text.prefix(1).lowercased() + text.dropFirst()
    }
}
