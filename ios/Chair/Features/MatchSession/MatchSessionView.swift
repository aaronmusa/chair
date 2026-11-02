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
    @State private var showsScoreFix = false
    @State private var showsEndMatch = false
    @State private var showsDelete = false

    @Environment(\.appRouter) private var router
    @Environment(\.appEnvironment) private var environment

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
                        if viewModel.phase == .complete {
                            Button("Done", action: handleDone())
                                .accessibilityIdentifier("session.done")
                        } else if viewModel.phase != .finishing {
                            Button("Pause", systemImage: "pause.circle", action: handlePause())
                                .accessibilityIdentifier("session.pause")
                        }
                    }
                }
                .toolbar {
                    if viewModel.phase == .complete, let summary = viewModel.summary {
                        ToolbarItem(placement: .topBarLeading) {
                            ShareLink(item: summary.shareText)
                                .accessibilityIdentifier("summary.share")
                        }
                        if !viewModel.isReadOnly {
                            ToolbarItem(placement: .topBarLeading) {
                                Menu("More", systemImage: "ellipsis.circle") {
                                    Button("Delete match", systemImage: "trash", role: .destructive, action: handleAskDelete())
                                }
                                .accessibilityIdentifier("summary.more")
                            }
                        }
                    }
                }
                .sheet(isPresented: $viewModel.isShowingSignInPrompt) {
                    SignInView(viewModel: SignInViewModel(
                        environment: environment,
                        reason: .saveMatch,
                        onFinish: handleSignInPromptFinished()
                    ))
                }
                .confirmationDialog("Delete this match?", isPresented: $showsDelete, titleVisibility: .visible) {
                    Button("Delete match", role: .destructive, action: handleDelete())
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The match and its points are removed from this device.")
                }
                .confirmationDialog("End match", isPresented: $showsEndMatch, titleVisibility: .visible) {
                    Button("Finish as is", action: handleFinishAsIs())
                    Button("Retire — \(viewModel.name(of: .a))", role: .destructive, action: handleRetire(.a))
                    Button("Retire — \(viewModel.name(of: .b))", role: .destructive, action: handleRetire(.b))
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Finish as is keeps the score. Retiring gives the match to the other side.")
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
                .sheet(isPresented: $showsScoreFix) {
                    if let state = viewModel.state {
                        ScoreFixSheet(
                            draft: ScoreFixDraft(state: state),
                            names: [.a: viewModel.name(of: .a), .b: viewModel.name(of: .b)],
                            slotNames: viewModel.names,
                            onApply: handleScoreFix(),
                            onCancel: handleCloseScoreFix()
                        )
                    }
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
        case .finishing:
            MatchOverView(text: viewModel.announcementText)
                .task(handleShowSummary())
        case .complete:
            if let summary = viewModel.summary {
                MatchSummaryView(model: summary)
            }
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
            onFixScore: handleShowScoreFix(),
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
            onSwapSides: handle(.swapEnds),
            onFixScore: handleShowScoreFix(),
            onEndMatch: handleShowEndMatch()
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

    private func handleShowEndMatch() -> () -> Void {
        {
            isPaused = false
            showsEndMatch = true
        }
    }

    private func handleFinishAsIs() -> () -> Void {
        { [viewModel] in
            Task { await viewModel.finishAsIs() }
        }
    }

    private func handleRetire(_ side: Side) -> () -> Void {
        { [viewModel] in
            Task { await viewModel.retire(side) }
        }
    }

    private func handleShowSummary() -> @MainActor @Sendable () async -> Void {
        { [viewModel] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            viewModel.showSummary()
            await viewModel.offerSignInAfterFirstMatch()
        }
    }

    private func handleSignInPromptFinished() -> () -> Void {
        { [viewModel] in viewModel.isShowingSignInPrompt = false }
    }

    private func handleAskDelete() -> () -> Void {
        { showsDelete = true }
    }

    private func handleDelete() -> () -> Void {
        { [viewModel] in
            guard viewModel.delete() else { return }
            router.presentedMatch = nil
        }
    }

    private func handleDone() -> () -> Void {
        { router.presentedMatch = nil }
    }

    private func handleShowScoreFix() -> () -> Void {
        {
            isPaused = false
            showsScoreFix = true
        }
    }

    private func handleCloseScoreFix() -> () -> Void {
        { showsScoreFix = false }
    }

    private func handleScoreFix() -> (ScoreSnapshot) async -> String? {
        { [viewModel] snapshot in
            let error = await viewModel.fixScore(snapshot)
            if error == nil {
                showsScoreFix = false
            }
            return error
        }
    }

    private func handleShowLog() -> () -> Void {
        { showsPointLog = true }
    }
}

private extension MatchSessionView {
    func handle(_ event: MatchEvent) -> () -> Void {
        { [viewModel] in
            Task { await viewModel.apply(event) }
        }
    }

    func handleSwapReceivers() -> () -> Void {
        { [viewModel] in
            guard let side = viewModel.getSet?.receivingSide else { return }
            Task { await viewModel.apply(.swapReceivers(side)) }
        }
    }

    func handlePoint() -> (Side) -> Void {
        { [viewModel] side in
            Task { await viewModel.pointWon(by: side) }
        }
    }

    func handlePlayPoint() -> () -> Void {
        { [viewModel] in viewModel.playPoint() }
    }

    func handlePause() -> () -> Void {
        { isPaused = true }
    }

    func handleResume() -> () -> Void {
        { isPaused = false }
    }

    func handleLoad() -> @MainActor @Sendable () async -> Void {
        { [viewModel] in viewModel.load() }
    }

    func handleAnnouncementTimer() -> @MainActor @Sendable () async -> Void {
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
