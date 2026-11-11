//
//  SavedCourtsTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/12/26.
//

import SwiftData
import XCTest

import ChairKit
import ChairTestSupport

@testable import Chair

@MainActor
final class SavedCourtsTests: XCTestCase {
    private static let home = CourtLocation(latitude: -33.8688, longitude: 151.2093)

    private var containers: [ModelContainer] = []

    func testANearbySavedCourtPlacesThePointsWithoutTappingAndTheSameViewAgrees() async throws {
        let truth = try SavedCourtFixtures.truth()
        let stores = try makeStores()
        let (matches, match, courts) = (stores.matches, stores.match, stores.courts)
        try courts.save(SavedCourtFixtures.court("Riverside 3", keypoints: truth, at: Self.home))
        let locator = CountingLocator(CourtLocation(latitude: -33.86885, longitude: 151.20935))
        let model = makeModel(
            match: match,
            matches: matches,
            courts: courts,
            locator: locator,
            capture: FakeCaptureSession(source: .clip(SavedCourtFixtures.footage.appending(path: "synthetic-netPost.mp4"))),
            suggester: CourtLineSuggester()
        )

        await model.start()

        XCTAssertEqual(model.courtInUse?.name, "Riverside 3")
        XCTAssertEqual(model.keypoints, truth)
        XCTAssertTrue(model.canContinue)
        try await waitUntilChecked(model)
        XCTAssertFalse(model.positionDiffers)
        await model.stop()
    }

    func testAPhoneFurtherBackShowsTheNoticeAndKeepsThePointsEditable() async throws {
        let truth = try SavedCourtFixtures.truth()
        let shifted = truth.mapValues { CGPoint(x: $0.x + 0.05 * 1920, y: $0.y) }
        let stores = try makeStores()
        let (matches, match, courts) = (stores.matches, stores.match, stores.courts)
        let court = SavedCourtFixtures.court("Riverside 3", keypoints: truth, at: nil)
        try courts.save(court)
        let model = makeModel(match: match, matches: matches, courts: courts, suggester: FixedSuggestion(keypoints: shifted))

        await model.start()
        model.use(court)
        let deadline = Date().addingTimeInterval(10)
        while !model.positionDiffers, Date() < deadline {
            await model.refresh()
            try await Task.sleep(for: .milliseconds(50))
        }

        XCTAssertTrue(model.positionDiffers)
        XCTAssertEqual(model.keypoints, truth)
        let corner = try XCTUnwrap(CourtKeypoint(.doublesRight, .farBaseline))
        model.move(corner, to: CGPoint(x: 100, y: 500))
        XCTAssertEqual(model.keypoints[corner], CGPoint(x: 100, y: 500))
        await model.stop()
    }

    func testWithLocationOffNoPromptAndCourtsArePickedByName() async throws {
        let truth = try SavedCourtFixtures.truth()
        let stores = try makeStores()
        let (matches, match, courts) = (stores.matches, stores.match, stores.courts)
        try courts.save(SavedCourtFixtures.court("Riverside 3", keypoints: truth, at: Self.home))
        let model = makeModel(match: match, matches: matches, courts: courts, locator: nil)

        await model.start()

        XCTAssertNil(model.courtInUse)
        XCTAssertTrue(model.keypoints.isEmpty)
        XCTAssertEqual(model.savedCourts.map(\.name), ["Riverside 3"])
        try model.use(XCTUnwrap(model.savedCourts.first))
        XCTAssertEqual(model.keypoints, truth)
        XCTAssertTrue(model.canContinue)
        XCTAssertFalse(try CameraSettings(defaults: XCTUnwrap(UserDefaults(suiteName: UUID().uuidString))).usesLocation)
        await model.stop()
    }

    func testWithLocationDeniedCourtsAreStillPickedByName() async throws {
        let truth = try SavedCourtFixtures.truth()
        let stores = try makeStores()
        let (matches, match, courts) = (stores.matches, stores.match, stores.courts)
        try courts.save(SavedCourtFixtures.court("Riverside 3", keypoints: truth, at: Self.home))
        let denied = CountingLocator(nil)
        let model = makeModel(match: match, matches: matches, courts: courts, locator: denied)

        await model.start()

        XCTAssertEqual(denied.askCount, 1)
        XCTAssertNil(model.courtInUse)
        XCTAssertEqual(model.savedCourts.count, 1)
        await model.stop()
    }

