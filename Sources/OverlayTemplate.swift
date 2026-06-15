import SwiftUI

struct OverlayTemplate: View {
    let canvasWidth: CGFloat = 684
    let canvasHeight: CGFloat = 883
    
    // Biometric parameters in points (mapping exactly to pixels in a 684x883 container)
    let chinY: CGFloat = 745            // 38 mm from top -> 745 pt
    let headTopMinY: CGFloat = 59       // 3 mm from top -> 59 pt
    let headTopMaxY: CGFloat = 98       // 5 mm from top -> 98 pt
    let headTopTargetY: CGFloat = 78    // 4 mm from top -> 78 pt
    let verticalCenter: CGFloat = 342   // 35mm center -> 342 pt
    let eyeLineY: CGFloat = 380         // Eye level guideline (approx 380 pt from top)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                
                // 1. Outer dark vignette with face oval cutout
                FaceCutoutShape(
                    canvasSize: CGSize(width: canvasWidth, height: canvasHeight),
                    ovalRect: CGRect(
                        x: verticalCenter - 200,
                        y: headTopTargetY,
                        width: 400,
                        height: chinY - headTopTargetY
                    )
                )
                .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
                
                // 2. Head crown tolerance zone (shaded green band)
                Group {
                    // Shaded area
                    Path { path in
                        path.addRect(CGRect(x: 0, y: headTopMinY, width: canvasWidth, height: headTopMaxY - headTopMinY))
                    }
                    .fill(Color.green.opacity(0.12))
                    
                    // Min line
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: headTopMinY))
                        path.addLine(to: CGPoint(x: canvasWidth, y: headTopMinY))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1.0, dash: [4, 4]))
                    .foregroundColor(Color.green.opacity(0.7))
                    
                    // Max line
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: headTopMaxY))
                        path.addLine(to: CGPoint(x: canvasWidth, y: headTopMaxY))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1.0, dash: [4, 4]))
                    .foregroundColor(Color.green.opacity(0.7))
                    
                    Text("Czubek głowy (3 - 5 mm)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(3)
                        .position(x: canvasWidth - 90, y: headTopMinY + 18)
                }
                
                // 3. Central Vertical Line
                Path { path in
                    path.move(to: CGPoint(x: verticalCenter, y: 0))
                    path.addLine(to: CGPoint(x: verticalCenter, y: canvasHeight))
                }
                .stroke(style: StrokeStyle(lineWidth: 0.75, dash: [6, 4]))
                .foregroundColor(Color.blue.opacity(0.5))
                
                // 4. Chin Line (Red guideline)
                Group {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: chinY))
                        path.addLine(to: CGPoint(x: canvasWidth, y: chinY))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                    .foregroundColor(Color.red.opacity(0.8))
                    
                    Text("Linia brody")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(3)
                        .position(x: 50, y: chinY - 12)
                }
                
                // 5. Eye level line (Yellow guide)
                Group {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: eyeLineY))
                        path.addLine(to: CGPoint(x: canvasWidth, y: eyeLineY))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1.0, dash: [3, 5]))
                    .foregroundColor(Color.yellow.opacity(0.6))
                    
                    Text("Linia oczu")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.yellow)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(3)
                        .position(x: 50, y: eyeLineY - 12)
                }
                
                // 6. Face Oval Guide
                Path { path in
                    path.addEllipse(in: CGRect(
                        x: verticalCenter - 200,
                        y: headTopTargetY,
                        width: 400,
                        height: chinY - headTopTargetY
                    ))
                }
                .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                
                // Outer framing indicator
                Rectangle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: canvasWidth, height: canvasHeight)
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }
}

// Custom shape to draw outer rectangle with inner cutout
struct FaceCutoutShape: Shape {
    let canvasSize: CGSize
    let ovalRect: CGRect
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Outer rect
        path.addRect(CGRect(origin: .zero, size: canvasSize))
        // Inner oval
        path.addEllipse(in: ovalRect)
        return path
    }
}

