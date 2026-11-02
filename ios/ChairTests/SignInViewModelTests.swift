//
//  SignInViewModelTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/3/26.
//

import AuthenticationServices
import XCTest

import ChairKit
import ChairTestSupport

@testable import Chair

@MainActor
final class SignInViewModelTests: XCTestCase {
    private let credential = AppleCredential(idToken: "token", nonce: "nonce", fullName: "Aaron Musa")

    func testSigningInExchangesTheTokenSavesApplesNameAndFinishes() async {
        let auth = FakeAuthService()
        let profiles = FakeProfileRemote()
        var finished = 0
        let viewModel = makeViewModel(auth: auth, profiles: profiles) { finished += 1 }

        await viewModel.complete(.success(credential))

        let session = await auth.currentSession()
        let claimed = await profiles.claimedNames
        let profile = await profiles.profile
        XCTAssertEqual(session, FakeAuthService.sampleSession)
        XCTAssertEqual(claimed, ["Aaron Musa"])
        XCTAssertEqual(profile?.displayName, "Aaron Musa")
        XCTAssertEqual(finished, 1)
    }

    func testCancellingDoesNothing() async {
        var finished = 0
        let viewModel = makeViewModel { finished += 1 }

        await viewModel.complete(.failure(ASAuthorizationError(.canceled)))

        XCTAssertNil(viewModel.alertMessage)
        XCTAssertNil(viewModel.inlineError)
        XCTAssertEqual(finished, 0)
    }

    func testANetworkErrorShowsAnInlineRetry() async {
        let viewModel = makeViewModel {}

        await viewModel.complete(.failure(URLError(.notConnectedToInternet)))

        XCTAssertEqual(viewModel.inlineError, "Couldn't reach Chair. Check your connection and try again.")
        XCTAssertNil(viewModel.alertMessage)
    }

    func testAnAppleErrorShowsAnAlertWithTheCode() async {
        let viewModel = makeViewModel {}

        await viewModel.complete(.failure(ASAuthorizationError(.failed)))

        XCTAssertEqual(viewModel.alertMessage, "Sign in with Apple failed (code 1004).")
    }

    func testContinueWithoutAnAccountDismissesAndStaysSignedOut() async {
        let auth = FakeAuthService()
        var finished = 0
        let viewModel = makeViewModel(auth: auth) { finished += 1 }

        viewModel.continueWithoutAccount()

        let session = await auth.currentSession()
        XCTAssertNil(session)
        XCTAssertEqual(finished, 1)
    }

    func testTheNonceSentToAppleIsTheHashOfTheOneSentToSupabase() {
        let nonce = SignInWithAppleCoordinator.randomNonce()

        XCTAssertEqual(nonce.count, 32)
        XCTAssertEqual(
            SignInWithAppleCoordinator.sha256("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    private func makeViewModel(
        auth: FakeAuthService = FakeAuthService(),
        profiles: FakeProfileRemote = FakeProfileRemote(),
        onFinish: @escaping () -> Void
    ) -> SignInViewModel {
        var environment = AppEnvironment.fakes()
        environment.auth = auth
        environment.profileRemote = profiles
        return SignInViewModel(environment: environment, onFinish: onFinish)
    }
}
