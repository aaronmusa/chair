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
    @State private var workout: WatchWorkoutController
    @State private var model: WatchMatchModel

    init() {
        let workout = WatchWorkoutController()
        _workout = State(initialValue: workout)
        _model = State(initialValue: WatchMatchModel(link: WatchLink(), haptics: DeviceWatchHaptics(), keepAlive: workout))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model, workout: workout)
        }
    }
}
