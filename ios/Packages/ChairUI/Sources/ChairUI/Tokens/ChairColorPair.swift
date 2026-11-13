//
//  ChairColorPair.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/26/26.
//

public struct ChairColorPair: Sendable, CustomStringConvertible {
    public let text: ChairColorToken
    public let background: ChairColorToken
    public let isLargeText: Bool

    public var minimumContrast: Double {
        isLargeText ? 3 : 4.5
    }

    public var description: String {
        "\(text.rawValue) on \(background.rawValue)"
    }

    public static let all: [ChairColorPair] = {
        let surfaces: [ChairColorToken] = [.surface, .surfaceRaised]
        let textOnSurfaces: [ChairColorToken] = [.ink, .inkSecondary, .playerA, .playerB, .success, .warning, .danger]
        let onSurfaces = textOnSurfaces.flatMap { text in
            surfaces.map { ChairColorPair(text: text, background: $0, isLargeText: false) }
        }
        let onControls = [ChairColorToken.ink, .inkSecondary].map {
            ChairColorPair(text: $0, background: .control, isLargeText: false)
        }
        let onFills = [
            ChairColorPair(text: .onAccent, background: .accent, isLargeText: false),
            ChairColorPair(text: .onAccent, background: .accentPressed, isLargeText: false),
            ChairColorPair(text: .onButton, background: .button, isLargeText: false),
            ChairColorPair(text: .surface, background: .danger, isLargeText: false),
        ]
        let tints = surfaces.map { ChairColorPair(text: .tint, background: $0, isLargeText: false) }
        return onSurfaces + onControls + onFills + tints
    }()
}
