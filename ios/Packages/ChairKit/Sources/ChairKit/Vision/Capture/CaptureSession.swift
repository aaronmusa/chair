//
//  CaptureSession.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/11/26.
//

#if os(iOS)
    import AVFoundation
    import Foundation
    import UIKit

    public struct SystemCameraAuthorization: CameraAuthorizing {
        public init() {}

        public func status() -> CameraPermission {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: .authorized
            case .notDetermined: .notDetermined
            default: .denied
            }
        }

        public func request() async -> Bool {
            await AVCaptureDevice.requestAccess(for: .video)
        }
    }

    public final class CaptureSession: NSObject, CaptureSource, @unchecked Sendable {
        public enum Lens: String, Sendable {
            case ultraWide
            case wide
        }

        public struct Choice {
            public let lens: Lens
            public let format: AVCaptureDevice.Format
            public let frameRate: Int
        }

        public struct Configuration: Equatable, Sendable {
            public let lens: Lens
            public let frameRate: Int
        }

        public static let preferredFrameRate = 60
        public static let settleDelay: TimeInterval = 2
        public static let width: Int32 = 1920
        public static let height: Int32 = 1080

        public let fanOut = FrameFanOut()
        public let session = AVCaptureSession()
        public private(set) var configuration: Configuration?
        private let queue = DispatchQueue(label: "chair.capture", qos: .userInitiated)
        private let feed = CaptureStateFeed()
        private let authorization: any CameraAuthorizing
        private let output = AVCaptureVideoDataOutput()
        private var device: AVCaptureDevice?
        private var observers: [NSObjectProtocol] = []

        public init(authorization: any CameraAuthorizing = SystemCameraAuthorization()) {
            self.authorization = authorization
            super.init()
        }

        public var state: CaptureState {
            feed.state
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
            let result = await onQueue { [self] in configureAndRun() }
            guard let result else { return }
            feed.send(result)
            if case .running = result {
                observe()
                await setIdleTimerDisabled(true)
            }
        }

        public func stop() async {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            _ = await onQueue { [self] in
                session.stopRunning()
                return CaptureState.idle
            }
            feed.send(.idle)
            await setIdleTimerDisabled(false)
        }

        public static func choose(_ devices: [(Lens, [AVCaptureDevice.Format])]) -> Choice? {
            let candidates = devices.flatMap { lens, formats in
                formats.filter(isFullHD).map { Choice(lens: lens, format: $0, frameRate: maxFrameRate($0)) }
            }
            if let sixty = candidates.first(where: { $0.frameRate >= preferredFrameRate }) {
                return Choice(lens: sixty.lens, format: sixty.format, frameRate: preferredFrameRate)
            }
            return candidates.max { $0.frameRate < $1.frameRate }.map {
                Choice(lens: $0.lens, format: $0.format, frameRate: min($0.frameRate, ThermalPolicy.reducedFrameRate))
            }
        }

        private static func isFullHD(_ format: AVCaptureDevice.Format) -> Bool {
            let size = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return size.width == width && size.height == height
        }

        private static func maxFrameRate(_ format: AVCaptureDevice.Format) -> Int {
            Int(format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0)
        }

        private func configureAndRun() -> CaptureState {
            let lenses: [(Lens, AVCaptureDevice.DeviceType)] = [(.ultraWide, .builtInUltraWideCamera), (.wide, .builtInWideAngleCamera)]
            let available = lenses.compactMap { lens, type in
                AVCaptureDevice.default(type, for: .video, position: .back).map { (lens, $0) }
            }
            guard let choice = Self.choose(available.map { ($0.0, $0.1.formats) }),
                  let camera = available.first(where: { $0.0 == choice.lens })?.1 else {
                return .unavailable(.noCamera)
            }
            let frameRate = choice.frameRate
            do {
                session.beginConfiguration()
                session.sessionPreset = .inputPriority
                session.inputs.forEach(session.removeInput)
                let input = try AVCaptureDeviceInput(device: camera)
                guard session.canAddInput(input) else { throw CaptureError.cannotAdd }
                session.addInput(input)
                if !session.outputs.contains(output) {
                    output.alwaysDiscardsLateVideoFrames = true
                    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
                    output.setSampleBufferDelegate(self, queue: queue)
                    guard session.canAddOutput(output) else { throw CaptureError.cannotAdd }
                    session.addOutput(output)
                }
                try camera.lockForConfiguration()
                camera.activeFormat = choice.format
                apply(frameRate: frameRate, to: camera)
                camera.unlockForConfiguration()
                if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(0) {
                    connection.videoRotationAngle = 0
                }
                session.commitConfiguration()
            } catch {
                session.commitConfiguration()
                return .unavailable(.failed)
            }
            device = camera
            configuration = Configuration(lens: choice.lens, frameRate: frameRate)
            fanOut.setFrameRate(frameRate)
            session.startRunning()
            queue.asyncAfter(deadline: .now() + Self.settleDelay, execute: handleSettle())
            let thermal = ThermalPolicy.frameRate(for: ProcessInfo.processInfo.thermalState, preferred: frameRate)
            return thermal.map { .running(frameRate: $0) } ?? .pausedForHeat
        }

        private func apply(
            frameRate: Int,
            to camera: AVCaptureDevice
        ) {
            let duration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
            camera.activeVideoMinFrameDuration = duration
            camera.activeVideoMaxFrameDuration = duration
        }

        private func handleSettle() -> @Sendable () -> Void {
            { [weak self] in
                guard let self, let camera = device, (try? camera.lockForConfiguration()) != nil else { return }
                if camera.isExposureModeSupported(.locked) {
                    camera.exposureMode = .locked
                }
                if camera.isWhiteBalanceModeSupported(.locked) {
                    camera.whiteBalanceMode = .locked
                }
                if camera.isFocusModeSupported(.locked) {
                    camera.focusMode = .locked
                }
                camera.unlockForConfiguration()
            }
        }

        private func observe() {
            let center = NotificationCenter.default
            observers = [
                center.addObserver(
                    forName: AVCaptureSession.wasInterruptedNotification,
                    object: session,
                    queue: nil,
                    using: handleInterruption()
                ),
                center.addObserver(
                    forName: AVCaptureSession.interruptionEndedNotification,
                    object: session,
                    queue: nil,
                    using: handleResume()
                ),
                center.addObserver(
                    forName: AVCaptureSession.runtimeErrorNotification,
                    object: session,
                    queue: nil,
                    using: handleRuntimeError()
                ),
                center.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: nil, using: handleThermal()),
            ]
        }

        private func handleInterruption() -> @Sendable (Notification) -> Void {
            { [weak self] notification in
                let raw = (notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? NSNumber)?.intValue
                let reason = raw.flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
                self?.feed.send(.interrupted(Self.interruption(reason)))
            }
        }

        private func handleResume() -> @Sendable (Notification) -> Void {
            { [weak self] _ in self?.applyThermalState() }
        }

        private func handleRuntimeError() -> @Sendable (Notification) -> Void {
            { [weak self] _ in
                guard let self else { return }
                queue.async(execute: handleRestart())
            }
        }

        private func handleRestart() -> @Sendable () -> Void {
            { [weak self] in
                guard let self else { return }
                session.startRunning()
                if !session.isRunning {
                    feed.send(.unavailable(.failed))
                }
            }
        }

        private func handleThermal() -> @Sendable (Notification) -> Void {
            { [weak self] _ in self?.applyThermalState() }
        }

        private func applyThermalState() {
            guard let configuration else { return }
            guard let frameRate = ThermalPolicy.frameRate(
                for: ProcessInfo.processInfo.thermalState,
                preferred: configuration.frameRate
            ) else {
                queue.async(execute: handlePause())
                feed.send(.pausedForHeat)
                return
            }
            queue.async(execute: handleFrameRate(frameRate))
            fanOut.setFrameRate(frameRate)
            feed.send(.running(frameRate: frameRate))
        }

        private func handlePause() -> @Sendable () -> Void {
            { [weak self] in self?.session.stopRunning() }
        }

        private func handleFrameRate(_ frameRate: Int) -> @Sendable () -> Void {
            { [weak self] in
                guard let self, let camera = device, (try? camera.lockForConfiguration()) != nil else { return }
                apply(frameRate: frameRate, to: camera)
                camera.unlockForConfiguration()
                if !session.isRunning {
                    session.startRunning()
                }
            }
        }

        private static func interruption(_ reason: AVCaptureSession.InterruptionReason?) -> CaptureState.Interruption {
            switch reason {
            case .videoDeviceInUseByAnotherClient: .otherApp
            case .videoDeviceNotAvailableInBackground: .background
            case .videoDeviceNotAvailableDueToSystemPressure: .systemPressure
            default: .unknown
            }
        }

        private func onQueue(_ work: @escaping @Sendable () -> CaptureState) async -> CaptureState? {
            await withCheckedContinuation { continuation in
                queue.async { continuation.resume(returning: work()) }
            }
        }

        @MainActor
        private func setIdleTimerDisabled(_ disabled: Bool) {
            UIApplication.shared.isIdleTimerDisabled = disabled
        }
    }

    extension CaptureSession: AVCaptureVideoDataOutputSampleBufferDelegate {
        public func captureOutput(
            _: AVCaptureOutput,
            didOutput sampleBuffer: CMSampleBuffer,
            from _: AVCaptureConnection
        ) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            fanOut.deliver(Frame(pixelBuffer: pixelBuffer, time: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)))
        }
    }

    private enum CaptureError: Error {
        case cannotAdd
    }
#endif
