//
//  CourtViewSnapshotTests.swift
//  ChairUIPackageTests
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI
import XCTest

import SnapshotTesting

@testable import ChairUI

@MainActor
final class CourtViewSnapshotTests: XCTestCase {
    func testMiniAndFullWidthInLightAndDark() {
        for width in [110.0, 340.0] {
            for (scheme, name) in [(ColorScheme.light, "light"), (.dark, "dark")] {
                let court = CourtViewPreview(orientation: .portrait)
                    .environment(\.colorScheme, scheme)
                assertSnapshot(of: court, as: .image(layout: layout(width: width, .portrait)), named: "\(Int(width))-\(name)")
            }
        }
    }

    func testLandscape() {
        let court = CourtViewPreview(orientation: .landscape)
        assertSnapshot(of: court, as: .image(layout: layout(width: 600, .landscape)))
    }

    func testTargetZoneSitsUnderTheMarkers() {
        let court = CourtView(
            players: [PlayerMarker(id: "Musa", side: .near, position: .behindBaseline(.near, on: .deuce, by: 1), role: .server)],
            targetZones: [CourtZone(id: "serve", from: CourtPoint(x: 1, y: -14), to: CourtPoint(x: 4, y: -12.885))]
        )
        assertSnapshot(of: court, as: .image(layout: layout(width: 340, .portrait)))
    }

    private func layout(
        width: Double,
        _ orientation: CourtOrientation
    ) -> SwiftUISnapshotLayout {
        .fixed(width: width, height: width / CourtCoordinate.aspectRatio(for: orientation))
    }
}
