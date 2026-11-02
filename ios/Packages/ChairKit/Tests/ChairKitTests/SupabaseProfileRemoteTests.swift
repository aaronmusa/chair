//
//  SupabaseProfileRemoteTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/3/26.
//

import Foundation
import SwiftData
import XCTest

import ChairKit
import ChairTestSupport
import Supabase

final class SupabaseProfileRemoteTests: XCTestCase {
    func testHandleAvailabilityIgnoresCase() async throws {
        let client = try LocalStack.client()
        _ = try await SupabaseAuthService(client: client).signIn(email: "test@chair.local", password: "chair-local")
        let profiles = SupabaseProfileRemote(client: client)

        let aaron = try await profiles.handleAvailable("AARON")
        let free = try await profiles.handleAvailable("aaron_m2")

        XCTAssertFalse(aaron)
        XCTAssertTrue(free)
    }

    func testAnEditRoundTripsAndAnotherUserSeesOnlyThePublicFields() async throws {
        let client = try LocalStack.client()
        _ = try await SupabaseAuthService(client: client).signIn(email: "test@chair.local", password: "chair-local")
        let profiles = SupabaseProfileRemote(client: client)
        let fetched = try await profiles.ownProfile()
        let original = try XCTUnwrap(fetched)
        var edited = original
        edited.handle = "tester_\(Int.random(in: 100 ... 999))"
        edited.homeCourt = "Rizal"
        edited.hand = .left
        edited.level = .advanced

        try await profiles.update(edited)
        let stored = try await profiles.ownProfile()
        XCTAssertEqual(stored, edited)

        let other = try LocalStack.client()
        _ = try await SupabaseAuthService(client: other).signIn(email: "juan@chair.test", password: "chair-local")
        let seen = try await SupabaseProfileRemote(client: other).publicProfile(handle: edited.handle.uppercased())
        XCTAssertEqual(seen, PublicProfile(id: edited.id, handle: edited.handle, displayName: edited.displayName, level: .advanced))

        try await profiles.update(original)
    }

    @MainActor
    func testDeletingAnAccountRemovesItAndSignsOut() async throws {
        guard ProcessInfo.processInfo.environment["CHAIR_FUNCTIONS_SERVED"] != nil else {
            throw XCTSkip("run make functions-serve and set CHAIR_FUNCTIONS_SERVED=1")
        }
        let client = try LocalStack.client()
        let email = "delete_\(UUID().uuidString.prefix(8).lowercased())@chair.test"
        _ = try await client.auth.signUp(email: email, password: "delete-me-123")
        let auth = SupabaseAuthService(client: client)
        let session = try await auth.signIn(email: email, password: "delete-me-123")
        let remote = SupabaseMatchRemote(client: client)
        var record = Match.sample(at: .now).record
        record.ownerID = session.userID
        try await remote.upsert(record)

        try await auth.deleteAccount()

        let after = await auth.currentSession()
        XCTAssertNil(after)
        let again = try LocalStack.client()
        do {
            _ = try await again.auth.signIn(email: email, password: "delete-me-123")
            XCTFail("the account should no longer exist")
        } catch {}
    }
}
