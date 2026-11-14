//
//  SignInView.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import AuthenticationServices
import SwiftUI

import ChairKit
#if DEBUG
    import ChairTestSupport
#endif
import ChairUI

struct SignInView: View {
    @State private var viewModel: SignInViewModel
    @State private var coordinator = SignInWithAppleCoordinator()
    @Environment(\.colorScheme) private var colorScheme

    init(viewModel: SignInViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.chair.lg) {
                Spacer(minLength: Spacing.chair.xl)
                mark
                Text(viewModel.reason.text)
                    .chairFont(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.chair.ink)
                if let error = viewModel.inlineError {
                    Text(error)
                        .chairFont(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.chair.danger)
                        .accessibilityIdentifier("signIn.error")
                }
                SignInWithAppleButton(.signIn, onRequest: handleRequest(), onCompletion: handleCompletion())
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .disabled(viewModel.isSigningIn)
                    .accessibilityIdentifier("signIn.apple")
                ChairButton("Continue without an account", style: .ghost, onTap: viewModel.continueWithoutAccount)
                    .accessibilityIdentifier("signIn.continue")
            }
            .padding(Spacing.chair.lg)
        }
        .background(Color.chair.surface)
        .alert("Couldn't sign in", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }

    private var mark: some View {
        VStack(spacing: Spacing.chair.sm) {
            AppIconArt()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .accessibilityHidden(true)
            VStack(spacing: Spacing.chair.xxs) {
                Text("Chair")
                    .chairFont(.scoreLarge)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.chair.ink)
                Capsule()
                    .fill(Color.chair.tint)
                    .frame(width: 120, height: 4)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )
    }

    private func handleRequest() -> (ASAuthorizationAppleIDRequest) -> Void {
        { [coordinator] request in coordinator.prepare(request) }
    }

    private func handleCompletion() -> (Result<ASAuthorization, any Error>) -> Void {
        { [coordinator, viewModel] result in
            let credential = coordinator.credential(from: result)
            Task { await viewModel.complete(credential) }
        }
    }
}

#if DEBUG
    #Preview("Light") {
        SignInView(viewModel: SignInViewModel(environment: .fakes(), onFinish: {}))
    }

    #Preview("AX5") {
        SignInView(viewModel: SignInViewModel(environment: .fakes(), onFinish: {}))
            .environment(\.dynamicTypeSize, .accessibility5)
    }
#endif
