from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="EcoTrack AI Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[""],
    allow_credentials=True,
    allow_methods=[""],
    allow_headers=["*"],
)


@app.get("/")
def home():
    return {"message": "Welcome to the EcoTrack AI Backend Engine!"}


@app.get("/api/pantry")
def get_pantry_items():
    return [
        {
            "id": 1,
            "name": "🚀 Python Powered Avocados",
            "quantity": "5 units",
            "days_left": 4,
        },
        {
            "id": 2,
            "name": "🥛 Fresh Organic Milk",
            "quantity": "1 bottle",
            "days_left": 2,
        },
        {
            "id": 3,
            "name": "🍓 Sweet Strawberries",
            "quantity": "1 pack",
            "days_left": 0,
        },
    ]


@app.post("/api/scan")
async def scan_item(file: UploadFile = File(...)):
    # This is where our Python AI model will analyze the image later.
    # For now, it successfully intercepts the real file and responds dynamically!
    print("📸 Received file from Flutter: " + file.filename)

    return {
    "status": "success",
    "filename": file.filename,
    "detected_item": "🍉 Fresh Watermelon",
    "days_left": 7,
    "confidence_score": "94.2%"
}