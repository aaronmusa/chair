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
                Section {
                    ForEach(section.rows) { row in
                        Button(action: handleSelect(row)) {
                            MatchRowView(row: row)
                        }
                        .buttonStyle(ChairButtonStyle(.ghost))
                        .overlay {
                            if row.id == selection {
                                RoundedRectangle(cornerRadius: Radius.chair.control)
                                    .stroke(Color.chair.tint, lineWidth: Stroke.chair.bold)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: Spacing.chair.xxs,
                            leading: Spacing.chair.md,
                            bottom: Spacing.chair.xxs,
                            trailing: Spacing.chair.md
                        ))
                        .accessibilityIdentifier("matches.row.\(row.id.uuidString)")
                    }
                } header: {
                    Text(section.title)
                        .chairFont(.caption)
                        .foregroundStyle(Color.chair.inkSecondary)
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
        HStack(spacing: Spacing.chair.sm) {
            badge
            VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                Text(row.title)
                    .chairFont(.headline)
                    .foregroundStyle(Color.chair.ink)
                Text(row.subtitle)
                    .chairFont(.caption)
                    .foregroundStyle(Color.chair.inkSecondary)
                Text(row.footer)
                    .chairFont(.callout)
                    .foregroundStyle(Color.chair.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !row.setLine.isEmpty {
                SetLineText(setLine: row.setLine)
                    .foregroundStyle(Color.chair.ink)
            }
            Image(systemName: "chevron.right")
                .font(Font.chair.callout.weight(.semibold))
                .foregroundStyle(Color.chair.inkSecondary)
                .accessibilityHidden(true)
        }
        .padding(Spacing.chair.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([row.title, row.badge, row.subtitle, row.setLine, row.footer].filter { !$0.isEmpty }.joined(separator: ", "))
    }

    @ViewBuilder
    private var badge: some View {
        switch row.badge {
        case "W", "L":
            ResultBadge(result: row.badge)
        case "In progress":
            HStack(spacing: Spacing.chair.xxs) {
                Circle().fill(Color.chair.onAccent).frame(width: 6, height: 6)
                Text("Live")
                    .chairFont(.caption)
            }
            .foregroundStyle(Color.chair.onAccent)
            .padding(.horizontal, Spacing.chair.xs)
            .frame(minHeight: 28)
            .background(Color.chair.accent, in: Capsule())
            .accessibilityHidden(true)
        default:
            EmptyView()
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
