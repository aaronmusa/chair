//
//  FreeTier.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

public enum FreeTier {
    public static let maxMatches = 20

    public static func matchesUsed(in statuses: [MatchStatus]) -> Int {
        statuses.count { $0 == .completed || $0 == .abandoned }
    }
}
