//
//  FakeCaptureSession.swift
//  ChairTestSupport
//
//  Created by Aaron Musa on 11/11/26.
//

#if DEBUG && !os(watchOS)
    import AVFoundation
    import CoreVideo
    import Foundation

    import ChairKit

    public struct FakeCameraAuthorization: CameraAuthorizing {
        public let permission: CameraPermission

        public init(_ permission: CameraPermission) {
            self.permission = permission
        }

        public func status() -> CameraPermission {
            permission
        }

        public func request() async -> Bool {
            permission == .authorized
        }
    }

    public final class FakeCaptureSession: CaptureSource, @unchecked Sendable {
        public enum Source: Sendable {
            case clip(URL)
            case blank(width: Int, height: Int)
        }

        public let fanOut: FrameFanOut
        private let feed = CaptureStateFeed()
        private let source: Source
        private let rate: Double
        private let preferredFrameRate: Int
        private let authorization: any CameraAuthorizing
        private let lens: CaptureLens
        private let lock = NSLock()
        private var replay: Task<Void, Never>?
        private var thermal = ProcessInfo.ThermalState.nominal
        private var interruption: CaptureState.Interruption?
        private var sent = 0
        private var latest: CVPixelBuffer?

        public init(
            source: Source,
            rate: Double = 60,
            lens: CaptureLens = .ultraWide,
            authorization: any CameraAuthorizing = FakeCameraAuthorization(.authorized)
        ) {
            self.lens = lens
            self.source = source
            self.rate = rate
            preferredFrameRate = Int(rate.rounded())
            self.authorization = authorization
            fanOut = FrameFanOut(frameRate: preferredFrameRate)
        }

        public var state: CaptureState {
            feed.state
        }

        public var framesSent: Int {
            lock.withLock { sent }
        }

        public func states() -> AsyncStream<CaptureState> {
            feed.stream()
        }

        public func start() async {
            if authorization.status() == .notDetermined {
                _ = await authorization.request()
            }
            guard authorization.status() == .authorized else {
                feed.send(.unavailable(.permissionDenied))
                return
            }
            publishState()
            replay?.cancel()
            replay = Task.detached(priority: .userInitiated) { [weak self] in await self?.runReplay() }
        }

        public func captureStill() async -> CVPixelBuffer? {
            lock.withLock { latest }
        }

        public func stop() async {
            replay?.cancel()
            replay = nil
            feed.send(.idle)
        }

        public func simulateThermal(_ state: ProcessInfo.ThermalState) {
            lock.withLock { thermal = state }
            publishState()
        }

        public func simulateInterruption(_ reason: CaptureState.Interruption) {
            lock.withLock { interruption = reason }
            publishState()
        }

        public func endInterruption() {
            lock.withLock { interruption = nil }
            publishState()
        }

        private func publishState() {
            let thermal: ProcessInfo.ThermalState = lock.withLock { self.thermal }
            if let interruption = lock.withLock({ self.interruption }) {
                feed.send(.interrupted(interruption))
                return
            }
            guard let frameRate = ThermalPolicy.frameRate(for: thermal, preferred: preferredFrameRate) else {
                feed.send(.pausedForHeat)
                return
            }
            fanOut.setFrameRate(frameRate)
            feed.send(.running(frameRate: frameRate, lens: lens))
        }

        private func runReplay() async {
            let clock = ContinuousClock()
            let start = clock.now
            var index = 0
            var frames = FrameSource(source)
            while !Task.isCancelled {
                guard let pixelBuffer = await frames.next() else { return }
                lock.withLock { latest = pixelBuffer }
                try? await clock.sleep(until: start + .seconds(Double(index) / rate))
                guard !Task.isCancelled else { return }
                if case let .running(format) = state, Self.keeps(index, of: rate, at: format.frameRate) {
                    fanOut.deliver(Frame(pixelBuffer: pixelBuffer, time: CMTime(seconds: Double(index) / rate, preferredTimescale: 600)))
                    lock.withLock { sent += 1 }
                }
                index += 1
            }
        }

        private static func keeps(
            _ index: Int,
            of rate: Double,
            at frameRate: Int
        ) -> Bool {
            let step = max(1, Int((rate / Double(frameRate)).rounded()))
            return index % step == 0
        }
    }

    private struct FrameSource {
        private let source: FakeCaptureSession.Source
        private var reader: AVAssetReader?
        private var output: AVAssetReaderTrackOutput?
        private var blank: CVPixelBuffer?

        init(_ source: FakeCaptureSession.Source) {
            self.source = source
        }

        mutating func next() async -> CVPixelBuffer? {
            switch source {
            case let .blank(width, height):
                if blank == nil {
                    blank = Self.makeBlank(width: width, height: height)
                }
                return blank
            case let .clip(url):
                if let buffer = output?.copyNextSampleBuffer().flatMap(CMSampleBufferGetImageBuffer) {
                    return buffer
                }
                guard await openReader(url) else { return nil }
                return output?.copyNextSampleBuffer().flatMap(CMSampleBufferGetImageBuffer)
            }
        }

        private mutating func openReader(_ url: URL) async -> Bool {
            reader?.cancelReading()
            let asset = AVURLAsset(url: url)
            guard let reader = try? AVAssetReader(asset: asset),
                  let track = try? await asset.loadTracks(withMediaType: .video).first else { return false }
            let output = AVAssetReaderTrackOutput(
                track: track,
                outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
            )
            output.alwaysCopiesSampleData = false
            reader.add(output)
            guard reader.startReading() else { return false }
            self.reader = reader
            self.output = output
            return true
        }

        private static func makeBlank(
            width: Int,
            height: Int
        ) -> CVPixelBuffer? {
            var buffer: CVPixelBuffer?
            CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, nil, &buffer)
            return buffer
        }
    }
#endif
