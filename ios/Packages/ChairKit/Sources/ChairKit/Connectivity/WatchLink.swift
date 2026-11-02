//
//  WatchLink.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import Observation

@MainActor
@Observable
public final class WatchLink {
    public static let appliedIDLimit = 100

    public private(set) var isReachable = false
    public private(set) var pendingInputCount = 0
    public private(set) var isWaitingForPeer = false
    public private(set) var isVersionMismatched = false
    public private(set) var lastAckLatency: Duration?

    @ObservationIgnored public let messages: AsyncStream<WatchMessage>
    @ObservationIgnored public let inputs: AsyncStream<WatchInput>
    @ObservationIgnored public let reachabilityStream: AsyncStream<Bool>

    @ObservationIgnored private let transport: any WatchTransport
    @ObservationIgnored private let retryInterval: Duration
    @ObservationIgnored private let retryLimit: Duration
    @ObservationIgnored private let messageContinuation: AsyncStream<WatchMessage>.Continuation
    @ObservationIgnored private let inputContinuation: AsyncStream<WatchInput>.Continuation
    @ObservationIgnored private let reachabilityContinuation: AsyncStream<Bool>.Continuation
    @ObservationIgnored private var pending: [Pending] = []
    @ObservationIgnored private var appliedIDs: [UUID] = []
    @ObservationIgnored private var listenTask: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?

    public init(
        transport: any WatchTransport,
        retryInterval: Duration = .seconds(3),
        retryLimit: Duration = .seconds(30)
    ) {
        self.transport = transport
        self.retryInterval = retryInterval
        self.retryLimit = retryLimit
        (messages, messageContinuation) = AsyncStream.makeStream(of: WatchMessage.self)
        (inputs, inputContinuation) = AsyncStream.makeStream(of: WatchInput.self)
        (reachabilityStream, reachabilityContinuation) = AsyncStream.makeStream(of: Bool.self)
    }

    #if canImport(WatchConnectivity)
        public convenience init() {
            self.init(transport: WCSessionTransport())
        }
    #endif

    public func activate() {
        guard listenTask == nil else { return }
        let events = transport.events
        listenTask = Task { [weak self] in
            for await event in events {
                guard let self else { return }
                await handle(event)
            }
        }
        transport.activate()
        setReachable(transport.isReachable)
    }

    public func send(_ input: WatchInput) async {
        guard !isVersionMismatched else { return }
        pending.append(Pending(input: input, firstSentAt: .now))
        pendingInputCount = pending.count
        await deliver(.input(input))
        startRetrying()
    }

    public func send(_ message: WatchMessage) async {
        guard !isVersionMismatched else { return }
        await deliver(message)
    }

    public func queue(_ message: WatchMessage) {
        guard !isVersionMismatched else { return }
        transport.transferUserInfo(WatchEnvelope(message).data)
    }

    public func acknowledge(_ inputID: UUID) async {
        await send(.ack(inputID: inputID))
    }

    private func deliver(_ message: WatchMessage) async {
        let data = WatchEnvelope(message).data
        guard transport.isReachable else {
            transport.transferUserInfo(data)
            return
        }
        do {
            try await transport.sendMessage(data)
        } catch {
            transport.transferUserInfo(data)
        }
    }

    private func handle(_ event: WatchTransportEvent) async {
        switch event {
        case let .reachability(reachable):
            setReachable(reachable)
            if reachable {
                await resendHeld()
            }
        case let .received(data):
            switch WatchEnvelope.decode(data) {
            case .versionMismatch:
                isVersionMismatched = true
            case let .message(message):
                await receive(message)
            case nil:
                break
            }
        }
    }

    private func receive(_ message: WatchMessage) async {
        switch message {
        case let .input(input):
            await receive(input)
        case let .ack(inputID):
            settle(inputID)
            messageContinuation.yield(message)
        default:
            messageContinuation.yield(message)
        }
    }

    private func receive(_ input: WatchInput) async {
        guard !appliedIDs.contains(input.id) else {
            await acknowledge(input.id)
            return
        }
        appliedIDs.append(input.id)
        if appliedIDs.count > Self.appliedIDLimit {
            appliedIDs.removeFirst(appliedIDs.count - Self.appliedIDLimit)
        }
        inputContinuation.yield(input)
    }

    private func settle(_ inputID: UUID) {
        guard let index = pending.firstIndex(where: { $0.input.id == inputID }) else { return }
        lastAckLatency = .now - pending[index].firstSentAt
        pending.remove(at: index)
        pendingInputCount = pending.count
        isWaitingForPeer = isWaitingForPeer && !pending.isEmpty
    }

    private func setReachable(_ reachable: Bool) {
        guard reachable != isReachable else { return }
        isReachable = reachable
        reachabilityContinuation.yield(reachable)
    }

    private func startRetrying() {
        guard retryTask == nil else { return }
        retryTask = Task { [weak self, retryInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: retryInterval)
                guard let self, await retry() else { return }
            }
        }
    }

    private func retry() async -> Bool {
        guard !pending.isEmpty else {
            retryTask = nil
            return false
        }
        let now = ContinuousClock.now
        if pending.contains(where: { now - $0.firstSentAt >= retryLimit }) {
            isWaitingForPeer = true
        }
        guard !isWaitingForPeer, transport.isReachable else { return true }
        for item in pending {
            await deliver(.input(item.input))
        }
        return true
    }

    private func resendHeld() async {
        guard !pending.isEmpty else { return }
        isWaitingForPeer = false
        let now = ContinuousClock.now
        pending = pending.map { Pending(input: $0.input, firstSentAt: now) }
        for item in pending {
            await deliver(.input(item.input))
        }
        startRetrying()
    }
}

private struct Pending {
    let input: WatchInput
    let firstSentAt: ContinuousClock.Instant
}
