//
//  MatchListView.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct MatchListActions {
    var onSelect: (MatchListModel.Row) -> Void = { _ in }
    var onNewMatch: () -> Void = {}
}

struct MatchListView: View {
    let model: MatchListModel
    @Binding var query: MatchListQuery
    var selection: UUID?
    var actions = MatchListActions()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            filters
            if model.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color.chair.surface)
        .searchable(text: $query.search, prompt: "Search opponents")
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: Spacing.chair.xs) {
            FlowLayout(spacing: Spacing.chair.xs) {
                ForEach(MatchListQuery.Filter.allCases, id: \.self) { filter in
                    ChairPill(filter.title, isSelected: query.filter == filter, onTap: handleFilter(filter))
                        .accessibilityIdentifier("matches.filter.\(filter.rawValue)")
                }
            }
            Text(model.countLabel)
                .chairFont(.callout)
                .foregroundStyle(Color.chair.inkSecondary)
                .accessibilityIdentifier("matches.count")
        }
        .padding(.horizontal, Spacing.chair.md)
        .padding(.vertical, Spacing.chair.sm)
    }

    private var list: some View {
        List {
            ForEach(model.sections) { section in
                Section(section.title) {
                    ForEach(section.rows) { row in
                        Button(action: handleSelect(row)) {
                            MatchRowView(row: row)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(row.id == selection ? Color.chair.surfaceRaised : Color.chair.surface)
                        .accessibilityIdentifier("matches.row.\(row.id.uuidString)")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.chair.md) {
            ContentUnavailableView(
                query == MatchListQuery() ? "No matches yet" : "No matches found",
                systemImage: "list.bullet.rectangle",
                description: Text(query == MatchListQuery() ? "Matches you play show here." : "Try another filter or name.")
            )
            if query == MatchListQuery() {
                ChairButton("New match", size: .large, onTap: actions.onNewMatch)
                    .accessibilityIdentifier("matches.newMatch")
                    .padding(.horizontal, Spacing.chair.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleFilter(_ filter: MatchListQuery.Filter) -> () -> Void {
        { query.filter = filter }
    }

    private func handleSelect(_ row: MatchListModel.Row) -> () -> Void {
        { actions.onSelect(row) }
    }
}

struct MatchRowView: View {
    let row: MatchListModel.Row

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.title)
                    .chairFont(.headline)
                    .foregroundStyle(Color.chair.ink)
                Spacer(minLength: Spacing.chair.xs)
                Text(row.badge)
                    .chairFont(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(badgeColor)
            }
            Text(row.subtitle)
                .chairFont(.callout)
                .foregroundStyle(Color.chair.inkSecondary)
            if !row.setLine.isEmpty {
                Text(row.setLine)
                    .chairFont(.body)
                    .monospacedDigit()
                    .foregroundStyle(Color.chair.ink)
            }
            Text(row.footer)
                .chairFont(.caption)
                .foregroundStyle(Color.chair.inkSecondary)
        }
        .padding(.vertical, Spacing.chair.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var badgeColor: Color {
        switch row.badge {
        case "W": Color.chair.success
        case "L": Color.chair.danger
        default: Color.chair.inkSecondary
        }
    }
}

extension MatchListQuery.Filter {
    var title: String {
        switch self {
        case .all: "All"
        case .singles: "Singles"
        case .doubles: "Doubles"
        case .inProgress: "In progress"
        }
    }
}
