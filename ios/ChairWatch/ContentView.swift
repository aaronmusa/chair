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
    let link: WatchLink

    #if DEBUG
        @State private var pingResult: String?
    #endif

    var body: some View {
        VStack(spacing: Spacing.chair.xs) {
            Text("Chair")
                .chairFont(.headline)
                .foregroundStyle(Color.chair.ink)
            Text("0–0")
                .font(Font.chair.score)
                .foregroundStyle(Color.chair.ink)
                .accessibilityLabel("Score, love all")
            #if DEBUG
                if let pingResult {
                    Text(pingResult)
                        .chairFont(.caption)
                        .foregroundStyle(Color.chair.inkSecondary)
                        .accessibilityIdentifier("watch.pingResult")
                }
            #endif
        }
        #if DEBUG
        .task(handlePingOnLaunch)
        #endif
    }

    #if DEBUG
        @Sendable
        private func handlePingOnLaunch() async {
            guard ProcessInfo.processInfo.arguments.contains("-PingPhone") else { return }
            for _ in 0 ..< 20 where !link.isReachable {
                try? await Task.sleep(for: .milliseconds(500))
            }
            var timings: [String] = []
            for _ in 0 ..< 3 {
                let started = ContinuousClock.now
                do {
                    let reply = try await link.send(.ping)
                    let elapsed = ContinuousClock.now - started
                    timings.append("\(reply.rawValue) \(elapsed.formatted(.units(allowed: [.milliseconds])))")
                } catch {
                    timings.append("failed: \(error)")
                }
            }
            pingResult = timings.joined(separator: "\n")
        }
    #endif
}
