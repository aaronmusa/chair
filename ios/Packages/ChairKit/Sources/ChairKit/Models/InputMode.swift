//
//  InputMode.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation

public enum InputMode: String, Codable, Sendable, CaseIterable {
    case manual
    case camera
}

public extension Match {
    var inputModeValue: InputMode? {
        InputMode(rawValue: inputMode)
    }

    var calibration: CourtCalibration? {
        get { calibrationData.flatMap { try? JSONDecoder().decode(CourtCalibration.self, from: $0) } }
        set { calibrationData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    var cameraPlacementValue: CameraPlacement? {
        get { cameraPlacement.flatMap(CameraPlacement.init(rawValue:)) }
        set { cameraPlacement = newValue?.rawValue }
    }
}
