//
//  ViewController.swift
//  MagicEye
//
//  Created by Klemenz, Oliver on 12.01.19.
//  Copyright © 2019 Klemenz, Oliver. All rights reserved.
//

import UIKit

class ViewController: UIViewController {


    @IBOutlet weak var result: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let pattern = UIImage(named: "tree")!
        let depth = UIImage(named: "depth")!
        result.image = generateBasic3D(size: UIScreen.main.bounds.size,
                                       patternImage: pattern,
                                       depthImage: depth)
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
        pattern.enumerate { (index, x, y, p) in
            let g = depth[index]!.gray
            pattern[x + shiftPixel(g), y] = p
        }
        return pattern.toUIImage()!
    }
    
    func generateAdvanced3D(size: CGSize, patternImage: UIImage, depthImage: UIImage) -> UIImage {
        var pattern = patternImage.pattern(size: size).rgba()
        let depth = depthImage.resize(size: size).rgba()
        // https://github.com/nitin-nizhawan/stereogram.js/blob/master/stereogram.js
        // https://github.com/dgtized/autostereogram/blob/gh-pages/autostereogram.js
        return patternImage
    }
}
