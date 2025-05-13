import os
from flask import Flask, request, jsonify, send_file
from gtts import gTTS
from flask_cors import CORS
from ultralytics import YOLO
from PIL import Image
import pytesseract

# Path to Tesseract executable (Windows)
pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

app = Flask(__name__)
CORS(app)

# Load YOLOv8 model
model = YOLO("yolov8n.pt")

# Static folder for saving files
STATIC_FOLDER = "static"
if not os.path.exists(STATIC_FOLDER):
    os.makedirs(STATIC_FOLDER)

@app.route('/')
def home():
    return "Flask server is running with YOLOv8 and Tesseract OCR!"

# ✅ Route 1: Object Detection Only
@app.route('/detect_objects', methods=['POST'])
def detect_objects():
    if 'image' not in request.files:
        return jsonify({"error": "No image uploaded"}), 400

    file = request.files['image']
    filepath = os.path.join(STATIC_FOLDER, "input.jpg")
    file.save(filepath)

    image = Image.open(filepath)

    results = model.predict(source=image, conf=0.1, save=False)
    detected_objects = set()
    for result in results:
        for box in result.boxes:
            class_id = int(box.cls.item())
            object_name = model.names[class_id]
            detected_objects.add(object_name)

    if not detected_objects:
        detected_objects.add("unknown object")

    objects_text = ", ".join(detected_objects)
    tts = gTTS(text=f"Detected objects are: {objects_text}", lang="en")
    audio_path = os.path.join(STATIC_FOLDER, "output.mp3")
    tts.save(audio_path)

    return jsonify({
        "objects": list(detected_objects),
        "audio": "output.mp3"
    })

# ✅ Route 2: Text Recognition Only
@app.route('/detect_text', methods=['POST'])
def detect_text():
    if 'image' not in request.files:
        return jsonify({"error": "No image uploaded"}), 400

    file = request.files['image']
    filepath = os.path.join(STATIC_FOLDER, "input.jpg")
    file.save(filepath)

    image = Image.open(filepath)

    extracted_text = pytesseract.image_to_string(image).strip()
    if not extracted_text:
        extracted_text = "No readable text"

    tts = gTTS(text=f"Detected text is: {extracted_text}", lang="en")
    audio_path = os.path.join(STATIC_FOLDER, "output.mp3")
    tts.save(audio_path)

    return jsonify({
        "text": extracted_text,
        "audio": "output.mp3"
    })

# ✅ Route 3: Serve Audio File
@app.route('/get_audio')
def get_audio():
    return send_file(os.path.join(STATIC_FOLDER, "output.mp3"), mimetype="audio/mpeg")

if __name__ == '__main__':
    app.run(debug=True, host="0.0.0.0", port=5019) 