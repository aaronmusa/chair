//
//  SupabaseAuthServiceTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import XCTest

import ChairKit
import Supabase

final class SupabaseAuthServiceTests: XCTestCase {
    func testTheDebugSignInOnTheLocalStackEmitsASessionAndHasAProfile() async throws {
        let client = try LocalStack.client()
        let auth = SupabaseAuthService(client: client)
        var sessions = auth.sessionStream.makeAsyncIterator()
        let before = await sessions.next()
        XCTAssertEqual(before, .some(nil))

        let signedIn = try await auth.signIn(email: "test@chair.local", password: "chair-local")
        let emitted = await sessions.next()

        XCTAssertEqual(emitted??.userID, signedIn.userID)
        let profile = try await SupabaseProfileRemote(client: client).ownProfile()
        XCTAssertEqual(profile?.id, signedIn.userID)
        XCTAssertTrue(profile?.handle.hasPrefix("player_") ?? false)
        try await auth.signOut()
    }

    func testAppleNameReplacesOnlyTheDefaultDisplayName() async throws {
        let client = try LocalStack.client()
        _ = try await SupabaseAuthService(client: client).signIn(email: "aaron@chair.test", password: "chair-local")
        let profiles = SupabaseProfileRemote(client: client)

        try await profiles.claimDisplayName("Someone Else")

        let profile = try await profiles.ownProfile()
        XCTAssertEqual(profile?.displayName, "Aaron", "a profile that no longer reads Player keeps its name")
    }
}

enum LocalStack {
    static func client() throws -> SupabaseClient {
        let environment = ProcessInfo.processInfo.environment
        guard let url = environment["CHAIR_SUPABASE_URL"].flatMap(URL.init(string:)),
              let key = environment["CHAIR_SUPABASE_ANON_KEY"] else {
            throw XCTSkip("set CHAIR_SUPABASE_URL and CHAIR_SUPABASE_ANON_KEY to run against the local stack")
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(auth: .init(storage: InMemoryAuthStorage(), emitLocalSessionAsInitialSession: true))
        )
    }
}
