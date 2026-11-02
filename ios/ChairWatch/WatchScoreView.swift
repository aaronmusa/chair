//
//  WatchScoreView.swift
//  ChairWatch
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct WatchScoreView: View {
    static let holdToScoreKey = "chair.watch.holdToScore"

    let model: WatchMatchModel
    let heartRate: Int?
    let notice: String?

    @AppStorage(Self.holdToScoreKey) private var holdToScore = true
    @State private var visibleAnnouncement: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let state = model.state, model.hasEnded {
            WatchResultView(state: state, onDone: handleDone())
        } else if let state = model.state, let card = model.setStartCard {
            WatchSetStartView(card: card, state: state, onPick: handlePick(card))
        } else if let state = model.state {
            TabView {
                WatchScorePage(
                    state: state,
                    announcement: visibleAnnouncement,
                    showsCorrection: model.showsCorrection,
                    isWaitingForPhone: model.link.isWaitingForPeer,
                    requiresHold: holdToScore,
                    heartRate: heartRate,
                    notice: notice,
                    lastAck: model.link.lastAckLatency,
                    actions: WatchScoreActions(onScore: handleScore(), onUndo: handleSend(.undo))
                )
                WatchControlsPage(onSend: handleSendAction())
                WatchEndMatchPage(onEnd: handleEnd())
                Form {
                    Toggle("Hold to score", isOn: $holdToScore)
                        .accessibilityIdentifier("watch.holdToScore")
                }
            }
            .tabViewStyle(.verticalPage)
            .background(Color.black)
            .task(id: model.announcementID, handleAnnouncement)
        } else {
            ProgressView()
        }
    }

    @Sendable
    private func handleAnnouncement() async {
        guard model.announcementID > 0 else { return }
        visibleAnnouncement = model.announcement
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return }
        if reduceMotion {
            visibleAnnouncement = nil
        } else {
            withAnimation { visibleAnnouncement = nil }
        }
    }

    private func handleDone() -> () -> Void {
        { Task { await model.finish() } }
    }

    private func handlePick(_ card: SetStartCard) -> (Bool) -> Void {
        { second in
            Task {
                switch card {
                case .serve: await model.chooseServer(second: second)
                case .deuce: await model.chooseDeuceReceiver(partner: second)
                }
            }
        }
    }

    private func handleEnd() -> (WatchInput.EndChoice) -> Void {
        { choice in Task { await model.endMatch(choice) } }
    }

    private func handleScore() -> (Bool) -> Void {
        { me in Task { await model.score(me: me) } }
    }

    private func handleSend(_ action: WatchInput.Action) -> () -> Void {
        { Task { await model.send(action) } }
    }

    private func handleSendAction() -> (WatchInput.Action) -> Void {
        { action in Task { await model.send(action) } }
    }
}
