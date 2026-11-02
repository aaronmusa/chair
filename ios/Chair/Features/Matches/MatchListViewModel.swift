//
//  MatchListViewModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import Observation

import ChairKit

@MainActor
@Observable
final class MatchListViewModel {
    var query = MatchListQuery()
    private(set) var model = MatchListModel(records: [])
    private(set) var records: [MatchRecord] = []
    private(set) var hasLoaded = false

    private let repository: (any MatchRepository)?

    init(repository: (any MatchRepository)?) {
        self.repository = repository
    }

    func observe() async {
        guard let repository else { return }
        for await records in repository.observe(query) {
            update(records)
        }
    }

    func update(_ records: [MatchRecord]) {
        self.records = records
        model = MatchListModel(records: records)
        hasLoaded = true
    }

    func record(id: UUID) -> MatchRecord? {
        records.first { $0.id == id }
    }

    func summary(id: UUID) -> MatchSummaryModel? {
        guard let record = record(id: id), let log = try? MatchLog(record: record) else { return nil }
        return MatchSummaryModel(record: record, log: log)
    }
}
