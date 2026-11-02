//
//  MatchesScreen.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct MatchesScreen: View {
    @State private var viewModel: MatchListViewModel

    @Environment(\.appRouter) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(viewModel: MatchListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle(AppSection.matches.title)
            .task(id: viewModel.query, handleObserve())
            .navigationDestination(item: compactDetail) { matchID in
                detail(matchID)
            }
    }

    @ViewBuilder
    private var content: some View {
        @Bindable var viewModel = viewModel
        let list = MatchListView(
            model: viewModel.model,
            query: $viewModel.query,
            selection: router.summaryMatchID,
            actions: MatchListActions(onSelect: handleSelect(), onNewMatch: handleNewMatch())
        )
        if horizontalSizeClass == .regular {
            HStack(spacing: 0) {
                list
                    .frame(width: 380)
                Divider()
                Group {
                    if let matchID = router.summaryMatchID {
                        detail(matchID)
                    } else {
                        ContentUnavailableView("Select a match", systemImage: "sidebar.left")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            list
        }
    }

    @ViewBuilder
    private func detail(_ matchID: UUID) -> some View {
        if let summary = viewModel.summary(id: matchID) {
            MatchSummaryView(model: summary)
                .accessibilityIdentifier("matches.detail")
        } else {
            ContentUnavailableView("Match unavailable", systemImage: "exclamationmark.triangle")
        }
    }

    private var compactDetail: Binding<UUID?> {
        Binding(
            get: { horizontalSizeClass == .regular ? nil : router.summaryMatchID },
            set: { router.summaryMatchID = $0 }
        )
    }

    private func handleSelect() -> (MatchListModel.Row) -> Void {
        { row in router.openMatch(row.id, isInProgress: row.isInProgress) }
    }

    private func handleNewMatch() -> () -> Void {
        { router.showNewMatch() }
    }

    private func handleObserve() -> @MainActor @Sendable () async -> Void {
        { [viewModel] in await viewModel.observe() }
    }
}
