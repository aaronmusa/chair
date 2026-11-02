//
//  MatchSessionView.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct MatchSessionView: View {
    @State private var viewModel: MatchSessionViewModel
    @State private var showsAnnouncement = true
    @State private var isPaused = false
    @State private var showsPointLog = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: MatchSessionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Pause", systemImage: "pause.circle", action: handlePause())
                            .accessibilityIdentifier("session.pause")
                    }
                }
                .sheet(isPresented: $isPaused) {
                    PauseSheet(actions: pauseActions)
                        .presentationDetents([.medium])
                }
                .sheet(item: pendingPointBinding) { pending in
                    OutcomeSheet(
                        winnerName: viewModel.name(of: pending.side),
                        isServerWinning: viewModel.isServer(pending.side),
                        onChoose: handleOutcome()
                    )
                    .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: $showsPointLog) {
                    PointLogSheet(
                        points: viewModel.pointLog,
                        names: [.a: viewModel.name(of: .a), .b: viewModel.name(of: .b)],
                        onFlip: handleFlip()
                    )
                    .presentationDetents([.medium, .large])
                }
                .alert("Couldn't do that", isPresented: errorBinding) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(viewModel.errorMessage ?? "")
                }
        }
        .accessibilityIdentifier("match.session")
        .task(handleLoad())
        .task(id: viewModel.announcementID, handleAnnouncementTimer())
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loading:
            ProgressView()
        case let .failed(message):
            ContentUnavailableView("Match unavailable", systemImage: "exclamationmark.triangle", description: Text(message))
        case .getSet:
            if let getSet = viewModel.getSet {
                GetSetView(presentation: getSet, actions: getSetActions)
            }
        case .rally:
            if let scoreboard = viewModel.scoreboard, let getSet = viewModel.getSet {
                RallyView(
                    scoreboard: scoreboard,
                    getSet: getSet,
                    announcement: stripText,
                    names: [.a: viewModel.name(of: .a), .b: viewModel.name(of: .b)],
                    actions: rallyActions
                )
            }
        case .complete:
            // TODO: Replace with MatchSummaryView in E2-10.
            ContentUnavailableView("Match complete", systemImage: "trophy", description: Text(viewModel.announcementText))
        }
    }

    private var stripText: String {
        guard !showsAnnouncement, let state = viewModel.state else { return viewModel.announcementText }
        return viewModel.formatter.score(state)
    }

    private var getSetActions: GetSetActions {
        GetSetActions(
            onSwapServer: handle(.swapServer),
            onSwapReceivers: handleSwapReceivers(),
            onSwapSides: handle(.swapEnds),
            onPlayPoint: handlePlayPoint()
        )
    }

    private var rallyActions: RallyActions {
        RallyActions(
            onPoint: handlePoint(),
            onFault: handle(.fault),
            onLet: handle(.let),
            onUndo: handle(.undo),
            onShowLog: handleShowLog()
        )
    }

    private var pauseActions: PauseActions {
        PauseActions(
            onResume: handleResume(),
            onSwapSides: handle(.swapEnds)
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.dismissError() } }
        )
    }

    private var pendingPointBinding: Binding<PendingPoint?> {
        Binding(
            get: { viewModel.pendingPoint.map(PendingPoint.init) },
            set: { if $0 == nil { viewModel.cancelPendingPoint() } }
        )
    }

    private func handleOutcome() -> (PointOutcome?, PointEnding?) -> Void {
        { [viewModel] outcome, ending in
            Task { await viewModel.recordPendingPoint(outcome: outcome, ending: ending) }
        }
    }

    private func handleFlip() -> (Int) -> Void {
        { [viewModel] index in
            showsPointLog = false
            Task { await viewModel.flip(pointIndex: index) }
        }
    }

    private func handleShowLog() -> () -> Void {
        { showsPointLog = true }
    }

    private func handle(_ event: MatchEvent) -> () -> Void {
        { [viewModel] in
            Task { await viewModel.apply(event) }
        }
    }

    private func handleSwapReceivers() -> () -> Void {
        { [viewModel] in
            guard let side = viewModel.getSet?.receivingSide else { return }
            Task { await viewModel.apply(.swapReceivers(side)) }
        }
    }

    private func handlePoint() -> (Side) -> Void {
        { [viewModel] side in
            Task { await viewModel.pointWon(by: side) }
        }
    }

    private func handlePlayPoint() -> () -> Void {
        { [viewModel] in viewModel.playPoint() }
    }

    private func handlePause() -> () -> Void {
        { isPaused = true }
    }

    private func handleResume() -> () -> Void {
        { isPaused = false }
    }

    private func handleLoad() -> @MainActor @Sendable () async -> Void {
        { [viewModel] in viewModel.load() }
    }

    private func handleAnnouncementTimer() -> @MainActor @Sendable () async -> Void {
        { [reduceMotion] in
            showsAnnouncement = true
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation { showsAnnouncement = false }
        }
    }
}

struct PendingPoint: Identifiable {
    let side: Side

    var id: Side {
        side
    }
}
