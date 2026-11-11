//
//  AppRouter.swift
//  Chair
//
//  Created by Aaron Musa on 10/31/26.
//

import Foundation
import Observation
import SwiftUI

struct PresentedMatch: Identifiable, Hashable {
    let id: UUID
}

enum PlayDestination: Hashable {
    case newMatch
    case placement(UUID)
    case calibration(UUID)
}

enum PendingRoute: Equatable {
    case newMatch
}

@MainActor
@Observable
final class AppRouter {
    var selectedSection: AppSection
    var presentedMatch: PresentedMatch?
    var summaryMatchID: UUID?
    var playPath: [PlayDestination] = []
    var isPickingOpponent = false
    var pickedHandle: String?
    var publicProfileHandle: String?
    var pendingRoute: PendingRoute?

    init(
        selectedSection: AppSection = .play,
        presentedMatch: PresentedMatch? = nil
    ) {
        self.selectedSection = selectedSection
        self.presentedMatch = presentedMatch
    }

    func presentSession(for matchID: UUID) {
        presentedMatch = PresentedMatch(id: matchID)
    }

    func showNewMatch() {
        selectedSection = .play
        playPath = [.newMatch]
    }

    func applyPendingRoute() {
        guard let route = pendingRoute else { return }
        pendingRoute = nil
        switch route {
        case .newMatch:
            guard presentedMatch == nil else { return }
            showNewMatch()
        }
    }

    func openMatch(
        _ matchID: UUID,
        isInProgress: Bool
    ) {
        if isInProgress {
            presentSession(for: matchID)
        } else {
            summaryMatchID = matchID
        }
    }

    func showPlacement(for matchID: UUID) {
        playPath.append(.placement(matchID))
    }

    func showCalibration(for matchID: UUID) {
        playPath.append(.calibration(matchID))
    }

    func startSession(for matchID: UUID) {
        playPath = []
        presentSession(for: matchID)
    }

    @discardableResult
    func handle(_ url: URL) -> Bool {
        if let handle = Self.userHandle(in: url) {
            if isPickingOpponent {
                pickedHandle = handle
            } else {
                publicProfileHandle = handle
            }
            return true
        }
        guard let matchID = Self.matchID(in: url) else { return false }
        selectedSection = .matches
        summaryMatchID = matchID
        return true
    }

    static func userHandle(in url: URL) -> String? {
        guard url.scheme == "chair", url.host() == "user" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 1, parts[0].wholeMatch(of: /[A-Za-z0-9_]{3,20}/) != nil else { return nil }
        return parts[0].lowercased()
    }

    static func matchID(in url: URL) -> UUID? {
        guard url.scheme == "chair", url.host() == "match" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 1 else { return nil }
        return UUID(uuidString: parts[0])
    }
}

extension EnvironmentValues {
    @Entry var appRouter = AppRouter()
}
