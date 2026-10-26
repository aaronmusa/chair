//
//  FixedClock.swift
//  ChairTestSupport
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation

import ChairKit

public struct FixedClock: ClockProvider {
    public var now: Date

    public init(_ now: Date) {
        self.now = now
    }

    public mutating func advance(by interval: TimeInterval) {
        now += interval
    }
}
