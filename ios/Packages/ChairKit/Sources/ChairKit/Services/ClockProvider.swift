//
//  ClockProvider.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation

public protocol ClockProvider: Sendable {
    var now: Date { get }
}

public struct SystemClock: ClockProvider {
    public init() {}

    public var now: Date {
        Date()
    }
}
