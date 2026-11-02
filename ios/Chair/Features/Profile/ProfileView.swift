//
//  ProfileView.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel

    init(viewModel: ProfileViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Group {
                header
                profileSection
                qrSection
                accountSection
            }
            .listRowBackground(Color.chair.surfaceRaised)
        }
        .scrollContentBackground(.hidden)
        .background(Color.chair.surface)
        .tint(Color.chair.accent)
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: handleSave())
                    .disabled(!viewModel.canSave)
                    .accessibilityIdentifier("profile.save")
            }
        }
        .task(handleLoad())
        .confirmationDialog("Delete your account?", isPresented: isAsking(.confirm), titleVisibility: .visible) {
            Button("Delete account", role: .destructive, action: viewModel.confirmDelete)
        } message: {
            Text("Your profile and the matches you scored are removed. Matches you were linked to stay with their owners.")
        }
        .alert("This can't be undone", isPresented: isAsking(.final)) {
            Button("Delete forever", role: .destructive, action: handleDelete())
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Chair deletes your account and signs you out.")
        }
        .alert("Profile", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        Section {
            HStack(spacing: Spacing.chair.md) {
                AvatarView(name: viewModel.displayName)
                VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                    Text(viewModel.displayName)
                        .chairFont(.title)
                        .foregroundStyle(Color.chair.ink)
                    Text("@\(viewModel.original?.handle ?? viewModel.handle)")
                        .chairFont(.callout)
                        .foregroundStyle(Color.chair.inkSecondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                LabeledContent("Handle") {
                    TextField("Handle", text: $viewModel.handle)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("profile.handle")
                }
                if let status = viewModel.handleStatus.text {
                    Text(status)
                        .chairFont(.callout)
                        .foregroundStyle(statusColor)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityIdentifier("profile.handleStatus")
                }
            }
            LabeledContent("Display name") {
                TextField("Display name", text: $viewModel.displayName)
                    .multilineTextAlignment(.trailing)
                    .textContentType(.name)
                    .accessibilityIdentifier("profile.displayName")
            }
            LabeledContent("Home court") {
                TextField("Home court", text: $viewModel.homeCourt, prompt: Text("Optional"))
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("profile.homeCourt")
            }
            Picker("Hand", selection: $viewModel.hand) {
                Text("Not set").tag(Hand?.none)
                ForEach(Hand.allCases, id: \.self) { Text($0.title).tag(Hand?.some($0)) }
            }
            .accessibilityIdentifier("profile.hand")
            Picker("Level", selection: $viewModel.level) {
                Text("Not set").tag(Level?.none)
                ForEach(Level.allCases, id: \.self) { Text($0.title).tag(Level?.some($0)) }
            }
            .accessibilityIdentifier("profile.level")
        }
    }

    @ViewBuilder
    private var qrSection: some View {
        if let handle = viewModel.original?.handle, let image = PlayerQRCode.image(for: handle) {
            Section {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("QR code for @\(handle)")
                    .accessibilityIdentifier("profile.qr")
            } header: {
                Text("Your code")
            } footer: {
                Text("Another player scans this to link you to a match.")
            }
        }
    }

    private var accountSection: some View {
        Section("Account") {
            Button("Sign out", action: handleSignOut())
                .accessibilityIdentifier("profile.signOut")
            Button("Delete account", role: .destructive, action: viewModel.requestDelete)
                .accessibilityIdentifier("profile.delete")
        }
        .disabled(viewModel.isWorking)
    }

    private var statusColor: Color {
        switch viewModel.handleStatus {
        case .available: Color.chair.success
        case .taken, .invalid, .unknown: Color.chair.danger
        case .checking, .unchanged: Color.chair.inkSecondary
        }
    }

    private func isAsking(_ step: ProfileViewModel.DeleteStep) -> Binding<Bool> {
        Binding(
            get: { viewModel.deleteStep == step },
            set: { if !$0, viewModel.deleteStep == step { viewModel.deleteStep = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func handleLoad() -> @MainActor @Sendable () async -> Void {
        { [viewModel] in await viewModel.load() }
    }

    private func handleSave() -> () -> Void {
        { [viewModel] in Task { await viewModel.save() } }
    }

    private func handleSignOut() -> () -> Void {
        { [viewModel] in Task { await viewModel.signOut() } }
    }

    private func handleDelete() -> () -> Void {
        { [viewModel] in Task { await viewModel.deleteAccount() } }
    }
}

extension Hand {
    var title: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        }
    }
}

extension Level {
    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
    }
}
