//
//  CourtThumbnails.swift
//  Chair
//
//  Created by Aaron Musa on 11/12/26.
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum CourtThumbnails {
    static let width = 320

    static var folder: URL {
        URL.applicationSupportDirectory.appending(path: "Courts", directoryHint: .isDirectory)
    }

    static func url(for file: String) -> URL {
        folder.appending(path: file)
    }

    static func save(
        _ image: CGImage?,
        id: UUID
    ) -> String? {
        guard let image, let scaled = scale(image) else { return nil }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = "\(id.uuidString).jpg"
        guard let destination = CGImageDestinationCreateWithURL(url(for: file) as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, scaled, [kCGImageDestinationLossyCompressionQuality: 0.7] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? file : nil
    }

    static func remove(_ file: String?) {
        guard let file else { return }
        try? FileManager.default.removeItem(at: url(for: file))
    }

    private static func scale(_ image: CGImage) -> CGImage? {
        let height = max(1, image.height * width / max(image.width, 1))
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceGray(),
            bitmapInfo: image.bitmapInfo.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
