//
//  WatchLink.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

#if canImport(WatchConnectivity)
    import Foundation
    import WatchConnectivity

    public final class WatchLink: NSObject, WCSessionDelegate, @unchecked Sendable {
        public enum LinkError: Error, Equatable {
            case unsupported
            case unreachable
            case noReply
        }

        public let messages: AsyncStream<WatchMessage>

        private let session: WCSession?
        private let continuation: AsyncStream<WatchMessage>.Continuation
        private let reply: @Sendable (WatchMessage) -> WatchMessage?

        public init(reply: @escaping @Sendable (WatchMessage) -> WatchMessage? = WatchMessage.defaultReply(to:)) {
            session = WCSession.isSupported() ? WCSession.default : nil
            (messages, continuation) = AsyncStream.makeStream(of: WatchMessage.self)
            self.reply = reply
            super.init()
        }

        public func activate() {
            session?.delegate = self
            session?.activate()
        }

        public var isReachable: Bool {
            session?.isReachable ?? false
        }

        public func send(_ message: WatchMessage) async throws -> WatchMessage {
            guard let session else { throw LinkError.unsupported }
            guard session.isReachable else { throw LinkError.unreachable }
            return try await withCheckedThrowingContinuation { continuation in
                session.sendMessage(message.payload) { response in
                    if let answer = WatchMessage(payload: response) {
                        continuation.resume(returning: answer)
                    } else {
                        continuation.resume(throwing: LinkError.noReply)
                    }
                } errorHandler: { error in
                    continuation.resume(throwing: error)
                }
            }
        }

        public func session(
            _: WCSession,
            activationDidCompleteWith _: WCSessionActivationState,
            error _: (any Error)?
        ) {}

        public func session(
            _: WCSession,
            didReceiveMessage message: [String: Any],
            replyHandler: @escaping ([String: Any]) -> Void
        ) {
            guard let received = WatchMessage(payload: message) else { return }
            continuation.yield(received)
            if let answer = reply(received) {
                replyHandler(answer.payload)
            }
        }

        public func session(
            _: WCSession,
            didReceiveMessage message: [String: Any]
        ) {
            guard let received = WatchMessage(payload: message) else { return }
            continuation.yield(received)
        }

        #if os(iOS)
            public func sessionDidBecomeInactive(_: WCSession) {}

            public func sessionDidDeactivate(_ session: WCSession) {
                session.activate()
            }
        #endif
    }
#endif
