import SwiftUI
import UniformTypeIdentifiers
import AppKit
import Vision

struct MainView: View {
    @StateObject private var state = AppState()
    @State private var showingExportPreview = false
    
    var body: some View {
        HStack(spacing: 0) {
            
            // Left Sidebar - Control Panel with glassmorphism
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // App Title Section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AutoFoto Legal Expres")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Generator zdjęć biometrycznych")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 10)
                    
                    Divider()
                    
                    // 1. Import Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("1. Zdjęcie źródłowe")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        if let url = state.inputImageUrl {
                            HStack {
                                Image(systemName: "doc.image.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(url.lastPathComponent)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    
                                    if let fileSizeStr = getFileSizeString(url: url) {
                                        Text(fileSizeStr)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        state.resetAll()
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(10)
                            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                            .cornerRadius(6)
                        } else {
                            Button(action: selectFile) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Wybierz plik...")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                    
                    Divider()
                    
                    // 2. Alignment & Adjustments Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("2. Ręczna korekta kadru")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        // Zoom slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Przybliżenie (Zoom)")
                                    .font(.system(size: 12))
                                Spacer()
                                Text(String(format: "%.0f%%", state.zoomScale * 100))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        state.zoomScale = 1.0
                                    }
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                                .disabled(state.inputImage == nil || state.zoomScale == 1.0)
                            }
                            Slider(value: $state.zoomScale, in: 0.3...3.0)
                                .disabled(state.inputImage == nil)
                        }
                        
                        // Rotation slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Obrót (Kąt)")
                                    .font(.system(size: 12))
                                Spacer()
                                Text(String(format: "%.1f°", state.rotationAngle))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        state.rotationAngle = 0.0
                                    }
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                                .disabled(state.inputImage == nil || state.rotationAngle == 0.0)
                            }
                            Slider(value: $state.rotationAngle, in: -15.0...15.0)
                                .disabled(state.inputImage == nil)
                        }
                        
                        // Reset row
                        HStack(spacing: 8) {
                            Button(action: {
                                withAnimation(.spring()) {
                                    state.panOffset = .zero
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.right.and.left.square")
                                    Text("Resetuj Pan")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(state.inputImage == nil || state.panOffset == .zero)
                            
                            Button(action: {
                                withAnimation(.spring()) {
                                    state.resetManualAdjustments()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Resetuj wszystko")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(state.inputImage == nil)
                        }
                    }
                    
                    Divider()
                    
                    // 3. AI Assistant Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("3. Asystent AI")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        // Background removal toggle
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $state.useBackgroundRemoval) {
                                Text("Automatyczne białe tło")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .toggleStyle(.checkbox)
                            .disabled(state.inputImage == nil)
                            
                            Text("Wykrywa postać i podmienia tło na białe.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .padding(.leading, 18)
                        }
                        
                        // Studio effect intensity slider
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Efekt oświetlenia studyjnego")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text(String(format: "%.0f%%", state.studioEffectIntensity * 100))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        state.studioEffectIntensity = 0.0
                                    }
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                                .disabled(state.inputImage == nil || state.studioEffectIntensity == 0.0)
                            }
                            Slider(value: $state.studioEffectIntensity, in: 0.0...1.5)
                                .disabled(state.inputImage == nil)
                            
                            Text("Rozjaśnia twarz i usuwa cienie.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .padding(.leading, 2)
                        }
                    }
                    
                    Divider()
                    
                    // 4. Quality Status Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("4. Walidacja jakości")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        if state.inputImage == nil {
                            Text("Załaduj zdjęcie, aby sprawdzić jakość.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .italic()
                        } else if state.qualityWarnings.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 16))
                                Text("Zdjęcie spełnia kryteria")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.green)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.yellow)
                                    Text("Wykryte ostrzeżenia:")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.yellow)
                                }
                                
                                ForEach(state.qualityWarnings, id: \.self) { warning in
                                    HStack(alignment: .top, spacing: 4) {
                                        Text("•")
                                            .foregroundColor(.secondary)
                                        Text(warning)
                                            .font(.system(size: 11))
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.yellow.opacity(0.08))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    
                    Divider()
                    
                    // 5. Save/Export Section
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: { showingExportPreview = true }) {
                            HStack {
                                Image(systemName: "eye.fill")
                                Text("Podgląd i eksport")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(state.inputImage == nil)
                        
                        if let status = state.exportStatusMessage {
                            Text(status)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(status.contains("pomyślnie") ? .green : .red)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(6)
                                .background(status.contains("pomyślnie") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .frame(width: 300)
            .background(VisualEffectView())
            
            // Divider line between sidebar and preview workspace
            Rectangle()
                .frame(width: 1)
                .foregroundColor(Color(NSColor.separatorColor))
            
            // Right workspace - Preview
            VStack {
                if state.isProcessing {
                    ZStack {
                        Color.black.opacity(0.05)
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Przetwarzanie przez AI...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EditorCanvas(state: state)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color(NSColor.underPageBackgroundColor))
        }
        .frame(width: 1024, height: 900)
        // Drag and Drop implementation
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url = url {
                    DispatchQueue.main.async {
                        self.loadImage(from: url)
                    }
                }
            }
            return true
        }
        .sheet(isPresented: $showingExportPreview) {
            ExportPreviewView(state: state, isPresented: $showingExportPreview, onSave: saveFile)
        }
    }
    
    // Core function to load image and trigger local AI detection
    private func loadImage(from url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        
        state.resetAll()
        state.inputImage = image
        state.inputImageUrl = url
        state.processedPreviewImage = image
        state.isProcessing = true
        
        let dispatchGroup = DispatchGroup()
        
        // Task 1: Face Detection
        dispatchGroup.enter()
        VisionHelper.detectFace(in: image) { result in
            DispatchQueue.main.async {
                if let result = result {
                    withAnimation(.spring()) {
                        state.autoScale = result.scale
                        state.autoOffset = result.offset
                        state.autoRotation = result.rotation
                        state.qualityWarnings = result.warnings
                    }
                } else {
                    withAnimation(.spring()) {
                        state.autoScale = 1.0
                        state.autoOffset = .zero
                        state.autoRotation = 0.0
                        state.qualityWarnings = ["Nie wykryto twarzy. Użyj przybliżenia i przesunięcia do dopasowania."]
                    }
                }
                dispatchGroup.leave()
            }
        }
        
        // Task 2: Background Segmentation Precomputation
        dispatchGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let ciImage = CIImage(cgImage: cgImage)
                let request = VNGeneratePersonSegmentationRequest()
                request.qualityLevel = .accurate
                let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
                do {
                    try handler.perform([request])
                    if let observation = request.results?.first {
                        let maskBuffer = observation.pixelBuffer
                        var maskImage = CIImage(cvPixelBuffer: maskBuffer)
                        // Scale mask to original image size
                        let scaleX = ciImage.extent.width / maskImage.extent.width
                        let scaleY = ciImage.extent.height / maskImage.extent.height
                        maskImage = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                        
                        DispatchQueue.main.async {
                            state.segmentationMask = maskImage
                            dispatchGroup.leave()
                        }
                        return
                    }
                } catch {
                    print("Precomputing segmentation failed: \(error)")
                }
            }
            DispatchQueue.main.async {
                dispatchGroup.leave()
            }
        }
        
        // Done
        dispatchGroup.notify(queue: .main) {
            state.isProcessing = false
            state.generatePreview()
        }
    }
    
    // Select image using standard macOS open panel
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                loadImage(from: url)
            }
        }
    }
    
    // Action trigger for exporting crop
    private func saveFile() {
        guard let img = state.inputImage else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.jpeg]
        panel.nameFieldStringValue = "biometric_photo.jpg"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                state.isProcessing = true
                state.exportStatusMessage = nil
                
                let finalScale = state.autoScale * state.zoomScale
                let finalOffset = CGSize(
                    width: state.autoOffset.width + state.panOffset.width,
                    height: state.autoOffset.height + state.panOffset.height
                )
                let finalRotation = state.autoRotation + state.rotationAngle
                
                let effectStudio = state.studioEffectIntensity
                let removeBg = state.useBackgroundRemoval
                
                // Background render thread
                DispatchQueue.global(qos: .userInitiated).async {
                    let renderedImage = ImageProcessor.renderFinalImage(
                        nsImage: img,
                        scale: finalScale,
                        offset: finalOffset,
                        rotation: finalRotation,
                        studioEffectIntensity: effectStudio,
                        useBackgroundRemoval: removeBg,
                        segmentationMask: state.segmentationMask
                      )
                    
                    if let rendered = renderedImage {
                        let success = ImageProcessor.saveAsJPEG(image: rendered, to: url)
                        DispatchQueue.main.async {
                            state.isProcessing = false
                            if success {
                                state.exportStatusMessage = "Zdjęcie zapisane pomyślnie!"
                            } else {
                                state.exportStatusMessage = "Błąd zapisu pliku."
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            state.isProcessing = false
                            state.exportStatusMessage = "Błąd renderowania obrazu."
                        }
                    }
                }
            }
        }
    }
    
    // Helper to calculate file size string
    private func getFileSizeString(url: URL) -> String? {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            if let size = values.fileSize {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .binary
                return formatter.string(fromByteCount: Int64(size))
            }
        } catch {}
        return nil
    }
}

