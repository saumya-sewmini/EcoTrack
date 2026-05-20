from fastapi import FastAPI

app = FastAPI(title="EcoTrack AI Backend")


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
