//
//  ComponentAccessibilityTests.swift
//  ChairUIPackageTests
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI
import UIKit
import XCTest

@testable import ChairUI

@MainActor
final class ComponentAccessibilityTests: XCTestCase {
    func testButtonReadsItsTitleAsAButton() {
        let element = elements(in: ChairButton("Start match", onTap: {})).first { $0.label == "Start match" }
        XCTAssertTrue(element?.traits.contains(.button) == true)
    }

    func testLoadingButtonSaysSo() {
        let element = elements(in: ChairButton("Save", isLoading: true, onTap: {})).first { $0.label == "Save" }
        XCTAssertEqual(element?.value, "Loading")
        XCTAssertTrue(element?.traits.contains(.notEnabled) == true)
    }

    func testSelectedPillIsASelectedButton() {
        let element = elements(in: ChairPill("Singles", isSelected: true, onTap: {})).first { $0.label == "Singles" }
        XCTAssertTrue(element?.traits.contains(.button) == true)
        XCTAssertTrue(element?.traits.contains(.selected) == true)
    }

    func testBadgePillIsStaticText() {
        let element = elements(in: ChairPill("Pro")).first { $0.label == "Pro" }
        XCTAssertTrue(element?.traits.contains(.staticText) == true)
        XCTAssertFalse(element?.traits.contains(.button) == true)
    }

    func testSegmentedMarksOnlyTheSelectedSegment() {
        let view = ChairSegmented([.init(0, "Singles"), .init(1, "Doubles")], selection: .constant(1))
        let found = elements(in: view)
        let singles = found.first { $0.label == "Singles" }
        let doubles = found.first { $0.label == "Doubles" }
        XCTAssertTrue(singles?.traits.contains(.button) == true)
        XCTAssertFalse(singles?.traits.contains(.selected) == true)
        XCTAssertTrue(doubles?.traits.contains(.selected) == true)
    }

    func testRowReadsTitleAndValue() {
        let element = elements(in: ChairRow("Voice", systemImage: "speaker.wave.2", value: "Daniel", showsChevron: true, onTap: {}))
            .first { $0.label == "Voice" }
        XCTAssertEqual(element?.value, "Daniel")
        XCTAssertTrue(element?.traits.contains(.button) == true)
    }

    func testCardAndSheetExposeTheirContent() {
        let card = elements(in: ChairCard { Text("Last match") })
        let sheet = elements(in: ChairSheet { Text("Point to Musa?") })
        XCTAssertTrue(card.contains { $0.label == "Last match" && $0.traits.contains(.staticText) })
        XCTAssertTrue(sheet.contains { $0.label == "Point to Musa?" && $0.traits.contains(.staticText) })
    }

    func testCountdownReadsSecondsLeft() {
        let element = elements(in: CountdownRingFace(progress: 0.4, secondsLeft: 3, size: .regular))
            .first { $0.label == "Countdown" }
        XCTAssertEqual(element?.value, "3 seconds")
        XCTAssertTrue(element?.traits.contains(.updatesFrequently) == true)
    }

    private struct Element {
        let label: String
        let value: String?
        let traits: UIAccessibilityTraits
    }

    private func elements(in view: some View) -> [Element] {
        let controller = UIHostingController(rootView: view.frame(width: 393))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        defer { window.isHidden = true }

        var found: [Element] = []
        func visit(_ object: NSObject) {
            if object.isAccessibilityElement, let label = object.accessibilityLabel, !label.isEmpty {
                found.append(Element(label: label, value: object.accessibilityValue, traits: object.accessibilityTraits))
            }
            let children: [Any] = object.accessibilityElements
                ?? (0 ..< max(object.accessibilityElementCount(), 0)).compactMap { object.accessibilityElement(at: $0) }
            children.compactMap { $0 as? NSObject }.forEach(visit)
            (object as? UIView)?.subviews.forEach(visit)
        }
        visit(controller.view)
        return found
    }
}
