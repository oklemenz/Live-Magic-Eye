//
//  CIImage+Extension.swift
//  LiveMagicEye
//
//  Created by Klemenz, Oliver on 20.02.19.
//  Copyright © 2019 Klemenz, Oliver. All rights reserved.
//

import Foundation
import CoreImage

extension CIImage {
    
    var cw90: CIImage {
        get {
            return transformed(by: CGAffineTransform(rotationAngle: .pi/2))
        }
    }
    
    var ccw90: CIImage {
        get {
            return transformed(by: CGAffineTransform(rotationAngle: -.pi/2))
        }
    }
    
    func scale(_ size: CGSize) -> CIImage {
        let scaleFactorWidth = Float(size.width) / Float(extent.width)
        let scaleFactorHeight = Float(size.height) / Float(extent.height)
        let scaleFactor = max(scaleFactorWidth, scaleFactorHeight)
        return applyingFilter("CIBicubicScaleTransform", parameters: ["inputScale": scaleFactor])
    }
    
    func alphaMatte() -> CIImage {
        return clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 0.5])
            .applyingFilter("CIGammaAdjust", parameters: ["inputPower": 0.5])
            .cropped(to: extent)        
    }
    
    func crop(rect: CGRect) -> CIImage {
        return applyingFilter("CICrop", parameters: ["inputRectangle": CIVector(cgRect: rect)])
    }
    
    func crop(size: CGSize) -> CIImage {
        return applyingFilter("CICrop", parameters: ["inputRectangle": CIVector(cgRect: CGRect(x: 0, y: 0, width: size.width, height: size.height))])
    }
    
    func normalize() -> CIImage {
        return transformed(by: CGAffineTransform(translationX: -extent.origin.x, y: -extent.origin.y))
    }
}
