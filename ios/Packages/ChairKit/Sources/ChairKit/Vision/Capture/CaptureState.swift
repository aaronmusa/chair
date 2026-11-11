//
//  CaptureState.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/11/26.
//

import CoreVideo
import Foundation

public enum CaptureLens: String, Codable, Sendable {
    case ultraWide
    case wide
}

public struct CaptureFormat: Equatable, Sendable {
    public static let fullHD = (width: 1920, height: 1080)

    public let lens: CaptureLens
    public let width: Int
    public let height: Int
    public let frameRate: Int

    public init(
        lens: CaptureLens,
        width: Int = CaptureFormat.fullHD.width,
        height: Int = CaptureFormat.fullHD.height,
        frameRate: Int
    ) {
        self.lens = lens
        self.width = width
        self.height = height
        self.frameRate = frameRate
    }

    public func with(frameRate: Int) -> CaptureFormat {
        CaptureFormat(lens: lens, width: width, height: height, frameRate: frameRate)
    }
}

public enum CaptureState: Equatable, Sendable {
    public enum Interruption: Equatable, Sendable {
        case otherApp
        case background
        case systemPressure
        case unknown
    }

    public enum Unavailable: Equatable, Sendable {
        case permissionDenied
        case noCamera
        case failed
    }

    case idle
    case running(CaptureFormat)
    case interrupted(Interruption)
    case pausedForHeat
    case unavailable(Unavailable)
}

public extension CaptureState {
    static func running(
        frameRate: Int,
        lens: CaptureLens = .ultraWide
    ) -> CaptureState {
        .running(CaptureFormat(lens: lens, frameRate: frameRate))
    }
}

public enum CameraPermission: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
}

public protocol CameraAuthorizing: Sendable {
    func status() -> CameraPermission
    func request() async -> Bool
}

public enum ThermalPolicy {
    public static let reducedFrameRate = 30

    public static func frameRate(
        for state: ProcessInfo.ThermalState,
        preferred: Int
    ) -> Int? {
        switch state {
        case .nominal, .fair: preferred
        case .serious: min(preferred, reducedFrameRate)
        case .critical: nil
        @unknown default: preferred
        }
    }
}

public protocol CaptureSource: AnyObject, Sendable {
    var fanOut: FrameFanOut { get }
    var state: CaptureState { get }
    func states() -> AsyncStream<CaptureState>
    func start() async
    func stop() async
    func captureStill() async -> CVPixelBuffer?
}

public final class CaptureStateFeed: @unchecked Sendable {
    private let lock = NSLock()
    private var current: CaptureState = .idle
    private var continuations: [UUID: AsyncStream<CaptureState>.Continuation] = [:]

    public init() {}

    public var state: CaptureState {
        lock.withLock { current }
    }

    public func send(_ state: CaptureState) {
        let targets: [AsyncStream<CaptureState>.Continuation] = lock.withLock {
            guard current != state else { return [] }
            current = state
            return Array(continuations.values)
        }
        targets.forEach { $0.yield(state) }
    }

    public func stream() -> AsyncStream<CaptureState> {
        let (stream, continuation) = AsyncStream.makeStream(of: CaptureState.self, bufferingPolicy: .bufferingNewest(8))
        let id = UUID()
        let first = lock.withLock {
            continuations[id] = continuation
            return current
        }
        continuation.yield(first)
        continuation.onTermination = handleTermination(id)
        return stream
    }

    private func handleTermination(_ id: UUID) -> @Sendable (AsyncStream<CaptureState>.Continuation.Termination) -> Void {
        { [weak self] _ in
            guard let self else { return }
            lock.withLock { _ = continuations.removeValue(forKey: id) }
        }
    }
}
