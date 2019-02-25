//
//  UIImage+RGBA.swift
//  LiveMagicEye
//
//  Created by Klemenz, Oliver on 12.01.19.
//  Copyright © 2019 Klemenz, Oliver. All rights reserved.
//

import Foundation
import UIKit

extension UIImage {
    
    func rgba() -> RGBAImage {
        return RGBAImage(image: self)!
    }
    
    func pattern(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            self.drawAsPattern(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
    }
    
    func resize(size: CGSize) -> UIImage {
        let widthRatio = size.width / self.size.width
        let heightRatio = size.height / self.size.height
        let newSize = widthRatio > heightRatio ?
            CGSize(width: self.size.width * widthRatio, height: self.size.height * widthRatio) :
            CGSize(width: self.size.width * heightRatio,  height: self.size.height * heightRatio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            self.draw(in: rect)
        }
    }
}

public struct Pixel {
    
    public var value: UInt32
    
    public var red: UInt8 {
        get {
            return UInt8(value & 0xFF)
        }
        set {
            value = UInt32(newValue) | (value & 0xFFFFFF00)
        }
    }
    
    public var green: UInt8 {
        get {
            return UInt8((value >> 8) & 0xFF)
        }
        set {
            value = (UInt32(newValue) << 8) | (value & 0xFFFF00FF)
        }
    }
    
    public var blue: UInt8 {
        get {
            return UInt8((value >> 16) & 0xFF)
        }
        set {
            value = (UInt32(newValue) << 16) | (value & 0xFF00FFFF)
        }
    }
    
    public var gray: UInt8 {
        get {
            return UInt8(0.21 * Float(red) + 0.72 * Float(green) + 0.07 * Float(blue))
        }
        set {
            red = newValue
            green = newValue
            blue = newValue
        }
    }
    
    public var alpha: UInt8 {
        get {
            return UInt8((value >> 24) & 0xFF)
        }
        set {
            value = (UInt32(newValue) << 24) | (value & 0x00FFFFFF)
        }
    }
}

public class RGBAImage {
    public var pixels: UnsafeMutableBufferPointer<Pixel>
    
    public var width: Int
    public var height: Int
    
    public init?(image: UIImage) {
        guard let cgImage = image.cgImage else { return nil }
        
        // Redraw image for correct pixel format
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        
        width = Int(image.size.width)
        height = Int(image.size.height)
        let bytesPerRow = width * 4
        
        let imageData = UnsafeMutablePointer<Pixel>.allocate(capacity: width * height)
        
        guard let imageContext = CGContext(data: imageData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else { return nil }
        imageContext.draw(cgImage, in: CGRect(origin: .zero, size: image.size))
        
        pixels = UnsafeMutableBufferPointer<Pixel>(start: imageData, count: width * height)
    }
    
    deinit {
        pixels.baseAddress?.deinitialize(count: pixels.count)
        pixels.baseAddress?.deallocate()
    }
    
    public func toUIImage() -> UIImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
        bitmapInfo |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        
        let bytesPerRow = width * 4
        
        let imageContext = CGContext(data: pixels.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo, releaseCallback: nil, releaseInfo: nil)
        
        guard let cgImage = imageContext!.makeImage() else {return nil}
        let image = UIImage(cgImage: cgImage)
        
        return image
    }
    
    public func pixel(x : Int, y : Int) -> Pixel? {
        guard x >= 0 && x < width && y >= 0 && y < height else {
            return nil
        }
        return pixel(index: y * width + x)
    }
    
    public func pixel(index : Int) -> Pixel? {
        return pixels[index]
    }
    
    public func pixel(x : Int, y : Int, p: Pixel) {
        guard x >= 0 && x < width && y >= 0 && y < height else {
            return
        }
        pixel(index: y * width + x, p: p)
    }
    
    public func pixel(index : Int, p: Pixel) {
        pixels[index] = p
    }
    
    subscript(index: Int) -> Pixel? {
        get {
            return pixel(index: index)
        }
        set(newValue) {
            pixel(index: index, p: newValue!)
        }
    }
    
    subscript(x: Int, y: Int) -> Pixel? {
        get {
            return pixel(x: x, y: y)
        }
        set(newValue) {
            pixel(x: x, y: y, p: newValue!)
        }
    }
    
    public func enumerate( process : (Int, Int, Int, Pixel) -> Void) {
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                process(index, x, y, pixels[index])
            }
        }
    }
    
    public func reverseEnumerate( process : (Int, Int, Int, Pixel) -> Void) {
        for y in (0..<height).reversed() {
            for x in (0..<width).reversed() {
                let index = y * width + x
                process(index, x, y, pixels[index])
            }
        }
    }
}
