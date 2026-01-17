
import os
from PIL import Image

SOURCE_DIR = r"C:\Users\adsta\OneDrive\Documents\Nina Verde\Angelina VR Hostess"
DEST_DIR = os.path.join(SOURCE_DIR, "head shots")

if not os.path.exists(DEST_DIR):
    os.makedirs(DEST_DIR)

files = [f for f in os.listdir(SOURCE_DIR) if f.lower().endswith(('.png', '.jpg', '.jpeg'))]

print(f"Found {len(files)} images. Processing...")

for f in files:
    try:
        path = os.path.join(SOURCE_DIR, f)
        img = Image.open(path)
        w, h = img.size
        
        # Heuristic: Head is usually in the top center.
        # Crop a square anchored at the top center.
        
        # Determine crop size (smaller of width or 1/2 height to avoid getting too much body)
        crop_size = min(w, int(h * 0.5))
        
        # Center X
        center_x = w // 2
        left = max(0, center_x - crop_size // 2)
        right = min(w, center_x + crop_size // 2)
        top = 0 # Start from top
        bottom = crop_size
        
        # Adjust if crop size is wider than image (can happen if image is portrait)
        # Re-calc
        if (right - left) < crop_size:
            # Image is too narrow, just take full width and top square
            left = 0
            right = w
            bottom = w # Square
        
        # Fine tuning: usually head starts a bit below top if it's a full body shot, 
        # but for VR hostess styling, top crop is usually safe for "Headshot" if we assume full height image.
        # Let's try a strict top-center crop.
        
        box = (left, top, right, bottom)
        crop = img.crop(box)
        
        dest_path = os.path.join(DEST_DIR, f"headshot_{f}")
        crop.save(dest_path)
        print(f"Saved {dest_path}")
        
    except Exception as e:
        print(f"Skipped {f}: {e}")

print("Done.")
