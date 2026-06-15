import Vision
import CoreImage
import AppKit

class ImageProcessor {
    
    // CoreImage Fast Background Removal using VNGeneratePersonSegmentationRequest
    static func removeBackground(image: CIImage) -> CIImage? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first else {
                return nil
            }
            
            let maskBuffer = observation.pixelBuffer
            var maskImage = CIImage(cvPixelBuffer: maskBuffer)
            
            // Resize the segmentation mask to fit the source image
            let scaleX = image.extent.width / maskImage.extent.width
            let scaleY = image.extent.height / maskImage.extent.height
            maskImage = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            
            // Create a clean white background of the same size
            let whiteBg = CIImage.white.cropped(to: image.extent)
            
            // Blend foreground image with white background using the mask
            let blendFilter = CIFilter(name: "CIBlendWithMask")
            blendFilter?.setValue(image, forKey: kCIInputImageKey)
            blendFilter?.setValue(whiteBg, forKey: kCIInputBackgroundImageKey)
            blendFilter?.setValue(maskImage, forKey: kCIInputMaskImageKey)
            
            return blendFilter?.outputImage
        } catch {
            print("Segmentation request failed: \(error)")
            return nil
        }
    }
    
    // CoreImage Filters to emulate professional studio lighting (lifting shadows, normalizing exposure)
    static func applyStudioEffect(image: CIImage, intensity: Double) -> CIImage {
        var output = image
        guard intensity > 0.0 else { return image }
        
        // 1. Lift shadows (soften dark areas under the nose/chin)
        if let shadowFilter = CIFilter(name: "CIHighlightShadowAdjust") {
            shadowFilter.setValue(output, forKey: kCIInputImageKey)
            let shadowAmount = 0.75 * intensity
            shadowFilter.setValue(min(shadowAmount, 1.0), forKey: "inputShadowAmount") // 0.0 to 1.0, 1.0 is maximum shadow lifting
            if let out = shadowFilter.outputImage {
                output = out
            }
        }
        
        // 2. Adjust color controls (subtle exposure boost, contrast normalization)
        if let colorFilter = CIFilter(name: "CIColorControls") {
            colorFilter.setValue(output, forKey: kCIInputImageKey)
            colorFilter.setValue(1.0 + 0.02 * intensity, forKey: kCIInputSaturationKey) // slight color boost
            colorFilter.setValue(0.04 * intensity, forKey: kCIInputBrightnessKey) // gentle brightness increase
            colorFilter.setValue(1.0 + 0.05 * intensity,   forKey: kCIInputContrastKey)   // gentle contrast increase
            if let out = colorFilter.outputImage {
                output = out
            }
        }
        
        return output
    }
    
    // Render the final transformed image at exactly 684 x 883 pixels
    static func renderFinalImage(
        nsImage: NSImage,
        scale: CGFloat,
        offset: CGSize,
        rotation: Double, // in degrees
        studioEffectIntensity: Double,
        useBackgroundRemoval: Bool,
        segmentationMask: CIImage?
    ) -> NSImage? {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        var ciImage = CIImage(cgImage: cgImage)
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        
        // Apply background replacement using cached mask
        if useBackgroundRemoval, let mask = segmentationMask {
            let whiteBg = CIImage.white.cropped(to: ciImage.extent)
            let blendFilter = CIFilter(name: "CIBlendWithMask")
            blendFilter?.setValue(ciImage, forKey: kCIInputImageKey)
            blendFilter?.setValue(whiteBg, forKey: kCIInputBackgroundImageKey)
            blendFilter?.setValue(mask, forKey: kCIInputMaskImageKey)
            if let blended = blendFilter?.outputImage {
                ciImage = blended
            }
        }
        
        // Apply lighting studio corrections
        if studioEffectIntensity > 0 {
            ciImage = applyStudioEffect(image: ciImage, intensity: studioEffectIntensity)
        }
        
        // Build transform matrix in CoreGraphics coordinate system
        // Step 1: Center image coordinates at (0,0)
        var transform = CGAffineTransform(translationX: -w / 2.0, y: -h / 2.0)
        
        // Step 2: Rotate around center (negated to match SwiftUI's clockwise rotation direction)
        let rad = CGFloat(-rotation * .pi / 180.0)
        transform = transform.concatenating(CGAffineTransform(rotationAngle: rad))
        
        // Step 3: Scale
        transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
        
        // Step 4: Translate to targeted frame placement in the 684x883 canvas
        // Canvas center: X = 342, Y = 441.5
        let dx = offset.width
        let dy = -offset.height // Flip Y offset because SwiftUI increases downwards and CoreGraphics increases upwards
        transform = transform.concatenating(CGAffineTransform(translationX: 342.0 + dx, y: 441.5 + dy))
        
        // Apply the combined transforms
        let transformedImage = ciImage.transformed(by: transform)
        
        // Create white backing canvas of size 684x883 to fill any blank margins
        let whiteCanvas = CIImage.white.cropped(to: CGRect(x: 0, y: 0, width: 684, height: 883))
        let finalComposite = transformedImage.composited(over: whiteCanvas)
        
        // Render via metal/hardware accelerated CIContext
        let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
        guard let outputCGImage = context.createCGImage(finalComposite, from: CGRect(x: 0, y: 0, width: 684, height: 883)) else {
            return nil
        }
        
        return NSImage(cgImage: outputCGImage, size: NSSize(width: 684, height: 883))
    }
    
    // Save image to destination URL as JPEG, ensuring file size is under 2.5 MB
    static func saveAsJPEG(image: NSImage, to url: URL) -> Bool {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        var quality: Float = 0.95
        var data: Data? = nil
        
        // Compression loop: if size is above 2.5 MB, lower quality progressively
        let maxSizeBytes = 2500000 // 2.5 MB with margin
        
        while quality >= 0.5 {
            data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
            if let size = data?.count, size <= maxSizeBytes {
                break
            }
            quality -= 0.05
        }
        
        guard let finalData = data else {
            return false
        }
        
        do {
            try finalData.write(to: url)
            return true
        } catch {
            print("Failed to save JPEG: \(error)")
            return false
        }
    }
}
