//
//  WatchTransport.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation

public enum WatchTransportEvent: Equatable, Sendable {
    case received(Data)
    case reachability(Bool)
}

public enum WatchTransportError: Error, Equatable {
    case unsupported
    case unreachable
}

public protocol WatchTransport: AnyObject, Sendable {
    var isReachable: Bool { get }
    var events: AsyncStream<WatchTransportEvent> { get }

    func activate()
    func sendMessage(_ data: Data) async throws
    func transferUserInfo(_ data: Data)
}
