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
        let scoreboard: ScoreboardModel?
    }

    struct LastMatch: Equatable {
        let matchID: UUID
        let title: String
        let detail: String
        let date: String
        let result: String?
        let setLine: String
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
        resume = sorted.first { $0.status == .inProgress && !$0.isReadOnly }.map(Self.resume)
        lastMatch = sorted.first { $0.status != .inProgress }.map(Self.lastMatch)

        let weekStart = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let week = sorted.filter { $0.status != .inProgress && $0.playedAt >= weekStart }
        let logs = week.compactMap { record in (try? MatchLog(record: record)).map { (log: $0, side: record.mySide) } }
        matchesPlayed = week.isEmpty ? "—" : "\(week.count)"

        let serve = logs.map { MatchStats(log: $0.log)[$0.side] }
        let servePoints = serve.map(\.servePoints).reduce(0, +)
        let firstIn = serve.map(\.firstServesIn).reduce(0, +)
        let tagged = logs.contains { MatchStats(log: $0.log).hasTaggedData }
        firstServe = tagged && servePoints > 0 ? "\(Int((Double(firstIn) / Double(servePoints) * 100).rounded()))%" : "—"

        let results = logs.compactMap { entry in Self.winner(entry.log).map { $0 == entry.side } }
        let wins = results.count { $0 }
        winLoss = results.isEmpty ? "—" : "\(wins)–\(results.count - wins)"
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

    private static func resume(_ record: MatchRecord) -> Resume {
        let state = (try? MatchLog(record: record))?.state
        return Resume(
            matchID: record.id,
            title: "Resume match vs \(opponent(in: record))",
            scoreboard: state.map { ScoreboardModel(state: $0, names: teamNames(record)) }
        )
    }

    private static func teamNames(_ record: MatchRecord) -> [Side: String] {
        let names = Dictionary(record.players.map { ($0.slot, $0.name) }, uniquingKeysWith: { first, _ in first })
        let name = { (slot: PlayerSlot) in names[slot] ?? "Player \(slot.rawValue)" }
        guard record.format == .doubles else { return [.a: name(.a1), .b: name(.b1)] }
        return [.a: "\(name(.a1)) and \(name(.a2))", .b: "\(name(.b1)) and \(name(.b2))"]
    }

    private static func lastMatch(_ record: MatchRecord) -> LastMatch {
        let sets = record.perspectiveSetLine
        let date = record.playedAt.formatted(date: .abbreviated, time: .omitted)
        let state = record.status == .abandoned ? "Ended early" : sets
        let winner = (try? MatchLog(record: record)).flatMap(Self.winner)
        return LastMatch(
            matchID: record.id,
            title: "vs \(opponent(in: record))",
            detail: [date, state].filter { !$0.isEmpty }.joined(separator: " · "),
            date: record.status == .abandoned ? "\(date) · Ended early" : date,
            result: winner.map { $0 == record.mySide ? "W" : "L" },
            setLine: record.status == .abandoned ? "" : sets
        )
    }
}
