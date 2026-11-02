//
//  SignInViewSnapshotTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI
import XCTest

import ChairKit
import ChairTestSupport
import SnapshotTesting

@testable import Chair

@MainActor
final class SignInViewSnapshotTests: XCTestCase {
    private struct Variant {
        let name: String
        let style: UIUserInterfaceStyle
        let typeSize: DynamicTypeSize
    }

    func testSignIn() {
        let variants = [
            Variant(name: "light", style: .light, typeSize: .large),
            Variant(name: "dark", style: .dark, typeSize: .large),
            Variant(name: "ax5", style: .light, typeSize: .accessibility5),
        ]
        for variant in variants {
            let view = SignInView(viewModel: SignInViewModel(environment: .fakes(), onFinish: {}))
                .environment(\.dynamicTypeSize, variant.typeSize)
            assertSnapshot(
                of: UIHostingController(rootView: view),
                as: .image(on: .iPhone13, traits: UITraitCollection(userInterfaceStyle: variant.style)),
                named: variant.name
            )
        }
    }
}
