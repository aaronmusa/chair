//
//  WatchCompanion.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation

import ChairKit

@MainActor
@Observable
final class WatchCompanion {
    var isActive = false

    @ObservationIgnored private let link: WatchLink
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let repository: any MatchRepository
    @ObservationIgnored private var listenTask: Task<Void, Never>?
    @ObservationIgnored private var matchesTask: Task<Void, Never>?
    @ObservationIgnored private var liveMatchID: UUID?

    init(
        link: WatchLink,
        router: AppRouter,
        repository: any MatchRepository
    ) {
        self.link = link
        self.router = router
        self.repository = repository
    }

    func start() {
        guard listenTask == nil else { return }
        let messages = link.messages
        listenTask = Task { [weak self] in
            for await message in messages {
                guard let self else { return }
                await handle(message)
            }
        }
        let matches = repository.observe()
        matchesTask = Task { [weak self] in
            for await records in matches {
                guard let self else { return }
                await follow(records)
            }
        }
        link.activate()
    }

    func follow(_ records: [MatchRecord]) async {
        if let liveMatchID, let record = records.first(where: { $0.id == liveMatchID }), record.status != .inProgress {
            self.liveMatchID = nil
            await link.send(.matchEnded)
            return
        }
        liveMatchID = Self.live(in: records)?.id
    }

    func handle(_ message: WatchMessage) async {
        switch message {
        case .openNewMatch:
            router.pendingRoute = .newMatch
            if isActive {
                router.applyPendingRoute()
            }
        case .requestState:
            await link.send(currentState())
        default:
            break
        }
    }

    func currentState() -> WatchMessage {
        let records = ((try? repository.fetch()) ?? []).map(\.record)
        if let live = Self.live(in: records), let log = try? MatchLog(record: live) {
            return .state(WatchState(record: live, log: log))
        }
        let finished = records.sorted { $0.playedAt > $1.playedAt }.first { $0.status != .inProgress }
        return .idle(lastResult: finished.map(Self.result))
    }

    private static func live(in records: [MatchRecord]) -> MatchRecord? {
        records
            .filter { $0.status == .inProgress && !$0.isReadOnly }
            .max { $0.playedAt < $1.playedAt }
    }

    private static func result(_ record: MatchRecord) -> String {
        let opponent = record.opponentNames.isEmpty ? "Opponent" : record.opponentNames
        return ["vs \(opponent)", record.perspectiveSetLine].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}
