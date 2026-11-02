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

    var body: some View {
        VStack(spacing: Spacing.chair.xs) {
            ForEach(model.rows, id: \.side) { row in
                rowView(row)
            }
        }
        .padding(Spacing.chair.sm)
        .background(Color.chair.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.chair.large))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("session.scoreboard")
    }

    private func rowView(_ row: ScoreboardModel.Row) -> some View {
        HStack(spacing: Spacing.chair.sm) {
            Circle()
                .fill(row.isServing ? Color.chair.accent : Color.clear)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(row.name)
                .chairFont(.headline)
                .foregroundStyle(Color.chair.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(row.games.enumerated()), id: \.offset) { _, games in
                Text("\(games)")
                    .chairFont(.title)
                    .monospacedDigit()
                    .foregroundStyle(Color.chair.inkSecondary)
            }
            Text(row.points)
                .chairFont(.scoreLarge)
                .monospacedDigit()
                .foregroundStyle(Color.chair.ink)
                .frame(minWidth: 72, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(row))
    }

    private func accessibilityLabel(_ row: ScoreboardModel.Row) -> String {
        let serving = row.isServing ? ", serving" : ""
        let games = row.games.map(String.init).joined(separator: ", ")
        return "\(row.name)\(serving). Games \(games). Points \(row.points)"
    }
}
