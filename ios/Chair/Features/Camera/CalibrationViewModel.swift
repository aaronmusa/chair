//
//  CalibrationViewModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/12/26.
//

import CoreGraphics
import CoreMedia
import Foundation
import Observation

import ChairKit

struct ReadinessPill: Identifiable, Equatable {
    enum Level: Equatable {
        case ok
        case neutral
        case warning
    }

    let id: String
    let title: String
    let level: Level
}

@MainActor
@Observable
final class CalibrationViewModel {
    static let suggestInterval = Duration.seconds(2)
    static let lowLight = 55.0
    static let glare = 225.0
    static let depthTarget = 15.0
    static let fitTarget = 3.0
    static let fitLimit = 8.0

    let matchID: UUID
    let placement: CameraPlacement
    let order: [CourtKeypoint]
    let capture: any CaptureSource
    private(set) var keypoints: [CourtKeypoint: CGPoint] = [:]
    private(set) var skipped: Set<CourtKeypoint> = []
    private(set) var isTouched = false
    private(set) var captureState = CaptureState.idle
    private(set) var meanLuminance: Double?
    private(set) var still: CGImage?
    private(set) var debugMask: CGImage?
    private(set) var errorMessage: String?
    var isShowingMask = false

    private let suggester: any KeypointSuggesting
    private let repository: (any MatchRepository)?
    private let clock: any ClockProvider
    private let onNext: (UUID) -> Void
    private var suggesting: Task<Void, Never>?
    private var watching: Task<Void, Never>?

    init(
        matchID: UUID,
        placement: CameraPlacement,
        capture: any CaptureSource,
        suggester: any KeypointSuggesting,
        repository: (any MatchRepository)?,
        clock: any ClockProvider,
        initial: [CourtKeypoint: CGPoint] = [:],
        onNext: @escaping (UUID) -> Void
    ) {
        self.matchID = matchID
        self.placement = placement
        order = CourtKeypoint.defaultSet(for: placement)
        self.capture = capture
        self.suggester = suggester
        self.repository = repository
        self.clock = clock
        self.onNext = onNext
        keypoints = initial
        isTouched = !initial.isEmpty
    }

    var frameSize: CGSize {
        guard case let .running(format) = captureState else {
            return CGSize(width: CaptureFormat.fullHD.width, height: CaptureFormat.fullHD.height)
        }
        return CGSize(width: format.width, height: format.height)
    }

    var nextKeypoint: CourtKeypoint? {
        order.first { keypoints[$0] == nil && !skipped.contains($0) }
    }

    var refusal: Homography.Refusal? {
        Homography.refusal(for: Array(keypoints.keys))
    }

    var homography: Homography? {
        refusal == nil ? Homography(keypoints) : nil
    }

    var canContinue: Bool {
        homography != nil
    }

    var quality: CalibrationQuality? {
        homography.map { CalibrationQuality(homography: $0, keypoints: keypoints, frameSize: frameSize) }
    }

    var projectedLines: [[CGPoint]] {
        guard let homography else { return [] }
        let bounds = CGRect(origin: .zero, size: frameSize).insetBy(dx: -frameSize.width, dy: -frameSize.height)
        return CourtModel.lines.map { segment in
            (0 ... 24).compactMap { step -> CGPoint? in
                let t = Double(step) / 24
                let court = CourtPoint(
                    x: segment.from.x + (segment.to.x - segment.from.x) * t,
                    y: segment.from.y + (segment.to.y - segment.from.y) * t
                )
                let pixel = homography.toPixel(court)
                guard bounds.contains(pixel), homography.toCourt(pixel) != nil else { return nil }
                return pixel
            }
        }
        .filter { $0.count > 1 }
    }

    var pills: [ReadinessPill] {
        [framingPill, cameraPill, lightPill, depthPill, fitPill].compactMap(\.self)
    }

