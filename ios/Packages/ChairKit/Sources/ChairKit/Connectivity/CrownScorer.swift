//
//  CrownScorer.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation

@MainActor
@Observable
public final class CrownScorer {
    public static let confirmWindow: Duration = .seconds(1)

    public private(set) var pendingMe: Bool?

    @ObservationIgnored private let window: Duration
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var onScore: ((Bool) -> Void)?

    public init(window: Duration = CrownScorer.confirmWindow) {
        self.window = window
    }

    public func detent(
        up: Bool,
        onScore: @escaping (Bool) -> Void
    ) -> Bool {
        if let pendingMe {
            if pendingMe != up {
                cancel()
            }
            return false
        }
        pendingMe = up
        self.onScore = onScore
        task = Task { [weak self, window] in
            try? await Task.sleep(for: window)
            guard let self, !Task.isCancelled else { return }
            confirm()
        }
        return true
    }

    public func cancel() {
        task?.cancel()
        task = nil
        pendingMe = nil
        onScore = nil
    }

    private func confirm() {
        guard let me = pendingMe else { return }
        let onScore = onScore
        task = nil
        pendingMe = nil
        self.onScore = nil
        onScore?(me)
    }
}
