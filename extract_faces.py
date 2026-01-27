
import cv2
import os
import sys
import time

def extract_faces():
    # Setup paths
    base_dir = r"C:\Users\adsta\Desktop\Nina Verde\ninaverde_app\assets\images\angelina"
    output_dir = os.path.join(base_dir, "head_shots")
    
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"Created directory: {output_dir}")

    # Load Haar Cascade
    cascade_path = cv2.data.haarcascades + 'haarcascade_frontalface_default.xml'
    face_cascade = cv2.CascadeClassifier(cascade_path)
    
    if face_cascade.empty():
        print("Error: Could not load Haar Cascade XML.")
        # Try local path or standard paths if needed, but cv2.data usually works
        return

    # Get images
    extensions = ('.jpg', '.jpeg', '.png', '.webp')
    files = [f for f in os.listdir(base_dir) if f.lower().endswith(extensions)]
    
    print(f"Found {len(files)} images to process.")
    
    count = 1
    
    for filename in files:
        img_path = os.path.join(base_dir, filename)
        img = cv2.imread(img_path)
        
        if img is None:
            print(f"Failed to load {filename}")
            continue
            
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Detect faces
        faces = face_cascade.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(30, 30),
            flags=cv2.CASCADE_SCALE_IMAGE
        )
        
        print(f"Processing {filename}: Found {len(faces)} faces.")
        
        for (x, y, w, h) in faces:
            # Add padding (make it a bit looser like a portrait)
            padding_x = int(w * 0.2)
            padding_y_top = int(h * 0.5) # More headroom
            padding_y_bot = int(h * 0.2) 
            
            # Start/End coords with bounds checking
            start_y = max(0, y - padding_y_top)
            end_y = min(img.shape[0], y + h + padding_y_bot)
            start_x = max(0, x - padding_x)
            end_x = min(img.shape[1], x + w + padding_x)
            
            # Crop
            face_img = img[start_y:end_y, start_x:end_x]
            
            if face_img.size == 0:
                continue
                
            # Extract source name (without extension)
            source_name = os.path.splitext(filename)[0].replace('angelina_', '')
            
            # Construct output filename
            # Format: AngelinaHeadShot[N]_[SourceName]_R[1-9].jpg
            out_name = f"AngelinaHeadShot{count}_{source_name}_R5.jpg" 
            out_path = os.path.join(output_dir, out_name)
            
            cv2.imwrite(out_path, face_img)
            print(f"Saved {out_name}")
            
            count += 1

if __name__ == "__main__":
    try:
        extract_faces()
    except Exception as e:
        print(f"An error occurred: {e}")
