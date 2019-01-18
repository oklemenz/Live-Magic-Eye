//
//  MagicEyeFilter.swift
//  MagicEye
//
//  Created by Klemenz, Oliver on 15.01.19.
//  Copyright © 2019 Klemenz, Oliver. All rights reserved.
//

import Foundation
import CoreImage

class MagicEyeFilter : CIFilter {
    
    static func KernelRoutine(p0: Int) -> String {
        return """
        /*
        A Core Image kernel routine that computes a magic eye effect.
        The code looks up the source pixel in the sampler and then shifts pixel by depth pixel information.
        */
        
        kernel vec4 kernelFunction(sampler image, sampler depth, float kMin, float kMax) {
            // destination coordinate
            vec2 dc = destCoord();
            int x = int(dc.x);
            int y = int(dc.y);
            // row calculations (two pattern sizes, always swapped)
            vec3 row[2 * \(p0)];
            // n patterns need to be calculated to reach dest x
            int n = x / \(p0);
            // relative destination coordinate in pattern
            int dx = x - \(p0) * n;
            // iterate each pattern index repeat
            for (int j = 0; j <= n; j++) {
                if (j == 0) {
                    // init first half of row from source image
                    for (int i = 0; i < \(p0); i++) {
                        row[i] = sample(image, samplerTransform(image, vec2(i, y))).rgb;
                    }
                } else {
                    // copy second half of row to first half of row
                    for (int i = 0; i < \(p0); i++) {
                        row[i] = row[\(p0) + i];
                    }
                }
                // init second half of row from source image at next pattern index
                for (int i = 0; i < \(p0); i++) {
                    // get image pixel at absolute position
                    row[\(p0) + i] = sample(image, samplerTransform(image, vec2(i + (j+1) * \(p0), y))).rgb;
                }
                // calculate shift of magic eye effect
                for (int i = 0; i < \(p0); i++) {
                    // get depth pixel at absolute position
                    vec3 depthPixel = sample(depth, samplerTransform(depth, vec2(i + j * \(p0), y))).rgb;
                    float g = 255 * clamp(depthPixel.r, 0.0, 1.0);
                    // magic eye formula
                    int p = int(\(p0) * (1 - (g * (kMax - kMin)) / (kMax * (255 * (1 + kMax) - g * (kMax - kMin)))));
                    row[i + p] = row[i];
                }
            }
            return vec4(row[dx], 1.0); // sample(image, samplerCoord(image));
        }
        """
    }

    private var kernel: CIKernel?
    
    @objc dynamic var inputImage: CIImage?
    @objc dynamic var depthImage: CIImage?
    @objc dynamic var kMin: CGFloat = 0.2
    @objc dynamic var kMax: CGFloat = 1.0
    @objc dynamic var p0: Int = 0 {
        didSet {
            kernel = nil
        }
    }

    override var outputImage: CIImage! {
        guard
            let inputImage = inputImage,
            let depthImage = depthImage
        else {
            return nil
        }
        let extent = inputImage.extent
        if kernel == nil {
            kernel = CIKernel(source: MagicEyeFilter.KernelRoutine(p0: p0))
        }
        let magicEye = kernel?.apply(
            extent: extent,
            roiCallback: { (index, rect) in
                return rect
            },
            arguments: [inputImage, depthImage, kMin, kMax])
        return magicEye!.cropped(to: extent)
    }
    
    func apply(inputImage: CIImage, depthImage: CIImage, p0: Int, kMin: CGFloat = 0.2, kMax: CGFloat = 1.0) -> CIImage? {
        setValue(inputImage, forKey: "inputImage")
        setValue(depthImage, forKey: "depthImage")
        setValue(p0, forKey: "p0")
        setValue(kMin, forKey: "kMin")
        setValue(kMax, forKey: "kMax")
        return outputImage
    }
}

class FilterVendor: NSObject, CIFilterConstructor {

    func filter(withName name: String) -> CIFilter? {
        switch name {
        case "MagicEye":
            return MagicEyeFilter()
        default:
            return nil
        }
    }
}

func registerMagicEyeFilter() {
    CIFilter.registerName("MagicEye", constructor: FilterVendor(), classAttributes: [kCIAttributeFilterName: "MagicEye"])
}
