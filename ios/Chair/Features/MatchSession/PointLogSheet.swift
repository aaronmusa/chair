//
//  PointLogSheet.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct PointLogSheet: View {
    let points: [LoggedPoint]
    let names: [Side: String]
    let onFlip: (Int) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if points.isEmpty {
                    ContentUnavailableView("No points yet", systemImage: "list.number", description: Text("Points in this game show here."))
                } else {
                    List(points, id: \.index) { point in
                        row(point)
                            .listRowBackground(Color.chair.surfaceRaised)
                            .listRowSeparatorTint(Color.chair.outline)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.chair.surface)
            .navigationTitle("This game")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ point: LoggedPoint) -> some View {
        HStack(spacing: Spacing.chair.sm) {
            Text("\(point.number)")
                .chairFont(.headline)
                .foregroundStyle(Color.chair.ink)
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(Color.chair.ink, lineWidth: Stroke.chair.regular))
            VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                if let how = Self.how(point) {
                    Text(how)
                        .chairFont(.caption)
                        .foregroundStyle(Color.chair.ink)
                        .padding(.horizontal, Spacing.chair.xs)
                        .padding(.vertical, Spacing.chair.xxs)
                        .background(Color.chair.control, in: Capsule())
                }
                Text("Point \(names[point.winner] ?? point.winner.rawValue)")
                    .chairFont(.headline)
                    .foregroundStyle(Color.chair.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: handleFlip(point.index)) {
                Text("Flip")
                    .chairFont(.headline)
                    .padding(.horizontal, Spacing.chair.md)
                    .frame(minHeight: 40)
            }
            .buttonStyle(ChairButtonStyle(.secondary))
            .accessibilityLabel("Flip point \(point.number)")
            .accessibilityIdentifier("pointLog.flip.\(point.number)")
        }
        .accessibilityElement(children: .combine)
    }

    private static func how(_ point: LoggedPoint) -> String? {
        let how = [point.outcome?.shortTitle, point.ending?.rawValue].compactMap(\.self).joined(separator: " ")
        return how.isEmpty ? nil : how
    }

    static func text(
        for point: LoggedPoint,
        names: [Side: String]
    ) -> String {
        let how = [point.outcome?.shortTitle, point.ending?.rawValue].compactMap(\.self).joined(separator: " ")
        let winner = names[point.winner] ?? point.winner.rawValue
        return how.isEmpty ? "\(point.number) · \(winner)" : "\(point.number) · \(how) · \(winner)"
    }

    private func handleFlip(_ index: Int) -> () -> Void {
        { onFlip(index) }
    }
}
