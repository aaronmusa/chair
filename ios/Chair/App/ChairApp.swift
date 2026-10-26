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

    init() {
        watchLink.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appEnvironment, environment)
        }
    }
}
