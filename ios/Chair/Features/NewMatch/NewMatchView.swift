//
//  NewMatchView.swift
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

struct NewMatchView: View {
    @State private var viewModel: NewMatchViewModel
    @Environment(\.appEnvironment) private var environment
    private let onStart: (UUID, InputMode) -> Void

    init(
        viewModel: NewMatchViewModel,
        onStart: @escaping (UUID, InputMode) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onStart = onStart
    }

    var body: some View {
        Form {
            Group {
                formatSection
                playersSection
                if viewModel.isDoubles {
                    teamSection(.a)
                    teamSection(.b)
                }
                rulesSection
                inputSection
            }
            .listRowBackground(Color.chair.surfaceRaised)
        }
        .scrollContentBackground(.hidden)
        .background(Color.chair.surface)
        .tint(Color.chair.tint)
        .navigationTitle("New match")
        .safeAreaInset(edge: .bottom) { startBar }
        .sheet(item: $viewModel.pickerSlot) { slot in
            OpponentPickerView(viewModel: OpponentPickerViewModel(environment: environment, onPick: handleLinked(slot)))
        }
        .sheet(isPresented: $viewModel.isShowingSignIn) {
            SignInView(viewModel: SignInViewModel(environment: environment, reason: .linkOpponent, onFinish: handleSignedIn()))
        }
    }

    private var formatSection: some View {
        Section("Format") {
            ChairSegmented(
                MatchFormat.allCases.map { ChairSegmented.Option($0, $0.title) },
                selection: $viewModel.setup.format
            )
            .accessibilityIdentifier("newMatch.format")
        }
    }

    private var playersSection: some View {
        Section("Players") {
            ForEach(viewModel.setup.slots, id: \.self) { slot in
                nameRow(slot)
            }
        }
    }

