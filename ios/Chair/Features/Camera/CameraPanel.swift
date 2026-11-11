//
//  CameraPanel.swift
//  Chair
//
//  Created by Aaron Musa on 11/12/26.
//

import CoreGraphics
import CoreMedia
import Foundation
import Observation
import SwiftUI

import ChairKit
import ChairUI

@MainActor
@Observable
final class CameraPanelModel {
    static let stillInterval = Duration.milliseconds(250)

    let matchID: UUID
    private(set) var calibration: CourtCalibration
    private(set) var capture: any CaptureSource
    private(set) var captureState = CaptureState.idle
    private(set) var still: CGImage?
    var isRecalibrating = false

    private let makeCapture: () -> any CaptureSource
    private let suggester: any KeypointSuggesting
    private let repository: (any MatchRepository)?
    private let clock: any ClockProvider
    private let courts: (any SavedCourtRepository)?
    private let locator: (any CourtLocating)?
    private var watching: Task<Void, Never>?
    private var previewing: Task<Void, Never>?

    init(
        matchID: UUID,
        calibration: CourtCalibration,
        makeCapture: @escaping () -> any CaptureSource,
        suggester: any KeypointSuggesting,
        repository: (any MatchRepository)?,
        clock: any ClockProvider,
        courts: (any SavedCourtRepository)? = nil,
        locator: (any CourtLocating)? = nil
    ) {
        self.courts = courts
        self.locator = locator
        self.matchID = matchID
        self.calibration = calibration
        self.makeCapture = makeCapture
        self.suggester = suggester
        self.repository = repository
        self.clock = clock
        capture = makeCapture()
    }

    var lines: [[CGPoint]] {
        CourtOverlay.lines(through: calibration.homography, frameSize: calibration.frameSize)
    }

    var chip: String {
        guard case let .running(format) = captureState else { return "Calibrated" }
        return "\(format.frameRate) fps · Calibrated"
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
        guard !(capture is CaptureSession) else { return }
        previewing?.cancel()
        previewing = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshStill()
                try? await Task.sleep(for: Self.stillInterval)
            }
        }
    }

    func stop() async {
        watching?.cancel()
        previewing?.cancel()
        await capture.stop()
        captureState = capture.state
    }

    func refreshStill() async {
        guard let buffer = await capture.captureStill(),
              let image = await LumaImage.from(Frame(pixelBuffer: buffer, time: .zero)) else { return }
        still = image.cgImage()
    }

    func recalibrate() async {
        await stop()
        isRecalibrating = true
    }

    func makeCalibrationModel() -> CalibrationViewModel {
        CalibrationViewModel(
            matchID: matchID,
            placement: calibration.placement,
            capture: makeCapture(),
            suggester: suggester,
            repository: repository,
            clock: clock,
            initial: calibration.keypoints,
            courts: courts,
            locator: locator,
            onNext: handleRecalibrated()
        )
    }

    func finishRecalibration() async {
        if let match = try? repository?.fetch().first(where: { $0.remoteID == matchID }), let updated = match.calibration {
            calibration = updated
        }
        isRecalibrating = false
        capture = makeCapture()
        await start()
    }

    private func handleRecalibrated() -> (UUID) -> Void {
        { [weak self] _ in
            guard let self else { return }
            Task { await self.finishRecalibration() }
        }
    }
}

struct CameraPanelView: View {
    @Bindable var model: CameraPanelModel

    var body: some View {
        GeometryReader { proxy in
            let mapping = FrameMapping(viewSize: proxy.size, frameSize: model.calibration.frameSize)
            ZStack {
                CameraPreview(capture: model.capture, still: model.still)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .accessibilityHidden(true)
                CourtLinesOverlay(lines: model.lines, mapping: mapping)
            }
        }
        .background(Color.black)
        .overlay(alignment: .topLeading) { chip }
        .overlay(alignment: .topTrailing) { recalibrateButton }
        .overlay(alignment: .bottom) {
            CaptureStatusView(state: model.captureState)
                .padding(Spacing.chair.sm)
        }
        .clipped()
        .environment(\.colorScheme, .dark)
        .fullScreenCover(isPresented: $model.isRecalibrating) {
            NavigationStack {
                CalibrationView(viewModel: model.makeCalibrationModel())
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session.camera")
    }

    private var chip: some View {
        Label(model.chip, systemImage: "video.fill")
            .chairFont(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.chair.sm)
            .padding(.vertical, Spacing.chair.xxs)
            .background(.black.opacity(0.6), in: Capsule())
            .padding(Spacing.chair.sm)
            .accessibilityIdentifier("session.camera.chip")
    }

    private var recalibrateButton: some View {
        Button("Recalibrate", systemImage: "scope", action: handleRecalibrate())
            .chairFont(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.chair.sm)
            .padding(.vertical, Spacing.chair.xxs)
            .background(.black.opacity(0.6), in: Capsule())
            .padding(Spacing.chair.sm)
            .accessibilityIdentifier("session.camera.recalibrate")
    }

    private func handleRecalibrate() -> () -> Void {
        { Task { await model.recalibrate() } }
    }
}
