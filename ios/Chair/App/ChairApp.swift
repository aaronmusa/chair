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
    private let accountPrompt: AccountPromptModel?
    private let profiles: ProfileRepository
    private let invites: InviteCenter?
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
            let migration = AccountMigration(repository: syncing, store: UserDefaultsAccountStore())
            let sync = SyncCoordinator(
                repository: syncing,
                auth: environment.auth,
                network: SystemNetworkMonitor(),
                clock: environment.clock,
                migration: migration
            )
            repository = syncing
            self.sync = sync
            accountPrompt = AccountPromptModel(auth: environment.auth, migration: migration, sync: sync)
        } else {
            repository = LocalMatchRepository(context: container.mainContext, clock: environment.clock)
            sync = nil
            accountPrompt = nil
        }
        self.repository = repository
        let coordinator = sync
        invites = environment.inviteRemote.map { InviteCenter(remote: $0, auth: environment.auth, sync: coordinator) }
        profiles = ProfileRepository(context: container.mainContext, remote: environment.profileRemote, clock: environment.clock)
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
                .environment(\.profileRepository, profiles)
                .environment(\.inviteCenter, invites)
                .modelContainer(container)
                .accountPrompt(accountPrompt)
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
