//
//  ViewController.swift
//  MagicEye
//
//  Created by Klemenz, Oliver on 12.01.19.
//  Copyright © 2019 Klemenz, Oliver. All rights reserved.
//

import UIKit
import MetalKit

class ViewController: UIViewController {

    @IBOutlet weak var result: UIImageView!
    @IBOutlet weak var resultMetal: MTKView!
    
    var magicEye: MagicEye!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        magicEye = MagicEye(
            size: UIScreen.main.bounds.size,
            pattern: UIImage(named: "flower"),
            depth: UIImage(named: "depth"))
        magicEye.setupRendering(metalView: resultMetal)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.magicEye.measure {
            _ = self.magicEye.generateFilter()
        }
    }
}
