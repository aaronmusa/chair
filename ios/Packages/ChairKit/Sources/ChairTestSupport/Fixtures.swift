//
//  Fixtures.swift
//  ChairTestSupport
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation

import ChairKit

public enum Fixtures {
    public static let matchDay = Date(timeIntervalSince1970: 1_793_000_000)
}

public extension Match {
    static func sample(at date: Date = Fixtures.matchDay) -> Match {
        let match = Match(playedAt: date, format: .singles, createdAt: date, updatedAt: date)
        match.players = [
            MatchPlayer.sample(.b1, name: "Reyes", at: date),
            MatchPlayer.sample(.a1, name: "Musa", at: date),
        ]
        match.points = [
            PointEvent(index: 2, at: date.addingTimeInterval(60), winnerSide: .a, outcome: .winner, updatedAt: date),
            PointEvent(index: 0, at: date, winnerSide: .a, outcome: .ace, updatedAt: date),
            PointEvent(index: 1, at: date.addingTimeInterval(30), winnerSide: .b, outcome: .unforcedError, updatedAt: date),
        ]
        return match
    }
}

public extension MatchPlayer {
    static func sample(
        _ slot: PlayerSlot = .a1,
        name: String = "Musa",
        at date: Date = Fixtures.matchDay
    ) -> MatchPlayer {
        MatchPlayer(slot: slot, name: name, updatedAt: date)
    }
}
