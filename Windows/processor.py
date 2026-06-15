import cv2
import numpy as np
from PIL import Image, ImageEnhance
import io

class ImageProcessor:
    @staticmethod
    def apply_studio_effect(pil_image: Image.Image, intensity: float) -> Image.Image:
        """
        Emulates Apple's CIHighlightShadowAdjust and exposure filters in Python.
        Lifts dark shadows, normalizes exposure, and adjusts contrast.
        """
        if intensity <= 0.0:
            return pil_image
            
        img_np = np.array(pil_image.convert('RGB')).astype(float)
        
        # 1. Lift dark shadows (intensity threshold: pixels below 128 brightness)
        # Calculate grayscale luminance to detect shadows
        gray = 0.299 * img_np[:, :, 0] + 0.587 * img_np[:, :, 1] + 0.114 * img_np[:, :, 2]
        
        # Shadow mask: pixels with luminance < 128
        shadow_mask = gray < 128
        
        # Boost factor: maximum at 0 brightness, decreasing linearly to 0 at 128 brightness
        boost = (128.0 - gray) / 128.0 * (38.0 * intensity)
        
        # Apply shadow lift to R, G, B channels
        for c in range(3):
            img_np[:, :, c] += np.where(shadow_mask, boost, 0)
            
        # Clip values to [0, 255]
        img_np = np.clip(img_np, 0, 255).astype(np.uint8)
        output = Image.fromarray(img_np)
        
        # 2. Adjust color controls using Pillow's enhancers
        # Brightness boost (exposure boost)
        brightness_enhancer = ImageEnhance.Brightness(output)
        output = brightness_enhancer.enhance(1.0 + 0.03 * intensity)
        
        # Contrast boost
        contrast_enhancer = ImageEnhance.Contrast(output)
        output = contrast_enhancer.enhance(1.0 + 0.04 * intensity)
        
        # Saturation boost (color boost)
        color_enhancer = ImageEnhance.Color(output)
        output = color_enhancer.enhance(1.0 + 0.02 * intensity)
        
        return output

    @staticmethod
    def render_final_image(
        pil_image: Image.Image,
        scale: float,
        offset_x: float,
        offset_y: float,
        rotation: float, # in degrees
        studio_effect_intensity: float,
        use_background_removal: bool,
        segmentation_mask: Image.Image = None
    ) -> Image.Image:
        """
        Renders the image on a 684x883 canvas with transforms and AI settings applied.
        """
        # 1. Background removal
        processed_img = pil_image
        if use_background_removal and segmentation_mask is not None:
            # Create white background of the same size
            white_bg = Image.new("RGB", pil_image.size, (255, 255, 255))
            # Blend original and white background using mask
            processed_img = Image.composite(pil_image.convert('RGB'), white_bg, segmentation_mask)
            
        # 2. Studio Lighting
        if studio_effect_intensity > 0.0:
            processed_img = ImageProcessor.apply_studio_effect(processed_img, studio_effect_intensity)
            
        # Convert to NumPy for pixel-perfect OpenCV affine warp
        img_np = np.array(processed_img.convert('RGB'))
        h, w, _ = img_np.shape
        
        cx, cy = w / 2.0, h / 2.0
        
        # OpenCV warp matrix M
        # Note: rotation is negated in cv2 to match SwiftUI's clockwise rotation direction
        M = cv2.getRotationMatrix2D((cx, cy), -rotation, scale)
        
        # Adjust translation column to align the center with the target center (342 + dx, 441.5 + dy)
        M[0, 2] = 342.0 + offset_x - (M[0, 0] * cx + M[0, 1] * cy)
        M[1, 2] = 441.5 + offset_y - (M[1, 0] * cx + M[1, 1] * cy)
        
        # Warp image to exactly 684 x 883 pixels, filling empty margins with white (255, 255, 255)
        warped = cv2.warpAffine(
            img_np, M, (684, 883), 
            flags=cv2.INTER_LANCZOS4, 
            borderMode=cv2.BORDER_CONSTANT, 
            borderValue=(255, 255, 255)
        )
        
        return Image.fromarray(warped)

    @staticmethod
    def save_as_jpeg(pil_image: Image.Image, file_path: str) -> bool:
        """
        Saves PIL Image as JPEG, ensuring file size is under 2.5 MB.
        """
        quality = 95
        max_size_bytes = 2500000 # 2.5 MB
        
        # Save dynamically checking size
        while quality >= 50:
            buffer = io.BytesIO()
            pil_image.save(buffer, format="JPEG", quality=quality)
            size = buffer.tell()
            if size <= max_size_bytes:
                try:
                    with open(file_path, "wb") as f:
                        f.write(buffer.getvalue())
                    return True
                except Exception as e:
                    print(f"Error saving file: {e}")
                    return False
            quality -= 5
            
        return False
