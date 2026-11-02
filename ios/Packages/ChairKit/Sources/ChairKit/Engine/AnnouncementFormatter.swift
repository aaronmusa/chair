//
//  AnnouncementFormatter.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/2/26.
//

public struct AnnouncementFormatter: Sendable {
    public let names: [Side: String]

    public init(names: [Side: String]) {
        self.names = names
    }

    public func text(_ announcements: [Announcement]) -> String {
        announcements.map(text).joined(separator: ". ")
    }

    public func text(_ announcement: Announcement) -> String {
        fixedText(announcement) ?? namedText(announcement)
    }

    public func score(_ state: MatchState) -> String {
        let serverSide = state.server.side
        switch state.currentGame {
        case let .standard(a, b):
            if a == .forty, b == .forty {
                return "Deuce"
            }
            if a == .advantage || b == .advantage {
                return "Advantage \(name(a == .advantage ? .a : .b))"
            }
            return gameScore(a: a, b: b, serverSide: serverSide)
        case let .tiebreak(a, b, _):
            return tiebreakScore(a: a, b: b, serverSide: serverSide)
        }
    }

    private func fixedText(_ announcement: Announcement) -> String? {
        switch announcement {
        case .ace: "Ace"
        case .out: "Out"
        case .net: "Net"
        case .deuce: "Deuce"
        case .receiverChoosesSide: "Deciding point, receiver chooses"
        case .fault: "Fault"
        case .doubleFault: "Double fault"
        case .changeEnds: "Change ends"
        case .correction: "Score corrected"
        default: nil
        }
    }

    private func namedText(_ announcement: Announcement) -> String {
        switch announcement {
        case let .score(a, b, serverSide): gameScore(a: a, b: b, serverSide: serverSide)
        case let .advantage(side): "Advantage \(name(side))"
        case let .game(side): "Game \(name(side))"
        case let .let(firstServe): firstServe ? "Let, first serve" : "Let, second serve"
        case let .gameAndSet(side, set): "Game and set \(name(side)), \(winnerFirst(set, winner: side))"
        case let .gameSetMatch(side, _): "Game, set and match \(name(side))"
        case let .retired(side): "\(name(side)) retires"
        case let .tiebreakScore(a, b, serverSide): tiebreakScore(a: a, b: b, serverSide: serverSide)
        case let .chooseServer(side): "\(name(side)) to choose the server"
        default: ""
        }
    }

    private func gameScore(
        a: GameScore,
        b: GameScore,
        serverSide: Side
    ) -> String {
        let (server, receiver) = serverSide == .a ? (a, b) : (b, a)
        if server == receiver {
            return server == .forty ? "Deuce" : "\(word(server))–all"
        }
        return "\(word(server))–\(word(receiver).lowercased())"
    }

    private func tiebreakScore(
        a: Int,
        b: Int,
        serverSide: Side
    ) -> String {
        let (server, receiver) = serverSide == .a ? (a, b) : (b, a)
        return server == receiver ? "\(server)–all" : "\(server)–\(receiver)"
    }

    private func winnerFirst(
        _ set: SetScore,
        winner: Side
    ) -> String {
        winner == .a ? "\(set.a)–\(set.b)" : "\(set.b)–\(set.a)"
    }

    private func word(_ score: GameScore) -> String {
        switch score {
        case .love: "Love"
        case .fifteen: "Fifteen"
        case .thirty: "Thirty"
        case .forty: "Forty"
        case .advantage: "Advantage"
        }
    }

    private func name(_ side: Side) -> String {
        names[side] ?? (side == .a ? "Player A" : "Player B")
    }
}
