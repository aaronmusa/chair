//
//  PlaceholderView.swift
//  Chair
//
//  Created by Aaron Musa on 10/31/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct PlaceholderView: View {
    let section: AppSection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.chair.md) {
                ChairCard {
                    VStack(alignment: .leading, spacing: Spacing.chair.sm) {
                        preview
                        Text("Coming soon")
                            .chairFont(.caption)
                            .foregroundStyle(Color.chair.tint)
                        Text(content.title)
                            .chairFont(.display)
                            .foregroundStyle(Color.chair.ink)
                        Text(content.detail)
                            .chairFont(.body)
                            .foregroundStyle(Color.chair.inkSecondary)
                    }
                }
                Text("Planned")
                    .chairFont(.caption)
                    .foregroundStyle(Color.chair.inkSecondary)
                    .accessibilityAddTraits(.isHeader)
                ChairCard {
                    VStack(alignment: .leading, spacing: Spacing.chair.sm) {
                        ForEach(content.planned, id: \.title) { item in
                            Label(item.title, systemImage: item.systemImage)
                                .chairFont(.headline)
                                .foregroundStyle(Color.chair.ink)
                        }
                    }
                }
            }
            .padding(Spacing.chair.md)
        }
        .background(Color.chair.surface)
        .navigationTitle(section.title)
        .accessibilityIdentifier("placeholder.\(section.rawValue)")
    }

    @ViewBuilder
    private var preview: some View {
        switch section {
        case .coach:
            CoachPreview()
        default:
            CourtView(orientation: .landscape, targetZones: Self.serveTargets)
                .frame(maxWidth: .infinity, maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: Radius.chair.small))
                .accessibilityHidden(true)
        }
    }

    private var content: ComingSoonContent {
        section == .coach ? .coach : .train
    }

    private static let serveTargets = [
        CourtZone(id: "wide", from: CourtPoint(x: -4.1, y: 5.0), to: CourtPoint(x: -2.7, y: 6.4)),
        CourtZone(id: "body", from: CourtPoint(x: -1.9, y: 5.0), to: CourtPoint(x: -0.5, y: 6.4)),
        CourtZone(id: "tee", from: CourtPoint(x: 0.5, y: 5.0), to: CourtPoint(x: 1.9, y: 6.4)),
    ]
}

private struct ComingSoonContent {
    struct Item {
        let title: String
        let systemImage: String
    }

    let title: String
    let detail: String
    let planned: [Item]

    static let train = ComingSoonContent(
        title: "Serve training",
        detail: "Hit targets, track your first-serve percentage and see your progress over time.",
        planned: [
            Item(title: "Serve targets", systemImage: "scope"),
            Item(title: "Rally drills", systemImage: "figure.tennis"),
            Item(title: "Weekly goals", systemImage: "calendar"),
        ]
    )

    static let coach = ComingSoonContent(
        title: "Match insights",
        detail: "After each match, Coach spots patterns in your points and tells you what to work on.",
        planned: [
            Item(title: "Error patterns", systemImage: "chart.bar"),
            Item(title: "Serve trends", systemImage: "chart.line.uptrend.xyaxis"),
            Item(title: "What to practise next", systemImage: "lightbulb"),
        ]
    )
}

private struct CoachPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.chair.xs) {
            HStack {
                Text("Example")
                    .chairFont(.caption)
                    .foregroundStyle(Color.chair.inkSecondary)
                Spacer()
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.chair.inkSecondary)
            }
            HStack(alignment: .bottom, spacing: Spacing.chair.md) {
                VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                    Text("62%")
                        .chairFont(.scoreLarge)
                        .foregroundStyle(Color.chair.ink)
                    Text("of unforced errors came on the backhand")
                        .chairFont(.callout)
                        .foregroundStyle(Color.chair.inkSecondary)
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: Spacing.chair.xxs) {
                    ForEach([0.4, 0.7, 0.5, 0.9, 0.62], id: \.self) { height in
                        Capsule()
                            .fill(Color.chair.tint)
                            .frame(width: 10, height: 60 * height)
                    }
                }
            }
        }
        .padding(Spacing.chair.md)
        .background(Color.chair.control, in: RoundedRectangle(cornerRadius: Radius.chair.control))
        .opacity(0.6)
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        PlaceholderView(section: .train)
    }
}
