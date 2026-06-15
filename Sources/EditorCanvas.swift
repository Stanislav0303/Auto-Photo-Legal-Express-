import SwiftUI
import AppKit

struct EditorCanvas: View {
    @ObservedObject var state: AppState
    
    // Track gesture start values to handle relative movement
    @State private var dragStartOffset: CGSize = .zero
    @State private var pinchStartScale: CGFloat = 1.0
    
    // Hover state and local event monitor for mouse scroll wheel
    @State private var isHovering = false
    @State private var scrollMonitor: Any? = nil
    
    let canvasWidth: CGFloat = 684
    let canvasHeight: CGFloat = 883
    
    var body: some View {
        ZStack {
            if let imageToDisplay = state.processedPreviewImage ?? state.inputImage {
                let imgSize = imageToDisplay.cgImageSize
                
                // Active preview canvas containing the image
                ZStack {
                    Image(nsImage: imageToDisplay)
                        .resizable()
                        .frame(width: imgSize.width, height: imgSize.height)
                        // Scale (auto-alignment scale * manual zoom scale)
                        .scaleEffect(state.autoScale * state.zoomScale)
                        // Rotation (auto-alignment rotation + manual slider rotation)
                        .rotationEffect(.degrees(state.autoRotation + state.rotationAngle))
                        // Offset (auto-alignment offset + manual pan offset)
                        .offset(
                            x: state.autoOffset.width + state.panOffset.width,
                            y: state.autoOffset.height + state.panOffset.height
                        )
                }
                .frame(width: canvasWidth, height: canvasHeight)
                .contentShape(Rectangle()) // Make the whole area interactive
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            state.panOffset = CGSize(
                                width: dragStartOffset.width + value.translation.width,
                                height: dragStartOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            dragStartOffset = state.panOffset
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            state.zoomScale = pinchStartScale * value
                        }
                        .onEnded { _ in
                            pinchStartScale = state.zoomScale
                        }
                )
                .onChange(of: state.panOffset) { newValue in
                    // Reset internal gesture memory if offset is cleared from outside (reset button)
                    if newValue == .zero {
                        dragStartOffset = .zero
                    }
                }
                .onChange(of: state.zoomScale) { newValue in
                    // Reset internal gesture memory if scale is cleared from outside
                    if newValue == 1.0 {
                        pinchStartScale = 1.0
                    }
                }
            } else {
                // Empty dropzone placeholder
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 64))
                        .foregroundColor(.gray)
                    
                    Text("Przeciągnij i upuść zdjęcie tutaj\nlub użyj panelu po lewej stronie.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(width: canvasWidth, height: canvasHeight)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .foregroundColor(Color.gray.opacity(0.5))
                )
            }
            
            // Draw Biometric Overlay Template on top
            if state.inputImage != nil {
                OverlayTemplate()
                    .allowsHitTesting(false) // Let drag/pinch pass through to the image layer
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .clipped() // Don't allow image to spill outside crop viewport
        .background(Color.black.opacity(0.1))
        .cornerRadius(4)
        .shadow(radius: 6)
        .onHover { hovering in
            isHovering = hovering
        }
        .onAppear {
            // Monitor scroll wheel events while mouse is hovering over the canvas
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                if isHovering && state.inputImage != nil {
                    let delta = event.deltaY
                    if delta != 0 {
                        // Scroll up zooms in, scroll down zooms out
                        let zoomSpeed: CGFloat = 0.015
                        let newScale = state.zoomScale + delta * zoomSpeed
                        state.zoomScale = min(max(newScale, 0.3), 3.0)
                        return nil // Consume event to prevent scrolling sidebar scroll view
                    }
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
                scrollMonitor = nil
            }
        }
    }
}

// Extension to safely extract pixel sizes for pixel-perfect alignment
extension NSImage {
    var cgImageSize: CGSize {
        guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return size
        }
        return CGSize(width: CGFloat(cg.width), height: CGFloat(cg.height))
    }
}
