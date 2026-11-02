//
//  ChairApp.swift
//  Chair
//
//  Created by Aaron Musa on 10/26/26.
//

import SwiftData
import SwiftUI

import ChairKit

@main
struct ChairApp: App {
    private let environment: AppEnvironment
    private let watchLink = WatchLink()
    private let container: ModelContainer
    private let repository: any MatchRepository
    private let sync: SyncCoordinator?
    @State private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let environment = AppEnvironment.make()
        let container = MatchStore.makeContainer()
        self.environment = environment
        self.container = container
        let repository: any MatchRepository
        if let remote = environment.matchRemote {
            let syncing = SyncingMatchRepository(context: container.mainContext, remote: remote, clock: environment.clock)
            repository = syncing
            sync = SyncCoordinator(repository: syncing, auth: environment.auth, network: SystemNetworkMonitor(), clock: environment.clock)
        } else {
            repository = LocalMatchRepository(context: container.mainContext, clock: environment.clock)
            sync = nil
        }
        self.repository = repository
        _router = State(initialValue: AppRouter.make(repository: repository, clock: environment.clock))
        watchLink.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appEnvironment, environment)
                .environment(\.appRouter, router)
                .environment(\.matchRepository, repository)
                .environment(\.syncCoordinator, sync)
                .modelContainer(container)
                .onChange(of: scenePhase, initial: true, handleScenePhase())
        }
    }

    private func handleScenePhase() -> (ScenePhase, ScenePhase) -> Void {
        { [sync] _, phase in
            guard phase == .active, let sync else { return }
            sync.start()
            Task { await sync.syncNow() }
        }
    }
}

extension AppRouter {
    static func make(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        repository: any MatchRepository,
        clock: any ClockProvider
    ) -> AppRouter {
        let router = AppRouter()
        #if DEBUG
            if arguments.contains("-PresentSampleMatch"), let matchID = sampleMatch(in: repository, at: clock.now) {
                router.presentSession(for: matchID)
            }
        #endif
        return router
    }

    #if DEBUG
        private static func sampleMatch(
            in repository: any MatchRepository,
            at date: Date
        ) -> UUID? {
            var setup = NewMatchSetup(defaults: MatchDefaults(playerName: "Aaron"))
            setup.names[.b1] = "Juan"
            guard let match = try? setup.makeMatch(at: date) else { return nil }
            try? repository.save(match)
            return match.remoteID
        }
    #endif
}
