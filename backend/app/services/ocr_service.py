import pytesseract
from PIL import Image
import io
import logging

logger = logging.getLogger(__name__)

class OCRService:
    @staticmethod
    def extract_text(file_content: bytes) -> str:
        """
        Extracts text from image bytes using Tesseract OCR.
        """
        try:
            image = Image.open(io.BytesIO(file_content))
            
            # Basic OCR
            text = pytesseract.image_to_string(image)
            
            if not text.strip():
                return "[OCR Result: No text found in image]"
                
            return text.strip()
            
        except Exception as e:
            logger.error(f"OCR Error: {e}")
            return f"[OCR Error: Could not process image. {str(e)}]"

    @staticmethod
    def is_image(filename: str) -> bool:
        """
        Check if file is a supported image format.
        """
        extensions = ('.png', '.jpg', '.jpeg', '.bmp', '.tiff', '.webp')
        return filename.lower().endswith(extensions)
