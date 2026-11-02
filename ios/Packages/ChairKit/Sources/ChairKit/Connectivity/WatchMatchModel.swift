//
//  WatchMatchModel.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation

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
    @ObservationIgnored private var listenTask: Task<Void, Never>?
    @ObservationIgnored private var pendingUndoID: UUID?

    public init(
        link: WatchLink,
        haptics: any WatchHaptics = SilentWatchHaptics()
    ) {
        self.link = link
        self.haptics = haptics
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
            if newState != state {
                state = newState
            }
            hasEnded = newState.phase == .complete
        case let .idle(result):
            state = nil
            lastResult = result
        case let .announcement(text):
            announcement = text
            announcementID += 1
        case let .ack(inputID):
            if inputID == pendingUndoID {
                pendingUndoID = nil
                showsCorrection = true
            }
        case .matchEnded:
            hasEnded = true
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

    public func score(me: Bool) async {
        guard let state else { return }
        await send(.point(me ? state.mySide : state.theirSide))
    }

    public func send(_ action: WatchInput.Action) async {
        guard let state else { return }
        let input = WatchInput(action, matchID: state.matchID)
        haptics.play(.click)
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
