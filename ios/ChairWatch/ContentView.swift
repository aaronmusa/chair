//
//  ContentView.swift
//  ChairWatch
//
//  Created by Aaron Musa on 10/26/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct ContentView: View {
    let model: WatchMatchModel
    let workout: WatchWorkoutController

    @State private var isScoring = false
    @State private var hasAskedForNewMatch = false

    var body: some View {
        NavigationStack {
            ScrollView {
                WatchHomeView(content: model.home, hasAskedForNewMatch: hasAskedForNewMatch, actions: actions)
            }
            .background(Color.black)
            .navigationDestination(isPresented: $isScoring) {
                WatchScoreView(model: model, heartRate: workout.heartRate, notice: workout.notice)
            }
        }
        .task(handleStart)
        .onChange(of: model.home, handleHomeChange())
    }

    private var actions: WatchHomeActions {
        WatchHomeActions(
            onJoin: handleJoin(),
            onNewMatch: handleNewMatch(),
            onRetry: handleRetry()
        )
    }

    @Sendable
    private func handleStart() async {
        model.start()
        await model.refresh()
    }

    private func handleJoin() -> () -> Void {
        {
            isScoring = true
            Task { await model.join() }
        }
    }

    private func handleNewMatch() -> () -> Void {
        {
            model.openNewMatchOnPhone()
            hasAskedForNewMatch = true
        }
    }

    private func handleRetry() -> () -> Void {
        {
            Task { await model.refresh() }
        }
    }

    private func handleHomeChange() -> (WatchHomeContent, WatchHomeContent) -> Void {
        { _, home in
            if case .join = home {
                hasAskedForNewMatch = false
            } else {
                isScoring = false
            }
        }
    }
}
