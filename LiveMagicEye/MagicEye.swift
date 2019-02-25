//
//  MagicEye.swift
//  LiveMagicEye
//
//  Created by Klemenz, Oliver on 18.01.19.
//  Copyright © 2019 Klemenz, Oliver. All rights reserved.
//

import Foundation
import UIKit
import MetalKit
import AVFoundation

class MagicEye : NSObject {
    
    var kMin: Float = 0.2
    var kMax: Float = 1.0
    private var p0: Int = 0
    
    var size: CGSize! {
        didSet {
            pattern = nil
            patternCI = nil
            depth = nil
            depthCI = nil
        }
    }
    var pattern: UIImage? {
        didSet {
            patternRGBA = nil
            patternCI = nil
            p0 = Int(pattern?.size.width ?? 0)
        }
    }
    var depth: UIImage? {
        didSet {
            depthRGBA = nil
            depthCI = nil
        }
    }
    
    var patternRGBA: RGBAImage?
    var depthRGBA: RGBAImage?
    var result: UIImage?
    
    var patternCI: CIImage?
    var depthCI: CIImage?
    var resultCI: CIImage?

    var measure: Bool = false

    static func registerFilter() {
        MagicEyeFilter.register()
    }
    
    init(size: CGSize, pattern: UIImage? = nil, depth: UIImage? = nil, kMin: Float = 0.2, kMax: Float = 1.0) {
        self.size = size
        self.pattern = pattern
        self.depth = depth
        self.kMin = kMin
        self.kMax = kMax
        self.p0 = Int(pattern?.size.width ?? 0)
    }
    
    func generateFilter() -> CIImage? {
        resultCI = nil
        if patternCI == nil, let pattern = pattern {
            patternCI = CIImage(image: pattern.pattern(size: size))
        }
        if depthCI == nil, let depth = depth {
            depthCI = CIImage(image: depth.resize(size: size))
        }
        wrap {
            if p0 > 0, let pattern = patternCI, let depth = depthCI {
                resultCI = pattern.applyingFilter("MagicEye", parameters: ["depthImage": depth, "p0": p0])
            }
        }
        return resultCI
    }
    
    func generatePixel() -> UIImage? {
        result = nil
        guard let pattern = pattern else {
            return nil
        }
        patternRGBA = pattern.pattern(size: size).rgba()
        if depthRGBA == nil, let depth = depth {
            depthRGBA = depth.resize(size: size).rgba()
        }
        wrap {
            if p0 > 0, let pattern = patternRGBA, let depth = depthRGBA {
                pattern.enumerate { (index, x, y, p) in
                    let g = depth[index]!.gray
                    pattern[x + shiftPixel(g), y] = p
                }
            }
        }
        result = patternRGBA!.toUIImage()
        return result
    }
    
    func shiftPixel(_ g: UInt8) -> Int {
        return Int(Float(p0) * (1 - (Float(g) * (kMax - kMin)) / (kMax * (255 * (1 + kMax) - Float(g) * (kMax - kMin)))))
    }
    
    func wrap(fn: () -> ()) {
        if (!measure) {
            fn()
        } else {
            let start = NSDate()
            fn()
            let end = NSDate()
            let timeInterval: Double = end.timeIntervalSince(start as Date)
            print("Generation: \(timeInterval) seconds")
        }
    }
}
