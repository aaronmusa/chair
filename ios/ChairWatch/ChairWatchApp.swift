//
//  ChairWatchApp.swift
//  ChairWatch
//
//  Created by Aaron Musa on 10/26/26.
//

import SwiftUI

import ChairKit

@main
struct ChairWatchApp: App {
    private let link = WatchLink()

    init() {
        link.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(link: link)
        }
    }
}
