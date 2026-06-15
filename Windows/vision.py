import cv2
import numpy as np
import mediapipe as mp
import math
from PIL import Image

class VisionHelper:
    def __init__(self):
        # Initialize MediaPipe models
        self.mp_face_mesh = mp.solutions.face_mesh.FaceMesh(
            static_image_mode=True,
            max_num_faces=1,
            refine_landmarks=True,
            min_detection_confidence=0.5
        )
        self.mp_selfie_segmentation = mp.solutions.selfie_segmentation.SelfieSegmentation(
            model_selection=0 # general model
        )
        
    def detect_face(self, pil_image: Image.Image):
        """
        Detects face landmarks, calculates biometric alignment parameters, 
        and extracts head tilt (roll) for auto-leveling.
        """
        # Convert PIL to RGB numpy array for OpenCV/MediaPipe
        img_np = np.array(pil_image.convert('RGB'))
        h, w, _ = img_np.shape
        
        # Run FaceMesh
        results = self.mp_face_mesh.process(img_np)
        
        if not results.multi_face_landmarks:
            return None
            
        landmarks = results.multi_face_landmarks[0].landmark
        
        # Biometric point indices in MediaPipe Face Mesh
        # 152: bottom of chin
        # 10: top center of forehead / hairline
        # 33: left eye corner (outer)
        # 263: right eye corner (outer)
        
        chin = landmarks[152]
        forehead = landmarks[10]
        left_eye = landmarks[33]
        right_eye = landmarks[263]
        
        # Calculate Roll angle (head tilt)
        # delta Y / delta X in image coordinates (Y increases downwards)
        dy = right_eye.y - left_eye.y
        dx = right_eye.x - left_eye.x
        roll = math.degrees(math.atan2(dy, dx))
        
        # Calculate face height in normalized units
        # (Y increases downwards, so chin.y > forehead.y)
        face_height_norm = chin.y - forehead.y
        
        # Estimate the crown of the head (hair top). 
        # The hair top is roughly 1.4x the distance from chin to forehead hairline
        head_top_norm_y = chin.y - face_height_norm * 1.40
        
        # Convert to pixel coordinates
        px_chin = (chin.x * w, chin.y * h)
        px_head_top = (chin.x * w, head_top_norm_y * h)
        px_face_height = px_chin[1] - px_head_top[1]
        
        # Target face height in a 684x883 canvas is 667 pixels (34mm in 35x45mm ratio)
        target_face_height = 667.0
        
        # Calculate autoScale
        auto_scale = 1.0
        if px_face_height > 0:
            auto_scale = target_face_height / px_face_height
            
        # SwiftUI coordinate math adapted for Qt:
        # We want to translate the chin point in the scaled image to align at X = 342, Y = 745.
        # Image center is placed at canvas center (342, 441.5) by default.
        # In Qt / PIL coordinate systems: origin is top-left, Y increases downwards.
        px_chin_y_swiftui = chin.y * h
        px_chin_x_swiftui = chin.x * w
        
        dx_offset = -auto_scale * (px_chin_x_swiftui - w / 2.0)
        dy_offset = (883.0 - 138.0) - 441.5 - auto_scale * (px_chin_y_swiftui - h / 2.0)
        
        # Quality warnings
        warnings = []
        if abs(roll) > 6.0:
            warnings.append(f"Przechylenie głowy w bok: {roll:.0f}° (wyprostuj twarz)")
            
        # Calculate yaw check (horizontal eye centering asymmetry)
        nose = landmarks[1]
        dist_left = abs(nose.x - left_eye.x)
        dist_right = abs(right_eye.x - nose.x)
        asymmetry = abs(dist_left - dist_right) / max(dist_left, dist_right)
        if asymmetry > 0.22:
            warnings.append("Głowa obrócona w bok (patrz na wprost)")
            
        # Brightness warning
        brightness = self.get_face_brightness(pil_image, landmarks)
        if brightness < 0.22:
            warnings.append(f"Zdjęcie jest za ciemne (jasność: {brightness*100:.0f}%)")
        elif brightness > 0.85:
            warnings.append("Zdjęcie twarzy jest prześwietlone")
            
        return {
            "scale": auto_scale,
            "offset_x": dx_offset,
            "offset_y": dy_offset,
            "rotation": -roll, # auto-rotation angle (negated to level face)
            "warnings": warnings,
            "chin_x": px_chin_x_swiftui,
            "chin_y": px_chin_y_swiftui
        }
        
    def generate_segmentation_mask(self, pil_image: Image.Image) -> Image.Image:
        """
        Runs selfies segmentation and returns a high-contrast black-and-white 
        mask image representing the foreground person (white) and background (black).
        """
        img_np = np.array(pil_image.convert('RGB'))
        
        # Run segmentation
        results = self.mp_selfie_segmentation.process(img_np)
        
        if results.segmentation_mask is None:
            # Return solid white mask (no background removal)
            return Image.new("L", pil_image.size, 255)
            
        # The segmentation mask is a float32 array of shape (h, w)
        # where values close to 1.0 represent the foreground
        mask = results.segmentation_mask
        
        # Convert to 8-bit mask (0-255) with a slight threshold/softening
        mask_8bit = (mask > 0.5).astype(np.uint8) * 255
        
        # Apply minor Gaussian blur to smooth the edges
        mask_smoothed = cv2.GaussianBlur(mask_8bit, (5, 5), 0)
        
        return Image.fromarray(mask_smoothed, mode="L")
        
    def get_face_brightness(self, pil_image: Image.Image, landmarks) -> float:
        """
        Crops the face bounding box and calculates its average brightness.
        """
        w, h = pil_image.size
        # Bounding box from landmarks
        x_coords = [lm.x for lm in landmarks]
        y_coords = [lm.y for lm in landmarks]
        
        min_x, max_x = int(min(x_coords) * w), int(max(x_coords) * w)
        min_y, max_y = int(min(y_coords) * h), int(max(y_coords) * h)
        
        # Crop face box
        face_box = (
            max(0, min_x),
            max(0, min_y),
            min(w, max_x),
            min(h, max_y)
        )
        if face_box[2] <= face_box[0] or face_box[3] <= face_box[1]:
            return 0.5
            
        cropped = pil_image.crop(face_box).convert('L')
        # Get mean pixel value (0-255)
        stat = np.array(cropped)
        if stat.size == 0:
            return 0.5
        return float(np.mean(stat)) / 255.0
        
    def close(self):
        self.mp_face_mesh.close()
        self.mp_selfie_segmentation.close()
