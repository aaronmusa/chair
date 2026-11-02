//
//  MatchListModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation

import ChairKit

struct MatchListModel: Equatable {
    struct Row: Equatable, Identifiable {
        let id: UUID
        let title: String
        let subtitle: String
        let badge: String
        let setLine: String
        let footer: String
        let isInProgress: Bool
    }

    struct Section: Equatable, Identifiable {
        let title: String
        let rows: [Row]

        var id: String {
            title
        }
    }

    let sections: [Section]
    let countLabel: String

    init(records: [MatchRecord]) {
        let rows = records.map(Self.row)
        var sections: [Section] = []
        for (record, row) in zip(records, rows) {
            let title = record.playedAt.formatted(.dateTime.month(.wide).year())
            if sections.last?.title == title {
                let last = sections.removeLast()
                sections.append(Section(title: title, rows: last.rows + [row]))
            } else {
                sections.append(Section(title: title, rows: [row]))
            }
        }
        self.sections = sections
        countLabel = records.count == 1 ? "1 match" : "\(records.count) matches"
    }

    var isEmpty: Bool {
        sections.isEmpty
    }

    private static func row(_ record: MatchRecord) -> Row {
        let log = try? MatchLog(record: record)
        let stats = log.map { MatchStats(log: $0) }
        let minutes = Int((stats?.duration ?? 0) / 60)
        let date = record.playedAt.formatted(date: .abbreviated, time: .omitted)
        let format = record.format == .doubles ? "Doubles" : "Singles"
        let input = record.inputMode == InputMode.camera.rawValue ? "camera" : "manual"
        let points = stats?.points.count ?? 0
        return Row(
            id: record.id,
            title: "vs \(record.opponentNames.isEmpty ? "Opponent" : record.opponentNames)",
            subtitle: "\(date) · \(format) · \(minutes) min",
            badge: badge(record, log: log),
            setLine: record.sets.map { "\($0.a)–\($0.b)" }.joined(separator: " "),
            footer: "\(points) \(points == 1 ? "point" : "points") · \(input)",
            isInProgress: record.status == .inProgress
        )
    }

    private static func badge(
        _ record: MatchRecord,
        log: MatchLog?
    ) -> String {
        switch record.status {
        case .inProgress: return "In progress"
        case .abandoned: return "Abandoned"
        case .completed:
            guard case let .complete(winner) = log?.state.phase else { return "Completed" }
            return winner == .a ? "W" : "L"
        }
    }
}
