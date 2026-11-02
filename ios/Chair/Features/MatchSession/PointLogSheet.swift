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
            Text(Self.text(for: point, names: names))
                .chairFont(.body)
                .foregroundStyle(Color.chair.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Flip", action: handleFlip(point.index))
                .buttonStyle(.bordered)
                .tint(Color.chair.accent)
                .accessibilityLabel("Flip point \(point.number)")
                .accessibilityIdentifier("pointLog.flip.\(point.number)")
        }
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
