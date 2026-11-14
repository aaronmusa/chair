//
//  OutcomeSheet.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct OutcomeSheet: View {
    let winnerName: String
    let isServerWinning: Bool
    let onChoose: (PointOutcome?, PointEnding?) -> Void

    @State private var ending: PointEnding?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.chair.md) {
                VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                    Text("Point \(winnerName)")
                        .chairFont(.caption)
                        .foregroundStyle(Color.chair.tint)
                    Text("How did it end?")
                        .chairFont(.title)
                        .foregroundStyle(Color.chair.ink)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.chair.sm), GridItem(.flexible())], spacing: Spacing.chair.sm) {
                    ForEach(PointOutcome.recordable, id: \.self) { outcome in
                        let isEnabled = Self.isEnabled(outcome, serverWinning: isServerWinning)
                        Button(action: handleChoose(outcome)) {
                            Text(outcome.title)
                                .chairFont(.action)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .padding(.horizontal, Spacing.chair.xs)
                        }
                        .buttonStyle(ChairButtonStyle(.secondary))
                        .disabled(!isEnabled)
                        .accessibilityLabel(outcome.title)
                        .accessibilityIdentifier("outcome.\(outcome.rawValue)")
                    }
                }
                Text("Ball")
                    .chairFont(.caption)
                    .foregroundStyle(Color.chair.inkSecondary)
                HStack(spacing: Spacing.chair.sm) {
                    endingButton("Out", ending: .out)
                        .accessibilityIdentifier("outcome.out")
                    endingButton("Net", ending: .net)
                        .accessibilityIdentifier("outcome.net")
                }
                Button(action: handleChoose(nil)) {
                    Text("Skip")
                        .chairFont(.action)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(ChairButtonStyle(.ghost))
                .accessibilityLabel("Skip")
                .accessibilityIdentifier("outcome.skip")
            }
            .padding(Spacing.chair.md)
        }
        .background(Color.chair.surface)
    }

    private func endingButton(
        _ title: String,
        ending value: PointEnding
    ) -> some View {
        Button(action: handleToggle(value)) {
            Text(title)
                .chairFont(.action)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(ChairButtonStyle(ending == value ? .primary : .ghost))
        .accessibilityLabel(title)
        .accessibilityAddTraits(ending == value ? .isSelected : [])
    }

    static func isEnabled(
        _ outcome: PointOutcome,
        serverWinning: Bool
    ) -> Bool {
        switch outcome {
        case .ace: serverWinning
        case .doubleFault: !serverWinning
        default: true
        }
    }

    private func handleChoose(_ outcome: PointOutcome?) -> () -> Void {
        { [ending] in onChoose(outcome, ending) }
    }

    private func handleToggle(_ value: PointEnding) -> () -> Void {
        { ending = ending == value ? nil : value }
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout Void
    ) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout Void
    ) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(
        _ subviews: Subviews,
        width: CGFloat
    ) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let last = rows.count - 1
            rows[last].width += (rows[last].indices.isEmpty ? 0 : spacing) + size.width
            rows[last].height = max(rows[last].height, size.height)
            rows[last].indices.append(index)
        }
        return rows
    }
}

extension PointOutcome {
    static let recordable: [PointOutcome] = [.winner, .unforcedError, .forcedError, .ace, .doubleFault]

    var title: String {
        switch self {
        case .ace: "Ace"
        case .doubleFault: "Double fault"
        case .winner: "Winner"
        case .unforcedError: "Unforced error"
        case .forcedError: "Forced error"
        case .let: "Let"
        }
    }

    var shortTitle: String {
        switch self {
        case .ace: "Ace"
        case .doubleFault: "DF"
        case .winner: "W"
        case .unforcedError: "UE"
        case .forcedError: "FE"
        case .let: "Let"
        }
    }
}
