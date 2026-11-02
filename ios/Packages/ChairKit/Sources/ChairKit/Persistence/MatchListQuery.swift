//
//  MatchListQuery.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation

public struct MatchListQuery: Equatable, Sendable {
    public enum Filter: String, CaseIterable, Sendable {
        case all
        case singles
        case doubles
        case inProgress
    }

    public var filter: Filter
    public var search: String

    public init(
        filter: Filter = .all,
        search: String = ""
    ) {
        self.filter = filter
        self.search = search
    }

    public func apply(_ records: [MatchRecord]) -> [MatchRecord] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return records
            .filter(matchesFilter)
            .filter { needle.isEmpty || $0.opponentNames.localizedCaseInsensitiveContains(needle) }
            .sorted { $0.playedAt > $1.playedAt }
    }

    private func matchesFilter(_ record: MatchRecord) -> Bool {
        switch filter {
        case .all: true
        case .singles: record.format == .singles
        case .doubles: record.format == .doubles
        case .inProgress: record.status == .inProgress
        }
    }
}

public extension MatchRecord {
    var opponentNames: String {
        players.filter { $0.slot.side == .b }.sorted { $0.slot < $1.slot }.map(\.name).joined(separator: " and ")
    }
}

public extension MatchRepository {
    func observe(_ query: MatchListQuery) -> AsyncStream<[MatchRecord]> {
        let source = observe()
        return AsyncStream { continuation in
            let task = Task {
                for await records in source {
                    continuation.yield(query.apply(records))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
