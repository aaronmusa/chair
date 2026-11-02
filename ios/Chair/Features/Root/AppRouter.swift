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
}

@MainActor
@Observable
final class AppRouter {
    var selectedSection: AppSection
    var presentedMatch: PresentedMatch?
    var summaryMatchID: UUID?
    var playPath: [PlayDestination] = []

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

    func startSession(for matchID: UUID) {
        playPath = []
        presentSession(for: matchID)
    }

    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let matchID = Self.matchID(in: url) else { return false }
        selectedSection = .matches
        summaryMatchID = matchID
        return true
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
