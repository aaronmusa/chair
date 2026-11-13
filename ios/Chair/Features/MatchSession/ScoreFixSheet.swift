//
//  ScoreFixSheet.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct ScoreFixSheet: View {
    let names: [Side: String]
    let slotNames: [PlayerSlot: String]
    let onApply: (ScoreSnapshot) async -> String?
    let onCancel: () -> Void

    @State private var draft: ScoreFixDraft
    @State private var error: String?

    init(
        draft: ScoreFixDraft,
        names: [Side: String],
        slotNames: [PlayerSlot: String],
        onApply: @escaping (ScoreSnapshot) async -> String?,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.names = names
        self.slotNames = slotNames
        self.onApply = onApply
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    if !draft.sets.isEmpty {
                        completedSets
                    }
                    currentSet
                    points
                    serverSection
                    if let error {
                        Section {
                            Text(error)
                                .chairFont(.callout)
                                .foregroundStyle(Color.chair.danger)
                                .accessibilityIdentifier("scoreFix.error")
                        }
                    }
                }
                .listRowBackground(Color.chair.surfaceRaised)
            }
            .scrollContentBackground(.hidden)
            .background(Color.chair.surface)
            .tint(Color.chair.tint)
            .navigationTitle("Fix score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply", action: handleApply())
                        .accessibilityIdentifier("scoreFix.apply")
                }
            }
        }
    }

    private var completedSets: some View {
        Section("Completed sets") {
            ForEach(draft.sets.indices, id: \.self) { index in
                gamesStepper("Set \(index + 1) · \(name(.a))", value: $draft.sets[index].a)
                gamesStepper("Set \(index + 1) · \(name(.b))", value: $draft.sets[index].b)
            }
        }
    }

    private var currentSet: some View {
        Section("This set") {
            gamesStepper(name(.a), value: $draft.currentSet.a)
                .accessibilityIdentifier("scoreFix.games.A")
            gamesStepper(name(.b), value: $draft.currentSet.b)
                .accessibilityIdentifier("scoreFix.games.B")
        }
    }

    @ViewBuilder
    private var points: some View {
        if draft.isTiebreak {
            Section("Tiebreak") {
                Stepper("\(name(.a)) \(draft.tiebreakA)", value: $draft.tiebreakA, in: 0 ... 30)
                Stepper("\(name(.b)) \(draft.tiebreakB)", value: $draft.tiebreakB, in: 0 ... 30)
            }
        } else {
            Section("Points") {
                pointsPicker(name(.a), selection: $draft.pointsA)
                    .accessibilityIdentifier("scoreFix.points.A")
                pointsPicker(name(.b), selection: $draft.pointsB)
                    .accessibilityIdentifier("scoreFix.points.B")
            }
        }
    }

    private var serverSection: some View {
        Section("Serving") {
            Picker("Server", selection: $draft.server) {
                ForEach(draft.servers, id: \.self) { slot in
                    Text(slotNames[slot] ?? slot.rawValue).tag(slot)
                }
            }
            .accessibilityIdentifier("scoreFix.server")
        }
    }

    private func gamesStepper(
        _ title: String,
        value: Binding<Int>
    ) -> some View {
        Stepper("\(title) \(value.wrappedValue)", value: value, in: 0 ... 7)
    }

    private func pointsPicker(
        _ title: String,
        selection: Binding<GameScore>
    ) -> some View {
        Picker(title, selection: selection) {
            ForEach(GameScore.allCases, id: \.self) { score in
                Text(score.label).tag(score)
            }
        }
    }

    private func name(_ side: Side) -> String {
        names[side] ?? side.rawValue
    }

    private func handleApply() -> () -> Void {
        {
            let snapshot = draft.snapshot
            Task {
                error = await onApply(snapshot)
            }
        }
    }
}

extension GameScore {
    var label: String {
        switch self {
        case .love: "Love"
        case .fifteen: "15"
        case .thirty: "30"
        case .forty: "40"
        case .advantage: "Ad"
        }
    }
}
