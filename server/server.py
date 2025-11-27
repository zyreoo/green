from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
import cv2
import numpy as np
import mediapipe as mp




app = FastAPI()



app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)



mp_hands = mp.solutions.hands

hands = mp_hands.Hands(static_image_mode=True,
                       max_num_hands=2,
                       min_detection_confidence=0.5)


@app.post("/hand")



async def detect_hand(file: UploadFile = File(...)):

    img_bytes = await image.read()

    nparr = np.frombuffer(img_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    results = hands.process(img_rgb)



    if not results.multi_hand_landmarks:
        return {"message": "No hands detected"}
    

    hand_landmarks = results.multi_hand_landmarks[0]


    landmarks_3d = []

    for lm in hand_landmarks.landmark:
        landmarks_3d.append({
            "x": float(lm.x),
            "y": float(lm.y),
            "z": float(lm.z)
        })



    return {"landmarks_3d": landmarks_3d}