    private func nameRow(_ slot: PlayerSlot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
            HStack {
                TextField(viewModel.label(for: slot), text: nameBinding(slot))
                    .textContentType(.name)
                    .accessibilityLabel(viewModel.label(for: slot))
                    .accessibilityIdentifier("newMatch.name.\(slot.rawValue)")
                if viewModel.canLink(slot) {
                    linkControl(slot)
                }
            }
            if let error = viewModel.error(for: slot) {
                Text(error)
                    .chairFont(.callout)
                    .foregroundStyle(Color.chair.danger)
                    .accessibilityIdentifier("newMatch.error.\(slot.rawValue)")
            }
        }
    }

    @ViewBuilder
    private func linkControl(_ slot: PlayerSlot) -> some View {
        if let profile = viewModel.linkedProfiles[slot] {
            Menu {
                Button("Unlink @\(profile.handle)", role: .destructive, action: handleUnlink(slot))
            } label: {
                LinkChip(status: .pending)
            }
            .accessibilityLabel("Linked to @\(profile.handle), pending")
            .accessibilityIdentifier("newMatch.link.\(slot.rawValue)")
        } else {
            Button(action: handleRequestLink(slot)) {
                Text("Link")
                    .chairFont(.callout)
                    .fontWeight(.semibold)
                    .padding(.horizontal, Spacing.chair.sm)
                    .frame(minHeight: 32)
            }
            .buttonStyle(ChairButtonStyle(.secondary))
            .accessibilityLabel("Link \(viewModel.label(for: slot)) to a Chair player")
            .accessibilityIdentifier("newMatch.link.\(slot.rawValue)")
        }
    }

    private func handleRequestLink(_ slot: PlayerSlot) -> () -> Void {
        { [viewModel] in Task { await viewModel.requestLink(slot) } }
    }

    private func handleUnlink(_ slot: PlayerSlot) -> () -> Void {
        { [viewModel] in viewModel.unlink(slot) }
    }

    private func handleLinked(_ slot: PlayerSlot) -> (PublicProfile) -> Void {
        { [viewModel] profile in viewModel.link(slot, to: profile) }
    }

    private func handleSignedIn() -> () -> Void {
        { [viewModel] in viewModel.isShowingSignIn = false }
    }

    private func teamSection(_ side: Side) -> some View {
        let slots: [PlayerSlot] = side == .a ? [.a1, .a2] : [.b1, .b2]
        return Section("Team \(side.rawValue)") {
            Picker("Serves first", selection: firstServerBinding(side)) {
                ForEach(slots, id: \.self) { Text(viewModel.displayName(for: $0)).tag($0) }
            }
            .accessibilityIdentifier("newMatch.firstServer.\(side.rawValue)")
            Picker("Receives on the deuce side", selection: deuceReceiverBinding(side)) {
                ForEach(slots, id: \.self) { Text(viewModel.displayName(for: $0)).tag($0) }
            }
            .accessibilityIdentifier("newMatch.deuceReceiver.\(side.rawValue)")
        }
    }

    private var rulesSection: some View {
        Section("Rules") {
            Picker("Sets", selection: $viewModel.setup.rules.sets) {
                ForEach(MatchRules.Sets.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Deuce", selection: $viewModel.setup.rules.deuce) {
                ForEach(MatchRules.Deuce.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Final set", selection: $viewModel.setup.rules.finalSet) {
                ForEach(MatchRules.FinalSet.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("First server", selection: $viewModel.setup.rules.firstServer) {
                ForEach(Side.allCases, id: \.self) { Text(firstServerTitle($0)).tag($0) }
            }
            .accessibilityIdentifier("newMatch.rules.firstServer")
        }
    }

    private var inputSection: some View {
        Section("Scoring input") {
            ForEach(InputMode.allCases, id: \.self, content: inputRow)
        }
    }

    private func inputRow(_ mode: InputMode) -> some View {
        let isSelected = viewModel.setup.inputMode == mode
        return Button(action: handleSelectInput(mode)) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                    Text(mode.title)
                        .foregroundStyle(Color.chair.ink)
                    Text(mode.detail)
                        .chairFont(.callout)
                        .foregroundStyle(Color.chair.inkSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.chair.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("newMatch.input.\(mode.rawValue)")
    }

    private var startBar: some View {
        VStack(spacing: Spacing.chair.xs) {
            if let startError = viewModel.startError {
                Text(startError)
                    .chairFont(.callout)
                    .foregroundStyle(Color.chair.danger)
            }
            ChairButton("Start match", size: .large, onTap: handleStart())
                .accessibilityIdentifier("newMatch.start")
        }
        .padding(.horizontal, Spacing.chair.md)
        .padding(.vertical, Spacing.chair.sm)
        .background(Color.chair.surface)
    }

    private func firstServerTitle(_ side: Side) -> String {
        if viewModel.isDoubles {
            return "Team \(side.rawValue)"
        }
        return viewModel.displayName(for: side == .a ? .a1 : .b1)
    }

    private func nameBinding(_ slot: PlayerSlot) -> Binding<String> {
        Binding(
            get: { viewModel.setup.names[slot] ?? "" },
            set: { viewModel.setup.names[slot] = $0 }
        )
    }

    private func firstServerBinding(_ side: Side) -> Binding<PlayerSlot> {
        Binding(
            get: { viewModel.setup.firstServers[side] ?? (side == .a ? .a1 : .b1) },
            set: { viewModel.setup.firstServers[side] = $0 }
        )
    }

    private func deuceReceiverBinding(_ side: Side) -> Binding<PlayerSlot> {
        Binding(
            get: { viewModel.setup.deuceReceivers[side] ?? (side == .a ? .a1 : .b1) },
            set: { viewModel.setup.deuceReceivers[side] = $0 }
        )
    }

    private func handleSelectInput(_ mode: InputMode) -> () -> Void {
        { viewModel.setup.inputMode = mode }
    }

    private func handleStart() -> () -> Void {
        {
            guard let matchID = viewModel.start() else { return }
            onStart(matchID, viewModel.setup.inputMode)
        }
    }
}

#if DEBUG
    #Preview("Singles") {
        NavigationStack {
            NewMatchView(
                viewModel: NewMatchViewModel(defaults: MatchDefaults(), repository: nil, clock: FixedClock(.now)),
                onStart: { _, _ in }
            )
        }
    }

    #Preview("Doubles AX5") {
        NavigationStack {
            NewMatchView(
                viewModel: NewMatchViewModel(defaults: MatchDefaults(format: .doubles), repository: nil, clock: FixedClock(.now)),
                onStart: { _, _ in }
            )
        }
        .environment(\.dynamicTypeSize, .accessibility5)
    }
#endif

private extension InputMode {
    var title: String {
        switch self {
        case .manual: "Manual"
        case .camera: "Camera + umpire"
        }
    }

    var detail: String {
        switch self {
        case .manual: "Tap the score on the phone or the watch"
        case .camera: "Mount the phone at the net and calibrate the court"
        }
    }
}
