import Vision
import AppKit

class VisionHelper {
    
    struct FaceDetectionResult {
        let scale: CGFloat
        let offset: CGSize
        let rotation: Double // in degrees
        let boundingBox: CGRect
        let chin: CGPoint
        let headTop: CGPoint
        let warnings: [String]
    }
    
    static func detectFace(in nsImage: NSImage, completion: @escaping (FaceDetectionResult?) -> Void) {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(nil)
            return
        }
        
        let request = VNDetectFaceLandmarksRequest { request, error in
            if let error = error {
                print("Vision error: \(error)")
                completion(nil)
                return
            }
            
            guard let results = request.results as? [VNFaceObservation], let face = results.first else {
                // No face detected
                completion(nil)
                return
            }
            
            let boundingBox = face.boundingBox
            let roll = face.roll?.doubleValue ?? 0.0
            let yaw = face.yaw?.doubleValue ?? 0.0
            
            let w = CGFloat(cgImage.width)
            let h = CGFloat(cgImage.height)
            
            // 1. Locate chin point in normalized coordinates
            var chinNorm = CGPoint(x: boundingBox.midX, y: boundingBox.minY)
            if let landmarks = face.landmarks, let contour = landmarks.faceContour {
                let points = contour.normalizedPoints
                if points.count > 8 {
                    // Standard 17-point contour has chin at index 8
                    chinNorm = points[8]
                } else if !points.isEmpty {
                    // Fallback to point with lowest y
                    chinNorm = points.min(by: { $0.y < $1.y }) ?? chinNorm
                }
            }
            
            // 2. Estimate top of head (hair crown) in normalized coordinates.
            // Face bounding box covers chin to eyebrows/forehead. 
            // The top of the hair is roughly 1.4x the distance from chin to box top.
            let faceHeightNorm = boundingBox.maxY - chinNorm.y
            let headTopNormY = chinNorm.y + faceHeightNorm * 1.40
            let headTopNorm = CGPoint(x: chinNorm.x, y: headTopNormY)
            
            // Convert to image pixel coordinates (Vision normalized coordinates: origin at bottom-left)
            let pxChin = CGPoint(x: chinNorm.x * w, y: chinNorm.y * h)
            let pxHeadTop = CGPoint(x: headTopNorm.x * w, y: headTopNormY * h)
            
            // Height of face in pixels
            let pxFaceHeight = pxHeadTop.y - pxChin.y
            
            // Target face height on our 684x883 canvas is 667 pixels (34mm in 35x45mm ratio)
            let targetFaceHeight: CGFloat = 667.0
            
            // Calculate scale
            var autoScale: CGFloat = 1.0
            if pxFaceHeight > 0 {
                autoScale = targetFaceHeight / pxFaceHeight
            }
            
            // Convert chin and head top to SwiftUI pixels (SwiftUI origin: top-left)
            let swiftUIChinY = (1.0 - chinNorm.y) * h
            let swiftUIChinX = chinNorm.x * w
            
            // Calculate offsets to center the face horizontally (X=342) and align chin to target line (Y=745)
            // Canvas center is (342, 441.5)
            let dx = -autoScale * (swiftUIChinX - w / 2.0)
            let dy = (883.0 - 138.0) - 441.5 - autoScale * (swiftUIChinY - h / 2.0)
            let autoOffset = CGSize(width: dx, height: dy)
            
            // Roll correction (auto rotation)
            let autoRotation = -roll
            
            // Quality warning analysis
            var warnings: [String] = []
            
            // Check Head Tilt (Roll / Yaw)
            if abs(roll) > 6.0 {
                warnings.append(String(format: "Przechylenie głowy w bok: %.0f° (wyprostuj twarz)", roll))
            }
            if abs(yaw) > 10.0 {
                warnings.append(String(format: "Głowa obrócona w bok (yaw: %.0f°)", yaw))
            }
            
            // Check brightness in face bounding box
            let brightness = checkFaceBrightness(cgImage: cgImage, boundingBox: boundingBox)
            if brightness < 0.22 {
                warnings.append(String(format: "Zdjęcie jest za ciemne (jasność twarzy: %.0f%%)", brightness * 100))
            } else if brightness > 0.85 {
                warnings.append("Zdjęcie twarzy jest prześwietlone")
            }
            
            // Check detection confidence
            if face.confidence < 0.75 {
                warnings.append("Niska pewność detekcji twarzy, zweryfikuj kadr ręcznie")
            }
            
            let result = FaceDetectionResult(
                scale: autoScale,
                offset: autoOffset,
                rotation: autoRotation,
                boundingBox: boundingBox,
                chin: pxChin,
                headTop: pxHeadTop,
                warnings: warnings
            )
            
            completion(result)
        }
        
        #if targetEnvironment(simulator)
        request.usesCPUOnly = true
        #endif
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform Vision request: \(error)")
                completion(nil)
            }
        }
    }
    
    // CoreGraphics 1x1 fast average brightness analyzer
    private static func checkFaceBrightness(cgImage: CGImage, boundingBox: CGRect) -> Double {
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        
        let cropRect = CGRect(
            x: boundingBox.origin.x * w,
            y: (1.0 - boundingBox.origin.y - boundingBox.size.height) * h,
            width: boundingBox.size.width * w,
            height: boundingBox.size.height * h
        ).intersection(CGRect(x: 0, y: 0, width: w, height: h))
        
        guard cropRect.width > 1 && cropRect.height > 1 else { return 0.5 }
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var rawData: [UInt8] = [0]
        guard let context = CGContext(
            data: &rawData,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 1,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return 0.5
        }
        
        guard let croppedImage = cgImage.cropping(to: cropRect) else { return 0.5 }
        context.draw(croppedImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        return Double(rawData[0]) / 255.0
    }
}
