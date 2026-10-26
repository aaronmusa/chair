//
//  EntitlementMappingTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

final class EntitlementMappingTests: XCTestCase {
    private let trialEnds = Fixtures.matchDay.addingTimeInterval(7 * 24 * 60 * 60)
    private let yearEnds = Fixtures.matchDay.addingTimeInterval(365 * 24 * 60 * 60)

    func testNoSubscriptionIsFree() {
        XCTAssertEqual(StoreKitSubscriptionService.entitlement(from: []), .free)
    }

    func testAnIntroductoryOfferIsATrialUntilItEnds() {
        let owned = [OwnedSubscription(productID: "chair.pro.monthly", expires: trialEnds, isIntroductoryOffer: true)]

        XCTAssertEqual(StoreKitSubscriptionService.entitlement(from: owned), .trial(expires: trialEnds))
    }

    func testAPaidPeriodIsPro() {
        let owned = [OwnedSubscription(productID: "chair.pro.yearly", expires: yearEnds, isIntroductoryOffer: false)]

        XCTAssertEqual(StoreKitSubscriptionService.entitlement(from: owned), .pro(expires: yearEnds))
    }

    func testProOutranksATrial() {
        let owned = [
            OwnedSubscription(productID: "chair.pro.monthly", expires: trialEnds, isIntroductoryOffer: true),
            OwnedSubscription(productID: "chair.pro.yearly", expires: yearEnds, isIntroductoryOffer: false),
        ]

        XCTAssertEqual(StoreKitSubscriptionService.entitlement(from: owned), .pro(expires: yearEnds))
    }

    func testRevokedAndUnknownProductsAreIgnored() {
        let owned = [
            OwnedSubscription(productID: "chair.pro.yearly", expires: yearEnds, isRevoked: true, isIntroductoryOffer: false),
            OwnedSubscription(productID: "someone.else.pro", expires: yearEnds, isIntroductoryOffer: false),
        ]

        XCTAssertEqual(StoreKitSubscriptionService.entitlement(from: owned), .free)
    }

    func testFreeTierCapIsTwentyMatches() {
        XCTAssertEqual(FreeTier.maxMatches, 20)
    }
}
