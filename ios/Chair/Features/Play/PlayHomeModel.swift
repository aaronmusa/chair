//
//  PlayHomeModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation

import ChairKit

struct PlayHomeModel: Equatable {
    struct Resume: Equatable {
        let matchID: UUID
        let title: String
    }

    struct LastMatch: Equatable {
        let matchID: UUID
        let title: String
        let detail: String
    }

    let resume: Resume?
    let lastMatch: LastMatch?
    let matchesPlayed: String
    let firstServe: String
    let winLoss: String

    init(
        records: [MatchRecord],
        now: Date
    ) {
        let sorted = records.sorted { $0.playedAt > $1.playedAt }
        resume = sorted.first { $0.status == .inProgress }.map {
            Resume(matchID: $0.id, title: "Resume match vs \(Self.opponent(in: $0))")
        }
        lastMatch = sorted.first { $0.status != .inProgress }.map(Self.lastMatch)

        let weekStart = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let week = sorted.filter { $0.status != .inProgress && $0.playedAt >= weekStart }
        let logs = week.compactMap { try? MatchLog(record: $0) }
        matchesPlayed = week.isEmpty ? "—" : "\(week.count)"

        let serve = logs.map { MatchStats(log: $0)[.a] }
        let servePoints = serve.map(\.servePoints).reduce(0, +)
        let firstIn = serve.map(\.firstServesIn).reduce(0, +)
        let tagged = logs.contains { MatchStats(log: $0).hasTaggedData }
        firstServe = tagged && servePoints > 0 ? "\(Int((Double(firstIn) / Double(servePoints) * 100).rounded()))%" : "—"

        let winners = logs.compactMap(Self.winner)
        let wins = winners.count { $0 == .a }
        winLoss = winners.isEmpty ? "—" : "\(wins)–\(winners.count - wins)"
    }

    var isEmpty: Bool {
        lastMatch == nil && resume == nil
    }

    private static func winner(_ log: MatchLog) -> Side? {
        guard case let .complete(winner) = log.state.phase else { return nil }
        return winner
    }

    private static func opponent(in record: MatchRecord) -> String {
        record.opponentNames.isEmpty ? "Opponent" : record.opponentNames
    }

    private static func lastMatch(_ record: MatchRecord) -> LastMatch {
        let sets = record.sets.map { "\($0.a)–\($0.b)" }.joined(separator: " ")
        let date = record.playedAt.formatted(date: .abbreviated, time: .omitted)
        let state = record.status == .abandoned ? "Ended early" : sets
        return LastMatch(
            matchID: record.id,
            title: "vs \(opponent(in: record))",
            detail: [date, state].filter { !$0.isEmpty }.joined(separator: " · ")
        )
    }
}
