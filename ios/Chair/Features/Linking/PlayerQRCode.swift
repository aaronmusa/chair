//
//  PlayerQRCode.swift
//  Chair
//
//  Created by Aaron Musa on 11/3/26.
//

import CoreImage.CIFilterBuiltins
import SwiftUI

enum PlayerQRCode {
    static func url(for handle: String) -> URL? {
        URL(string: "chair://user/\(handle)")
    }

    static func image(for handle: String) -> UIImage? {
        guard let url = url(for: handle) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
