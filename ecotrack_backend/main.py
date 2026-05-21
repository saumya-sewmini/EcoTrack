import os
import io
import json
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from PIL import Image
from google import genai
from google.genai import types
import mimetypes
from dotenv import load_dotenv

load_dotenv()

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
    {
        "id": 1,
        "name": "Avocados",
        "quantity": "5 units",
        "days_left": 4,
    },
    {"id": 2, "name": "🥛 Fresh Organic Milk", "quantity": "1 bottle", "days_left": 2},
]


@app.get("/")
def home():
    return {"message": "Welcome to the EcoTrack AI Backend Engine!"}


@app.get("/api/pantry")
def get_pantry_items():
    return pantry_database


# Generates a custom recipe from active pantry ingredients
@app.get("/api/recipes")
def generate_pantry_recipe():
    print("🍳 AI Chef is looking through the pantry...")

    # Check if the user actually has items tracked
    if not pantry_database:
        return {
            "recipe": "Your digital pantry is currently empty! Scan some ingredients first so the AI Chef has something to work with."
        }

    # Extract just the clean food names from our database objects
    food_names = [
        item["name"]
        .replace("✨ ", "")
        .replace("🚀 ", "")
        .replace("🥛 ", "")
        .replace("🍓 ", "")
        for item in pantry_database
    ]
    ingredients_string = ", ".join(food_names)

    print(f"Ingredients passing to Chef: {ingredients_string}")

    # Initialize client safely using our verified setup
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        return {
            "recipe": "Error: GEMINI_API_KEY is missing from your .env configuration file."
        }

    try:
        client = genai.Client(api_key=api_key)

        chef_prompt = (
            f"You are EcoChef, an elite anti-food-waste culinary AI. Look at this list of ingredients "
            f"available in the user's kitchen: {ingredients_string}. \n\n"
            "Create a simple, delicious recipe that utilizes one or more of these items. "
            "Structure your answer clearly with a 🍳 Recipe Title, a brief Ingredients needed section, "
            "and a clear, numbered 3-step preparation guide. Keep the total response concise and fun!"
        )

        response = client.models.generate_content(
            model="gemini-2.5-flash", contents=chef_prompt
        )

        return {"recipe": response.text}

    except Exception as e:
        print(f"❌ EcoChef Error: {str(e)}")
        return {
            "recipe": "The kitchen is temporarily closed! Unable to generate a recipe right now."
        }


@app.post("/api/scan")
async def scan_item(file: UploadFile = File(...)):
    print(f"📸 Received file for AI analysis: {file.filename}")

    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=500, detail="GEMINI_API_KEY is missing from your .env file."
        )

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
