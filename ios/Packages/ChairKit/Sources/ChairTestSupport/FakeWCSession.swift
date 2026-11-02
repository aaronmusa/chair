//
//  FakeWCSession.swift
//  ChairTestSupport
//
//  Created by Aaron Musa on 11/3/26.
//

#if DEBUG
    import Foundation

    import ChairKit

    public final class FakeWCSession: WatchTransport, @unchecked Sendable {
        public let events: AsyncStream<WatchTransportEvent>

        private let continuation: AsyncStream<WatchTransportEvent>.Continuation
        private let lock = NSLock()
        private weak var peer: FakeWCSession?
        private var reachable: Bool
        private var outbox: [Data] = []
        private var queuedUserInfo: [Data] = []
        private var transferred: [Data] = []

        public init(reachable: Bool = true) {
            self.reachable = reachable
            (events, continuation) = AsyncStream.makeStream(of: WatchTransportEvent.self)
        }

        public static func pair(reachable: Bool = true) -> (phone: FakeWCSession, watch: FakeWCSession) {
            let phone = FakeWCSession(reachable: reachable)
            let watch = FakeWCSession(reachable: reachable)
            phone.peer = watch
            watch.peer = phone
            return (phone, watch)
        }

        public var isReachable: Bool {
            lock.withLock { reachable }
        }

        public var sent: [WatchMessage] {
            lock.withLock { outbox }.compactMap(Self.message)
        }

        public var transferredUserInfo: [WatchMessage] {
            lock.withLock { transferred }.compactMap(Self.message)
        }

        public func activate() {}

        public func sendMessage(_ data: Data) async throws {
            guard isReachable else { throw WatchTransportError.unreachable }
            lock.withLock { outbox.append(data) }
            peer?.deliver(data)
        }

        public func transferUserInfo(_ data: Data) {
            let deliverNow = lock.withLock {
                outbox.append(data)
                transferred.append(data)
                if !reachable {
                    queuedUserInfo.append(data)
                }
                return reachable
            }
            if deliverNow {
                peer?.deliver(data)
            }
        }

        public func setReachable(_ reachable: Bool) {
            setOwnReachability(reachable)
            peer?.setOwnReachability(reachable)
        }

        public func receive(_ message: WatchMessage) {
            deliver(WatchEnvelope(message).data)
        }

        public func receive(raw data: Data) {
            deliver(data)
        }

        public func clearSent() {
            lock.withLock { outbox.removeAll() }
        }

        private func deliver(_ data: Data) {
            continuation.yield(.received(data))
        }

        private func setOwnReachability(_ reachable: Bool) {
            let flushed = lock.withLock {
                self.reachable = reachable
                guard reachable else { return [Data]() }
                defer { queuedUserInfo.removeAll() }
                return queuedUserInfo
            }
            flushed.forEach { peer?.deliver($0) }
            continuation.yield(.reachability(reachable))
        }

        private static func message(_ data: Data) -> WatchMessage? {
            guard case let .message(message) = WatchEnvelope.decode(data) else { return nil }
            return message
        }
    }
#endif
