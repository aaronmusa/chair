//
//  UmpireSettingsSnapshotTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI
import XCTest

import ChairKit
import ChairTestSupport
import ChairUI
import SnapshotTesting

@testable import Chair

@MainActor
final class UmpireSettingsSnapshotTests: XCTestCase {
    private struct Variant {
        let name: String
        let style: UIUserInterfaceStyle
        let typeSize: DynamicTypeSize
    }

    func testUmpireSettings() {
        let variants = [
            Variant(name: "light", style: .light, typeSize: .large),
            Variant(name: "dark", style: .dark, typeSize: .large),
            Variant(name: "ax5", style: .light, typeSize: .accessibility5),
        ]
        for variant in variants {
            let settings = UmpireSettings.fake(UmpirePreferences(volume: 0.8))
            let view = NavigationStack {
                Form {
                    UmpireSettingsSection(settings: settings, routeName: "JBL Flip", voices: [])
                        .listRowBackground(Color.chair.surfaceRaised)
                }
                .scrollContentBackground(.hidden)
                .background(Color.chair.surface)
                .tint(Color.chair.accent)
                .navigationTitle("Settings")
            }
            .environment(\.dynamicTypeSize, variant.typeSize)
            assertSnapshot(
                of: UIHostingController(rootView: view),
                as: .image(on: .iPhone13, traits: UITraitCollection(userInterfaceStyle: variant.style)),
                named: variant.name
            )
        }
    }
}