    func testNextOffersToSaveANewCourtWithItsLocationAndAThumbnailThatStaysLocal() async throws {
        let truth = try SavedCourtFixtures.truth()
        let stores = try makeStores()
        let (matches, match, courts) = (stores.matches, stores.match, stores.courts)
        var opened: UUID?
        let model = makeModel(
            match: match,
            matches: matches,
            courts: courts,
            locator: CountingLocator(Self.home),
            capture: FakeCaptureSession(source: .clip(SavedCourtFixtures.footage.appending(path: "synthetic-netPost.mp4"))),
            initial: truth
        ) { opened = $0 }
        await model.start()
        let deadline = Date().addingTimeInterval(10)
        while model.still == nil, Date() < deadline {
            await model.refresh()
            try await Task.sleep(for: .milliseconds(50))
        }

        model.finish()
        XCTAssertTrue(model.isOfferingSave)
        XCTAssertEqual(model.saveName, "Court 1")
        XCTAssertNil(opened)
        model.saveName = "Home"
        model.saveCourt()

        XCTAssertEqual(opened, match.remoteID)
        let saved = try XCTUnwrap(courts.fetch().first)
        XCTAssertEqual(saved.name, "Home")
        XCTAssertEqual(saved.latitude, Self.home.latitude)
        XCTAssertEqual(saved.calibration?.keypoints, truth)
        let thumbnail = try XCTUnwrap(saved.thumbnailFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: CourtThumbnails.url(for: thumbnail).path))
        CourtThumbnails.remove(thumbnail)
        await model.stop()
    }

    func testSavedCourtsSyncToASecondDeviceWithoutTheirThumbnail() async throws {
        let remote = FakeSavedCourtRemote()
        let me = UUID()
        let first = try syncingCourts(remote)
        let second = try syncingCourts(remote)
        let court = try SavedCourtFixtures.court("Home", keypoints: SavedCourtFixtures.truth(), at: Self.home)
        court.thumbnailFile = "local-only.jpg"
        try first.save(court)

        try await first.sync(as: me)
        try await second.sync(as: me)

        let copy = try XCTUnwrap(second.fetch().first)
        XCTAssertEqual(copy.name, "Home")
        XCTAssertNil(copy.thumbnailFile)
    }

    func testUsingASavedCourtUpdatesItInsteadOfAskingAgain() throws {
        let truth = try SavedCourtFixtures.truth()
        let stores = try makeStores()
        let (matches, match, courts) = (stores.matches, stores.match, stores.courts)
        let court = SavedCourtFixtures.court("Riverside 3", keypoints: truth, at: nil)
        try courts.save(court)
        var opened: UUID?
        let model = makeModel(match: match, matches: matches, courts: courts) { opened = $0 }

        model.use(court)
        model.finish()

        XCTAssertFalse(model.isOfferingSave)
        XCTAssertEqual(opened, match.remoteID)
        XCTAssertEqual(try courts.fetch().first?.lastUsedAt, Fixtures.matchDay)
    }

    private func waitUntilChecked(_ model: CalibrationViewModel) async throws {
        let deadline = Date().addingTimeInterval(60)
        while model.still == nil, Date() < deadline {
            await model.refresh()
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertNotNil(model.still, "the court check needs a frame")
    }

    private struct Stores {
        let matches: LocalMatchRepository
        let match: Match
        let courts: LocalSavedCourtRepository
    }

    private func makeStores() throws -> Stores {
        let container = try InMemoryModelContainer()
        containers.append(container)
        let matches = LocalMatchRepository(context: container.mainContext)
        let match = Match.sample()
        try matches.save(match)
        return Stores(
            matches: matches,
            match: match,
            courts: LocalSavedCourtRepository(context: container.mainContext, clock: FixedClock(Fixtures.matchDay))
        )
    }

    private func syncingCourts(_ remote: FakeSavedCourtRemote) throws -> SyncingSavedCourtRepository {
        let container = try InMemoryModelContainer()
        containers.append(container)
        return SyncingSavedCourtRepository(context: container.mainContext, remote: remote, clock: FixedClock(Fixtures.matchDay))
    }

    private func makeModel(
        match: Match,
        matches: LocalMatchRepository,
        courts: LocalSavedCourtRepository,
        locator: (any CourtLocating)? = nil,
        capture: any CaptureSource = FakeCaptureSession(source: .blank(width: 64, height: 36)),
        suggester: any KeypointSuggesting = FixedSuggestion(keypoints: [:]),
        initial: [CourtKeypoint: CGPoint] = [:],
        onNext: @escaping (UUID) -> Void = { _ in }
    ) -> CalibrationViewModel {
        CalibrationViewModel(
            matchID: match.remoteID,
            placement: .netPost,
            capture: capture,
            suggester: suggester,
            repository: matches,
            clock: FixedClock(Fixtures.matchDay),
            initial: initial,
            courts: courts,
            locator: locator,
            onNext: onNext
        )
    }
}

private struct FixedSuggestion: KeypointSuggesting {
    let keypoints: [CourtKeypoint: CGPoint]

    func suggest(
        in _: LumaImage,
        placement _: CameraPlacement,
        frameSize _: CGSize
    ) async -> CourtSuggestion {
        CourtSuggestion(keypoints: keypoints, confidence: 0.9)
    }
}

private final class CountingLocator: CourtLocating, @unchecked Sendable {
    private let lock = NSLock()
    private let location: CourtLocation?
    private var asked = 0

    init(_ location: CourtLocation?) {
        self.location = location
    }

    var askCount: Int {
        lock.withLock { asked }
    }

    func currentLocation() async -> CourtLocation? {
        lock.withLock { asked += 1 }
        return location
    }
}

private enum SavedCourtFixtures {
    static let footage = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Packages/ChairKit/Tests/ChairKitTests/Fixtures/Footage")

    static func court(
        _ name: String,
        keypoints: [CourtKeypoint: CGPoint],
        at location: CourtLocation?
    ) -> SavedCourt {
        let calibration = CourtCalibration(
            keypoints: keypoints,
            placement: .netPost,
            frameSize: CGSize(width: 1920, height: 1080),
            date: Fixtures.matchDay
        )
        return SavedCourt(
            name: name,
            calibration: calibration!,
            latitude: location?.latitude,
            longitude: location?.longitude,
            createdAt: Fixtures.matchDay,
            updatedAt: Fixtures.matchDay
        )
    }

    static func truth() throws -> [CourtKeypoint: CGPoint] {
        struct Mark: Decodable {
            let keypoint: CourtKeypoint
            let pixel: [String: Double]
        }
        struct Frame: Decodable {
            let points: [Mark]
        }
        struct Truth: Decodable {
            let keypoints: [Frame]
        }
        let data = try Data(contentsOf: footage.appending(path: "ground_truth/synthetic-netPost.json"))
        return try Dictionary(uniqueKeysWithValues: JSONDecoder().decode(Truth.self, from: data).keypoints[0].points.map {
            ($0.keypoint, CGPoint(x: $0.pixel["x"] ?? 0, y: $0.pixel["y"] ?? 0))
        })
    }
}
