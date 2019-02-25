//
//  CVPixelBuffer+Extension.swift
//  LiveMagicEye
//
//  Created by Klemenz, Oliver on 19.02.19.
//  Copyright © 2019 Klemenz, Oliver. All rights reserved.
//

import AVFoundation
import UIKit

extension CVPixelBuffer {
    
    func clamp() -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
        let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(self), to: UnsafeMutablePointer<Float>.self)
        for y in 0 ..< height {
            for x in 0 ..< width {
                let pixel = floatBuffer[y * width + x]
                floatBuffer[y * width + x] = min(1.0, max(pixel, 0.0))
            }
        }
        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
        return self
    }
    
    func transform(size: CGSize, rotation: CGFloat = 0) -> CIImage? {
        let image = CIImage(cvPixelBuffer: self, options: [:])
        let scale = Float(size.width) / Float(image.extent.width)
        return image.transformed(by: CGAffineTransform(rotationAngle: rotation)).applyingFilter("CIBicubicScaleTransform", parameters: ["inputScale": scale])
    }
}
