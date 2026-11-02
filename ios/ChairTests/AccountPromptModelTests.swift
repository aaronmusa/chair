//
//  AccountPromptModelTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftData
import XCTest

import ChairKit
import ChairTestSupport

@testable import Chair

@MainActor
final class AccountPromptModelTests: XCTestCase {
    private struct Subject {
        let model: AccountPromptModel
        let repository: SyncingMatchRepository
        let auth: FakeAuthService
    }

    private var container: ModelContainer?
    private let session = FakeAuthService.sampleSession

    func testSigningInWithThreeLocalMatchesAsksToKeepThem() throws {
        let model = try makeModel(localMatches: 3).model

        model.check(session)

        XCTAssertEqual(model.prompt, .keepLocal(count: 3))
        XCTAssertEqual(model.title, "Keep your 3 matches?")
    }

    func testKeepClosesThePromptAndKeepsTheMatches() throws {
        let subject = try makeModel(localMatches: 2)
        let model = subject.model
        let repository = subject.repository
        model.check(session)

        model.keep()

        XCTAssertNil(model.prompt)
        XCTAssertEqual(try repository.fetch().count, 2)
    }

    func testDiscardDeletesTheLocalMatches() throws {
        let subject = try makeModel(localMatches: 2)
        let model = subject.model
        let repository = subject.repository
        model.check(session)

        model.discard()

        XCTAssertNil(model.prompt)
        XCTAssertTrue(try repository.fetch().isEmpty)
    }

    func testADifferentUserIsAskedToReplaceAndCancellingSignsOut() async throws {
        let subject = try makeModel(localMatches: 1, lastUserID: UUID())
        let model = subject.model
        let repository = subject.repository
        let auth = subject.auth
        _ = try await auth.signIn(email: "a", password: "b")
        model.check(session)
        XCTAssertEqual(model.prompt, .replaceLocal)
        XCTAssertEqual(model.title, "Replace local data with the new account?")

        await model.cancelReplace()

        let signedIn = await auth.currentSession()
        XCTAssertNil(signedIn)
        XCTAssertEqual(try repository.fetch().count, 1)
    }

    func testReplaceEmptiesTheCache() throws {
        let subject = try makeModel(localMatches: 2, lastUserID: UUID())
        let model = subject.model
        let repository = subject.repository
        model.check(session)

        model.replace()

        XCTAssertTrue(try repository.fetch().isEmpty)
    }

    func testNoLocalMatchesMeansNoPrompt() throws {
        let model = try makeModel(localMatches: 0).model

        model.check(session)

        XCTAssertNil(model.prompt)
    }

    private func makeModel(
        localMatches: Int,
        lastUserID: UUID? = nil
    ) throws -> Subject {
        let container = try InMemoryModelContainer()
        self.container = container
        let repository = SyncingMatchRepository(context: container.mainContext, remote: FakeMatchRemote())
        for _ in 0 ..< localMatches {
            try repository.save(Match.sample())
        }
        let auth = FakeAuthService()
        let migration = AccountMigration(repository: repository, store: InMemoryAccountStore(lastUserID: lastUserID))
        return Subject(
            model: AccountPromptModel(auth: auth, migration: migration, sync: nil),
            repository: repository,
            auth: auth
        )
    }
}
