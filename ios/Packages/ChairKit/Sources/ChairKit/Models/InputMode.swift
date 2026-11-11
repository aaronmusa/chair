//
//  InputMode.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/2/26.
//

public enum InputMode: String, Codable, Sendable, CaseIterable {
    case manual
    case camera
}

public extension Match {
    var inputModeValue: InputMode? {
        InputMode(rawValue: inputMode)
    }

    var cameraPlacementValue: CameraPlacement? {
        get { cameraPlacement.flatMap(CameraPlacement.init(rawValue:)) }
        set { cameraPlacement = newValue?.rawValue }
    }
}
