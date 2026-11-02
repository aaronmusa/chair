//
//  MatchDefaults+Titles.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import ChairKit

extension MatchFormat {
    var title: String {
        switch self {
        case .singles: "Singles"
        case .doubles: "Doubles"
        }
    }
}

extension MatchRules.Sets {
    var title: String {
        switch self {
        case .bestOf3: "Best of 3"
        case .bestOf5: "Best of 5"
        }
    }
}

extension MatchRules.Deuce {
    var title: String {
        switch self {
        case .advantage: "Advantage"
        case .noAd: "No-ad"
        }
    }
}

extension MatchRules.FinalSet {
    var title: String {
        switch self {
        case .tiebreak7: "Tiebreak to 7"
        case .tiebreak10: "Tiebreak to 10"
        case .advantage: "Advantage"
        }
    }
}
