//
//  QRScannerView.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI
import Vision
import VisionKit

struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(
        _: DataScannerViewController,
        context _: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScan: (String) -> Void
        private var didScan = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(
            _: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems _: [RecognizedItem]
        ) {
            guard !didScan else { return }
            for item in addedItems {
                if case let .barcode(code) = item, let payload = code.payloadStringValue {
                    didScan = true
                    onScan(payload)
                    return
                }
            }
        }
    }
}
