//
//  StoreKitSubscriptionServiceTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import StoreKit
import StoreKitTest
import UIKit
import XCTest

import ChairKit

final class StoreKitSubscriptionServiceTests: XCTestCase {
    private nonisolated(unsafe) var session: SKTestSession?

    override func setUp() async throws {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        self.session = session
    }

    override func tearDown() {
        session?.clearTransactions()
        session = nil
    }

    func testBuyingMonthlyStartsASevenDayTrial() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CHAIR_STOREKIT_PURCHASE"] == "1",
            "The purchase is killed outside Xcode (#13); set CHAIR_STOREKIT_PURCHASE=1 in the scheme's Test environment to run it."
        )
        let service = StoreKitSubscriptionService()
        let startsFree = try await withTimeout { await service.entitlement() }
        XCTAssertEqual(startsFree, .free)
        let trialBefore = try await withTimeout { await service.isTrialAvailable() }
        XCTAssertTrue(trialBefore)
        let purchasedAt = Date()

        let result = try await withTimeout { try await Self.buyInHostScene("chair.pro.monthly") }
        guard case .success(.verified) = result else {
            return XCTFail("purchase did not succeed: \(result)")
        }
        let entitlement = try await withTimeout { await service.entitlement() }

        guard case let .trial(expires) = entitlement else {
            return XCTFail("expected a trial, got \(entitlement)")
        }
        XCTAssertEqual(expires.timeIntervalSince(purchasedAt), 7 * 24 * 60 * 60, accuracy: 120)
        let trialAfter = await service.isTrialAvailable()
        XCTAssertFalse(trialAfter)
    }

    @MainActor
    private static func buyInHostScene(_ productID: String) async throws -> Product.PurchaseResult {
        let products = try await Product.products(for: [productID])
        let product = try XCTUnwrap(products.first)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        return try await product.purchase(confirmIn: scene)
    }

    func testBothProductsLoadCheapestFirst() async throws {
        let products = try await withTimeout { try await StoreKitSubscriptionService().products() }

        XCTAssertEqual(products.map(\.id), ["chair.pro.monthly", "chair.pro.yearly"])
    }
}

private struct StoreKitTimedOut: Error {}

private func withTimeout<T: Sendable>(
    seconds: Double = 30,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw StoreKitTimedOut()
        }
        let first = try await group.next()!
        group.cancelAll()
        return first
    }
}
