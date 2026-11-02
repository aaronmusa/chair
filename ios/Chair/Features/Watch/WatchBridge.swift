//
//  WatchBridge.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation
import SwiftUI
import UIKit

import ChairKit

@MainActor
@Observable
final class WatchBridge {
    typealias SessionFactory = (UUID) -> MatchSessionViewModel

    var isActive = false

    @ObservationIgnored private(set) var session: MatchSessionViewModel?
    @ObservationIgnored private let link: WatchLink
    @ObservationIgnored private let router: AppRouter
    @ObservationIgnored private let repository: any MatchRepository
    @ObservationIgnored private let makeSession: SessionFactory
    @ObservationIgnored private let statePushDelay: Duration
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var pushTask: Task<Void, Never>?
    @ObservationIgnored private var liveMatchID: UUID?
    @ObservationIgnored private var sentAnnouncementID = 0

    init(
        link: WatchLink,
        router: AppRouter,
        repository: any MatchRepository,
        statePushDelay: Duration = .milliseconds(100),
        makeSession: @escaping SessionFactory
    ) {
        self.link = link
        self.router = router
        self.repository = repository
        self.statePushDelay = statePushDelay
        self.makeSession = makeSession
    }

    static func sessionFactory(
        environment: AppEnvironment,
        repository: any MatchRepository
    ) -> SessionFactory {
        { matchID in
            MatchSessionViewModel(
                matchID: matchID,
                repository: repository,
                clock: environment.clock,
                asksHowPointEnded: environment.matchDefaults.load().asksHowPointEnded,
                auth: environment.auth,
                firstMatchPrompt: FirstMatchPrompt.make()
            )
        }
    }

    func start() {
        guard tasks.isEmpty else { return }
        let messages = link.messages
        let inputs = link.inputs
        let matches = repository.observe()
        tasks = [
            Task { [weak self] in
                for await message in messages {
                    await self?.handle(message)
                }
            },
            Task { [weak self] in
                for await input in inputs {
                    await self?.receive(input)
                }
            },
            Task { [weak self] in
                for await records in matches {
                    await self?.follow(records)
                }
            },
        ]
        link.activate()
    }

    func session(for matchID: UUID) -> MatchSessionViewModel {
        if let session, session.matchID == matchID, session.isLive || router.presentedMatch?.id == matchID {
            return session
        }
        let made = makeSession(matchID)
        made.onChange = handleSessionChange()
        made.load()
        session = made
        sentAnnouncementID = made.announcementID
        return made
    }

    func currentSession() -> MatchSessionViewModel? {
        if let session, router.presentedMatch?.id == session.matchID, session.isLive {
            return session
        }
        let records = ((try? repository.fetch()) ?? []).map(\.record)
        return Self.live(in: records).map { session(for: $0.id) }
    }

    func receive(_ input: WatchInput) async {
        let work = UIApplication.shared.beginBackgroundTask(withName: "Watch input")
        defer { UIApplication.shared.endBackgroundTask(work) }
        guard let session = currentSession(),
              input.matchID == nil || input.matchID == session.matchID,
              await session.applyFromWatch(Self.event(for: input.action)) else {
            await link.send(.refused(inputID: input.id))
            await link.send(currentState())
            return
        }
        await link.acknowledge(input.id)
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

    func follow(_ records: [MatchRecord]) async {
        if let liveMatchID, let record = records.first(where: { $0.id == liveMatchID }), record.status != .inProgress {
            self.liveMatchID = nil
            await link.send(.matchEnded)
            return
        }
        liveMatchID = Self.live(in: records)?.id
    }

    func currentState() -> WatchMessage {
        if let state = currentSession()?.watchState {
            return .state(state)
        }
        let records = ((try? repository.fetch()) ?? []).map(\.record)
        let finished = records.sorted { $0.playedAt > $1.playedAt }.first { $0.status != .inProgress }
        return .idle(lastResult: finished.map(Self.result))
    }

    static func event(for action: WatchInput.Action) -> MatchEvent {
        switch action {
        case let .point(side): .pointWon(by: side, outcome: nil, ending: nil)
        case .fault: .fault
        case .let: .let
        case .undo: .undo
        case .swapEnds: .swapEnds
        }
    }

    private func handleSessionChange() -> () -> Void {
        { [weak self] in self?.scheduleStatePush() }
    }

    private func scheduleStatePush() {
        pushTask?.cancel()
        pushTask = Task { [weak self, statePushDelay] in
            try? await Task.sleep(for: statePushDelay)
            guard let self, !Task.isCancelled else { return }
            await pushSessionState()
        }
    }

    private func pushSessionState() async {
        guard let session, let state = session.watchState else { return }
        await link.send(.state(state))
        guard session.announcementID != sentAnnouncementID else { return }
        sentAnnouncementID = session.announcementID
        if !session.announcements.isEmpty {
            await link.send(.announcement(text: session.announcementText))
        }
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

extension EnvironmentValues {
    @Entry var watchBridge: WatchBridge?
}
