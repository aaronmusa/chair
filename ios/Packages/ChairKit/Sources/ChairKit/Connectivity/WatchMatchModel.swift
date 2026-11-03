//
//  WatchMatchModel.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation

public enum SetStartCard: Equatable, Sendable {
    case serve(first: PlayerSlot, second: PlayerSlot)
    case deuce(current: PlayerSlot, partner: PlayerSlot)
}

public enum WatchHomeContent: Equatable, Sendable {
    case join(WatchState)
    case startOnPhone(lastResult: String?)
    case unreachable
    case updatePhone
}

@MainActor
@Observable
public final class WatchMatchModel {
    public private(set) var state: WatchState?
    public private(set) var announcement: String?
    public private(set) var hasEnded = false
    public private(set) var lastResult: String?
    public private(set) var announcementID = 0
    public private(set) var showsCorrection = false

    @ObservationIgnored public let link: WatchLink
    @ObservationIgnored private let haptics: any WatchHaptics
    @ObservationIgnored public let keepAlive: any WatchKeepAlive
    @ObservationIgnored public let gate = InputGate()
    @ObservationIgnored public let crown: CrownScorer
    @ObservationIgnored private var listenTask: Task<Void, Never>?
    @ObservationIgnored private var pendingUndoID: UUID?
    private var answeredServe: Set<Int> = []
    private var answeredDeuce: Set<Int> = []

    public init(
        link: WatchLink,
        haptics: any WatchHaptics = SilentWatchHaptics(),
        keepAlive: any WatchKeepAlive = NoKeepAlive(),
        crown: CrownScorer = CrownScorer()
    ) {
        self.crown = crown
        self.link = link
        self.haptics = haptics
        self.keepAlive = keepAlive
    }

    public func start() {
        guard listenTask == nil else { return }
        let messages = link.messages
        listenTask = Task { [weak self] in
            for await message in messages {
                guard let self else { return }
                apply(message)
            }
        }
        link.activate()
    }

    public func apply(_ message: WatchMessage) {
        switch message {
        case let .state(newState):
            if let state, newState.matchID == state.matchID {
                playMilestone(from: state.score, to: newState.score)
            }
            if newState != state {
                state = newState
            }
            hasEnded = newState.phase == .complete
            endWorkoutIfOver()
        case let .idle(result):
            state = nil
            lastResult = result
        case let .announcement(text):
            announcement = text
            announcementID += 1
        case .refused:
            haptics.play(.failure)
        case let .ack(inputID):
            if inputID == pendingUndoID {
                pendingUndoID = nil
                showsCorrection = true
            }
        case .matchEnded:
            hasEnded = true
            endWorkoutIfOver()
        default:
            break
        }
    }

    public var home: WatchHomeContent {
        if link.isVersionMismatched {
            return .updatePhone
        }
        if let state, state.phase != .complete {
            return .join(state)
        }
        guard link.isReachable else { return .unreachable }
        return .startOnPhone(lastResult: lastResult)
    }

    public var setStartCard: SetStartCard? {
        guard let state, state.isDoubles, state.isSetStart else { return nil }
        let set = state.score.sets.count
        if state.server.side == state.mySide, !answeredServe.contains(set) {
            return .serve(first: state.server, second: state.server.partner)
        }
        guard let receiver = state.deuceReceiver, !answeredDeuce.contains(set) else { return nil }
        return .deuce(current: receiver, partner: receiver.partner)
    }

    public func chooseServer(second: Bool) async {
        guard let state else { return }
        answeredServe.insert(state.score.sets.count)
        if second {
            await send(.swapServer)
        }
    }

    public func chooseDeuceReceiver(partner: Bool) async {
        guard let state else { return }
        answeredDeuce.insert(state.score.sets.count)
        if partner {
            await send(.swapReceivers(state.mySide))
        }
    }

    public func endMatch(_ choice: WatchInput.EndChoice) async {
        await send(.endMatch(choice))
    }

    public func finish() async {
        await endWorkout()
        state = nil
        hasEnded = false
        await refresh()
    }

    public func join() async {
        hasEnded = false
        await refresh()
        if !keepAlive.isRunning {
            await keepAlive.start()
        }
    }

    public func endWorkout() async {
        keepAlive.end()
        await link.send(.endWorkout)
    }

    private func endWorkoutIfOver() {
        guard hasEnded, keepAlive.isRunning else { return }
        keepAlive.end()
    }

    private func playMilestone(
        from old: ScoreSnapshot,
        to new: ScoreSnapshot
    ) {
        if new.sets.count > old.sets.count {
            haptics.play(.success)
        } else if new.currentSet.a + new.currentSet.b > old.currentSet.a + old.currentSet.b {
            haptics.play(.notification)
        }
    }

    public func score(me: Bool) async {
        guard gate.allows() else { return }
        await sendPoint(me: me, click: true)
    }

    public func turnCrown(up: Bool) {
        guard gate.allows() else { return }
        if crown.detent(up: up, onScore: handleCrownScore()) {
            haptics.play(.click)
        }
    }

    private func handleCrownScore() -> (Bool) -> Void {
        { [weak self] me in
            Task { await self?.sendPoint(me: me, click: false) }
        }
    }

    private func sendPoint(
        me: Bool,
        click: Bool
    ) async {
        guard let state else { return }
        await send(.point(me ? state.mySide : state.theirSide), click: click)
    }

    public func send(
        _ action: WatchInput.Action,
        click: Bool = true
    ) async {
        guard let state else { return }
        let input = WatchInput(action, matchID: state.matchID)
        if click {
            haptics.play(.click)
        }
        if action == .undo {
            pendingUndoID = input.id
        } else {
            showsCorrection = false
        }
        await link.send(input)
    }

    public func refresh() async {
        await link.send(.requestState)
    }

    public func openNewMatchOnPhone() {
        link.queue(.openNewMatch)
    }
}
