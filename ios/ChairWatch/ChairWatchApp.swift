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
    @State private var model = WatchMatchModel(link: WatchLink())

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }
}
