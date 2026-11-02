//
//  AppSection.swift
//  Chair
//
//  Created by Aaron Musa on 10/31/26.
//

import Foundation

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case play
    case matches
    case train
    case coach
    case settings

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .play: "Play"
        case .matches: "Matches"
        case .train: "Train"
        case .coach: "Coach"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .play: "play.circle"
        case .matches: "list.bullet.rectangle"
        case .train: "figure.tennis"
        case .coach: "brain.head.profile"
        case .settings: "gearshape"
        }
    }
}
