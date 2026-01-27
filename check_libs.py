
import os
import sys

def check_imports():
    missing = []
    try:
        import cv2
        print("cv2: OK")
    except ImportError:
        missing.append("opencv-python")
    
    try:
        from PIL import Image
        print("PIL: OK")
    except ImportError:
        missing.append("Pillow")
        
    if missing:
        print(f"MISSING_LIBS: {','.join(missing)}")
        return False
    return True

if __name__ == "__main__":
    check_imports()
