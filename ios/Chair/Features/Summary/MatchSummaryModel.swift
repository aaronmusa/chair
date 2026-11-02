//
//  MatchSummaryModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation

import ChairKit

struct MatchSummaryModel: Equatable {
    struct StatRow: Equatable, Identifiable {
        let title: String
        let a: String
        let b: String

        var id: String {
            title
        }
    }

    struct Run: Equatable {
        let side: Side
        let length: Int
    }

    struct PointRow: Equatable, Identifiable {
        let id: Int
        let context: String
        let detail: String
    }

    let matchID: UUID
    let names: [Side: String]
    let header: String
    let result: String
    let setLine: String
    let rows: [StatRow]
    let runs: [Run]
    let points: [PointRow]
    let shareText: String
    let isReadOnly: Bool
    let ownerID: UUID?

    init(
        record: MatchRecord,
        log: MatchLog
    ) {
        matchID = record.id
        let doubles = record.format == .doubles
        let bySlot = Dictionary(uniqueKeysWithValues: record.players.map { ($0.slot, $0.name) })
        let name = { (slot: PlayerSlot) in bySlot[slot] ?? slot.rawValue }
        let teams: [Side: String] = doubles
            ? [.a: "\(name(.a1)) and \(name(.a2))", .b: "\(name(.b1)) and \(name(.b2))"]
            : [.a: name(.a1), .b: name(.b1)]
        let me = record.mySide
        names = [.a: teams[me] ?? "", .b: teams[me.opponent] ?? ""]
        let stats = MatchStats(log: log)
        let state = log.state

        header = Self.header(record: record, duration: stats.duration)
        setLine = state.summary.map { Self.setText($0, from: me) }.joined(separator: " ")
        result = Self.result(state: state, status: record.status, names: teams)
        rows = Self.rows(stats, from: me)
        runs = Self.runs(stats.points).map { Run(side: $0.side == me ? .a : .b, length: $0.length) }
        points = stats.points.map { Self.pointRow($0, names: teams) }
        isReadOnly = record.isReadOnly
        ownerID = record.ownerID
        let sharedSets = state.summary.map { Self.setText($0, from: .a) }.joined(separator: " ")
        shareText = [result, sharedSets].filter { !$0.isEmpty }.joined(separator: " ") + " · Chair"
    }

    private static func header(
        record: MatchRecord,
        duration: TimeInterval
    ) -> String {
        let date = record.playedAt.formatted(date: .abbreviated, time: .omitted)
        let minutes = Int(duration / 60)
        let length = minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
        let format = record.format == .doubles ? "Doubles" : "Singles"
        let input = record.inputMode == InputMode.camera.rawValue ? "Camera" : "Manual"
        return [date, length, format, input].joined(separator: " · ")
    }

    private static func result(
        state: MatchState,
        status: MatchStatus,
        names: [Side: String]
    ) -> String {
        let a = names[.a] ?? "A"
        let b = names[.b] ?? "B"
        if case let .complete(winner) = state.phase {
            return winner == .a ? "\(a) def. \(b)" : "\(b) def. \(a)"
        }
        return status == .abandoned ? "\(a) v \(b) · ended early" : "\(a) v \(b)"
    }

    private static func setText(
        _ set: SetSummary,
        from me: Side
    ) -> String {
        let (mine, theirs) = me == .a ? (set.a, set.b) : (set.b, set.a)
        guard let tiebreak = set.tiebreak else { return "\(mine)–\(theirs)" }
        let (tbMine, tbTheirs) = me == .a ? (tiebreak.a, tiebreak.b) : (tiebreak.b, tiebreak.a)
        return "\(mine)–\(theirs)(\(tbMine)–\(tbTheirs))"
    }

    private static func rows(
        _ stats: MatchStats,
        from me: Side
    ) -> [StatRow] {
        let a = stats[me]
        let b = stats[me.opponent]
        let tagged = stats.hasTaggedData
        let value = { (number: Int) in tagged ? "\(number)" : "—" }
        let ratio = { (part: Int, whole: Int) -> String in
            guard tagged, whole > 0 else { return "—" }
            return "\(part)/\(whole) (\(Int((Double(part) / Double(whole) * 100).rounded()))%)"
        }
        return [
            StatRow(title: "Points won", a: "\(a.pointsWon)", b: "\(b.pointsWon)"),
            StatRow(title: "Aces", a: value(a.aces), b: value(b.aces)),
            StatRow(title: "Double faults", a: value(a.doubleFaults), b: value(b.doubleFaults)),
            StatRow(title: "Winners", a: value(a.winners), b: value(b.winners)),
            StatRow(title: "Unforced errors", a: value(a.unforcedErrors), b: value(b.unforcedErrors)),
            StatRow(title: "Forced errors", a: value(a.forcedErrors), b: value(b.forcedErrors)),
            StatRow(title: "1st serve in", a: ratio(a.firstServesIn, a.servePoints), b: ratio(b.firstServesIn, b.servePoints)),
            StatRow(
                title: "1st serve points won",
                a: ratio(a.firstServePointsWon, a.firstServesIn),
                b: ratio(b.firstServePointsWon, b.firstServesIn)
            ),
            StatRow(
                title: "Break points won",
                a: ratio(a.breakPointsWon, a.breakPointChances),
                b: ratio(b.breakPointsWon, b.breakPointChances)
            ),
            StatRow(
                title: "Break points saved",
                a: ratio(a.breakPointsSaved, a.breakPointsFaced),
                b: ratio(b.breakPointsSaved, b.breakPointsFaced)
            ),
        ]
    }

    private static func runs(_ points: [PlayedPoint]) -> [Run] {
        points.reduce(into: []) { runs, point in
            if let last = runs.last, last.side == point.winner {
                runs[runs.count - 1] = Run(side: last.side, length: last.length + 1)
            } else {
                runs.append(Run(side: point.winner, length: 1))
            }
        }
    }

    private static func pointRow(
        _ point: PlayedPoint,
        names: [Side: String]
    ) -> PointRow {
        let score = Self.score(point.scoreBefore, server: point.server)
        let context = "Set \(point.set) · Game \(point.game) · \(score)"
        let how = [point.outcome?.title, point.ending?.rawValue].compactMap(\.self).joined(separator: ", ")
        let winner = names[point.winner] ?? point.winner.rawValue
        return PointRow(id: point.number, context: context, detail: how.isEmpty ? "Point \(winner)" : "\(how) · \(winner)")
    }

    private static func score(
        _ game: GameState,
        server: Side
    ) -> String {
        switch game {
        case let .standard(a, b):
            let (first, second) = server == .a ? (a, b) : (b, a)
            return "\(first.label)–\(second.label)"
        case let .tiebreak(a, b, _):
            return server == .a ? "\(a)–\(b)" : "\(b)–\(a)"
        }
    }
}
