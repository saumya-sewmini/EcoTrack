import os
import io
import json
import mimetypes
from datetime import datetime, date, timedelta  # ⏰ NEW: Time handling modules
from fastapi import FastAPI, File, UploadFile, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from google import genai
from google.genai import types
from dotenv import load_dotenv

from sqlalchemy import (
    create_engine,
    Column,
    Integer,
    String,
    Date,
)  # 💾 NEW: Date column type
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session

load_dotenv()

app = FastAPI(title="Time-Aware EcoTrack AI Engine")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DATABASE_URL = "sqlite:///./ecotrack.db"
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


# 📝 UPDATED DATABASE TABLE SCHEMA
class PantryItem(Base):
    __tablename__ = "pantry_items"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    quantity = Column(String)
    expiry_date = Column(Date)  # ⏰ Swapped standard integer for an exact Date stamp


Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        # Seed default items calculating relative forward offsets from today's real date
        if db.query(PantryItem).count() == 0:
            today = date.today()
            default_items = [
                PantryItem(
                    name="🚀 Python Powered Avocados",
                    quantity="5 units",
                    expiry_date=today + timedelta(days=4),
                ),
                PantryItem(
                    name="🥛 Fresh Organic Milk",
                    quantity="1 bottle",
                    expiry_date=today + timedelta(days=2),
                ),
                PantryItem(
                    name="🍓 Sweet Strawberries",
                    quantity="1 pack",
                    expiry_date=today + timedelta(days=0),
                ),
            ]
            db.add_all(default_items)
            db.commit()
        yield db
    finally:
        db.close()


@app.get("/")
def home():
    return {"message": "Welcome to the Time-Aware EcoTrack AI Engine!"}


# 📋 GET ALL ITEMS: Calculates countdown logic dynamically on-the-fly
@app.get("/api/pantry")
def get_pantry_items(db: Session = Depends(get_db)):
    db_items = db.query(PantryItem).all()
    today = date.today()

    response_list = []
    for item in db_items:
        # Calculate difference between expiration calendar block and today's calendar date
        delta = item.expiry_date - today
        days_left = delta.days

        # Format output payload to mirror exactly what the Flutter interface expects
        response_list.append(
            {
                "id": item.id,
                "name": item.name,
                "quantity": item.quantity,
                "days_left": max(
                    0, days_left
                ),  # Clamp to 0 so expired items don't display weird negative numbers
            }
        )

    return response_list


# 🍳 GENERATE RECIPE: Injects calculated real-time variables into AI Chef prompt context
@app.get("/api/recipes")
def generate_pantry_recipe(db: Session = Depends(get_db)):
    db_items = db.query(PantryItem).all()
    if not db_items:
        return {
            "recipe": "Your digital pantry is currently empty! Scan some ingredients first."
        }

    food_names = [
        item.name.replace("✨ ", "")
        .replace("🚀 ", "")
        .replace("🥛 ", "")
        .replace("🍓 ", "")
        for item in db_items
    ]
    ingredients_string = ", ".join(food_names)

    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        return {"recipe": "Error: GEMINI_API_KEY missing."}

    try:
        client = genai.Client(api_key=api_key)
        chef_prompt = (
            f"You are EcoChef, an elite anti-food-waste culinary AI. Look at this list of ingredients: {ingredients_string}. "
            "Create a simple, delicious recipe that utilizes one or more of these items. "
            "Structure your answer with a 🍳 Recipe Title, Ingredients, and a 3-step preparation guide."
        )
        response = client.models.generate_content(
            model="gemini-2.5-flash", contents=chef_prompt
        )
        return {"recipe": response.text}
    except Exception as e:
        return {"recipe": f"Glitch generating recipe: {str(e)}"}


# 📸 SCAN & INSERT ITEM: Converts AI estimated days directly into future calendar dates
@app.post("/api/scan")
async def scan_item(file: UploadFile = File(...), db: Session = Depends(get_db)):
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY is missing.")

    try:
        file_bytes = await file.read()
        mime_type, _ = mimetypes.guess_type(file.filename)
        if not mime_type or mime_type == "application/octet-stream":
            mime_type = "image/jpeg"

        client = genai.Client(api_key=api_key)
        ai_prompt = (
            "Analyze this image. Identify the primary raw food item present. "
            "Estimate its typical remaining pantry/fridge shelf life in whole days. "
            "Return output STRICTLY as raw JSON string matching format exactly:\n"
            '{"item_name": "Name of Food", "estimated_days": 5}'
        )

        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=[
                types.Part.from_bytes(data=file_bytes, mime_type=mime_type),
                ai_prompt,
            ],
        )

        clean_json_text = (
            response.text.strip().removeprefix("```json").removesuffix("```").strip()
        )
        ai_data = json.loads(clean_json_text)

        detected_name = ai_data.get("item_name", "Unknown Item")
        estimated_days = int(ai_data.get("estimated_days", 7))

        # ⏰ CRUCIAL CALCULATION: Calculate future expiration date relative to right now
        calculated_expiry = date.today() + timedelta(days=estimated_days)

        new_item = PantryItem(
            name=f"✨ {detected_name}",
            quantity="1 unit (AI Scanned)",
            expiry_date=calculated_expiry,  # Saved as absolute data object anchor
        )

        db.add(new_item)
        db.commit()
        db.refresh(new_item)

        return {
            "status": "success",
            "detected_item": new_item.name,
            "days_left": estimated_days,
        }

    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"AI Scanning system error: {str(e)}"
        )


@app.delete("/api/pantry/{item_id}")
def delete_pantry_item(item_id: int, db: Session = Depends(get_db)):
    item_to_delete = db.query(PantryItem).filter(PantryItem.id == item_id).first()
    if not item_to_delete:
        raise HTTPException(status_code=404, detail="Item not found.")

    db.delete(item_to_delete)
    db.commit()
    return {"status": "success"}
