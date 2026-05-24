import os
import io
import json
import mimetypes
from fastapi import FastAPI, File, UploadFile, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from google import genai
from google.genai import types
from dotenv import load_dotenv

# 📦 NEW DATABASE IMPORTS
from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session

load_dotenv()

app = FastAPI(title="EcoTrack AI Backend Engine")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 💾 SQLALCHEMY & SQLITE CONFIGURATION
DATABASE_URL = "sqlite:///./ecotrack.db"
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


# 📝 DATABASE TABLE SCHEMA MODEL
class PantryItem(Base):
    __tablename__ = "pantry_items"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    quantity = Column(String)
    days_left = Column(Integer)


# Build the ecotrack.db file and tables instantly if they don't exist yet
Base.metadata.create_all(bind=engine)


# 🔌 DEPENDENCY: Opens a secure database thread per request and closes it when done
def get_db():
    db = SessionLocal()
    try:
        # Seed default items on first boot if the database is brand new and empty
        if db.query(PantryItem).count() == 0:
            default_items = [
                PantryItem(
                    name="🚀 Python Powered Avocados", quantity="5 units", days_left=4
                ),
                PantryItem(
                    name="🥛 Fresh Organic Milk", quantity="1 bottle", days_left=2
                ),
                PantryItem(
                    name="🍓 Sweet Strawberries", quantity="1 pack", days_left=0
                ),
            ]
            db.add_all(default_items)
            db.commit()
        yield db
    finally:
        db.close()


@app.get("/")
def home():
    return {"message": "Welcome to the Persistent EcoTrack AI Backend Engine!"}


# 📋 GET ALL ITEMS: Fetches directly out of SQLite table
@app.get("/api/pantry")
def get_pantry_items(db: Session = Depends(get_db)):
    items = db.query(PantryItem).all()
    return items


# 🍳 GENERATE RECIPE: Pulls current items out of SQLite table to build the AI prompt
@app.get("/api/recipes")
def generate_pantry_recipe(db: Session = Depends(get_db)):
    print("🍳 AI Chef is querying the SQLite database...")
    pantry_items = db.query(PantryItem).all()

    if not pantry_items:
        return {
            "recipe": "Your digital pantry is currently empty! Scan some ingredients first."
        }

    food_names = [
        item.name.replace("✨ ", "")
        .replace("🚀 ", "")
        .replace("🥛 ", "")
        .replace("🍓 ", "")
        for item in pantry_items
    ]
    ingredients_string = ", ".join(food_names)

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
            "Structure your answer clearly with a 🍳 Recipe Title, a brief Ingredients section, "
            "and a clear, numbered 3-step preparation guide. Keep the total response concise and fun!"
        )
        response = client.models.generate_content(
            model="gemini-2.5-flash", contents=chef_prompt
        )
        return {"recipe": response.text}
    except Exception as e:
        print(f"❌ EcoChef Error: {str(e)}")
        return {"recipe": f"The kitchen hit an execution glitch: {str(e)}"}


# 📸 SCAN & INSERT ITEM: Converts AI image scan directly into a committed SQLite row
@app.post("/api/scan")
async def scan_item(file: UploadFile = File(...), db: Session = Depends(get_db)):
    print(f"📸 Received file for AI analysis: {file.filename}")

    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=500, detail="GEMINI_API_KEY is missing from your .env file."
        )

    try:
        file_bytes = await file.read()
        mime_type, _ = mimetypes.guess_type(file.filename)
        if not mime_type or mime_type == "application/octet-stream":
            mime_type = "image/jpeg"

        print(f"⚙️ Overriding transmission label to valid type: {mime_type}")
        client = genai.Client(api_key=api_key)

        ai_prompt = (
            "Analyze this image. Identify the primary raw food, grocery, or produce item present. "
            "Estimate its typical remaining pantry/fridge shelf life in whole days. "
            "Return the output STRICTLY as a raw JSON string matching this format exactly, with no markdown code blocks:\n"
            '{"item_name": "Name of Food", "estimated_days": 5}'
        )

        print("🤖 Sending image payload to Gemini AI...")
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

        detected_name = ai_data.get("item_name", "Unknown Grocery Item")
        days_left = ai_data.get("estimated_days", 7)

        print(f"✨ Gemini identified: {detected_name} (Shelf life: {days_left} days)")

        # 🌟 NEW: Create a new row entry instance using our SQLAlchemy model class
        new_item = PantryItem(
            name=f"✨ {detected_name}",
            quantity="1 unit (AI Scanned)",
            days_left=int(days_left),
        )

        # Stage, execute, and lock the item into our local hard drive storage file permanent pipeline
        db.add(new_item)
        db.commit()
        db.refresh(new_item)  # Populates the auto-generated unique ID field

        print(f"💾 Saved {detected_name} directly to ecotrack.db file!")

        return {
            "status": "success",
            "filename": file.filename,
            "detected_item": new_item.name,
            "days_left": new_item.days_left,
            "confidence_score": "Verified via Gemini AI & Saved Permanently",
        }

    except Exception as e:
        print(f"❌ AI Processing Exception: {str(e)}")
        raise HTTPException(status_code=500, detail=f"AI Processing failed: {str(e)}")


# 🗑️ DELETE ITEM: Finds specific item entry row in SQLite and purges it
@app.delete("/api/pantry/{item_id}")
def delete_pantry_item(item_id: int, db: Session = Depends(get_db)):
    print(f"🗑️ Database request received to delete item ID: {item_id}")

    # Query the item row inside SQLite matching this specific target ID
    item_to_delete = db.query(PantryItem).filter(PantryItem.id == item_id).first()

    if not item_to_delete:
        raise HTTPException(
            status_code=404, detail="Item not found in your SQLite database."
        )

    # Execute structural drop command
    db.delete(item_to_delete)
    db.commit()

    print(f"💾 Database updated. Item ID {item_id} has been dropped.")
    return {
        "status": "success",
        "message": f"Item {item_id} successfully dropped from ecotrack.db.",
    }
