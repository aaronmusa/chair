//
//  MatchListViewSnapshotTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI
import XCTest

import ChairKit
import ChairTestSupport
import SnapshotTesting

@testable import Chair

@MainActor
final class MatchListViewSnapshotTests: XCTestCase {
    func testMatchListCompact() throws {
        try assertStyles(.compact, config: .iPhone13)
    }

    func testMatchListRegularShowsTheSelectedSummary() throws {
        let (finished, _) = try SummaryFixture.make(events: Array(repeating: SummaryFixture.point(.a), count: 48))
        let older = try MatchListFixture.record(format: .doubles, opponent: "Lia", on: "2026-09-12")
        let viewModel = MatchListViewModel(repository: nil)
        viewModel.update(MatchListQuery().apply([finished.record, older]))
        let router = AppRouter(selectedSection: .matches)
        router.summaryMatchID = finished.remoteID
        for style in [UIUserInterfaceStyle.light, .dark] {
            let view = NavigationStack { MatchesScreen(viewModel: viewModel) }
                .environment(\.appRouter, router)
                .environment(\.horizontalSizeClass, .regular)
            assertSnapshot(
                of: UIHostingController(rootView: view),
                as: .image(on: .iPadPro11(.landscape), traits: UITraitCollection(userInterfaceStyle: style)),
                named: style == .dark ? "dark" : "light"
            )
        }
    }

    private func assertStyles(
        _ sizeClass: UserInterfaceSizeClass,
        config: ViewImageConfig,
        testName: String = #function,
        line: UInt = #line
    ) throws {
        let (finished, _) = try SummaryFixture.make(events: Array(repeating: SummaryFixture.point(.a), count: 48))
        let (live, _) = try SummaryFixture.make(events: [SummaryFixture.point(.b)])
        let older = try MatchListFixture.record(format: .doubles, opponent: "Lia", on: "2026-09-12")
        let model = MatchListModel(records: MatchListQuery().apply([finished.record, live.record, older]))
        for style in [UIUserInterfaceStyle.light, .dark] {
            let view = NavigationStack {
                MatchListView(model: model, query: .constant(MatchListQuery()))
                    .navigationTitle("Matches")
            }
            .environment(\.horizontalSizeClass, sizeClass)
            assertSnapshot(
                of: UIHostingController(rootView: view),
                as: .image(on: config, traits: UITraitCollection(userInterfaceStyle: style)),
                named: style == .dark ? "dark" : "light",
                testName: testName,
                line: line
            )
        }
    }
}
