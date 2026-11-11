//
//  SavedCourtMatching.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/12/26.
//

import CoreGraphics
import CoreLocation
import Foundation

public struct CourtLocation: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(
        latitude: Double,
        longitude: Double
    ) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public func distance(to other: CourtLocation) -> Double {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}

public protocol CourtLocating: Sendable {
    func currentLocation() async -> CourtLocation?
}

public enum SavedCourtMatching {
    public static let nearbyRadius = 50.0
    public static let mismatchFraction = 0.03

    public static func nearest(
        _ courts: [SavedCourtRecord],
        to location: CourtLocation
    ) -> SavedCourtRecord? {
        courts
            .compactMap { court -> (SavedCourtRecord, Double)? in
                guard let latitude = court.latitude, let longitude = court.longitude else { return nil }
                return (court, CourtLocation(latitude: latitude, longitude: longitude).distance(to: location))
            }
            .filter { $0.1 <= nearbyRadius }
            .min { $0.1 < $1.1 }?
            .0
    }

    public static func disagreement(
        saved: [CourtKeypoint: CGPoint],
        suggested: [CourtKeypoint: CGPoint],
        frameWidth: Double
    ) -> Double? {
        let shared = Set(saved.keys).intersection(suggested.keys)
        guard !shared.isEmpty, frameWidth > 0 else { return nil }
        return shared.compactMap { keypoint -> Double? in
            guard let a = saved[keypoint], let b = suggested[keypoint] else { return nil }
            return hypot(a.x - b.x, a.y - b.y) / frameWidth
        }
        .max()
    }

    public static func differs(
        saved: [CourtKeypoint: CGPoint],
        suggested: [CourtKeypoint: CGPoint],
        frameWidth: Double
    ) -> Bool {
        (disagreement(saved: saved, suggested: suggested, frameWidth: frameWidth) ?? 0) > mismatchFraction
    }
}

#if os(iOS)
    public final class SystemCourtLocator: NSObject, CourtLocating, CLLocationManagerDelegate, @unchecked Sendable {
        private let manager = CLLocationManager()
        private var pending: CheckedContinuation<CourtLocation?, Never>?
        private var authorizing: CheckedContinuation<Void, Never>?

        override public init() {
            super.init()
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }

        @MainActor
        public func currentLocation() async -> CourtLocation? {
            if manager.authorizationStatus == .notDetermined {
                await withCheckedContinuation { continuation in
                    authorizing = continuation
                    manager.requestWhenInUseAuthorization()
                }
            }
            guard [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus) else { return nil }
            return await withCheckedContinuation { continuation in
                pending = continuation
                manager.requestLocation()
            }
        }

        public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            guard manager.authorizationStatus != .notDetermined else { return }
            authorizing?.resume()
            authorizing = nil
        }

        public func locationManager(
            _: CLLocationManager,
            didUpdateLocations locations: [CLLocation]
        ) {
            let location = locations.last.map { CourtLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude) }
            pending?.resume(returning: location)
            pending = nil
        }

        public func locationManager(
            _: CLLocationManager,
            didFailWithError _: any Error
        ) {
            pending?.resume(returning: nil)
            pending = nil
        }
    }
#endif
