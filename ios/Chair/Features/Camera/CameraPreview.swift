//
//  CameraPreview.swift
//  Chair
//
//  Created by Aaron Musa on 11/12/26.
//

import AVFoundation
import SwiftUI
import UIKit

import ChairKit

struct FrameMapping {
    let viewSize: CGSize
    let frameSize: CGSize

    var scale: CGFloat {
        min(viewSize.width / max(frameSize.width, 1), viewSize.height / max(frameSize.height, 1))
    }

    var origin: CGPoint {
        CGPoint(x: (viewSize.width - frameSize.width * scale) / 2, y: (viewSize.height - frameSize.height * scale) / 2)
    }

    func toView(_ point: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale)
    }

    func toFrame(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - origin.x) / scale, y: (point.y - origin.y) / scale)
    }
}

struct CameraPreview: View {
    let capture: any CaptureSource
    let still: CGImage?

    var body: some View {
        if let session = capture as? CaptureSession {
            PreviewLayerView(session: session.session)
        } else if let still {
            Image(decorative: still, scale: 1)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Color.black
        }
    }
}

private struct PreviewLayerView: UIViewRepresentable {
    final class LayerView: UIView {
        override static var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer? {
            layer as? AVCaptureVideoPreviewLayer
        }
    }

    let session: AVCaptureSession

    func makeUIView(context _: Context) -> LayerView {
        let view = LayerView()
        view.backgroundColor = .black
        view.previewLayer?.session = session
        view.previewLayer?.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(
        _ view: LayerView,
        context _: Context
    ) {
        view.previewLayer?.session = session
    }
}

extension CourtKeypoint {
    func label(for placement: CameraPlacement) -> String {
        switch placement {
        case .netPost, .chair: netPostLabel
        case .baseline: baselineLabel
        }
    }

    private var netPostLabel: String {
        let side = along == .farBaseline || along == .farService ? "Left" : "Right"
        switch (across, along) {
        case (.doublesRight, _): return "\(side) far corner"
        case (.singlesRight, .farBaseline), (.singlesRight, .nearBaseline): return "\(side) baseline, singles line"
        case (.singlesRight, _): return "\(side) service line, singles line"
        case (.centre, _): return "\(side) service T"
        default: return rawValue
        }
    }

    private var baselineLabel: String {
        let end = along == .farBaseline || along == .farService ? "Far" : "Near"
        let side = across == .doublesLeft || across == .singlesLeft ? "left" : across == .centre ? "centre" : "right"
        return "\(end) \(side) \(along == .farBaseline || along == .nearBaseline ? "corner" : "service point")"
    }
}
