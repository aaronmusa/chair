//
//  PublicProfileView.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct PublicProfileView: View {
    @State private var viewModel: PublicProfileViewModel

    init(viewModel: PublicProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Group {
                if let profile = viewModel.profile {
                    header(profile)
                    Section {
                        LabeledContent("Level", value: profile.level?.title ?? "Not set")
                        LabeledContent("Matches with you", value: "\(viewModel.matchesWithYou)")
                            .accessibilityIdentifier("publicProfile.matchesWithYou")
                    }
                } else if viewModel.isMissing {
                    Text("No player with the handle @\(viewModel.handle)")
                        .chairFont(.body)
                        .foregroundStyle(Color.chair.inkSecondary)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
            .listRowBackground(Color.chair.surfaceRaised)
        }
        .scrollContentBackground(.hidden)
        .background(Color.chair.surface)
        .navigationTitle("@\(viewModel.handle)")
        .task(handleLoad())
    }

    private func header(_ profile: PublicProfile) -> some View {
        Section {
            HStack(spacing: Spacing.chair.md) {
                AvatarView(name: profile.displayName)
                VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                    Text(profile.displayName)
                        .chairFont(.title)
                        .foregroundStyle(Color.chair.ink)
                    Text("@\(profile.handle)")
                        .chairFont(.callout)
                        .foregroundStyle(Color.chair.inkSecondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func handleLoad() -> @MainActor @Sendable () async -> Void {
        { [viewModel] in await viewModel.load() }
    }
}
