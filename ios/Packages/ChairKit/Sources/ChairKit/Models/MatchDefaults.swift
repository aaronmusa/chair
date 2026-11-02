//
//  MatchDefaults.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation

public struct MatchDefaults: Codable, Hashable, Sendable {
    public static let fallbackPlayerName = "You"

    public var format: MatchFormat
    public var sets: MatchRules.Sets
    public var deuce: MatchRules.Deuce
    public var finalSet: MatchRules.FinalSet
    public var playerName: String
    public var asksHowPointEnded: Bool

    public init(
        format: MatchFormat = .singles,
        sets: MatchRules.Sets = .bestOf3,
        deuce: MatchRules.Deuce = .advantage,
        finalSet: MatchRules.FinalSet = .tiebreak7,
        playerName: String = "",
        asksHowPointEnded: Bool = true
    ) {
        self.format = format
        self.sets = sets
        self.deuce = deuce
        self.finalSet = finalSet
        self.playerName = playerName
        self.asksHowPointEnded = asksHowPointEnded
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = MatchDefaults()
        format = try container.decodeIfPresent(MatchFormat.self, forKey: .format) ?? fallback.format
        sets = try container.decodeIfPresent(MatchRules.Sets.self, forKey: .sets) ?? fallback.sets
        deuce = try container.decodeIfPresent(MatchRules.Deuce.self, forKey: .deuce) ?? fallback.deuce
        finalSet = try container.decodeIfPresent(MatchRules.FinalSet.self, forKey: .finalSet) ?? fallback.finalSet
        playerName = try container.decodeIfPresent(String.self, forKey: .playerName) ?? fallback.playerName
        asksHowPointEnded = try container.decodeIfPresent(Bool.self, forKey: .asksHowPointEnded) ?? fallback.asksHowPointEnded
    }

    public var rules: MatchRules {
        MatchRules(sets: sets, deuce: deuce, finalSet: finalSet)
    }

    public var playerAName: String {
        let trimmed = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.fallbackPlayerName : trimmed
    }
}

public protocol MatchDefaultsStore: Sendable {
    func load() -> MatchDefaults
    func save(_ defaults: MatchDefaults)
}

public struct UserDefaultsMatchDefaultsStore: MatchDefaultsStore, @unchecked Sendable {
    public static let key = "chair.matchDefaults"

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() -> MatchDefaults {
        guard let data = userDefaults.data(forKey: Self.key),
              let defaults = try? JSONDecoder().decode(MatchDefaults.self, from: data) else {
            return MatchDefaults()
        }
        return defaults
    }

    public func save(_ defaults: MatchDefaults) {
        guard let data = try? JSONEncoder().encode(defaults) else { return }
        userDefaults.set(data, forKey: Self.key)
    }
}
