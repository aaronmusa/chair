//
//  WatchMatchModel.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation

@MainActor
@Observable
public final class WatchMatchModel {
    public private(set) var state: WatchState?
    public private(set) var announcement: String?
    public private(set) var hasEnded = false

    @ObservationIgnored public let link: WatchLink
    @ObservationIgnored private var listenTask: Task<Void, Never>?

    public init(link: WatchLink) {
        self.link = link
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
        case let .announcement(text):
            announcement = text
        case .matchEnded:
            hasEnded = true
        default:
            break
        }
    }
}
