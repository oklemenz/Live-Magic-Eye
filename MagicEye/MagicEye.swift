//
//  MagicEye.swift
//  MagicEye
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
            depth = nil
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
    var patternCI: CIImage?
    var depthCI: CIImage?

    var magicEyeFilter: MagicEyeFilter?
    var renderer: MetalRenderer?
    var currentDrawableSize: CGSize!
    var resultImage: CIImage?
    var renderResultImage: Bool = false
    
    init(size: CGSize, pattern: UIImage? = nil, depth: UIImage? = nil, kMin: Float = 0.2, kMax: Float = 1.0) {
        self.size = size
        self.pattern = pattern
        self.depth = depth
        self.kMin = kMin
        self.kMax = kMax
        self.p0 = Int(pattern?.size.width ?? 0)
    }
    
    func setupRendering(metalView: MTKView) {
        let device = MTLCreateSystemDefaultDevice()!
        metalView.device = device
        metalView.backgroundColor = UIColor.clear
        metalView.contentScaleFactor = UIScreen.main.nativeScale
        metalView.delegate = self
        renderer = MetalRenderer(metalDevice: device, renderDestination: metalView)
        magicEyeFilter = MagicEyeFilter()
    }
    
    func generateFilter() -> CIImage? {
        resultImage = nil
        guard let pattern = pattern, let depth = depth else {
            return nil
        }
        patternCI = patternCI ?? CIImage(image: pattern.pattern(size: size))
        depthCI = depthCI ?? CIImage(image: depth.resize(size: size))
        var result: CIImage?
        measure {
            if let pattern = patternCI, let depth = depthCI {
                result = magicEyeFilter?.apply(inputImage: pattern, depthImage: depth, p0: p0)
                //registerMagicEyeFilter()
                //pattern.applyingFilter("MagicEye", parameters: ["depthImage": depth, "p0": p0])
            }
        }
        if let result = result {
            renderResultImage = true
            resultImage =  result.transformed(by: CGAffineTransform(scaleX: UIScreen.main.nativeScale, y: UIScreen.main.nativeScale))
        }
        return resultImage
    }
    
    func generateBasic() -> UIImage? {
        guard let pattern = pattern, let depth = depth else {
            return nil
        }
        patternRGBA = pattern.pattern(size: size).rgba()
        depthRGBA = depthRGBA ?? depth.resize(size: size).rgba()
        measure {
            if var pattern = patternRGBA, let depth = depthRGBA {
                pattern.enumerate { (index, x, y, p) in
                    let g = depth[index]!.gray
                    pattern[x + shiftPixel(g), y] = p
                }
            }
        }
        return patternRGBA!.toUIImage()
    }
    
    func shiftPixel(_ g: UInt8) -> Int {
        return Int(Float(p0) * (1 - (Float(g) * (kMax - kMin)) / (kMax * (255 * (1 + kMax) - Float(g) * (kMax - kMin)))))
    }
    
    func measure(fn: () -> ()) {
        let start = NSDate()
        fn()
        let end = NSDate()
        let timeInterval: Double = end.timeIntervalSince(start as Date)
        print("Generation: \(timeInterval) seconds")
    }
}

extension MagicEye: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        currentDrawableSize = size
    }
    
    func draw(in view: MTKView) {
        if renderResultImage {
            if let renderer = renderer, let image = resultImage {
                renderer.update(with: image)
                renderResultImage = false
            }
        }
    }
}
