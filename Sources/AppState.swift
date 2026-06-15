import SwiftUI
import Combine

class AppState: ObservableObject {
    // Loaded Image State
    @Published var inputImage: NSImage? = nil
    @Published var inputImageUrl: URL? = nil
    @Published var processedPreviewImage: NSImage? = nil
    @Published var segmentationMask: CIImage? = nil
    
    // UI and Processing States
    @Published var isProcessing: Bool = false
    @Published var exportStatusMessage: String? = nil
    
    // Core AI Toggles & Adjustments
    @Published var studioEffectIntensity: Double = 0.0 {
        didSet { generatePreview() }
    }
    @Published var useBackgroundRemoval: Bool = false {
        didSet { generatePreview() }
    }
    
    // Quality Warnings (Polish language based on requirements)
    @Published var qualityWarnings: [String] = []
    
    // Automatic Alignment Parameters (Calculated by Vision API)
    @Published var autoScale: CGFloat = 1.0
    @Published var autoOffset: CGSize = .zero
    @Published var autoRotation: Double = 0.0
    
    // Manual Adjustments (Additive to auto-alignment)
    @Published var zoomScale: CGFloat = 1.0
    @Published var panOffset: CGSize = .zero
    @Published var rotationAngle: Double = 0.0 // in degrees
    
    // Debug / Visual guides computed from Vision
    @Published var faceBoundingBox: CGRect? = nil
    @Published var chinPoint: CGPoint? = nil
    @Published var headTopPoint: CGPoint? = nil
    
    // Resets manual adjustments to default
    func resetManualAdjustments() {
        zoomScale = 1.0
        panOffset = .zero
        rotationAngle = 0.0
        exportStatusMessage = nil
    }
    
    // Full Reset
    func resetAll() {
        inputImage = nil
        inputImageUrl = nil
        processedPreviewImage = nil
        segmentationMask = nil
        isProcessing = false
        exportStatusMessage = nil
        studioEffectIntensity = 0.0
        useBackgroundRemoval = false
        qualityWarnings = []
        autoScale = 1.0
        autoOffset = .zero
        autoRotation = 0.0
        resetManualAdjustments()
        faceBoundingBox = nil
        chinPoint = nil
        headTopPoint = nil
    }
    
    // Asynchronous optimized preview generator utilizing cached segmentation mask
    func generatePreview() {
        guard let original = inputImage else { return }
        
        if studioEffectIntensity == 0.0 && !useBackgroundRemoval {
            self.processedPreviewImage = original
            return
        }
        
        let intensity = studioEffectIntensity
        let removeBg = useBackgroundRemoval
        let mask = segmentationMask
        
        DispatchQueue.global(qos: .userInteractive).async {
            guard let cgImage = original.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            let ciImage = CIImage(cgImage: cgImage)
            var outputImage = ciImage
            
            // Apply background removal using cached mask
            if removeBg, let maskImage = mask {
                let whiteBg = CIImage.white.cropped(to: ciImage.extent)
                let blendFilter = CIFilter(name: "CIBlendWithMask")
                blendFilter?.setValue(ciImage, forKey: kCIInputImageKey)
                blendFilter?.setValue(whiteBg, forKey: kCIInputBackgroundImageKey)
                blendFilter?.setValue(maskImage, forKey: kCIInputMaskImageKey)
                if let blended = blendFilter?.outputImage {
                    outputImage = blended
                }
            }
            
            // Apply studio effects
            if intensity > 0.0 {
                outputImage = ImageProcessor.applyStudioEffect(image: outputImage, intensity: intensity)
            }
            
            let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
            if let outputCGImage = context.createCGImage(outputImage, from: outputImage.extent) {
                let preview = NSImage(cgImage: outputCGImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                DispatchQueue.main.async {
                    self.processedPreviewImage = preview
                }
            }
        }
    }
}
