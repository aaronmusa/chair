//
//  FrameFanOut.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/11/26.
//

import CoreMedia
import CoreVideo
import Foundation

public struct Frame: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer
    public let time: CMTime

    public init(
        pixelBuffer: CVPixelBuffer,
        time: CMTime
    ) {
        self.pixelBuffer = pixelBuffer
        self.time = time
    }
}

public final class FrameFanOut: @unchecked Sendable {
    public struct Token: Hashable, Sendable {
        fileprivate let id: UUID
    }

    public struct Stats: Equatable, Sendable {
        public var delivered = 0
        public var dropped = 0
    }

    private final class Consumer: @unchecked Sendable {
        let priority: Int
        let minimumInterval: Double
        let queue: DispatchQueue
        let onFrame: @Sendable (Frame) -> Void
        let onFrameRate: @Sendable (Int) -> Void
        var isBusy = false
        var lastTime: Double?
        var stats = Stats()

        init(
            priority: Int,
            maxRate: Double,
            queue: DispatchQueue,
            onFrame: @escaping @Sendable (Frame) -> Void,
            onFrameRate: @escaping @Sendable (Int) -> Void
        ) {
            self.priority = priority
            minimumInterval = maxRate > 0 ? 1 / maxRate : 0
            self.queue = queue
            self.onFrame = onFrame
            self.onFrameRate = onFrameRate
        }
    }

    private static let intervalTolerance = 0.002

    private let lock = NSLock()
    private var consumers: [UUID: Consumer] = [:]
    private var currentFrameRate: Int

    public init(frameRate: Int = 60) {
        currentFrameRate = frameRate
    }

    public var frameRate: Int {
        lock.withLock { currentFrameRate }
    }

    @discardableResult
    public func register(
        label: String,
        priority: Int = 0,
        maxRate: Double,
        onFrame: @escaping @Sendable (Frame) -> Void,
        onFrameRate: @escaping @Sendable (Int) -> Void = { _ in }
    ) -> Token {
        let consumer = Consumer(
            priority: priority,
            maxRate: maxRate,
            queue: DispatchQueue(label: "chair.frames.\(label)", qos: .userInitiated),
            onFrame: onFrame,
            onFrameRate: onFrameRate
        )
        let token = Token(id: UUID())
        lock.withLock { consumers[token.id] = consumer }
        return token
    }

    public func unregister(_ token: Token) {
        lock.withLock { _ = consumers.removeValue(forKey: token.id) }
    }

    public func stats(_ token: Token) -> Stats? {
        lock.withLock { consumers[token.id]?.stats }
    }

    public func deliver(_ frame: Frame) {
        let seconds = frame.time.seconds
        let ready: [Consumer] = lock.withLock {
            consumers.values.sorted { $0.priority > $1.priority }.filter { consumer in
                if let last = consumer.lastTime, seconds - last < consumer.minimumInterval - Self.intervalTolerance {
                    return false
                }
                guard !consumer.isBusy else {
                    consumer.stats.dropped += 1
                    return false
                }
                consumer.isBusy = true
                consumer.lastTime = seconds
                consumer.stats.delivered += 1
                return true
            }
        }
        for consumer in ready {
            consumer.queue.async(execute: handleDelivery(of: frame, to: consumer))
        }
    }

    public func setFrameRate(_ frameRate: Int) {
        let targets: [Consumer] = lock.withLock {
            guard currentFrameRate != frameRate else { return [] }
            currentFrameRate = frameRate
            return Array(consumers.values)
        }
        for consumer in targets {
            consumer.queue.async(execute: handleFrameRate(frameRate, to: consumer))
        }
    }

    private func handleFrameRate(
        _ frameRate: Int,
        to consumer: Consumer
    ) -> @Sendable () -> Void {
        { consumer.onFrameRate(frameRate) }
    }

    private func handleDelivery(
        of frame: Frame,
        to consumer: Consumer
    ) -> @Sendable () -> Void {
        { [weak self] in
            consumer.onFrame(frame)
            guard let self else { return }
            lock.withLock { consumer.isBusy = false }
        }
    }
}
