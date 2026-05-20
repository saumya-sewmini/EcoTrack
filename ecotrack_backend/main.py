from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
import io

app = FastAPI(title="EcoTrack AI Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 🛑 LIVE MEMORY DATABASE: This replaces our static list!
# It acts as a temporary database that updates live while the server is running.
pantry_database = [
    {
        "id": 1,
        "name": "🚀 Python Powered Avocados",
        "quantity": "5 units",
        "days_left": 4,
    },
    {"id": 2, "name": "🥛 Fresh Organic Milk", "quantity": "1 bottle", "days_left": 2},
    {"id": 3, "name": "🍓 Sweet Strawberries", "quantity": "1 pack", "days_left": 0},
]

@app.get("/")
def home():
    return {"message": "Welcome to the EcoTrack AI Backend Engine!"}

# Fetch items directly from our live database array
@app.get("/api/pantry")
def get_pantry_items():
    return pantry_database

@app.post("/api/scan")
async def scan_item(file: UploadFile = File(...)):
    print(f"📸 Scanning incoming file: {file.filename}")
    
    file_bytes = await file.read()
    image = Image.open(io.BytesIO(file_bytes))
    width, height = image.size
    
    # AI logic choice rule
    detected_name = "🍎 Fresh Red Apples" if width > height else "🥦 Fresh Organic Broccoli"
    
    # Create a new dynamic entry dictionary
    new_item = {
        "id": len(pantry_database) + 1,
        "name": detected_name,
        "quantity": "1 item (Scanned)",
        "days_left": 6
    }
    
    # 💾 SAVE STEP: Append this new scanned item straight into our running list!
    pantry_database.append(new_item)
    print(f"💾 Successfully saved {detected_name} to the active database list!")
    
    return {
        "status": "success",
        "filename": file.filename,
        "detected_item": detected_name,
        "days_left": 6,
        "confidence_score": "96.5%"
    }
