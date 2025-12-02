import base64
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
mp_face_mesh = mp.solutions.face_mesh
mp_drawing = mp.solutions.drawing_utils
mp_styles = mp.solutions.drawing_styles

hands = mp_hands.Hands(
    static_image_mode=True,
    max_num_hands=2,
    min_detection_confidence=0.5
)
face_mesh = mp_face_mesh.FaceMesh(
    static_image_mode=True,
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5,
)


@app.post("/hand")
async def detect_hand(image: UploadFile = File(...)):
    img_bytes = await image.read()

    nparr = np.frombuffer(img_bytes, np.uint8)
    frame_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if frame_bgr is None:
        return {"message": "Invalid image data"}

    img_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
    hand_results = hands.process(img_rgb)
    face_results = face_mesh.process(img_rgb)

    annotated = frame_bgr.copy()
    hand_landmarks = []
    face_landmarks = []

    if hand_results.multi_hand_landmarks:
        for hand in hand_results.multi_hand_landmarks:
            mp_drawing.draw_landmarks(
                annotated,
                hand,
                mp_hands.HAND_CONNECTIONS,
                mp_styles.get_default_hand_landmarks_style(),
                mp_styles.get_default_hand_connections_style(),
            )

        first_hand = hand_results.multi_hand_landmarks[0]
        for lm in first_hand.landmark:
            hand_landmarks.append({
                "x": float(lm.x),
                "y": float(lm.y),
                "z": float(lm.z)
            })

    if face_results.multi_face_landmarks:
        for face in face_results.multi_face_landmarks:
            mp_drawing.draw_landmarks(
                annotated,
                face,
                mp_face_mesh.FACEMESH_TESSELATION,
                landmark_drawing_spec=None,
                connection_drawing_spec=mp_styles
                .get_default_face_mesh_tesselation_style(),
            )
            mp_drawing.draw_landmarks(
                annotated,
                face,
                mp_face_mesh.FACEMESH_CONTOURS,
                landmark_drawing_spec=None,
                connection_drawing_spec=mp_styles
                .get_default_face_mesh_contours_style(),
            )

        first_face = face_results.multi_face_landmarks[0]
        for lm in first_face.landmark:
            face_landmarks.append({
                "x": float(lm.x),
                "y": float(lm.y),
                "z": float(lm.z)
            })

    success, buffer = cv2.imencode(".jpg", annotated)
    frame_base64 = ""
    if success:
        frame_base64 = base64.b64encode(buffer).decode("utf-8")

    if not hand_landmarks and not face_landmarks:
        return {"message": "No hands detected", "frame": frame_base64}

    return {
        "hand_landmarks": hand_landmarks,
        "face_landmarks": face_landmarks,
        "frame": frame_base64
    }

