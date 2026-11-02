//
//  SettingsView.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairKit
#if DEBUG
    import ChairTestSupport
#endif
import ChairUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Environment(\.syncCoordinator) private var sync

    init(viewModel: SettingsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Form {
            Group {
                matchDefaultsSection
                umpireSection
                accountSection
                syncSection
                aboutSection
            }
            .listRowBackground(Color.chair.surfaceRaised)
        }
        .scrollContentBackground(.hidden)
        .background(Color.chair.surface)
        .tint(Color.chair.accent)
        .navigationTitle("Settings")
        .task(handleRefreshAccount())
    }

    private var matchDefaultsSection: some View {
        Section("Match defaults") {
            Picker("Format", selection: $viewModel.defaults.format) {
                ForEach(MatchFormat.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .accessibilityIdentifier("settings.format")
            Picker("Sets", selection: $viewModel.defaults.sets) {
                ForEach(MatchRules.Sets.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .accessibilityIdentifier("settings.sets")
            Picker("Deuce", selection: $viewModel.defaults.deuce) {
                ForEach(MatchRules.Deuce.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .accessibilityIdentifier("settings.deuce")
            Picker("Final set", selection: $viewModel.defaults.finalSet) {
                ForEach(MatchRules.FinalSet.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .accessibilityIdentifier("settings.finalSet")
            LabeledContent("Player name") {
                TextField("Player name", text: $viewModel.defaults.playerName, prompt: Text(MatchDefaults.fallbackPlayerName))
                    .multilineTextAlignment(.trailing)
                    .textContentType(.name)
                    .accessibilityIdentifier("settings.playerName")
            }
            Toggle("Ask how each point ended", isOn: $viewModel.defaults.asksHowPointEnded)
                .accessibilityIdentifier("settings.asksHowPointEnded")
        }
    }

    private var umpireSection: some View {
        Section {
            Toggle("Umpire voice", isOn: .constant(false))
                .disabled(true)
        } header: {
            Text("Umpire")
        } footer: {
            Text("Available with umpire voice.")
        }
    }

    private var accountSection: some View {
        Section("Account") {
            LabeledContent("Account", value: viewModel.accountStatus)
                .accessibilityIdentifier("settings.account")
        }
    }

    private var syncSection: some View {
        Section("Sync") {
            if let sync {
                LabeledContent("Last synced", value: SyncText.lastSynced(sync.lastSyncedAt))
                    .accessibilityIdentifier("settings.lastSynced")
                LabeledContent("Waiting to upload", value: "\(sync.pendingCount)")
                    .accessibilityIdentifier("settings.pending")
                if let error = sync.lastError {
                    Text(error)
                        .chairFont(.callout)
                        .foregroundStyle(Color.chair.danger)
                }
                Button("Sync now", action: handleSyncNow(sync))
                    .disabled(sync.isSyncing)
                    .accessibilityIdentifier("settings.syncNow")
            } else {
                LabeledContent("Sync", value: "Matches stay on this device")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: viewModel.version)
            LabeledContent("Build", value: viewModel.build)
            Link("Privacy policy", destination: SettingsViewModel.privacyURL)
            Link("Support", destination: SettingsViewModel.supportURL)
        }
    }

    private func handleSyncNow(_ sync: SyncCoordinator) -> () -> Void {
        { Task { await sync.syncNow() } }
    }

    private func handleRefreshAccount() -> @MainActor @Sendable () async -> Void {
        { [viewModel] in await viewModel.refreshAccount() }
    }
}

#if DEBUG
    #Preview("Light") {
        NavigationStack {
            SettingsView(viewModel: SettingsViewModel(environment: .fakes()))
        }
    }

    #Preview("AX5") {
        NavigationStack {
            SettingsView(viewModel: SettingsViewModel(environment: .fakes()))
        }
        .environment(\.dynamicTypeSize, .accessibility5)
    }
#endif

enum SyncText {
    static func lastSynced(_ date: Date?) -> String {
        guard let date else { return "Never" }
        return date.formatted(.relative(presentation: .named))
    }
}
