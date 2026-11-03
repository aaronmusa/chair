//
//  AppEnvironment+App.swift
//  Chair
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import SwiftUI

import ChairKit
#if DEBUG
    import ChairTestSupport
#endif
import Supabase

extension AppEnvironment {
    struct Config: Equatable {
        let supabaseURL: URL
        let anonKey: String

        init?(info: [String: Any]) {
            guard let urlString = info["SupabaseURL"] as? String,
                  let url = URL(string: urlString), url.host() != nil,
                  let key = info["SupabaseAnonKey"] as? String, !key.isEmpty, !key.contains("$(") else {
                return nil
            }
            supabaseURL = url
            anonKey = key
        }
    }

    static func make(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        info: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) -> AppEnvironment {
        #if DEBUG
            if arguments.contains("-UseFakes") {
                var fakes = AppEnvironment.fakes(clock: FixedClock(.now))
                if arguments.contains("-SignedIn") {
                    fakes.auth = FakeAuthService(signedIn: true)
                    fakes.profileRemote = FakeProfileRemote(profile: ProfileRecord(
                        id: FakeAuthService.sampleSession.userID,
                        handle: "aaron",
                        displayName: "Aaron Musa",
                        homeCourt: "Rizal Memorial",
                        hand: .right,
                        level: .intermediate
                    ))
                }
                return fakes
            }
        #endif
        guard let config = Config(info: info) else {
            return .unavailable
        }
        return .live(config)
    }

    static func live(_ config: Config) -> AppEnvironment {
        let client = SupabaseClient(supabaseURL: config.supabaseURL, supabaseKey: config.anonKey)
        let auth = SupabaseAuthService(client: client)
        return AppEnvironment(
            auth: auth,
            speechOutput: UmpireSpeech(synthesizer: SystemSynthesizer(), cues: CuePlayer()),
            speechInput: UnavailableService(),
            coach: EdgeCoachService(
                auth: auth,
                functionsURL: config.supabaseURL.appending(path: "functions/v1"),
                anonKey: config.anonKey
            ),
            subscription: StoreKitSubscriptionService(),
            clock: SystemClock(),
            haptics: SystemHaptics(),
            matchDefaults: UserDefaultsMatchDefaultsStore(),
            matchRemote: SupabaseMatchRemote(client: client),
            profileRemote: SupabaseProfileRemote(client: client),
            inviteRemote: SupabaseInviteRemote(client: client)
        )
    }
}

extension EnvironmentValues {
    @Entry var appEnvironment: AppEnvironment = .unavailable
}
