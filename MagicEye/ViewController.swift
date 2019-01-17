//
//  ViewController.swift
//  MagicEye
//
//  Created by Klemenz, Oliver on 12.01.19.
//  Copyright © 2019 Klemenz, Oliver. All rights reserved.
//

import UIKit
import MetalKit
import AVFoundation

class ViewController: UIViewController {


    @IBOutlet weak var result: UIImageView!
    
    @IBOutlet weak var resultMetal: MTKView!
    var renderer: MetalRenderer!
    var resultImage: CIImage?
    var currentDrawableSize: CGSize!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        filter3DSetup()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let pattern = UIImage(named: "tree")!
        let depth = UIImage(named: "depth")!
        
        result.image = nil
        
        DispatchQueue.main.async {
            self.measure {
               self.filter3D(pattern: pattern, depth: depth)
            }
        }
    }
    
    func basic3D(pattern: UIImage, depth: UIImage) {
        self.result.image = self.generateBasic3D(
            size: UIScreen.main.bounds.size,
            patternImage: pattern,
            depthImage: depth)
    }
    
    func filter3DSetup() {
        let device = MTLCreateSystemDefaultDevice()!
        resultMetal.device = device
        resultMetal.backgroundColor = UIColor.clear
        resultMetal.contentScaleFactor = UIScreen.main.nativeScale
        resultMetal.delegate = self
        renderer = MetalRenderer(metalDevice: device, renderDestination: resultMetal)
    }
    
    func filter3D(pattern: UIImage, depth: UIImage) {
        resultImage = self.generateFilter3D(
            size: UIScreen.main.bounds.size,
            patternImage: pattern,
            depthImage: depth).transformed(by: CGAffineTransform(scaleX: UIScreen.main.nativeScale, y: UIScreen.main.nativeScale))
    }
    
    func generateBasic3D(size: CGSize, patternImage: UIImage, depthImage: UIImage) -> UIImage {
        let kMin: Float = 0.2
        let kMax: Float = 1.0
        let p0: Int = Int(patternImage.size.width)
        
        func shiftPixel(_ g: UInt8) -> Int {
            return Int(Float(p0) * (1 - (Float(g) * (kMax - kMin)) / (kMax * (255 * (1 + kMax) - Float(g) * (kMax - kMin)))))
        }

        var pattern = patternImage.pattern(size: size).rgba()
        let depth = depthImage.resize(size: size).rgba()
        
        measure {
            pattern.enumerate { (index, x, y, p) in
                let g = depth[index]!.gray
                pattern[x + shiftPixel(g), y] = p
            }
        }

        return pattern.toUIImage()!
    }
    
    func generateFilter3D(size: CGSize, patternImage: UIImage, depthImage: UIImage) -> CIImage {
        let p0: Int = Int(patternImage.size.width)
        
        let pattern = CIImage(image: patternImage.pattern(size: size))
        let depth = CIImage(image: depthImage.resize(size: size))
        var result: CIImage? = nil
        registerMagicEyeFilter()
        measure {
            result = pattern!.applyingFilter("MagicEye", parameters: ["depthImage": depth!, "p0": p0])
        }
        return result!
    }
    
    func measure(fn: () -> ()) {
        let start = NSDate()
        fn()
        let end = NSDate()
        let timeInterval: Double = end.timeIntervalSince(start as Date)
        print("Execution: \(timeInterval) seconds")
    }
}

extension ViewController: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        currentDrawableSize = size
    }
    
    func draw(in view: MTKView) {
        if let image = resultImage {
            renderer.update(with: image)
        }
    }
}
