import sys
import os
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, 
    QLabel, QPushButton, QSlider, QCheckBox, QFileDialog, QDialog, 
    QFrame, QSplitter, QProgressBar, QMessageBox
)
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QSize
from PyQt6.QtGui import QFont, QIcon, QPixmap
from PIL import Image

# Import local project modules
from vision import VisionHelper
from processor import ImageProcessor
from canvas import PhotoEditorCanvas

class AppState:
    def __init__(self):
        self.input_image = None
        self.input_file_path = None
        self.processed_preview_image = None
        self.segmentation_mask = None
        
        self.is_processing = False
        self.export_status_message = None
        
        self.studio_effect_intensity = 0.0
        self.use_background_removal = False
        
        self.quality_warnings = []
        
        self.auto_scale = 1.0
        self.auto_offset_x = 0.0
        self.auto_offset_y = 0.0
        self.auto_rotation = 0.0
        
        self.zoom_scale = 1.0
        self.pan_offset_x = 0.0
        self.pan_offset_y = 0.0
        self.rotation_angle = 0.0
        
    def reset_manual_adjustments(self):
        self.zoom_scale = 1.0
        self.pan_offset_x = 0.0
        self.pan_offset_y = 0.0
        self.rotation_angle = 0.0
        self.export_status_message = None
        
    def reset_all(self):
        self.input_image = None
        self.input_file_path = None
        self.processed_preview_image = None
        self.segmentation_mask = None
        self.is_processing = False
        self.export_status_message = None
        self.studio_effect_intensity = 0.0
        self.use_background_removal = False
        self.quality_warnings = []
        self.auto_scale = 1.0
        self.auto_offset_x = 0.0
        self.auto_offset_y = 0.0
        self.auto_rotation = 0.0
        self.reset_manual_adjustments()

# Background thread to load image, compute face metrics and segmentation mask
class ImageLoaderWorker(QThread):
    finished = pyqtSignal(dict)
    
    def __init__(self, file_path):
        super().__init__()
        self.file_path = file_path
        
    def run(self):
        try:
            pil_img = Image.open(self.file_path)
            # Fix EXIF orientation if present
            pil_img = ImageProcessor.apply_studio_effect(pil_img, 0.0) # passes through normalizer
            
            helper = VisionHelper()
            face_result = helper.detect_face(pil_img)
            mask = helper.generate_segmentation_mask(pil_img)
            helper.close()
            
            self.finished.emit({
                "pil_image": pil_img,
                "face_result": face_result,
                "mask": mask
            })
        except Exception as e:
            import traceback
            err_msg = "".join(traceback.format_exception(type(e), e, e.__traceback__))
            print(f"Error in loader thread: {err_msg}")
            self.finished.emit({"error": err_msg})