    func start() async {
        await capture.start()
        captureState = capture.state
        watching?.cancel()
        let states = capture.states()
        watching = Task { [weak self] in
            for await state in states {
                self?.captureState = state
            }
        }
        suggesting?.cancel()
        suggesting = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: Self.suggestInterval)
            }
        }
    }

    func stop() async {
        suggesting?.cancel()
        suggesting = nil
        watching?.cancel()
        watching = nil
        await capture.stop()
        captureState = capture.state
    }

    func refresh() async {
        guard let buffer = await capture.captureStill(),
              let image = await LumaImage.from(Frame(pixelBuffer: buffer, time: .zero)) else { return }
        meanLuminance = image.meanLuminance
        still = image.cgImage()
        guard !isTouched else { return }
        let suggestion = await suggester.suggest(in: image, placement: placement, frameSize: frameSize)
        guard !isTouched, suggestion.confidence >= CourtLineDetector.minimumConfidence else { return }
        keypoints = suggestion.keypoints
        #if DEBUG
            debugMask = LineMask(image).cgImage()
        #endif
    }

    func place(at point: CGPoint) {
        guard let keypoint = nextKeypoint else { return }
        isTouched = true
        keypoints[keypoint] = point
    }

    func move(
        _ keypoint: CourtKeypoint,
        to point: CGPoint
    ) {
        isTouched = true
        keypoints[keypoint] = CGPoint(
            x: min(max(point.x, 0), frameSize.width),
            y: min(max(point.y, 0), frameSize.height)
        )
    }

    func skip(_ keypoint: CourtKeypoint) {
        isTouched = true
        keypoints[keypoint] = nil
        skipped.insert(keypoint)
    }

    func redo() {
        keypoints = [:]
        skipped = []
        isTouched = false
    }

    func finish() {
        errorMessage = nil
        guard let calibration = CourtCalibration(
            keypoints: keypoints,
            placement: placement,
            lens: lens,
            frameSize: frameSize,
            date: clock.now
        ) else {
            errorMessage = refusal?.message ?? "Place at least 4 points"
            return
        }
        guard let repository, let match = try? repository.fetch().first(where: { $0.remoteID == matchID }) else {
            errorMessage = "Couldn't find this match. Go back and start it again."
            return
        }
        do {
            match.cameraPlacementValue = placement
            match.calibration = calibration
            try repository.save(match)
            onNext(matchID)
        } catch {
            errorMessage = "Couldn't save the calibration. Try again."
        }
    }

    private var lens: CaptureLens {
        guard case let .running(format) = captureState else { return .ultraWide }
        return format.lens
    }

    private var framingPill: ReadinessPill? {
        let corners = order.filter { $0.along == .farBaseline || $0.along == .nearBaseline }
            .filter { $0.across == .doublesLeft || $0.across == .doublesRight }
        guard let homography else {
            return ReadinessPill(id: "framing", title: "Place the corners", level: .neutral)
        }
        let frame = CGRect(origin: .zero, size: frameSize)
        let inFrame = corners.allSatisfy { frame.contains(homography.toPixel($0.court)) }
        let title = placement == .baseline ? "All corners in frame" : "Far corners in frame"
        return ReadinessPill(id: "framing", title: inFrame ? title : "Corners out of frame", level: inFrame ? .ok : .warning)
    }

    private var cameraPill: ReadinessPill? {
        guard case let .running(format) = captureState else { return nil }
        let lensTitle = format.lens == .ultraWide ? "0.5×" : "1×"
        let level: ReadinessPill.Level = format.lens == .ultraWide && format.frameRate >= CaptureSession.preferredFrameRate ? .ok : .warning
        return ReadinessPill(id: "camera", title: "\(lensTitle) · \(format.frameRate) fps", level: level)
    }

    private var lightPill: ReadinessPill? {
        guard let meanLuminance else { return nil }
        if meanLuminance < Self.lowLight {
            return ReadinessPill(id: "light", title: "Low light", level: .warning)
        }
        if meanLuminance > Self.glare {
            return ReadinessPill(id: "light", title: "Glare", level: .warning)
        }
        return ReadinessPill(id: "light", title: "Light OK", level: .ok)
    }

    private var depthPill: ReadinessPill? {
        guard let error = quality?.baselineError else { return nil }
        let centimetres = Int((error * 2).rounded())
        return ReadinessPill(
            id: "depth",
            title: "Baseline depth ±\(centimetres) cm",
            level: Double(centimetres) <= Self.depthTarget ? .ok : .warning
        )
    }

    private var fitPill: ReadinessPill? {
        guard let quality, keypoints.count > Homography.minimumPoints else { return nil }
        let error = quality.reprojectionError
        let level: ReadinessPill.Level = error <= Self.fitTarget ? .ok : error > Self.fitLimit ? .warning : .neutral
        return ReadinessPill(id: "fit", title: "Fit \(Int(error.rounded())) px", level: level)
    }
}
