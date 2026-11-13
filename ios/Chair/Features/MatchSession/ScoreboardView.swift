//
//  ScoreboardView.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct ScoreboardView: View {
    let model: ScoreboardModel
    var isCompact = false

    @ScaledMetric(relativeTo: .headline) private var ballSize: CGFloat = 18
    @ScaledMetric(relativeTo: .title) private var gamesWidth: CGFloat = 36
    @ScaledMetric(relativeTo: .largeTitle) private var pointsWidth: CGFloat = 64

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Spacing.chair.sm, verticalSpacing: 0) {
            if !isCompact {
                header
                Divider().overlay(Color.chair.outline)
            }
            ForEach(Array(model.rows.enumerated()), id: \.element.side) { index, row in
                if index > 0 {
                    Divider().overlay(Color.chair.outline)
                }
                rowView(row)
            }
        }
        .padding(.horizontal, Spacing.chair.md)
        .padding(.vertical, isCompact ? Spacing.chair.xs : Spacing.chair.xxs)
        .background(Color.chair.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.chair.control))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.chair.control)
                .stroke(Color.chair.outline, lineWidth: Stroke.chair.thin)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("session.scoreboard")
    }

    private var header: some View {
        GridRow {
            Color.clear.frame(width: ballSize, height: 1)
            Color.clear.frame(height: 1)
            ForEach(Array(setColumns.enumerated()), id: \.offset) { index, _ in
                Text("Set \(index + 1)")
                    .frame(width: gamesWidth)
            }
            Text("Pts")
                .frame(width: pointsWidth, alignment: .trailing)
        }
        .chairFont(.caption)
        .foregroundStyle(Color.chair.inkSecondary)
        .padding(.vertical, Spacing.chair.xs)
        .accessibilityHidden(true)
    }

    private var setColumns: [Int] {
        model.rows.first?.games ?? []
    }

    private func rowView(_ row: ScoreboardModel.Row) -> some View {
        GridRow {
            Image(systemName: "tennisball.fill")
                .font(.system(size: ballSize))
                .foregroundStyle(Color.chair.tint)
                .opacity(row.isServing ? 1 : 0)
                .accessibilityHidden(true)
            Text(row.name)
                .chairFont(.action)
                .foregroundStyle(Color.chair.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(row.games.enumerated()), id: \.offset) { _, games in
                Text("\(games)")
                    .chairFont(isCompact ? .title : .score)
                    .foregroundStyle(Color.chair.ink)
                    .frame(width: gamesWidth)
            }
            Text(row.points)
                .chairFont(isCompact ? .score : .scoreLarge)
                .foregroundStyle(Color.chair.tint)
                .frame(width: pointsWidth, alignment: .trailing)
        }
        .padding(.vertical, isCompact ? Spacing.chair.xxs : Spacing.chair.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(row))
    }

    private func accessibilityLabel(_ row: ScoreboardModel.Row) -> String {
        let serving = row.isServing ? ", serving" : ""
        let games = row.games.map(String.init).joined(separator: ", ")
        return "\(row.name)\(serving). Games \(games). Points \(row.points)"
    }
}
