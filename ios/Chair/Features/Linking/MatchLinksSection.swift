//
//  MatchLinksSection.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct MatchLinksSection: View {
    let matchID: UUID

    @Environment(\.matchRepository) private var repository
    @Environment(\.appEnvironment) private var environment

    var body: some View {
        if let repository {
            MatchLinksList(viewModel: MatchLinksViewModel(matchID: matchID, repository: repository, environment: environment))
        }
    }
}

struct MatchLinksList: View {
    @State private var viewModel: MatchLinksViewModel
    @Environment(\.appEnvironment) private var environment

    init(viewModel: MatchLinksViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.chair.xs) {
            ForEach(viewModel.rows) { row in
                HStack(spacing: Spacing.chair.sm) {
                    Text(row.name)
                        .chairFont(.body)
                        .foregroundStyle(Color.chair.ink)
                    LinkChip(status: row.status)
                    Spacer()
                    if row.status == .none {
                        smallButton("Link", style: .secondary, onTap: handleRequestLink(row.slot))
                            .accessibilityLabel("Link \(row.name) to a Chair player")
                    } else {
                        smallButton("Unlink", style: .destructive, onTap: handleUnlink(row.slot))
                            .accessibilityLabel("Unlink \(row.name)")
                    }
                }
                .padding(.horizontal, Spacing.chair.md)
                .padding(.vertical, Spacing.chair.xs)
                .background(Color.chair.control, in: RoundedRectangle(cornerRadius: Radius.chair.control))
                .accessibilityIdentifier("summary.link.\(row.slot.rawValue)")
            }
        }
        .task(handleWatch())
        .sheet(item: $viewModel.pickerSlot) { slot in
            OpponentPickerView(viewModel: OpponentPickerViewModel(environment: environment, onPick: handleLinked(slot)))
        }
        .sheet(isPresented: $viewModel.isShowingSignIn) {
            SignInView(viewModel: SignInViewModel(environment: environment, reason: .linkOpponent, onFinish: handleSignedIn()))
        }
    }

    private func handleWatch() -> @MainActor @Sendable () async -> Void {
        { [viewModel] in await viewModel.watch() }
    }

    private func handleRequestLink(_ slot: PlayerSlot) -> () -> Void {
        { [viewModel] in Task { await viewModel.requestLink(slot) } }
    }

    private func handleUnlink(_ slot: PlayerSlot) -> () -> Void {
        { [viewModel] in viewModel.unlink(slot) }
    }

    private func handleLinked(_ slot: PlayerSlot) -> (PublicProfile) -> Void {
        { [viewModel] profile in viewModel.link(slot, to: profile) }
    }

    private func handleSignedIn() -> () -> Void {
        { [viewModel] in viewModel.isShowingSignIn = false }
    }

    private func smallButton(
        _ title: String,
        style: ChairButton.Style,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            Text(title)
                .chairFont(.callout)
                .fontWeight(.semibold)
                .padding(.horizontal, Spacing.chair.sm)
                .frame(minHeight: 32)
        }
        .buttonStyle(ChairButtonStyle(style))
    }
}
