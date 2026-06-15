from PyQt6.QtWidgets import QWidget
from PyQt6.QtGui import QPainter, QImage, QColor, QPen, QFont, QPainterPath
from PyQt6.QtCore import Qt, QPointF, QRectF, QRect

class PhotoEditorCanvas(QWidget):
    def __init__(self, state, parent=None):
        super().__init__(parent)
        self.state = state
        self.setFixedSize(684, 883)
        
        self.qimage = None
        self.dragging = False
        self.drag_start_pos = QPointF(0, 0)
        self.saved_pan_offset_x = 0.0
        self.saved_pan_offset_y = 0.0
        
        # Enable mouse hover events
        self.setMouseTracking(True)
        
    def set_pil_image(self, pil_image):
        """
        Converts PIL Image to PyQt6 QImage and refreshes the canvas.
        """
        if pil_image is None:
            self.qimage = None
            self.update()
            return
            
        # Convert PIL to QImage
        img_rgb = pil_image.convert('RGBA')
        data = img_rgb.tobytes("raw", "RGBA")
        self.qimage = QImage(data, img_rgb.width, img_rgb.height, QImage.Format.Format_RGBA8888)
        self.update()
        
    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
        
        # 1. Fill background with light gray when empty, white when active
        if self.qimage is None:
            painter.fillRect(self.rect(), QColor(240, 240, 240))
            
            # Draw empty placeholder
            painter.setPen(QPen(QColor(150, 150, 150), 2, Qt.PenStyle.DashLine))
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawRoundedRect(QRectF(10, 10, 664, 863), 8, 8)
            
            painter.setPen(QColor(100, 100, 100))
            painter.setFont(QFont("Arial", 12, QFont.Weight.Medium))
            painter.drawText(
                self.rect(), 
                Qt.AlignmentFlag.AlignCenter, 
                "Przeciągnij i upuść zdjęcie tutaj\nlub użyj panelu bocznego"
            )
        else:
            # Clean white canvas background
            painter.fillRect(self.rect(), Qt.GlobalColor.white)
            
            painter.save()
            # Move origin to the center of the canvas (342, 441.5)
            painter.translate(342.0, 441.5)
            
            # Apply translations (auto offset + manual pan)
            dx = self.state.auto_offset_x + self.state.pan_offset_x
            dy = self.state.auto_offset_y + self.state.pan_offset_y
            painter.translate(dx, dy)
            
            # Apply rotation around center (degrees)
            rot = self.state.auto_rotation + self.state.rotation_angle
            painter.rotate(rot)
            
            # Apply scale (auto scale * manual zoom)
            scale = self.state.auto_scale * self.state.zoom_scale
            painter.scale(scale, scale)
            
            # Draw the QImage centered around its own center
            iw = self.qimage.width()
            ih = self.qimage.height()
            painter.drawImage(int(-iw / 2.0), int(-ih / 2.0), self.qimage)
            painter.restore()
            
            # 2. Draw biometric template overlay lines on top
            self.draw_biometric_overlay(painter)
            
    def draw_biometric_overlay(self, painter):
        # Ellipse bounding box dimensions (width 400, height 667, top 78)
        ellipse_rect = QRectF(342.0 - 200, 78.0, 400.0, 667.0)
        
        # 1. Dark vignette mask with face oval cutout (Even-Odd Fill)
        path = QPainterPath()
        path.setFillRule(Qt.FillRule.OddEvenFill)
        path.addRect(QRectF(self.rect()))
        path.addEllipse(ellipse_rect)
        
        painter.setBrush(QColor(0, 0, 0, 115)) # 0.45 opacity
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawPath(path)
        
        # 2. Shaded top-of-head crown zone (Y = 59 to 98)
        painter.fillRect(0, 59, 684, 39, QColor(0, 200, 0, 30))
        
        # Min/Max target lines
        green_dash = QPen(QColor(0, 200, 0, 180), 1, Qt.PenStyle.DashLine)
        painter.setPen(green_dash)
        painter.drawLine(0, 59, 684, 59)
        painter.drawLine(0, 98, 684, 98)
        
        # Label
        painter.setPen(QColor(0, 180, 0))
        painter.setFont(QFont("Arial", 8, QFont.Weight.Bold))
        painter.drawText(QRect(684 - 190, 65, 180, 20), Qt.AlignmentFlag.AlignRight, "Czubek głowy (3 - 5 mm)")
        
        # 3. Vertical center line (blue dashed)
        blue_dash = QPen(QColor(0, 0, 255, 120), 1, Qt.PenStyle.DashLine)
        painter.setPen(blue_dash)
        painter.drawLine(342, 0, 342, 883)
        
        # 4. Chin Line (red dashed)
        red_dash = QPen(QColor(255, 0, 0, 200), 1.5, Qt.PenStyle.DashLine)
        painter.setPen(red_dash)
        painter.drawLine(0, 745, 684, 745)
        
        painter.setPen(QColor(255, 50, 50))
        painter.drawText(QRect(15, 745 - 18, 120, 20), Qt.AlignmentFlag.AlignLeft, "Linia brody")
        
        # 5. Eye level guideline (yellow dashed)
        yellow_dash = QPen(QColor(200, 180, 0, 150), 1, Qt.PenStyle.DashLine)
        painter.setPen(yellow_dash)
        painter.drawLine(0, 380, 684, 380)
        
        painter.setPen(QColor(200, 180, 0))
        painter.drawText(QRect(15, 380 - 18, 120, 20), Qt.AlignmentFlag.AlignLeft, "Linia oczu")
        
        # 6. Face oval outline (white)
        white_solid = QPen(QColor(255, 255, 255, 150), 1.5, Qt.PenStyle.SolidLine)
        painter.setPen(white_solid)
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawEllipse(ellipse_rect)
        
        # Border framing
        painter.setPen(QPen(QColor(255, 255, 255, 50), 1))
        painter.drawRect(self.rect().adjusted(0, 0, -1, -1))
        
    def mousePressEvent(self, event):
        if self.qimage is not None and event.button() == Qt.MouseButton.LeftButton:
            self.dragging = True
            self.drag_start_pos = event.position()
            self.saved_pan_offset_x = self.state.pan_offset_x
            self.saved_pan_offset_y = self.state.pan_offset_y
            
    def mouseMoveEvent(self, event):
        if self.dragging:
            delta = event.position() - self.drag_start_pos
            self.state.pan_offset_x = self.saved_pan_offset_x + delta.x()
            self.state.pan_offset_y = self.saved_pan_offset_y + delta.y()
            self.update()
            
    def mouseReleaseEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.dragging = False
            
    def wheelEvent(self, event):
        if self.qimage is not None:
            # deltaY / 120 gives ticks (+1.0 for scroll up, -1.0 for scroll down)
            delta = event.angleDelta().y() / 120.0
            zoom_speed = 0.025
            new_scale = self.state.zoom_scale + delta * zoom_speed
            self.state.zoom_scale = min(max(new_scale, 0.3), 3.0)
            self.update()
            
            # Emit notification to parent layout to update sidebar sliders
            self.parent().on_canvas_zoomed()
            event.accept()
