//
//  RootView.swift
//  Chair
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI

import ChairUI

struct RootView: View {
    #if DEBUG
        @State private var isShowingGallery = ProcessInfo.processInfo.arguments.contains("-ShowGallery")
    #endif

    var body: some View {
        #if DEBUG
            ExampleView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 2, perform: handleShowGallery())
                .fullScreenCover(isPresented: $isShowingGallery) {
                    GalleryView()
                }
        #else
            ExampleView()
        #endif
    }

    #if DEBUG
        private func handleShowGallery() -> () -> Void {
            { isShowingGallery = true }
        }
    #endif
}
