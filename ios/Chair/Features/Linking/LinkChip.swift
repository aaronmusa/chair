//
//  LinkChip.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct LinkChip: View {
    let status: LinkStatus

    var body: some View {
        if let title {
            Text(title)
                .chairFont(.caption)
                .padding(.horizontal, Spacing.chair.xs)
                .padding(.vertical, Spacing.chair.xxs)
                .foregroundStyle(color)
                .background(Capsule().fill(color.opacity(0.14)))
                .accessibilityLabel("Link \(title.lowercased())")
        }
    }

    private var title: String? {
        switch status {
        case .none: nil
        case .pending: "Pending"
        case .accepted: "Linked"
        case .declined: "Declined"
        }
    }

    private var color: Color {
        switch status {
        case .accepted: Color.chair.success
        case .declined: Color.chair.danger
        case .pending, .none: Color.chair.inkSecondary
        }
    }
}
