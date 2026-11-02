//
//  WatchHaptics.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

public enum WatchHaptic: Equatable, Sendable {
    case click
    case notification
    case success
    case failure
}

@MainActor
public protocol WatchHaptics {
    func play(_ haptic: WatchHaptic)
}

public struct SilentWatchHaptics: WatchHaptics {
    public init() {}

    public func play(_: WatchHaptic) {}
}
