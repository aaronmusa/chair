//
//  ScoredByLine.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct ScoredByLine: View {
    let ownerID: UUID?

    @State private var handle: String?
    @Environment(\.appEnvironment) private var environment

    var body: some View {
        Label(handle.map { "Scored by @\($0)" } ?? "Scored by another player", systemImage: "lock.fill")
            .chairFont(.callout)
            .foregroundStyle(Color.chair.inkSecondary)
            .accessibilityIdentifier("summary.scoredBy")
            .task(id: ownerID, handleLoad())
    }

    private func handleLoad() -> @MainActor @Sendable () async -> Void {
        { [environment, ownerID] in
            guard let ownerID else { return }
            handle = try? await environment.profileRemote?.publicProfile(id: ownerID)?.handle
        }
    }
}
