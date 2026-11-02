//
//  SettingsViewModel.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import Observation

import ChairKit

@MainActor
@Observable
final class SettingsViewModel {
    static let privacyURL = URL(string: "https://aaronmusa.github.io/chair-legal/privacy/")!
    static let supportURL = URL(string: "https://aaronmusa.github.io/chair-legal/support/")!

    var defaults: MatchDefaults {
        didSet { store.save(defaults) }
    }

    private(set) var accountStatus = "Not signed in"
    let version: String
    let build: String

    private let store: any MatchDefaultsStore
    private let auth: any AuthService

    init(
        environment: AppEnvironment,
        info: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) {
        store = environment.matchDefaults
        auth = environment.auth
        defaults = environment.matchDefaults.load()
        version = info["CFBundleShortVersionString"] as? String ?? "–"
        build = info["CFBundleVersion"] as? String ?? "–"
    }

    func refreshAccount() async {
        accountStatus = await auth.currentSession() == nil ? "Not signed in" : "Signed in"
    }
}
