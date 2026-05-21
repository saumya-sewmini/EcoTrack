import os
import io
import json
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
from google import genai
from google.genai import types
import mimetypes

app = FastAPI(title="EcoTrack AI Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 💾 Active Memory Database
pantry_database = [
    {"id": 1, "name": "🚀 Python Powered Avocados", "quantity": "5 units", "days_left": 4},
    {"id": 2, "name": "🥛 Fresh Organic Milk", "quantity": "1 bottle", "days_left": 2},
    {"id": 3, "name": "🍓 Sweet Strawberries", "quantity": "1 pack", "days_left": 0}
]

@app.get("/")
def home():
    return {"message": "Welcome to the EcoTrack AI Backend Engine!"}

@app.get("/api/pantry")
def get_pantry_items():
    return pantry_database

@app.post("/api/scan")
async def scan_item(file: UploadFile = File(...)):
    print(f"📸 Received file for AI analysis: {file.filename}")

    api_key = os.environ.get("GEMINI_API_KEY", "AIzaSyCdwpBmWYl_wcxgdSHgbELw6FKNUHtD9Nw")

    try:
        # 1. Read the file bytes directly
        file_bytes = await file.read()

        # 2. 🧠 SMART MIME-TYPE FIX:
        # Check the filename extension to figure out the real image format
        mime_type, _ = mimetypes.guess_type(file.filename)
        if not mime_type or mime_type == "application/octet-stream":
            # Default to image/jpeg if guessing fails, which works for most photos!
            mime_type = "image/jpeg"
            
        print(f"⚙️ Overriding transmission label to valid type: {mime_type}")

        # 3. Initialize the Google Gen AI Client
        client = genai.Client(api_key=api_key)

        # 4. Construct a strict structured output prompt
        ai_prompt = (
            "Analyze this image. Identify the primary raw food, grocery, or produce item present. "
            "Estimate its typical remaining pantry/fridge shelf life in whole days. "
            "Return the output STRICTLY as a raw JSON string matching this format exactly, with no markdown code blocks:\n"
            '{"item_name": "Name of Food", "estimated_days": 5}'
        )

        print("🤖 Sending image payload to Gemini AI...")

        # 5. Execute the multimodal vision call using the correct mime_type variable
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=[
                types.Part.from_bytes(data=file_bytes, mime_type=mime_type),
                ai_prompt,
            ],
        )

        # 6. Parse the response text safely
        clean_json_text = (
            response.text.strip().removeprefix("```json").removesuffix("```").strip()
        )
        ai_data = json.loads(clean_json_text)

        detected_name = ai_data.get("item_name", "Unknown Grocery Item")
        days_left = ai_data.get("estimated_days", 7)

        print(f"✨ Gemini identified: {detected_name} (Shelf life: {days_left} days)")

        # 7. Package and save to our persistent pantry dashboard array
        new_item = {
            "id": len(pantry_database) + 1,
            "name": f"✨ {detected_name}",
            "quantity": "1 unit (AI Scanned)",
            "days_left": int(days_left),
        }

        pantry_database.append(new_item)
        print(f"💾 Saved {detected_name} to the active database list!")

        return {
            "status": "success",
            "filename": file.filename,
            "detected_item": f"✨ {detected_name}",
            "days_left": days_left,
            "confidence_score": "Verified via Gemini AI",
        }

    except Exception as e:
        print(f"❌ AI Processing Exception: {str(e)}")
        raise HTTPException(status_code=500, detail=f"AI Processing failed: {str(e)}")