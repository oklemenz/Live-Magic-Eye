//
//  ViewController.swift
//  LiveMagicEye
//
//  Created by Klemenz, Oliver on 19.02.19.
//  Copyright © 2019 Klemenz, Oliver. All rights reserved.
//

import UIKit
import MetalKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate, MTKViewDelegate {
        
    @IBOutlet weak var preview: UIImageView!
    @IBOutlet weak var previewMetal: MTKView!
    
    let session = AVCaptureSession()
    let dataOutputQueue = DispatchQueue(label: "de.oklemenz.LiveMagicEye.Queue",
                                        qos: .userInitiated,
                                        attributes: [],
                                        autoreleaseFrequency: .workItem)
    var ciContext: CIContext?
    var renderer: MetalRenderer!
    var currentDrawableSize: CGSize!
    
    let patternImage = "flower"
    var depthMap: CIImage?
    var magicEye: MagicEye!

    let factor: CGFloat = 0.5
    let throttleBias = 100
    var throttle = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(thermalStateChanged),
                                               name: ProcessInfo.thermalStateDidChangeNotification, object: nil)

        setupMagicEye()
        setupDepthCamera()
        //setupMetal()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }

    func setupMagicEye() {
        let size = CGSize(width: UIScreen.main.bounds.size.width * factor, height: UIScreen.main.bounds.size.height * factor)
        magicEye = MagicEye(size: size, pattern: UIImage(named: patternImage))
    }

    func setupMetal() {
        let device = MTLCreateSystemDefaultDevice()!
        previewMetal.device = device
        previewMetal.backgroundColor = UIColor.clear
        previewMetal.delegate = self
        renderer = MetalRenderer(metalDevice: device, renderDestination: previewMetal)
        currentDrawableSize = previewMetal.currentDrawable!.layer.drawableSize
    }
    
    func generate(_ depthMap: CIImage) {
        self.depthMap = depthMap
    }
    
    func update() {
        let now = currentTimeInMilliSeconds()
        guard throttle == 0 || now - throttle >= throttleBias, let depthMap = depthMap else {
            return
        }
        throttle = now
        
        updateImagePixel(depthMap)
    }
    
    func updateImagePixel(_ depthMap: CIImage) {
        magicEye.depth = UIImage(ciImage: depthMap.alphaMatte().cw90.scale(magicEye.size).normalize().crop(size: magicEye.size))
        self.preview.image = magicEye.generatePixel()
    }
    
    func updateImageFilter(_ depthMap: CIImage) {
        magicEye.depthCI = depthMap.alphaMatte().cw90.scale(magicEye.size).normalize().crop(size: magicEye.size)
        if let result = magicEye.generateFilter() {
            if ciContext == nil {
                ciContext = CIContext()
            }
            self.preview.image = UIImage(cgImage: ciContext!.createCGImage(result, from: result.extent)!)
        }
    }

    func updateMetalFilter(_ depthMap: CIImage) {
        magicEye.depthCI = depthMap.alphaMatte().cw90.scale(currentDrawableSize).normalize().crop(size: magicEye.size)
        _ = magicEye.generateFilter()
    }
    
    func wait(time: Double, call: (() -> ())?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + time) {
            if let call = call {
                call()
            }
        }
    }
    
    func currentTimeInMilliSeconds() -> Int {
        return Int(Date().timeIntervalSince1970 * 1000)
    }
    
    // MARK: - Setup Depth Camera
    func setupDepthCamera() {
        var device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTrueDepthCamera],
            mediaType: .video,
            position: .back).devices.first
        if device === nil {
            device = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInDualCamera],
                mediaType: .video,
                position: .back).devices.first
        }
        guard let camera = device else {
            alertDeviceNotSupported()
            return
        }
        
        session.sessionPreset = .photo
        
        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)
            session.addInput(cameraInput)
        } catch {
            fatalError(error.localizedDescription)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        session.addOutput(videoOutput)
        
        let videoConnection = videoOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
        
        let depthOutput = AVCaptureDepthDataOutput()
        depthOutput.setDelegate(self, callbackQueue: dataOutputQueue)
        depthOutput.isFilteringEnabled = true
        
        session.addOutput(depthOutput)
        
        let depthConnection = depthOutput.connection(with: .depthData)
        depthConnection?.videoOrientation = .portrait
        
        do {
            try camera.lockForConfiguration()
            if let frameDuration = camera.activeDepthDataFormat?.videoSupportedFrameRateRanges.first?.minFrameDuration {
                camera.activeVideoMinFrameDuration = frameDuration
            }
            camera.unlockForConfiguration()
        } catch {
            fatalError(error.localizedDescription)
        }
        
        session.startRunning()
    }
    
    // MARK: - Capture Depth Data Delegate Methods (AVCaptureDepthDataOutputDelegate)
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        var convertedDepth: AVDepthData
        if depthData.depthDataType != kCVPixelFormatType_DisparityFloat32 {
            convertedDepth = depthData.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
        } else {
            convertedDepth = depthData
        }
        let depthMap = CIImage(cvPixelBuffer: convertedDepth.depthDataMap.clamp())
        DispatchQueue.main.async { [weak self] in
            self?.generate(depthMap)
        }
    }
    
    // MARK: - Capture Video Data Delegate Methods (AVCaptureVideoDataOutputSampleBufferDelegate)
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async { [weak self] in
            self?.update()
        }
    }
    
    // MARK: - Metal
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        currentDrawableSize = size
    }
    
    func draw(in view: MTKView) {
        if let image = magicEye.resultCI {
            renderer.update(with: image.scale(currentDrawableSize))
        }
    }
    
    // MARK: - Thermal State Change
    @objc
    func thermalStateChanged(notification: NSNotification) {
        if let processInfo = notification.object as? ProcessInfo {
            showThermalState(state: processInfo.thermalState)
        }
    }
    
    func showThermalState(state: ProcessInfo.ThermalState) {
        DispatchQueue.main.async {
            var thermalStateString = ""
            if state == .nominal {
                thermalStateString = "nominal"
            } else if state == .fair {
                thermalStateString = "fair"
            } else if state == .serious {
                thermalStateString = "serious"
            } else if state == .critical {
                thermalStateString = "critical"
            }
            if (state == .serious || state == .critical) {
                let alertController = UIAlertController(title: "Warning!", message: "Thermal state is \(thermalStateString). You may leave the app, that the thermal state of the device can recover", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }
    
    func alertDeviceNotSupported() {
        let alertController = UIAlertController(title: "Device is not supported", message: "No depth video camera available.", preferredStyle: .alert)
        present(alertController, animated: true, completion: nil)
    }
}
