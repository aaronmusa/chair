//
//  HoldGate.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation

@MainActor
@Observable
public final class HoldGate {
    public static let defaultDuration: Duration = .milliseconds(400)

    public private(set) var isHolding = false

    @ObservationIgnored public let duration: Duration
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var isPressed = false
    @ObservationIgnored private var onFire: (() -> Void)?

    public init(duration: Duration = HoldGate.defaultDuration) {
        self.duration = duration
    }

    public func begin(onFire: @escaping () -> Void) {
        guard !isPressed else { return }
        isPressed = true
        isHolding = true
        self.onFire = onFire
        task = Task { [weak self, duration] in
            try? await Task.sleep(for: duration)
            guard let self, !Task.isCancelled else { return }
            fire()
        }
    }

    private func fire() {
        isHolding = false
        task = nil
        onFire?()
        onFire = nil
    }

    public func end() {
        task?.cancel()
        task = nil
        isPressed = false
        isHolding = false
        onFire = nil
    }
}
