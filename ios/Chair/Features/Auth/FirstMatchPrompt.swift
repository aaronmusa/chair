//
//  FirstMatchPrompt.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation

final class FirstMatchPrompt {
    private static let key = "chair.firstMatchPrompt.shown"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var wasShown: Bool {
        defaults.bool(forKey: Self.key)
    }

    func markShown() {
        defaults.set(true, forKey: Self.key)
    }

    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> FirstMatchPrompt? {
        guard arguments.contains("-UseFakes") else { return FirstMatchPrompt() }
        guard arguments.contains("-FirstMatchPrompt"), let fresh = UserDefaults(suiteName: "chair.uitests.\(UUID().uuidString)") else {
            return nil
        }
        return FirstMatchPrompt(defaults: fresh)
    }
}
