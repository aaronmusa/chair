//
//  WCSessionTransport.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

#if canImport(WatchConnectivity)
    import Foundation
    import WatchConnectivity

    public final class WCSessionTransport: NSObject, WatchTransport, WCSessionDelegate, @unchecked Sendable {
        static let payloadKey = "payload"

        public let events: AsyncStream<WatchTransportEvent>

        private let session: WCSession?
        private let continuation: AsyncStream<WatchTransportEvent>.Continuation

        override public init() {
            session = WCSession.isSupported() ? WCSession.default : nil
            (events, continuation) = AsyncStream.makeStream(of: WatchTransportEvent.self)
            super.init()
        }

        public var isReachable: Bool {
            session?.isReachable ?? false
        }

        public func activate() {
            session?.delegate = self
            session?.activate()
        }

        public func sendMessage(_ data: Data) async throws {
            guard let session else { throw WatchTransportError.unsupported }
            guard session.isReachable else { throw WatchTransportError.unreachable }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                session.sendMessage([Self.payloadKey: data]) { _ in
                    continuation.resume()
                } errorHandler: { error in
                    continuation.resume(throwing: error)
                }
            }
        }

        public func transferUserInfo(_ data: Data) {
            _ = session?.transferUserInfo([Self.payloadKey: data])
        }

        public func session(
            _ session: WCSession,
            activationDidCompleteWith _: WCSessionActivationState,
            error _: (any Error)?
        ) {
            continuation.yield(.reachability(session.isReachable))
        }

        public func sessionReachabilityDidChange(_ session: WCSession) {
            continuation.yield(.reachability(session.isReachable))
        }

        public func session(
            _: WCSession,
            didReceiveMessage message: [String: Any],
            replyHandler: @escaping ([String: Any]) -> Void
        ) {
            replyHandler([:])
            receive(message)
        }

        public func session(
            _: WCSession,
            didReceiveMessage message: [String: Any]
        ) {
            receive(message)
        }

        public func session(
            _: WCSession,
            didReceiveUserInfo userInfo: [String: Any]
        ) {
            receive(userInfo)
        }

        #if os(iOS)
            public func sessionDidBecomeInactive(_: WCSession) {}

            public func sessionDidDeactivate(_ session: WCSession) {
                session.activate()
            }
        #endif

        private func receive(_ payload: [String: Any]) {
            guard let data = payload[Self.payloadKey] as? Data else { return }
            continuation.yield(.received(data))
        }
    }
#endif
