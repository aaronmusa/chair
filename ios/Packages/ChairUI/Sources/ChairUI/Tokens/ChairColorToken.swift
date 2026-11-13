//
//  ChairColorToken.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/26/26.
//

import SwiftUI

public enum ChairColorToken: String, CaseIterable, Sendable {
    case ink
    case inkSecondary
    case surface
    case surfaceRaised
    case outline
    case accent
    case accentPressed
    case onAccent
    case button
    case onButton
    case control
    case tint
    case court
    case courtLine
    case playerA
    case playerB
    case success
    case warning
    case danger

    public var color: Color {
        Color(rawValue, bundle: .module)
    }
}

public struct ChairColors: Sendable {
    public let ink = ChairColorToken.ink.color
    public let inkSecondary = ChairColorToken.inkSecondary.color
    public let surface = ChairColorToken.surface.color
    public let surfaceRaised = ChairColorToken.surfaceRaised.color
    public let outline = ChairColorToken.outline.color
    public let accent = ChairColorToken.accent.color
    public let accentPressed = ChairColorToken.accentPressed.color
    public let onAccent = ChairColorToken.onAccent.color
    public let button = ChairColorToken.button.color
    public let onButton = ChairColorToken.onButton.color
    public let control = ChairColorToken.control.color
    public let tint = ChairColorToken.tint.color
    public let court = ChairColorToken.court.color
    public let courtLine = ChairColorToken.courtLine.color
    public let playerA = ChairColorToken.playerA.color
    public let playerB = ChairColorToken.playerB.color
    public let success = ChairColorToken.success.color
    public let warning = ChairColorToken.warning.color
    public let danger = ChairColorToken.danger.color
}

public extension Color {
    static let chair = ChairColors()
}
