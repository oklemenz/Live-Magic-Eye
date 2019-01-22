//
//  CVPixelBuffer+CIImage.swift
//  MagicEye
//
//  Created by Klemenz, Oliver on 18.01.19.
//  Copyright © 2019 Klemenz, Oliver. All rights reserved.
//

import Foundation
import CoreVideo
import CoreImage

extension CVPixelBuffer {
    func transformedImage(targetSize: CGSize, rotationAngle: CGFloat) -> CIImage? {
        let image = CIImage(cvPixelBuffer: self, options: [:])
        let scaleFactor = Float(targetSize.width) / Float(image.extent.width)
        return image.transformed(by: CGAffineTransform(rotationAngle: rotationAngle)).applyingFilter("CIBicubicScaleTransform", parameters: ["inputScale": scaleFactor])
    }
}
