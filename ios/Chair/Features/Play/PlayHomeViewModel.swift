//
//  PlayHomeViewModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import Observation

import ChairKit

@MainActor
@Observable
final class PlayHomeViewModel {
    private(set) var model: PlayHomeModel
    private(set) var hasLoaded = false

    private let repository: (any MatchRepository)?
    private let clock: any ClockProvider

    init(
        repository: (any MatchRepository)?,
        clock: any ClockProvider
    ) {
        self.repository = repository
        self.clock = clock
        model = PlayHomeModel(records: [], now: clock.now)
    }

    func observe() async {
        guard let repository else { return }
        for await records in repository.observe() {
            update(records)
        }
    }

    func update(_ records: [MatchRecord]) {
        model = PlayHomeModel(records: records, now: clock.now)
        hasLoaded = true
    }
}
