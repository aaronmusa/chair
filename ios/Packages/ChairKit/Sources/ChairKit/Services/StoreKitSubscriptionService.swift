//
//  StoreKitSubscriptionService.swift
//  ChairKit
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import StoreKit

public struct StoreKitSubscriptionService: SubscriptionService {
    public static let productIDs = ["chair.pro.monthly", "chair.pro.yearly"]

    public init() {}

    public func entitlement() async -> Entitlement {
        .free
    }

    public func isTrialAvailable() async -> Bool {
        false
    }

    public func products() async throws -> [SubscriptionProduct] {
        try await Product.products(for: Self.productIDs)
            .sorted { $0.price < $1.price }
            .map { SubscriptionProduct(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice) }
    }

    public func purchase(_: String) async throws -> Entitlement {
        throw SubscriptionError.purchaseUnavailable
    }

    public func restore() async throws -> Entitlement {
        .free
    }
}
