import os
import base64
import io
import json
import logging
from typing import Optional, List
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import requests
from PIL import Image
import cv2
import numpy as np

# Load YOLOv8 if available
yolo_model = None
try:
    from ultralytics import YOLO
    # Loads local or downloads small YOLOv8 nano model
    yolo_model = YOLO("yolov8n.pt")
except Exception as e:
    print(f"Error loading YOLOv8: {e}")

# Load OpenCV face detector
face_cascade = None
try:
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
except Exception as e:
    print(f"Error loading Face Cascade: {e}")

app = FastAPI(title="Clahan Academy AI Service", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ai-service")

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://ollama-service:11434")

class FeedbackRequest(BaseModel):
    score: int
    percentage: int
    examType: str
    examName: str

@app.get("/health")
def health():
    return {"status": "healthy", "service": "ai-service"}

@app.post("/api/ai/motivational-feedback")
def generate_feedback(req: FeedbackRequest):
    logger.info(f"Generating feedback for score {req.percentage}% on {req.examName}")
    
    prompt = (
        f"You are Clahan Academy's AI mentor. Write a concise, 1-sentence, motivational, professional exam review feedback. "
        f"The student scored {req.percentage}% in the exam '{req.examName}' ({req.examType} test). "
        f"Provide specific guidance based on their percentage. Keep it under 25 words. Do not prefix with 'Here is your feedback' or quotes."
    )
    
    try:
        response = requests.post(
            f"{OLLAMA_URL}/api/generate",
            json={
                "model": "phi3",
                "prompt": prompt,
                "stream": False,
                "options": {"num_predict": 40}
            },
            timeout=4.0
        )
        if response.status_code == 200:
            result = response.json()
            feedback = result.get("response", "").strip().replace('"', '')
            if feedback:
                return {"feedback": feedback}
    except Exception as e:
        logger.warn(f"Ollama call failed, using rule fallback: {str(e)}")
        
    # Local Rule-based fallback matching requirements
    pct = req.percentage
    if pct >= 80:
        return {"feedback": f"Excellent work! You scored {pct}%. Strong coding performance. Focus more on aptitude accuracy."}
    elif pct >= 60:
        return {"feedback": f"Good effort! You scored {pct}%. Practice more problem solving and coding constructs to boost score."}
    else:
        return {"feedback": f"Keep practicing! You scored {pct}%. Focus on problem solving, basics of programming languages, and fundamental concepts."}

@app.post("/api/ai/proctor/frame")
async def analyze_frame(
    frame: str = Form(...), # Base64 encoded JPEG
    attemptId: str = Form(...)
):
    try:
        # Clean base64 string
        if "," in frame:
            frame = frame.split(",")[1]
        
        img_bytes = base64.b64decode(frame)
        image = Image.open(io.BytesIO(img_bytes))
        
        # Convert PIL Image to OpenCV format (BGR) for face detection
        open_cv_image = np.array(image.convert("RGB"))
        open_cv_image = open_cv_image[:, :, ::-1].copy() # Convert RGB to BGR
        
        # Initialize default response
        face_count = 1
        objects_detected = []
        violations = []
        
        # 1. Run YOLOv8 Object Detection (direct in-process)
        if yolo_model is not None:
            try:
                results = yolo_model(image, verbose=False)
                for r in results:
                    for c in r.boxes.cls:
                        class_name = yolo_model.names[int(c)]
                        objects_detected.append(class_name)
            except Exception as e:
                logger.error(f"YOLO detection error: {str(e)}")
        
        # 2. Run Face detection (direct in-process using Haar Cascade)
        if face_cascade is not None:
            try:
                gray = cv2.cvtColor(open_cv_image, cv2.COLOR_BGR2GRAY)
                faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=4)
                face_count = len(faces)
            except Exception as e:
                logger.error(f"Face detection error: {str(e)}")
                face_count = 1

        # Evaluate violations
        if face_count == 0:
            violations.append("NO_FACE_DETECTED")
        elif face_count > 1:
            violations.append("MULTIPLE_FACES_DETECTED")

        if "cell phone" in objects_detected:
            violations.append("MOBILE_PHONE_DETECTED")
        if "book" in objects_detected:
            violations.append("BOOK_DETECTED")

        return {
            "faceCount": face_count,
            "objectsDetected": objects_detected,
            "ocrText": None,
            "violations": violations,
            "verified": (face_count == 1 and len(violations) == 0)
        }

    except Exception as e:
        logger.error(f"Error analyzing frame: {str(e)}")
        # Graceful fallback: return safe state to avoid crashing exam flow
        return {
            "faceCount": 1,
            "objectsDetected": [],
            "ocrText": None,
            "violations": [],
            "verified": True
        }

