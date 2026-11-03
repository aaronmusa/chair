//
//  InputGate.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation

@MainActor
@Observable
public final class InputGate {
    public static let settleTime: Duration = .milliseconds(300)

    public private(set) var isLuminanceReduced = true

    @ObservationIgnored private var fullSince: ContinuousClock.Instant?

    public init() {}

    public func update(
        isLuminanceReduced: Bool,
        at now: ContinuousClock.Instant = .now
    ) {
        guard isLuminanceReduced != self.isLuminanceReduced || fullSince == nil else { return }
        self.isLuminanceReduced = isLuminanceReduced
        fullSince = isLuminanceReduced ? nil : now
    }

    public func allows(at now: ContinuousClock.Instant = .now) -> Bool {
        guard !isLuminanceReduced, let fullSince else { return false }
        return now - fullSince >= Self.settleTime
    }
}
