//
//  AccountPromptModifier.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit

struct AccountPromptModifier: ViewModifier {
    let model: AccountPromptModel?

    func body(content: Content) -> some View {
        if let model {
            content
                .task(handleWatch(model))
                .alert(model.title, isPresented: isPresented(model, .keepLocal(count: 0))) {
                    Button("Keep", action: model.keep)
                        .keyboardShortcut(.defaultAction)
                    Button("Discard", role: .destructive, action: model.discard)
                } message: {
                    Text(model.message)
                }
                .alert(model.title, isPresented: isPresented(model, .replaceLocal)) {
                    Button("Replace", role: .destructive, action: model.replace)
                    Button("Cancel", role: .cancel, action: handleCancelReplace(model))
                } message: {
                    Text(model.message)
                }
        } else {
            content
        }
    }

    private func isPresented(
        _ model: AccountPromptModel,
        _ kind: AccountPrompt
    ) -> Binding<Bool> {
        Binding(
            get: {
                switch (model.prompt, kind) {
                case (.keepLocal, .keepLocal), (.replaceLocal, .replaceLocal): true
                default: false
                }
            },
            set: { _ in }
        )
    }

    private func handleWatch(_ model: AccountPromptModel) -> @MainActor @Sendable () async -> Void {
        { await model.watch() }
    }

    private func handleCancelReplace(_ model: AccountPromptModel) -> () -> Void {
        { Task { await model.cancelReplace() } }
    }
}

extension View {
    func accountPrompt(_ model: AccountPromptModel?) -> some View {
        modifier(AccountPromptModifier(model: model))
    }
}
