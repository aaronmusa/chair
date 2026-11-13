//
//  AvatarView.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairUI

struct AvatarView: View {
    let name: String
    var size: CGFloat = 72

    var body: some View {
        Text(Self.initials(for: name))
            .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.chair.onAccent)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.chair.accent))
            .accessibilityHidden(true)
    }

    static func initials(for name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace).prefix(2)
        let letters = words.compactMap(\.first).map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }
}
