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
    private(set) var savedCourts: [SavedCourt] = []
    private(set) var courtInUse: SavedCourt?
    private(set) var positionDiffers = false
    var isOfferingSave = false
    var isMeasuring = false
    private(set) var measurement: String?
    var saveName = ""

    private let suggester: any KeypointSuggesting
    private let repository: (any MatchRepository)?
    private let clock: any ClockProvider
    private let onNext: (UUID) -> Void
    private let courts: (any SavedCourtRepository)?
    private let locator: (any CourtLocating)?
    private var location: CourtLocation?
    private var checksCourt = false
    private var finished: CourtCalibration?
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
        courts: (any SavedCourtRepository)? = nil,
        locator: (any CourtLocating)? = nil,
        onNext: @escaping (UUID) -> Void
    ) {
        self.courts = courts
        self.locator = locator
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
        homography.map { CourtOverlay.lines(through: $0, frameSize: frameSize) } ?? []
    }

    var pills: [ReadinessPill] {
        [framingPill, cameraPill, lightPill, depthPill, fitPill].compactMap(\.self)
    }

    func start() async {
        savedCourts = ((try? courts?.fetch()) ?? []).filter { $0.calibration?.placement == placement }
        if location == nil, let locator {
            location = await locator.currentLocation()
        }
        if courtInUse == nil, keypoints.isEmpty, let here = location {
            let records = savedCourts.compactMap(\.record)
            if let nearest = SavedCourtMatching.nearest(records, to: here),
               let court = savedCourts.first(where: { $0.remoteID == nearest.id }) {
                use(court)
            }
        }
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
        if checksCourt, let saved = courtInUse?.calibration?.keypoints {
            checksCourt = false
            let suggestion = await suggester.suggest(in: image, placement: placement, frameSize: frameSize)
            guard suggestion.confidence >= CourtLineDetector.minimumConfidence else { return }
            positionDiffers = SavedCourtMatching.differs(
                saved: saved,
                suggested: suggestion.keypoints,
                frameWidth: Double(frameSize.width)
            )
            return
        }
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
        courtInUse = nil
        positionDiffers = false
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
        } catch {
            errorMessage = "Couldn't save the calibration. Try again."
            return
        }
        guard let courts else {
            onNext(matchID)
            return
        }
        finished = calibration
        if let court = courtInUse {
            court.calibration = calibration
            court.lastUsedAt = clock.now
            court.thumbnailFile = CourtThumbnails.save(still, id: court.remoteID) ?? court.thumbnailFile
            try? courts.save(court)
            onNext(matchID)
        } else {
            saveName = "Court \(savedCourts.count + 1)"
            isOfferingSave = true
        }
    }

    private var lens: CaptureLens {
        guard case let .running(format) = captureState else { return .ultraWide }
        return format.lens
    }
}

private extension CalibrationViewModel {
    var framingPill: ReadinessPill? {
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

    var cameraPill: ReadinessPill? {
        guard case let .running(format) = captureState else { return nil }
        let lensTitle = format.lens == .ultraWide ? "0.5×" : "1×"
        let level: ReadinessPill.Level = format.lens == .ultraWide && format.frameRate >= CaptureSession.preferredFrameRate ? .ok : .warning
        return ReadinessPill(id: "camera", title: "\(lensTitle) · \(format.frameRate) fps", level: level)
    }

    var lightPill: ReadinessPill? {
        guard let meanLuminance else { return nil }
        if meanLuminance < Self.lowLight {
            return ReadinessPill(id: "light", title: "Low light", level: .warning)
        }
        if meanLuminance > Self.glare {
            return ReadinessPill(id: "light", title: "Glare", level: .warning)
        }
        return ReadinessPill(id: "light", title: "Light OK", level: .ok)
    }

    var depthPill: ReadinessPill? {
        guard let error = quality?.baselineError else { return nil }
        let centimetres = Int((error * 2).rounded())
        return ReadinessPill(
            id: "depth",
            title: "Baseline depth ±\(centimetres) cm",
            level: Double(centimetres) <= Self.depthTarget ? .ok : .warning
        )
    }

    var fitPill: ReadinessPill? {
        guard let quality, keypoints.count > Homography.minimumPoints else { return nil }
        let error = quality.reprojectionError
        let level: ReadinessPill.Level = error <= Self.fitTarget ? .ok : error > Self.fitLimit ? .warning : .neutral
        return ReadinessPill(id: "fit", title: "Fit \(Int(error.rounded())) px", level: level)
    }
}

extension CalibrationViewModel {
    func use(_ court: SavedCourt) {
        guard let calibration = court.calibration else { return }
        keypoints = calibration.keypoints
        skipped = []
        isTouched = true
        courtInUse = court
        positionDiffers = false
        checksCourt = true
    }

    func saveCourt() {
        isOfferingSave = false
        guard let courts, let calibration = finished else { return onNext(matchID) }
        let name = saveName.trimmingCharacters(in: .whitespaces)
        let court = SavedCourt(
            name: name.isEmpty ? "Court \(savedCourts.count + 1)" : name,
            calibration: calibration,
            lastUsedAt: clock.now,
            latitude: location?.latitude,
            longitude: location?.longitude,
            createdAt: clock.now,
            updatedAt: clock.now
        )
        court.thumbnailFile = CourtThumbnails.save(still, id: court.remoteID)
        do {
            try courts.save(court)
        } catch {
            errorMessage = "Couldn't save the court. The match still has its calibration."
        }
        onNext(matchID)
    }

    func skipSavingCourt() {
        isOfferingSave = false
        onNext(matchID)
    }
}

extension CalibrationViewModel {
    func measure(at point: CGPoint) {
        guard let court = homography?.toCourt(point) else {
            measurement = "Place 4 points first"
            return
        }
        let x = (court.x * 100).rounded() / 100 + 0
        let y = (court.y * 100).rounded() / 100 + 0
        measurement = String(format: "x %.2f m · y %.2f m", x, y)
    }
}
