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
        var owned: [OwnedSubscription] = []
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            owned.append(OwnedSubscription(
                productID: transaction.productID,
                expires: transaction.expirationDate,
                isRevoked: transaction.revocationDate != nil,
                isIntroductoryOffer: transaction.offer?.type == .introductory
            ))
        }
        return Self.entitlement(from: owned)
    }

    public static func entitlement(from owned: [OwnedSubscription]) -> Entitlement {
        owned
            .filter { productIDs.contains($0.productID) && !$0.isRevoked }
            .compactMap { subscription -> Entitlement? in
                guard let expires = subscription.expires else { return nil }
                return subscription.isIntroductoryOffer ? .trial(expires: expires) : .pro(expires: expires)
            }
            .max { rank($0) < rank($1) } ?? .free
    }

    public func isTrialAvailable() async -> Bool {
        guard let product = try? await Product.products(for: [Self.productIDs[0]]).first,
              let subscription = product.subscription else { return false }
        return await subscription.isEligibleForIntroOffer
    }

    public func products() async throws -> [SubscriptionProduct] {
        try await Product.products(for: Self.productIDs)
            .sorted { $0.price < $1.price }
            .map { SubscriptionProduct(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice) }
    }

    public func purchase(_ productID: String) async throws -> Entitlement {
        guard let product = try await Product.products(for: [productID]).first else {
            throw SubscriptionError.productNotFound(productID)
        }
        switch try await product.purchase() {
        case let .success(.verified(transaction)):
            await transaction.finish()
            return await entitlement()
        case .success(.unverified), .pending, .userCancelled:
            return await entitlement()
        @unknown default:
            return await entitlement()
        }
    }

    public func restore() async throws -> Entitlement {
        try await AppStore.sync()
        return await entitlement()
    }

    private static func rank(_ entitlement: Entitlement) -> Int {
        switch entitlement {
        case .free: 0
        case .trial: 1
        case .pro: 2
        }
    }
}

public struct OwnedSubscription: Equatable, Sendable {
    public let productID: String
    public let expires: Date?
    public let isRevoked: Bool
    public let isIntroductoryOffer: Bool

    public init(
        productID: String,
        expires: Date?,
        isRevoked: Bool = false,
        isIntroductoryOffer: Bool
    ) {
        self.productID = productID
        self.expires = expires
        self.isRevoked = isRevoked
        self.isIntroductoryOffer = isIntroductoryOffer
    }
}
