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
    @State private var router = AppRouter.make()

    init() {
        let environment = AppEnvironment.make()
        let container = MatchStore.makeContainer()
        self.environment = environment
        self.container = container
        repository = LocalMatchRepository(context: container.mainContext, clock: environment.clock)
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
    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppRouter {
        let router = AppRouter()
        #if DEBUG
            if arguments.contains("-PresentSampleMatch") {
                router.presentSession(for: UUID())
            }
        #endif
        return router
    }
}
