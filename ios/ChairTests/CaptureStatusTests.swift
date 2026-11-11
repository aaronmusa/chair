//
//  CaptureStatusTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/11/26.
//

import SwiftUI
import XCTest

import ChairKit
import ChairTestSupport
import ChairUI
import SnapshotTesting

@testable import Chair

@MainActor
final class CaptureStatusTests: XCTestCase {
    private struct Variant {
        let name: String
        let style: UIUserInterfaceStyle
        let typeSize: DynamicTypeSize
    }

    func testDeniedPermissionOffersSettings() {
        let status = CaptureStatus(.unavailable(.permissionDenied))

        XCTAssertEqual(status?.title, "Camera access is off")
        XCTAssertEqual(status?.offersSettings, true)
    }

    func testOnlyProblemsShowAStatus() {
        XCTAssertNil(CaptureStatus(.idle))
        XCTAssertNil(CaptureStatus(.running(frameRate: 60)))
        XCTAssertEqual(CaptureStatus(.running(frameRate: 30))?.title, "Camera at 30 fps")
        XCTAssertEqual(CaptureStatus(.interrupted(.otherApp))?.title, "Another app is using the camera")
        XCTAssertEqual(CaptureStatus(.pausedForHeat)?.offersSettings, false)
        XCTAssertEqual(CaptureStatus(.unavailable(.noCamera))?.title, "No camera available")
    }

    func testTheSimulatorHasNoCamera() async {
        let capture = CaptureSession(authorization: FakeCameraAuthorization(.authorized))

        await capture.start()

        XCTAssertEqual(capture.state, .unavailable(.noCamera))
    }

    func testADeniedCaptureSessionIsUnavailable() async {
        let capture = CaptureSession(authorization: FakeCameraAuthorization(.denied))

        await capture.start()

        XCTAssertEqual(capture.state, .unavailable(.permissionDenied))
    }

    func testCaptureStatusSnapshots() {
        let states: [CaptureState] = [
            .unavailable(.permissionDenied),
            .interrupted(.otherApp),
            .pausedForHeat,
            .running(frameRate: 30),
        ]
        let variants = [
            Variant(name: "light", style: .light, typeSize: .large),
            Variant(name: "dark", style: .dark, typeSize: .large),
            Variant(name: "ax5", style: .light, typeSize: .accessibility5),
        ]
        for variant in variants {
            let view = ScrollView {
                VStack(spacing: Spacing.chair.md) {
                    ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                        CaptureStatusView(state: state)
                    }
                }
                .padding(Spacing.chair.md)
            }
            .background(Color.chair.surface)
            .environment(\.dynamicTypeSize, variant.typeSize)
            assertSnapshot(
                of: UIHostingController(rootView: view),
                as: .image(on: .iPhone13, traits: UITraitCollection(userInterfaceStyle: variant.style)),
                named: variant.name
            )
        }
    }
}
