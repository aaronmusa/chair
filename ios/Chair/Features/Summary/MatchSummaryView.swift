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
                MatchLinksSection(matchID: model.matchID)
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
                .chairFont(.callout)
                .foregroundStyle(Color.chair.inkSecondary)
            Text(model.result)
                .chairFont(.title)
                .foregroundStyle(Color.chair.ink)
            Text(model.setLine)
                .chairFont(.score)
                .monospacedDigit()
                .foregroundStyle(Color.chair.ink)
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
            statLine(title: "", a: model.names[.a] ?? "A", b: model.names[.b] ?? "B", isHeader: true)
            ForEach(model.rows) { row in
                Divider()
                statLine(title: row.title, a: row.a, b: row.b, isHeader: false)
            }
        }
        .padding(Spacing.chair.sm)
        .background(Color.chair.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.chair.large))
    }

    private func statLine(
        title: String,
        a: String,
        b: String,
        isHeader: Bool
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.chair.sm) {
                Text(a).frame(maxWidth: .infinity, alignment: .leading)
                Text(title).foregroundStyle(Color.chair.inkSecondary).multilineTextAlignment(.center)
                Text(b).frame(maxWidth: .infinity, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                if isHeader {
                    Text("\(a) v \(b)")
                } else {
                    Text(title).foregroundStyle(Color.chair.inkSecondary)
                    Text("\(model.names[.a] ?? "A") \(a)")
                    Text("\(model.names[.b] ?? "B") \(b)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .chairFont(isHeader ? .headline : .body)
        .foregroundStyle(Color.chair.ink)
        .padding(.vertical, Spacing.chair.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isHeader ? "\(a) versus \(b)" : "\(title): \(model.names[.a] ?? "A") \(a), \(model.names[.b] ?? "B") \(b)")
    }

    private var momentum: some View {
        VStack(alignment: .leading, spacing: Spacing.chair.xs) {
            Text("Momentum")
                .chairFont(.headline)
                .foregroundStyle(Color.chair.ink)
            MomentumBar(runs: model.runs)
                .frame(height: 80)
                .accessibilityLabel("Momentum")
                .accessibilityValue("\(model.runs.count) runs of points")
        }
    }

    private var shotMapPlaceholder: some View {
        Text("Shot map arrives with camera scoring")
            .chairFont(.callout)
            .foregroundStyle(Color.chair.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Color.chair.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.chair.large))
    }

    private var pointList: some View {
        LazyVStack(alignment: .leading, spacing: Spacing.chair.xs) {
            ForEach(model.points) { point in
                VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                    Text(point.context)
                        .chairFont(.callout)
                        .foregroundStyle(Color.chair.inkSecondary)
                    Text(point.detail)
                        .chairFont(.body)
                        .foregroundStyle(Color.chair.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                Divider()
            }
        }
    }

    private var coachPlaceholder: some View {
        ContentUnavailableView(
            "Coach is locked",
            systemImage: "lock.fill",
            description: Text("Match insights arrive in a later update.")
        )
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
