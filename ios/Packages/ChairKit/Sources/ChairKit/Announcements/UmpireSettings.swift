//
//  UmpireSettings.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import Observation

public struct UmpirePreferences: Codable, Equatable, Sendable {
    public static let volumeRange: ClosedRange<Float> = 0.5 ... 1

    public var isEnabled: Bool
    public var voiceID: String?
    public var verbosity: Verbosity
    public var cuesEnabled: Bool
    public var volume: Float
    public var respectsSilentMode: Bool
    public var keepsAudioAlive: Bool
    public var speakerTipShown: Bool

    public init(
        isEnabled: Bool = true,
        voiceID: String? = nil,
        verbosity: Verbosity = .normal,
        cuesEnabled: Bool = true,
        volume: Float = 1,
        respectsSilentMode: Bool = false,
        keepsAudioAlive: Bool = false,
        speakerTipShown: Bool = false
    ) {
        self.isEnabled = isEnabled
        self.voiceID = voiceID
        self.verbosity = verbosity
        self.cuesEnabled = cuesEnabled
        self.volume = volume
        self.respectsSilentMode = respectsSilentMode
        self.keepsAudioAlive = keepsAudioAlive
        self.speakerTipShown = speakerTipShown
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = UmpirePreferences()
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? fallback.isEnabled
        voiceID = try container.decodeIfPresent(String.self, forKey: .voiceID)
        verbosity = try container.decodeIfPresent(Verbosity.self, forKey: .verbosity) ?? fallback.verbosity
        cuesEnabled = try container.decodeIfPresent(Bool.self, forKey: .cuesEnabled) ?? fallback.cuesEnabled
        volume = try container.decodeIfPresent(Float.self, forKey: .volume) ?? fallback.volume
        respectsSilentMode = try container.decodeIfPresent(Bool.self, forKey: .respectsSilentMode) ?? fallback.respectsSilentMode
        keepsAudioAlive = try container.decodeIfPresent(Bool.self, forKey: .keepsAudioAlive) ?? fallback.keepsAudioAlive
        speakerTipShown = try container.decodeIfPresent(Bool.self, forKey: .speakerTipShown) ?? fallback.speakerTipShown
    }

    public var clampedVolume: Float {
        min(max(volume, Self.volumeRange.lowerBound), Self.volumeRange.upperBound)
    }
}

@MainActor
@Observable
public final class UmpireSettings {
    public static let key = "chair.umpire"

    public var preferences: UmpirePreferences {
        didSet { save() }
    }

    @ObservationIgnored private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        preferences = userDefaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(UmpirePreferences.self, from: $0) } ?? UmpirePreferences()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        userDefaults.set(data, forKey: Self.key)
    }
}
