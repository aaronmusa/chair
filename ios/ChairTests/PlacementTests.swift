//
//  PlacementTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/11/26.
//

import SwiftData
import SwiftUI
import XCTest

import ChairKit
import ChairTestSupport
import ChairUI
import SnapshotTesting

@testable import Chair

@MainActor
final class PlacementTests: XCTestCase {
    private final class AskingAuthorization: CameraAuthorizing, @unchecked Sendable {
        private let lock = NSLock()
        private var current = CameraPermission.notDetermined
        private var requests = 0
        private let answer: Bool

        init(answer: Bool) {
            self.answer = answer
        }

        var requestCount: Int {
            lock.withLock { requests }
        }

        func status() -> CameraPermission {
            lock.withLock { current }
        }

        func request() async -> Bool {
            lock.withLock {
                requests += 1
                current = answer ? .authorized : .denied
            }
            return answer
        }
    }

    private struct Variant {
        let name: String
        let style: UIUserInterfaceStyle
        let typeSize: DynamicTypeSize
    }

    private var container: ModelContainer?

    func testStartingACameraMatchShowsPlacementBeforeTheLiveScreen() throws {
        let router = AppRouter()
        router.showNewMatch()
        let repository = try makeRepository()
        let model = NewMatchViewModel(defaults: MatchDefaults(), repository: repository, clock: FixedClock(Fixtures.matchDay))
        model.setup.names[.b1] = "Juan"
        model.setup.inputMode = .camera

        let matchID = try XCTUnwrap(model.start())
        router.showPlacement(for: matchID)

        XCTAssertEqual(router.playPath, [.newMatch, .placement(matchID)])
        XCTAssertNil(router.presentedMatch)
        XCTAssertEqual(try repository.fetch().first?.inputModeValue, .camera)
    }

    func testAllowingTheCameraSavesThePlacementAndOpensTheMatch() async throws {
        let repository = try makeRepository()
        let match = Match.sample()
        try repository.save(match)
        let authorization = AskingAuthorization(answer: true)
        var opened: UUID?
        let model = PlacementViewModel(matchID: match.remoteID, repository: repository, authorization: authorization) { opened = $0 }
        model.placement = .chair

        await model.openCamera()

        XCTAssertEqual(authorization.requestCount, 1)
        XCTAssertEqual(opened, match.remoteID)
        XCTAssertEqual(try repository.fetch().first?.cameraPlacementValue, .chair)
    }

    func testDenyingTheCameraKeepsThePlayerOnPlacementWithTheSettingsLink() async throws {
        let repository = try makeRepository()
        let match = Match.sample()
        try repository.save(match)
        var opened = false
        let model = PlacementViewModel(
            matchID: match.remoteID,
            repository: repository,
            authorization: AskingAuthorization(answer: false)
        ) { _ in opened = true }

        await model.openCamera()

        XCTAssertEqual(model.permission, .denied)
        XCTAssertFalse(opened)
        XCTAssertNil(try repository.fetch().first?.cameraPlacement)
        XCTAssertEqual(CaptureStatus(.unavailable(.permissionDenied))?.offersSettings, true)
    }

    func testAMissingMatchSaysSoInsteadOfOpening() async {
        var opened = false
        let model = PlacementViewModel(
            matchID: UUID(),
            repository: nil,
            authorization: FakeCameraAuthorization(.authorized)
        ) { _ in opened = true }

        await model.openCamera()

        XCTAssertFalse(opened)
        XCTAssertEqual(model.errorMessage, "Couldn't find this match. Go back and start it again.")
    }

    func testPlacementSnapshots() {
        let variants = [
            Variant(name: "light", style: .light, typeSize: .large),
            Variant(name: "dark", style: .dark, typeSize: .large),
            Variant(name: "ax5", style: .light, typeSize: .accessibility5),
        ]
        for variant in variants {
            assertSnapshot(
                of: host(.notDetermined, typeSize: variant.typeSize),
                as: .image(on: .iPhone13, traits: UITraitCollection(userInterfaceStyle: variant.style)),
                named: "compact-\(variant.name)"
            )
        }
        for style in [UIUserInterfaceStyle.light, .dark] {
            assertSnapshot(
                of: host(.notDetermined, alternatives: true),
                as: .image(on: .iPadPro11(.portrait), traits: UITraitCollection(userInterfaceStyle: style)),
                named: "regular-\(style == .light ? "light" : "dark")"
            )
        }
        assertSnapshot(
            of: host(.denied),
            as: .image(on: .iPhone13, traits: UITraitCollection(userInterfaceStyle: .light)),
            named: "compact-denied"
        )
    }

    private func host(
        _ permission: CameraPermission,
        typeSize: DynamicTypeSize = .large,
        alternatives: Bool = false
    ) -> UIViewController {
        let model = PlacementViewModel(
            matchID: UUID(),
            repository: nil,
            authorization: FakeCameraAuthorization(permission)
        ) { _ in }
        model.isShowingAlternatives = alternatives
        let view = NavigationStack { PlacementView(viewModel: model) }
            .environment(\.dynamicTypeSize, typeSize)
        return UIHostingController(rootView: view)
    }

    private func makeRepository() throws -> LocalMatchRepository {
        let container = try InMemoryModelContainer()
        self.container = container
        return LocalMatchRepository(context: container.mainContext)
    }
}
