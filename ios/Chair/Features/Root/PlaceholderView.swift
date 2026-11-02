//
//  PlaceholderView.swift
//  Chair
//
//  Created by Aaron Musa on 10/31/26.
//

import SwiftUI

import ChairUI

struct PlaceholderView: View {
    let section: AppSection

    var body: some View {
        ContentUnavailableView {
            Label(section.title, systemImage: section.systemImage)
        } description: {
            Text("Coming in a later update")
        }
        .foregroundStyle(Color.chair.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.chair.surface)
        .navigationTitle(section.title)
    }
}

#Preview {
    NavigationStack {
        PlaceholderView(section: .train)
    }
}
