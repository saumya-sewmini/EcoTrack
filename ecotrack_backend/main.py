import os
import io
import json
import mimetypes
from datetime import datetime, date, timedelta
from typing import List, Dict, Any

from fastapi import FastAPI, File, UploadFile, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from google import genai
from google.genai import types
from dotenv import load_dotenv

from sqlalchemy import create_engine, Column, Integer, String, Date
from sqlalchemy.orm import declarative_base, sessionmaker, Session

load_dotenv()

app = FastAPI(title="Time-Aware EcoTrack AI Engine")

# Security Constraints: Cross-Origin Resource Sharing Rules
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Persistence Subsystem Configuration
DATABASE_URL = "sqlite:///./ecotrack.db"
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class PantryItem(Base):
    __tablename__ = "pantry_items"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True, nullable=False)
    quantity = Column(String, nullable=False)
    expiry_date = Column(Date, nullable=False)


Base.metadata.create_all(bind=engine)


# Pydantic Schema for Guaranteed AI Output Geometry
class FoodScanResult(BaseModel):
    item_name: str = Field(
        description="The formal, common text name of the identified raw food item."
    )
    estimated_days: int = Field(
        description="Estimated safe remaining shelf-life margin expressed in total integer days."
    )


def get_db():
    db = SessionLocal()
    try:
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


@app.get("/", status_code=status.HTTP_200_OK)
def home() -> Dict[str, str]:
    return {"status": "healthy", "engine": "Time-Aware EcoTrack AI Engine v1.0.0"}


@app.get("/api/pantry", response_model=List[Dict[str, Any]])
def get_pantry_items(db: Session = Depends(get_db)):
    db_items = db.query(PantryItem).all()
    today = date.today()

    response_list = []
    for item in db_items:
        delta = item.expiry_date - today
        # Enforce baseline zero bounds to prevent negative tracking calculations downstream
        days_left = max(0, delta.days)

        response_list.append(
            {
                "id": item.id,
                "name": item.name,
                "quantity": item.quantity,
                "days_left": days_left,
            }
        )

    return response_list


@app.get("/api/recipes", status_code=status.HTTP_200_OK)
def generate_pantry_recipe(db: Session = Depends(get_db)) -> Dict[str, str]:
    db_items = db.query(PantryItem).all()
    if not db_items:
        return {
            "recipe": "Your digital pantry is currently empty! Scan some ingredients first."
        }

    # Normalize name keys by stripping presentation emojis before context packaging
    clean_items = [
        item.name.replace("✨ ", "")
        .replace("🚀 ", "")
        .replace("🥛 ", "")
        .replace("🍓 ", "")
        for item in db_items
    ]
    ingredients_string = ", ".join(clean_items)

    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="GEMINI_API_KEY environment variable is uninitialized.",
        )

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
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Upstream model inference cycle failed: {str(e)}",
        )


@app.post("/api/scan", status_code=status.HTTP_201_CREATED)
def scan_item(
    file: UploadFile = File(...), db: Session = Depends(get_db)
) -> Dict[str, Any]:
    """
    Processes incoming binary asset streams via worker pools.
    Swapped to a standard 'def' boundary layer to prevent async loop stalling
    during compute-heavy blocking IO.
    """
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="GEMINI_API_KEY environment variable is uninitialized.",
        )

    try:
        # Read the file contents synchronously using the underlying file object descriptor
        file_bytes = file.file.read()
        mime_type, _ = mimetypes.guess_type(file.filename)
        if not mime_type or mime_type == "application/octet-stream":
            mime_type = "image/jpeg"

        client = genai.Client(api_key=api_key)
        ai_prompt = (
            "Analyze this image. Identify the primary raw food item present. "
            "Estimate its typical remaining pantry/fridge shelf life in whole days."
        )

        # Enforce explicit structural constraints at the API gateway layer
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=[
                types.Part.from_bytes(data=file_bytes, mime_type=mime_type),
                ai_prompt,
            ],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=FoodScanResult,
            ),
        )

        # Response text is now guaranteed to follow the FoodScanResult Pydantic schema perfectly
        ai_data = json.loads(response.text)
        detected_name = ai_data.get("item_name", "Unknown Item")
        estimated_days = int(ai_data.get("estimated_days", 7))

        calculated_expiry = date.today() + timedelta(days=estimated_days)

        new_item = PantryItem(
            name=f"✨ {detected_name}",
            quantity="1 unit (AI Scanned)",
            expiry_date=calculated_expiry,
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
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ingestion pipeline execution aborted: {str(e)}",
        )


@app.delete("/api/pantry/{item_id}", status_code=status.HTTP_200_OK)
def delete_pantry_item(item_id: int, db: Session = Depends(get_db)) -> Dict[str, str]:
    item_to_delete = db.query(PantryItem).filter(PantryItem.id == item_id).first()
    if not item_to_delete:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Target tracking record missing.",
        )

    db.delete(item_to_delete)
    db.commit()
    return {"status": "success"}
