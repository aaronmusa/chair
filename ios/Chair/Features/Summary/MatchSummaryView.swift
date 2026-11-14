//
//  MatchSummaryView.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairKit
import ChairUI

enum SummaryTab: Hashable {
    case stats
    case points
    case coach
}

struct MatchSummaryView: View {
    let model: MatchSummaryModel

    @State private var tab = SummaryTab.stats
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.chair.md) {
                header
                if model.isReadOnly {
                    ScoredByLine(ownerID: model.ownerID)
                } else {
                    MatchLinksSection(matchID: model.matchID)
                }
                ChairSegmented(
                    [.init(.stats, "Stats"), .init(.points, "Points"), .init(.coach, "Coach")],
                    selection: $tab
                )
                .accessibilityIdentifier("summary.tabs")
                switch tab {
                case .stats: stats
                case .points: pointList
                case .coach: coachPlaceholder
                }
            }
            .padding(Spacing.chair.md)
        }
        .background(Color.chair.surface)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
            Text(model.header)
                .chairFont(.caption)
                .foregroundStyle(Color.chair.inkSecondary)
            Text(model.result)
                .chairFont(.title)
                .foregroundStyle(Color.chair.ink)
            HStack(spacing: Spacing.chair.md) {
                ForEach(Array(model.setLine.split(separator: " ").enumerated()), id: \.offset) { _, set in
                    Text(set)
                        .chairFont(.scoreLarge)
                }
            }
            .foregroundStyle(Color.chair.ink)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.setLine)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("summary.header")
    }

    @ViewBuilder
    private var stats: some View {
        if horizontalSizeClass == .regular {
            HStack(alignment: .top, spacing: Spacing.chair.lg) {
                statsTable
                VStack(alignment: .leading, spacing: Spacing.chair.md) {
                    momentum
                    shotMapPlaceholder
                }
            }
        } else {
            statsTable
            momentum
            shotMapPlaceholder
        }
    }

    private var statsTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text(model.names[.a] ?? "A")
                Spacer()
                Text(model.names[.b] ?? "B")
            }
            .chairFont(.caption)
            .foregroundStyle(Color.chair.ink)
            .padding(.vertical, Spacing.chair.xs)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(model.names[.a] ?? "A") versus \(model.names[.b] ?? "B")")
            ForEach(model.rows) { row in
                Divider().overlay(Color.chair.outline)
                statLine(row)
            }
        }
        .padding(.horizontal, Spacing.chair.md)
        .padding(.vertical, Spacing.chair.xs)
        .background(Color.chair.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.chair.control))
        .overlay(RoundedRectangle(cornerRadius: Radius.chair.control).stroke(Color.chair.outline, lineWidth: Stroke.chair.thin))
    }

    private func statLine(_ row: MatchSummaryModel.StatRow) -> some View {
        VStack(spacing: Spacing.chair.xxs) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.chair.sm) {
                    Text(row.a).chairFont(.headline).frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.title).chairFont(.caption).foregroundStyle(Color.chair.inkSecondary).multilineTextAlignment(.center)
                    Text(row.b).chairFont(.headline).frame(maxWidth: .infinity, alignment: .trailing)
                }
                VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                    Text(row.title).chairFont(.caption).foregroundStyle(Color.chair.inkSecondary)
                    Text("\(model.names[.a] ?? "A") \(row.a)").chairFont(.body)
                    Text("\(model.names[.b] ?? "B") \(row.b)").chairFont(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(Color.chair.ink)
            if let share = StatShare(a: row.a, b: row.b) {
                GeometryReader { proxy in
                    HStack(spacing: 2) {
                        Capsule().fill(Color.chair.playerA).frame(width: max(proxy.size.width * share.a - 1, 0))
                        Capsule().fill(Color.chair.playerB)
                    }
                }
                .frame(height: 4)
                .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Spacing.chair.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.title): \(model.names[.a] ?? "A") \(row.a), \(model.names[.b] ?? "B") \(row.b)")
    }

    private var momentum: some View {
        VStack(alignment: .leading, spacing: Spacing.chair.xs) {
            Text("Momentum")
                .chairFont(.caption)
                .foregroundStyle(Color.chair.inkSecondary)
                .accessibilityAddTraits(.isHeader)
            ChairCard {
                MomentumBar(runs: model.runs)
                    .frame(height: 80)
                    .accessibilityLabel("Momentum")
                    .accessibilityValue("\(model.runs.count) runs of points")
            }
        }
    }

    private var shotMapPlaceholder: some View {
        ChairCard {
            Text("Shot map arrives with camera scoring")
                .chairFont(.callout)
                .foregroundStyle(Color.chair.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
    }

    private var pointList: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(model.points) { point in
                HStack(spacing: Spacing.chair.sm) {
                    Text(point.score)
                        .chairFont(.score)
                        .foregroundStyle(Color.chair.ink)
                        .frame(minWidth: 72, alignment: .leading)
                    VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                        Text(point.setAndGame)
                            .chairFont(.caption)
                            .foregroundStyle(Color.chair.inkSecondary)
                        if let outcome = point.outcome {
                            Text(outcome)
                                .chairFont(.caption)
                                .foregroundStyle(Color.chair.ink)
                                .padding(.horizontal, Spacing.chair.xs)
                                .padding(.vertical, Spacing.chair.xxs)
                                .background(Color.chair.control, in: Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(point.winner)
                        .chairFont(.headline)
                        .foregroundStyle(Color.chair.ink)
                }
                .padding(.vertical, Spacing.chair.xs)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(point.context), \(point.detail)")
                Divider().overlay(Color.chair.outline)
            }
        }
    }

    private var coachPlaceholder: some View {
        ChairCard {
            VStack(spacing: Spacing.chair.sm) {
                Image(systemName: "lock.fill")
                    .font(Font.chair.title)
                    .foregroundStyle(Color.chair.tint)
                Text("Coach is locked")
                    .chairFont(.title)
                    .foregroundStyle(Color.chair.ink)
                Text("Match insights arrive in a later update.")
                    .chairFont(.body)
                    .foregroundStyle(Color.chair.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.chair.lg)
        }
        .accessibilityElement(children: .combine)
    }
}

struct MomentumBar: View {
    let runs: [MatchSummaryModel.Run]

    var body: some View {
        Canvas { context, size in
            let total = max(runs.map(\.length).reduce(0, +), 1)
            let longest = CGFloat(max(runs.map(\.length).max() ?? 1, 1))
            let unit = size.width / CGFloat(total)
            let middle = size.height / 2
            var x: CGFloat = 0
            for run in runs {
                let width = unit * CGFloat(run.length)
                let height = middle * CGFloat(run.length) / longest
                let rect = run.side == .a
                    ? CGRect(x: x, y: middle - height, width: width, height: height)
                    : CGRect(x: x, y: middle, width: width, height: height)
                context.fill(Path(rect), with: .color(run.side == .a ? Color.chair.playerA : Color.chair.playerB))
                x += width
            }
            context.stroke(
                Path { $0.move(to: CGPoint(x: 0, y: middle)); $0.addLine(to: CGPoint(x: size.width, y: middle)) },
                with: .color(Color.chair.outline),
                lineWidth: 1
            )
        }
    }
}

struct StatShare {
    let a: Double

    init?(
        a: String,
        b: String
    ) {
        guard let left = Self.value(a), let right = Self.value(b), left + right > 0 else { return nil }
        self.a = left / (left + right)
    }

    private static func value(_ text: String) -> Double? {
        if let percent = text.firstMatch(of: /(\d+)%/) {
            return Double(percent.1)
        }
        return text.firstMatch(of: /\d+/).flatMap { Double($0.output) }
    }
}
