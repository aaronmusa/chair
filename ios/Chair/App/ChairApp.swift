//
//  ChairApp.swift
//  Chair
//
//  Created by Aaron Musa on 10/26/26.
//

import SwiftUI

import ChairKit

@main
struct ChairApp: App {
    private let environment = AppEnvironment.make()
    private let watchLink = WatchLink()
    @State private var router = AppRouter.make()

    init() {
        watchLink.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appEnvironment, environment)
                .environment(\.appRouter, router)
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
