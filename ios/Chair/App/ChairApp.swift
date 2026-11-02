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
    private let repository: LocalMatchRepository
    @State private var router: AppRouter

    init() {
        let environment = AppEnvironment.make()
        let container = MatchStore.makeContainer()
        self.environment = environment
        self.container = container
        let repository = LocalMatchRepository(context: container.mainContext, clock: environment.clock)
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
                .modelContainer(container)
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
