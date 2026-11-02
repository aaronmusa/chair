//
//  WatchKeepAlive.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

@MainActor
public protocol WatchKeepAlive: AnyObject {
    var isRunning: Bool { get }

    func start() async
    func end()
}

@MainActor
public final class NoKeepAlive: WatchKeepAlive {
    public private(set) var isRunning = false

    public init() {}

    public func start() async {
        isRunning = true
    }

    public func end() {
        isRunning = false
    }
}