// macOS Visual Effect View (Glassmorphism backdrop)
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .sidebar
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// Dynamic Export Preview Screen presenting final cropped image without grid lines
struct ExportPreviewView: View {
    @ObservedObject var state: AppState
    @Binding var isPresented: Bool
    var onSave: () -> Void
    
    @State private var previewImage: NSImage? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Podgląd gotowego zdjęcia")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            ZStack {
                if let preview = previewImage {
                    Image(nsImage: preview)
                        .resizable()
                        .frame(width: 342, height: 441.5) // display at exactly 50% scale
                        .border(Color.secondary.opacity(0.3), width: 1)
                        .cornerRadius(4)
                        .shadow(radius: 6)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Generowanie podglądu...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 342, height: 441.5)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.2))
                    .cornerRadius(6)
                }
            }
            
            VStack(spacing: 4) {
                Text("Rozdzielczość wyjściowa: 684 x 883 pikseli")
                    .font(.system(size: 12, weight: .semibold))
                Text("Wymiar dokumentu: 35 x 45 mm (biometryczne)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button("Wróć do edycji") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Button(action: {
                    isPresented = false
                    onSave()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Pobierz i zapisz...")
                      }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400, height: 600)
        .onAppear {
            generatePreview()
        }
    }
    
    private func generatePreview() {
        guard let img = state.inputImage else { return }
        
        let finalScale = state.autoScale * state.zoomScale
        let finalOffset = CGSize(
            width: state.autoOffset.width + state.panOffset.width,
            height: state.autoOffset.height + state.panOffset.height
        )
        let finalRotation = state.autoRotation + state.rotationAngle
        
        let intensity = state.studioEffectIntensity
        let removeBg = state.useBackgroundRemoval
        
        DispatchQueue.global(qos: .userInitiated).async {
            let rendered = ImageProcessor.renderFinalImage(
                nsImage: img,
                scale: finalScale,
                offset: finalOffset,
                rotation: finalRotation,
                studioEffectIntensity: intensity,
                useBackgroundRemoval: removeBg,
                segmentationMask: state.segmentationMask
            )
            
            DispatchQueue.main.async {
                self.previewImage = rendered
            }
        }
    }
}
