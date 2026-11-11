//
//  MatchSessionView+Camera.swift
//  Chair
//
//  Created by Aaron Musa on 11/12/26.
//

import SwiftUI

import ChairKit

extension MatchSessionView {
    func handleStopCamera() -> () -> Void {
        { [camera] in
            Task { await camera?.stop() }
        }
    }

    func startCamera() async {
        guard camera == nil, let calibration = viewModel.calibration, viewModel.phase != .complete else { return }
        let model = CameraPanelModel(
            matchID: viewModel.matchID,
            calibration: calibration,
            makeCapture: makeCapture,
            suggester: CourtLineSuggester(),
            repository: viewModel.repositoryForCamera,
            clock: environment.clock
        )
        camera = model
        await model.start()
    }
}
