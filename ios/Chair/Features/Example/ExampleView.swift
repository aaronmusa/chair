//
//  ExampleView.swift
//  Chair
//
//  Created by Aaron Musa on 10/26/26.
//

import SwiftUI

struct ExampleView: View {
    @State private var viewModel = ExampleViewModel()

    var body: some View {
        Button(viewModel.title, action: viewModel.tap)
            .font(.largeTitle.bold())
    }
}

#Preview {
    ExampleView()
}