class ExportPreviewDialog(QDialog):
    def __init__(self, state, parent=None):
        super().__init__(parent)
        self.state = state
        self.setWindowTitle("Podgląd gotowego zdjęcia")
        self.setFixedSize(400, 600)
        self.setStyleSheet("background-color: #2b2b2b; color: white;")
        
        self.preview_image = None
        self.init_ui()
        
    def init_ui(self):
        layout = QVBoxLayout()
        layout.setSpacing(16)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # Header
        title = QLabel("Podgląd gotowego zdjęcia")
        title.setFont(QFont("Arial", 14, QFont.Weight.Bold))
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)
        
        # Image Preview Area
        self.img_label = QLabel()
        self.img_label.setFixedSize(342, 442)
        self.img_label.setStyleSheet("border: 1px solid #555; background-color: #1a1a1a; border-radius: 4px;")
        self.img_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.img_label)
        
        # Metadata Label
        meta_label = QLabel("Rozdzielczość wyjściowa: 684 x 883 pikseli\nWymiar dokumentu: 35 x 45 mm (biometryczne)")
        meta_label.setFont(QFont("Arial", 9))
        meta_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        meta_label.setStyleSheet("color: #aaa;")
        layout.addWidget(meta_label)
        
        # Button Row
        btn_layout = QHBoxLayout()
        close_btn = QPushButton("Wróć do edycji")
        close_btn.setStyleSheet("padding: 8px 16px; border: 1px solid #555; border-radius: 4px; background-color: #3a3a3a;")
        close_btn.clicked.connect(self.reject)
        
        save_btn = QPushButton("Pobierz i zapisz...")
        save_btn.setStyleSheet("padding: 8px 16px; border: none; border-radius: 4px; background-color: #28a745; font-weight: bold;")
        save_btn.clicked.connect(self.accept)
        
        btn_layout.addWidget(close_btn)
        btn_layout.addWidget(save_btn)
        layout.addLayout(btn_layout)
        
        self.setLayout(layout)
        self.generate_preview()
        
    def generate_preview(self):
        if self.state.input_image is None:
            return
            
        final_scale = self.state.auto_scale * self.state.zoom_scale
        final_offset_x = self.state.auto_offset_x + self.state.pan_offset_x
        final_offset_y = self.state.auto_offset_y + self.state.pan_offset_y
        final_rotation = self.state.auto_rotation + self.state.rotation_angle
        
        self.preview_image = ImageProcessor.render_final_image(
            pil_image=self.state.input_image,
            scale=final_scale,
            offset_x=final_offset_x,
            offset_y=final_offset_y,
            rotation=final_rotation,
            studio_effect_intensity=self.state.studio_effect_intensity,
            use_background_removal=self.state.use_background_removal,
            segmentation_mask=self.state.segmentation_mask
        )
        
        # Convert PIL to QPixmap
        img_rgb = self.preview_image.convert('RGBA')
        data = img_rgb.tobytes("raw", "RGBA")
        qimg = QImage(data, img_rgb.width, img_rgb.height, QImage.Format.Format_RGBA8888)
        pixmap = QPixmap.fromImage(qimg)
        
        # Scale for 50% display (342x441.5)
        scaled_pixmap = pixmap.scaled(342, 442, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
        self.img_label.setPixmap(scaled_pixmap)


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.state = AppState()
        self.setWindowTitle("AutoFoto Legal Expres")
        self.setMinimumSize(1024, 900)
        self.setAcceptDrops(True)
        
        # Set window icon if present
        if os.path.exists("logo.ico"):
            self.setWindowIcon(QIcon("logo.ico"))
            
        # Modern Dark stylesheet emulating glassmorphism
        self.setStyleSheet("""
            QMainWindow {
                background-color: #1e1e1e;
            }
            QFrame#sidebar {
                background-color: #262626;
                border-right: 1px solid #333;
            }
            QLabel {
                color: #e0e0e0;
            }
            QSlider::groove:horizontal {
                height: 4px;
                background: #444;
                border-radius: 2px;
            }
            QSlider::handle:horizontal {
                background: #007aff;
                width: 14px;
                height: 14px;
                margin-top: -5px;
                border-radius: 7px;
            }
            QSlider::handle:horizontal:disabled {
                background: #555;
            }
            QPushButton {
                background-color: #3a3a3a;
                border: 1px solid #555;
                color: white;
                border-radius: 4px;
                padding: 6px 12px;
            }
            QPushButton:hover {
                background-color: #4a4a4a;
            }
            QPushButton:disabled {
                background-color: #222;
                color: #666;
                border-color: #333;
            }
            QCheckBox {
                color: #e0e0e0;
                spacing: 8px;
            }
            QCheckBox::indicator {
                width: 16px;
                height: 16px;
                background-color: #3a3a3a;
                border: 1px solid #555;
                border-radius: 3px;
            }
            QCheckBox::indicator:checked {
                background-color: #007aff;
                image: url(check.png); /* Falls back to solid color if missing */
            }
            QCheckBox::indicator:disabled {
                background-color: #222;
                border-color: #333;
            }
        """)
        
        self.init_ui()
        
    def init_ui(self):
        main_layout = QHBoxLayout()
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)
        
        # --- LEFT SIDEBAR (Sidebar controls) ---
        sidebar = QFrame()
        sidebar.setObjectName("sidebar")
        sidebar.setFixedWidth(300)
        sidebar_layout = QVBoxLayout()
        sidebar_layout.setContentsMargins(20, 20, 20, 20)
        sidebar_layout.setSpacing(20)
        
        # App Title
        title_box = QVBoxLayout()
        title = QLabel("AutoFoto Legal Expres")
        title.setFont(QFont("Arial", 16, QFont.Weight.Bold))
        subtitle = QLabel("Generator zdjęć biometrycznych")
        subtitle.setFont(QFont("Arial", 9, QFont.Weight.Medium))
        subtitle.setStyleSheet("color: #888;")
        title_box.addWidget(title)
        title_box.addWidget(subtitle)
        sidebar_layout.addLayout(title_box)
        
        sidebar_layout.addWidget(self.create_divider())
        
        # 1. Source Photo Selection
        import_box = QVBoxLayout()
        import_box.setSpacing(8)
        import_lbl = QLabel("1. Zdjęcie źródłowe")
        import_lbl.setFont(QFont("Arial", 10, QFont.Weight.Bold))
        import_lbl.setStyleSheet("color: #888;")
        import_box.addWidget(import_lbl)
        
        self.file_info_lbl = QLabel("Brak załadowanego pliku")
        self.file_info_lbl.setFont(QFont("Arial", 9))
        self.file_info_lbl.setWordWrap(True)
        import_box.addWidget(self.file_info_lbl)
        
        self.import_btn = QPushButton("Wybierz plik...")
        self.import_btn.clicked.connect(self.select_file)
        import_box.addWidget(self.import_btn)
        sidebar_layout.addLayout(import_box)
        
        sidebar_layout.addWidget(self.create_divider())
        
        # 2. Manual adjustments
        adjust_box = QVBoxLayout()
        adjust_box.setSpacing(12)
        adjust_lbl = QLabel("2. Ręczna korekta kadru")
        adjust_lbl.setFont(QFont("Arial", 10, QFont.Weight.Bold))
        adjust_lbl.setStyleSheet("color: #888;")
        adjust_box.addWidget(adjust_lbl)
        
        # Zoom control
        zoom_header = QHBoxLayout()
        zoom_lbl = QLabel("Przybliżenie (Zoom)")
        zoom_lbl.setFont(QFont("Arial", 9))
        self.zoom_val = QLabel("100%")
        self.zoom_val.setFont(QFont("Consolas", 9))
        self.zoom_val.setStyleSheet("color: #888;")
        self.zoom_reset = QPushButton("↺")
        self.zoom_reset.setFixedSize(20, 20)
        self.zoom_reset.clicked.connect(self.reset_zoom)
        
        zoom_header.addWidget(zoom_lbl)
        zoom_header.addStretch()
        zoom_header.addWidget(self.zoom_val)
        zoom_header.addWidget(self.zoom_reset)
        adjust_box.addLayout(zoom_header)
        
        self.zoom_slider = QSlider(Qt.Orientation.Horizontal)
        self.zoom_slider.setRange(30, 300) # 30% to 300%
        self.zoom_slider.setValue(100)
        self.zoom_slider.valueChanged.connect(self.on_zoom_changed)
        adjust_box.addWidget(self.zoom_slider)
        
        # Rotation control
        rot_header = QHBoxLayout()
        rot_lbl = QLabel("Obrót (Kąt)")
        rot_lbl.setFont(QFont("Arial", 9))
        self.rot_val = QLabel("0.0°")
        self.rot_val.setFont(QFont("Consolas", 9))
        self.rot_val.setStyleSheet("color: #888;")
        self.rot_reset = QPushButton("↺")
        self.rot_reset.setFixedSize(20, 20)
        self.rot_reset.clicked.connect(self.reset_rotation)
        
        rot_header.addWidget(rot_lbl)
        rot_header.addStretch()
        rot_header.addWidget(self.rot_val)
        rot_header.addWidget(self.rot_reset)
        adjust_box.addLayout(rot_header)
        
        self.rot_slider = QSlider(Qt.Orientation.Horizontal)
        self.rot_slider.setRange(-150, 150) # -15.0 to 15.0 degrees (*10)
        self.rot_slider.setValue(0)
        self.rot_slider.valueChanged.connect(self.on_rotation_changed)
        adjust_box.addWidget(self.rot_slider)
        
        # Reset row
        reset_row = QHBoxLayout()
        self.reset_pan_btn = QPushButton("Resetuj Pan")
        self.reset_pan_btn.clicked.connect(self.reset_pan)
        self.reset_all_btn = QPushButton("Resetuj wszystko")
        self.reset_all_btn.clicked.connect(self.reset_all_adjustments)
        reset_row.addWidget(self.reset_pan_btn)
        reset_row.addWidget(self.reset_all_btn)
        adjust_box.addLayout(reset_row)
        sidebar_layout.addLayout(adjust_box)
        
        sidebar_layout.addWidget(self.create_divider())
        
        # 3. AI Assistant
        ai_box = QVBoxLayout()
        ai_box.setSpacing(10)
        ai_lbl = QLabel("3. Asystent AI")
        ai_lbl.setFont(QFont("Arial", 10, QFont.Weight.Bold))
        ai_lbl.setStyleSheet("color: #888;")
        ai_box.addWidget(ai_lbl)
        
        self.bg_checkbox = QCheckBox("Automatyczne białe tło")
        self.bg_checkbox.setFont(QFont("Arial", 9))
        self.bg_checkbox.stateChanged.connect(self.on_bg_removal_toggled)
        ai_box.addWidget(self.bg_checkbox)
        
        # Studio lighting intensity
        studio_header = QHBoxLayout()
        studio_lbl = QLabel("Efekt oświetlenia studyjnego")
        studio_lbl.setFont(QFont("Arial", 9))
        self.studio_val = QLabel("0%")
        self.studio_val.setFont(QFont("Consolas", 9))
        self.studio_val.setStyleSheet("color: #888;")
        self.studio_reset = QPushButton("↺")
        self.studio_reset.setFixedSize(20, 20)
        self.studio_reset.clicked.connect(self.reset_studio_lighting)
        
        studio_header.addWidget(studio_lbl)
        studio_header.addStretch()
        studio_header.addWidget(self.studio_val)
        studio_header.addWidget(self.studio_reset)
        ai_box.addLayout(studio_header)
        
        self.studio_slider = QSlider(Qt.Orientation.Horizontal)
        self.studio_slider.setRange(0, 150) # 0% to 150%
        self.studio_slider.setValue(0)
        self.studio_slider.valueChanged.connect(self.on_studio_changed)
        ai_box.addWidget(self.studio_slider)
        sidebar_layout.addLayout(ai_box)
        
        sidebar_layout.addWidget(self.create_divider())
        
        # 4. Quality Status
        quality_box = QVBoxLayout()
        quality_box.setSpacing(8)
        quality_lbl = QLabel("4. Walidacja jakości")
        quality_lbl.setFont(QFont("Arial", 10, QFont.Weight.Bold))
        quality_lbl.setStyleSheet("color: #888;")
        quality_box.addWidget(quality_lbl)
        
        self.status_lbl = QLabel("Załaduj zdjęcie, aby sprawdzić jakość.")
        self.status_lbl.setFont(QFont("Arial", 9))
        self.status_lbl.setWordWrap(True)
        self.status_lbl.setStyleSheet("color: #888; font-style: italic;")
        quality_box.addWidget(self.status_lbl)
        sidebar_layout.addLayout(quality_box)
        
        sidebar_layout.addWidget(self.create_divider())
        
        # 5. Export Button
        self.export_btn = QPushButton("👁 Podgląd i eksport")
        self.export_btn.setFont(QFont("Arial", 11, QFont.Weight.Bold))
        self.export_btn.setStyleSheet("""
            background-color: #28a745; 
            border: none; 
            color: white; 
            padding: 12px; 
            border-radius: 6px;
        """)
        self.export_btn.clicked.connect(self.open_export_preview)
        sidebar_layout.addWidget(self.export_btn)
        
        sidebar_layout.addStretch()
        sidebar.setLayout(sidebar_layout)
        main_layout.addWidget(sidebar)
        
        # --- RIGHT WORKSPACE (Canvas) ---
        workspace = QFrame()
        workspace.setStyleSheet("background-color: #121212;")
        workspace_layout = QVBoxLayout()
        workspace_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        # Spinner/Progress view
        self.progress_frame = QFrame()
        self.progress_frame.setFixedSize(300, 100)
        self.progress_frame.setStyleSheet("background-color: #262626; border-radius: 8px;")
        progress_layout = QVBoxLayout(self.progress_frame)
        self.progress_label = QLabel("Przetwarzanie przez AI...")
        self.progress_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.progress_bar = QProgressBar()
        self.progress_bar.setRange(0, 0) # Infinite animation
        progress_layout.addWidget(self.progress_label)
        progress_layout.addWidget(self.progress_bar)
        
        # Add Editor Canvas
        self.canvas = PhotoEditorCanvas(self.state, self)
        
        workspace_layout.addWidget(self.canvas)
        workspace_layout.addWidget(self.progress_frame)
        self.progress_frame.hide()
        
        workspace.setLayout(workspace_layout)
        main_layout.addWidget(workspace)
        
        # Parent layout setting
        central_widget = QWidget()
        central_widget.setLayout(main_layout)
        self.setCentralWidget(central_widget)
        
        self.disable_controls()
        
    def create_divider(self):
        divider = QFrame()
        divider.setFrameShape(QFrame.Shape.HLine)
        divider.setStyleSheet("background-color: #333;")
        return divider
        
    def disable_controls(self):
        self.zoom_slider.setEnabled(False)
        self.rot_slider.setEnabled(False)
        self.zoom_reset.setEnabled(False)
        self.rot_reset.setEnabled(False)
        self.reset_pan_btn.setEnabled(False)
        self.reset_all_btn.setEnabled(False)
        self.bg_checkbox.setEnabled(False)
        self.studio_slider.setEnabled(False)
        self.studio_reset.setEnabled(False)
        self.export_btn.setEnabled(False)
        
    def enable_controls(self):
        self.zoom_slider.setEnabled(True)
        self.rot_slider.setEnabled(True)
        self.zoom_reset.setEnabled(True)
        self.rot_reset.setEnabled(True)
        self.reset_pan_btn.setEnabled(True)
        self.reset_all_btn.setEnabled(True)
        self.bg_checkbox.setEnabled(True)
        self.studio_slider.setEnabled(True)
        self.studio_reset.setEnabled(True)
        self.export_btn.setEnabled(True)
        
    def select_file(self):
        file_path, _ = QFileDialog.getOpenFileName(
            self, "Wybierz zdjęcie", "", "Zdjęcia (*.jpg *.jpeg *.png)"
        )
        if file_path:
            self.load_image(file_path)
            
    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
            
    def dropEvent(self, event):
        for url in event.mimeData().urls():
            file_path = url.toLocalFile()
            if file_path.lower().endswith(('.png', '.jpg', '.jpeg')):
                self.load_image(file_path)
                break
                
    def load_image(self, file_path):
        self.state.reset_all()
        self.state.input_file_path = file_path
        self.file_info_lbl.setText(f"Plik: {os.path.basename(file_path)}")
        
        # Show progress
        self.canvas.hide()
        self.progress_frame.show()
        self.disable_controls()
        
        # Start background loader
        self.loader_thread = ImageLoaderWorker(file_path)
        self.loader_thread.finished.connect(self.on_image_loaded)
        self.loader_thread.start()
        
    def on_image_loaded(self, result):
        self.progress_frame.hide()
        self.canvas.show()
        
        if not result or result.get("pil_image") is None:
            err_msg = result.get("error", "Nieznany błąd (pusty wynik)") if result else "Pusty wynik"
            self.file_info_lbl.setText("Błąd ładowania pliku")
            QMessageBox.critical(
                self, 
                "Błąd ładowania obrazu", 
                f"Nie udało się załadować zdjęcia.\n\nSzczegóły błędu:\n{err_msg}"
            )
            return
            
        self.state.input_image = result["pil_image"]
        self.state.segmentation_mask = result["mask"]
        
        face_result = result["face_result"]
        if face_result:
            self.state.auto_scale = face_result["scale"]
            self.state.auto_offset_x = face_result["offset_x"]
            self.state.auto_offset_y = face_result["offset_y"]
            self.state.auto_rotation = face_result["rotation"]
            self.state.quality_warnings = face_result["warnings"]
        else:
            self.state.auto_scale = 1.0
            self.state.auto_offset_x = 0.0
            self.state.auto_offset_y = 0.0
            self.state.auto_rotation = 0.0
            self.state.quality_warnings = ["Nie wykryto twarzy. Użyj przybliżenia i przesunięcia do dopasowania."]
            
        # Update sliders and values
        self.sync_sliders()
        self.update_quality_status()
        self.enable_controls()
        
        # Run preview pipeline
        self.generate_preview()
        
    def generate_preview(self):
        if self.state.input_image is None:
            return
            
        # Optimization: Apply white background using cached mask
        processed = self.state.input_image
        if self.state.use_background_removal and self.state.segmentation_mask is not None:
            white_bg = Image.new("RGB", self.state.input_image.size, (255, 255, 255))
            processed = Image.composite(self.state.input_image.convert('RGB'), white_bg, self.state.segmentation_mask)
            
        if self.state.studio_effect_intensity > 0.0:
            processed = ImageProcessor.apply_studio_effect(processed, self.state.studio_effect_intensity)
            
        self.state.processed_preview_image = processed
        self.canvas.set_pil_image(processed)
        
    def sync_sliders(self):
        # Zoom (float 0.3 - 3.0 -> int 30 - 300)
        self.zoom_slider.setValue(int(self.state.zoom_scale * 100))
        self.zoom_val.setText(f"{int(self.state.zoom_scale * 100)}%")
        
        # Rotation (float -15.0 - 15.0 -> int -150 - 150)
        self.rot_slider.setValue(int(self.state.rotation_angle * 10))
        self.rot_val.setText(f"{self.state.rotation_angle:.1f}°")
        
        # Studio effect (float 0.0 - 1.5 -> int 0 - 150)
        self.studio_slider.setValue(int(self.state.studio_effect_intensity * 100))
        self.studio_val.setText(f"{int(self.state.studio_effect_intensity * 100)}%")
        
        # Background checkbox
        self.bg_checkbox.setChecked(self.state.use_background_removal)
        
    def on_zoom_changed(self, value):
        self.state.zoom_scale = value / 100.0
        self.zoom_val.setText(f"{value}%")
        self.canvas.update()
        
    def on_canvas_zoomed(self):
        # Callback from canvas mouse-wheel zoom
        self.zoom_slider.setValue(int(self.state.zoom_scale * 100))
        self.zoom_val.setText(f"{int(self.state.zoom_scale * 100)}%")
        
    def on_rotation_changed(self, value):
        self.state.rotation_angle = value / 10.0
        self.rot_val.setText(f"{self.state.rotation_angle:.1f}°")
        self.canvas.update()
        
    def on_studio_changed(self, value):
        self.state.studio_effect_intensity = value / 100.0
        self.studio_val.setText(f"{value}%")
        self.generate_preview()
        
    def on_bg_removal_toggled(self, state):
        self.state.use_background_removal = (state == Qt.CheckState.Checked.value)
        self.generate_preview()
        
    def reset_zoom(self):
        self.state.zoom_scale = 1.0
        self.zoom_slider.setValue(100)
        self.zoom_val.setText("100%")
        self.canvas.update()
        
    def reset_rotation(self):
        self.state.rotation_angle = 0.0
        self.rot_slider.setValue(0)
        self.rot_val.setText("0.0°")
        self.canvas.update()
        
    def reset_pan(self):
        self.state.pan_offset_x = 0.0
        self.state.pan_offset_y = 0.0
        self.canvas.update()
        
    def reset_studio_lighting(self):
        self.state.studio_effect_intensity = 0.0
        self.studio_slider.setValue(0)
        self.studio_val.setText("0%")
        self.generate_preview()
        
    def reset_all_adjustments(self):
        self.state.reset_manual_adjustments()
        self.sync_sliders()
        self.canvas.update()
        self.generate_preview()
        
    def update_quality_status(self):
        if not self.state.quality_warnings:
            self.status_lbl.setText("✓ Zdjęcie spełnia kryteria jakości.")
            self.status_lbl.setStyleSheet("color: #28a745; font-weight: bold; background-color: #1b3a24; padding: 6px; border-radius: 4px;")
        else:
            warnings_text = "⚠️ Ostrzeżenia jakości:\n" + "\n".join([f"• {w}" for w in self.state.quality_warnings])
            self.status_lbl.setText(warnings_text)
            self.status_lbl.setStyleSheet("color: #ffc107; background-color: #3a331a; padding: 6px; border-radius: 4px; border: 1px solid #ffc107;")
            
    def open_export_preview(self):
        dialog = ExportPreviewDialog(self.state, self)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            self.export_image(dialog.preview_image)
            
    def export_image(self, final_pil_image):
        file_path, _ = QFileDialog.getSaveFileName(
            self, "Zapisz gotowe zdjęcie", "biometric_photo.jpg", "JPEG Image (*.jpg)"
        )
        if file_path:
            success = ImageProcessor.save_as_jpeg(final_pil_image, file_path)
            if success:
                self.file_info_lbl.setText(f"Zapisano: {os.path.basename(file_path)}")
            else:
                self.file_info_lbl.setText("Błąd zapisu pliku!")


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())
