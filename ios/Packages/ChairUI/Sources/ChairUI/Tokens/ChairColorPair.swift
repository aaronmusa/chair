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
        let onAccents = [ChairColorToken.accent, .accentPressed].map {
            ChairColorPair(text: .surface, background: $0, isLargeText: false)
        }
        return onSurfaces + onAccents
    }()
}
