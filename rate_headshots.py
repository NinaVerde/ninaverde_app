import cv2
import os
import numpy as np
from PIL import Image

def analyze_realism(img_path):
    """
    Analyze an image and return a realism score (1-9).
    1 = most cartoon-like, 9 = most photorealistic
    """
    # Load image
    img = cv2.imread(img_path)
    if img is None:
        return 5  # Default if can't load
    
    # Convert to different color spaces
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    
    scores = []
    
    # 1. Color Variance Analysis
    # Photorealistic images have more varied, natural color distributions
    color_std = np.std(img)
    saturation_std = np.std(hsv[:,:,1])
    color_score = min(9, max(1, int((color_std / 30) * 3 + (saturation_std / 30) * 3)))
    scores.append(color_score)
    
    # 2. Edge Analysis
    # Cartoon images have cleaner, more defined edges
    edges = cv2.Canny(gray, 50, 150)
    edge_density = np.sum(edges > 0) / edges.size
    # Lower edge density often means smoother, more realistic gradients
    edge_score = min(9, max(1, int(9 - (edge_density * 30))))
    scores.append(edge_score)
    
    # 3. Texture Complexity (Laplacian variance)
    # More texture detail = more realistic
    laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
    texture_score = min(9, max(1, int((laplacian_var / 100) * 2 + 3)))
    scores.append(texture_score)
    
    # 4. Histogram Analysis
    # Photorealistic images tend to have more spread-out histograms
    hist = cv2.calcHist([gray], [0], None, [256], [0, 256])
    hist_std = np.std(hist)
    hist_score = min(9, max(1, int((hist_std / 50) * 3 + 2)))
    scores.append(hist_score)
    
    # 5. Smoothness (bilateral filtering difference)
    # Cartoon images change less after smoothing
    blurred = cv2.bilateralFilter(img, 9, 75, 75)
    diff = np.mean(np.abs(img.astype(float) - blurred.astype(float)))
    smooth_score = min(9, max(1, int((diff / 5) + 3)))
    scores.append(smooth_score)
    
    # Average all scores and round
    final_score = int(round(np.mean(scores)))
    final_score = max(1, min(9, final_score))  # Clamp to 1-9
    
    return final_score

def rate_and_rename_headshots():
    """
    Analyze all headshots and rename them with appropriate R ratings.
    """
    headshots_dir = r"C:\Users\adsta\Desktop\Nina Verde\ninaverde_app\assets\images\angelina\head_shots"
    
    if not os.path.exists(headshots_dir):
        print(f"Error: Directory not found: {headshots_dir}")
        return
    
    # Get all current headshot files
    files = [f for f in os.listdir(headshots_dir) if f.startswith("AngelinaHeadShot") and f.endswith(".jpg")]
    files.sort()
    
    print(f"Found {len(files)} headshots to rate...")
    print("-" * 60)
    
    ratings_count = {i: 0 for i in range(1, 10)}
    
    for filename in files:
        filepath = os.path.join(headshots_dir, filename)
        
        # Analyze the image
        rating = analyze_realism(filepath)
        ratings_count[rating] += 1
        
        # Extract the parts from the filename
        # Format: AngelinaHeadShot[N]_[SourceName]_R[old].jpg
        try:
            # Split by underscores and reconstruct
            parts = filename.replace('.jpg', '').split('_')
            
            # parts[0] = "AngelinaHeadShotN"
            # parts[1...-1] = source name parts
            # parts[-1] = "Rold"
            
            num_part = parts[0].replace('AngelinaHeadShot', '')
            source_parts = parts[1:-1]  # Everything between number and R rating
            source_name = '_'.join(source_parts)
            
            new_filename = f"AngelinaHeadShot{num_part}_{source_name}_R{rating}.jpg"
            new_filepath = os.path.join(headshots_dir, new_filename)
            
            # Rename if different
            if filename != new_filename:
                os.rename(filepath, new_filepath)
                print(f"[OK] {filename} -> R{rating} (renamed to {new_filename})")
            else:
                print(f"[OK] {filename} -> R{rating} (already correct)")
                
        except Exception as e:
            print(f"[ERROR] Error processing {filename}: {e}")
    
    print("-" * 60)
    print("\nRating Distribution:")
    for rating in range(1, 10):
        count = ratings_count[rating]
        bar = "#" * count
        print(f"R{rating}: {bar} ({count})")
    
    print(f"\nTotal: {sum(ratings_count.values())} headshots rated")

if __name__ == "__main__":
    rate_and_rename_headshots()
