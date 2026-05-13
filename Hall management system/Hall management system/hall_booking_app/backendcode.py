from __future__ import annotations

import hashlib
import hmac
import json
import os
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
from math import asin, cos, radians, sin, sqrt

from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import or_
from werkzeug.security import check_password_hash, generate_password_hash
from dotenv import load_dotenv

app = Flask(__name__, static_folder="assets", static_url_path="/assets")

# Load .env from parent folder
here = os.path.abspath(os.path.dirname(__file__))
dotenv_path = os.path.join(here, "..", ".env")
load_dotenv(dotenv_path)

# ─────────────────────────────────────────────
#  CORS
# ─────────────────────────────────────────────
CORS(app, resources={r"/*": {"origins": "*"}},
     supports_credentials=False,
     allow_headers=["Content-Type", "Authorization", "Accept"],
     methods=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"])

@app.after_request
def apply_cors_headers(response):
    response.headers["Access-Control-Allow-Origin"]  = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS, PATCH"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, Accept"
    return response

@app.before_request
def handle_options():
    if request.method == "OPTIONS":
        response = app.make_default_options_response()
        response.headers["Access-Control-Allow-Origin"]  = "*"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS, PATCH"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, Accept"
        return response

# ─────────────────────────────────────────────
#  DATABASE
# ─────────────────────────────────────────────
SQL_SERVER   = os.getenv("SQL_SERVER",   r"localhost\SQLEXPRESS")
SQL_DATABASE = os.getenv("SQL_DATABASE", "MHDB")
SQL_DRIVER   = os.getenv("SQL_DRIVER",   "ODBC Driver 17 for SQL Server")

SQLALCHEMY_DATABASE_URI = (
    f"mssql+pyodbc://{SQL_SERVER}/{SQL_DATABASE}"
    f"?driver={SQL_DRIVER.replace(' ', '+')}"
    f"&trusted_connection=yes"
)

app.config["SQLALCHEMY_DATABASE_URI"]    = SQLALCHEMY_DATABASE_URI
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
    "fast_executemany": True,
    "pool_pre_ping":    True,
}

db = SQLAlchemy(app)

ADMIN_EMAIL    = os.getenv("ADMIN_EMAIL",    "admin@admin.com")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin123")

SMTP_SERVER   = "smtp.gmail.com"
SMTP_PORT     = 587
SMTP_USERNAME = os.getenv("SMTP_USERNAME", "your-email@gmail.com")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "your-app-password")
FROM_EMAIL    = os.getenv("FROM_EMAIL",    "your-email@gmail.com")
FROM_NAME     = "Shaadi Ghar"

# ─────────────────────────────────────────────
#  JAZZCASH CONFIG
# ─────────────────────────────────────────────
JAZZCASH_MERCHANT_ID    = os.getenv("JAZZCASH_MERCHANT_ID",    "your_merchant_id")
JAZZCASH_PASSWORD       = os.getenv("JAZZCASH_PASSWORD",       "your_jazzcash_password")
JAZZCASH_INTEGRITY_SALT = os.getenv("JAZZCASH_INTEGRITY_SALT", "your_integrity_salt")
JAZZCASH_API_URL        = os.getenv(
    "JAZZCASH_API_URL",
    "https://sandbox.jazzcash.com.pk/ApplicationAPI/API/2.0/Purchase/DoMWalletTransaction",
)
JAZZCASH_RETURN_URL = os.getenv(
    "JAZZCASH_RETURN_URL", "http://127.0.0.1:5000/payments/jazzcash/callback"
)

# ─────────────────────────────────────────────
#  IMAGE HELPERS
# ─────────────────────────────────────────────
_BASE_DIR           = os.path.dirname(os.path.abspath(__file__))
_FLUTTER_ASSETS_DIR = os.path.join(_BASE_DIR, "assets")
BACKEND_BASE_URL    = os.getenv("BACKEND_BASE_URL", "http://127.0.0.1:5000")


def asset_path_to_url(path: str) -> str:
    path = path.strip()
    if not path:
        return path
    if path.startswith("http://") or path.startswith("https://"):
        return path
    path = path.replace("\\", "/").lstrip("/")
    return f"{BACKEND_BASE_URL.rstrip('/')}/{path}"


# ─────────────────────────────────────────────
#  STATIC ASSET ROUTES
# ─────────────────────────────────────────────
@app.route("/assets/<path:relpath>")
def serve_assets(relpath: str):
    if not os.path.isdir(_FLUTTER_ASSETS_DIR):
        return jsonify({"error": "Assets directory not found."}), 404
    return send_from_directory(_FLUTTER_ASSETS_DIR, relpath)

@app.route("/app_assets/<path:relpath>")
def app_assets(relpath: str):
    if not os.path.isdir(_FLUTTER_ASSETS_DIR):
        return jsonify({"error": "Assets directory not found."}), 404
    return send_from_directory(_FLUTTER_ASSETS_DIR, relpath)


def utc_now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


# ─────────────────────────────────────────────
#  CITY COORDINATES
# ─────────────────────────────────────────────
CITY_COORDINATES = {
    "karachi":    (24.8607, 67.0011),
    "lahore":     (31.5204, 74.3587),
    "islamabad":  (33.6844, 73.0479),
    "rawalpindi": (33.5651, 73.0169),
    "faisalabad": (31.4504, 73.1350),
    "multan":     (30.1575, 71.5249),
    "peshawar":   (34.0151, 71.5249),
    "quetta":     (30.1798, 66.9750),
    "hyderabad":  (25.3960, 68.3578),
    "gujranwala": (32.1877, 74.1945),
    "sialkot":    (32.4945, 74.5229),
    "sargodha":   (32.0836, 72.6711),
    "bahawalpur": (29.3956, 71.6836),
}

# ─────────────────────────────────────────────
#  SEED DATA
# ─────────────────────────────────────────────
DEFAULT_PHOTOGRAPHERS = [
    {
        "name": "Fahad Photography", "phone": "03001112233",
        "email": "fahad@photo.pk", "city": "Karachi",
        "experience_years": 8, "price_per_day": Decimal("25000.00"),
        "portfolio_url": "https://instagram.com/fahadphoto",
        "description": "Specialist in wedding & mehndi photography with cinematic reels.",
        "is_available": True, "hall_ids": json.dumps([1, 6]),
    },
    {
        "name": "Lahore Lens Studio", "phone": "03111223344",
        "email": "lens@studio.pk", "city": "Lahore",
        "experience_years": 5, "price_per_day": Decimal("18000.00"),
        "portfolio_url": "https://instagram.com/lahorelens",
        "description": "Candid & traditional wedding photography.",
        "is_available": True, "hall_ids": json.dumps([2, 7]),
    },
    {
        "name": "Clicks by Usman", "phone": "03334445566",
        "email": "usman@clicks.pk", "city": "Faisalabad",
        "experience_years": 3, "price_per_day": Decimal("12000.00"),
        "portfolio_url": "",
        "description": "Budget-friendly event photographer.",
        "is_available": True, "hall_ids": json.dumps([3, 9]),
    },
]

DEFAULT_MENUS = [
    {"hall_id": 1, "category": "Biryani & Rice", "item_name": "Chicken Biryani",      "price_per_plate": Decimal("450"), "description": "Sindhi-style aromatic basmati rice with chicken", "is_vegetarian": False},
    {"hall_id": 1, "category": "Biryani & Rice", "item_name": "Mutton Biryani",       "price_per_plate": Decimal("650"), "description": "Rich mutton biryani with saffron",                 "is_vegetarian": False},
    {"hall_id": 1, "category": "Biryani & Rice", "item_name": "Vegetable Biryani",    "price_per_plate": Decimal("400"), "description": "Veg biryani with fresh vegetables",                "is_vegetarian": True},
    {"hall_id": 1, "category": "Main Course",    "item_name": "Chicken Karahi",       "price_per_plate": Decimal("550"), "description": "Spicy chicken karahi with ginger & green chilies", "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course",    "item_name": "Mutton Karahi",        "price_per_plate": Decimal("750"), "description": "Tender mutton karahi",                              "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course",    "item_name": "Nihari",               "price_per_plate": Decimal("600"), "description": "Slow-cooked beef shank nihari with bone marrow",   "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course",    "item_name": "Haleem",               "price_per_plate": Decimal("500"), "description": "Lentil & meat haleem",                             "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course",    "item_name": "Chicken Haleem",       "price_per_plate": Decimal("450"), "description": "Chicken haleem",                                   "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course",    "item_name": "Palak Gosht",          "price_per_plate": Decimal("550"), "description": "Spinach with mutton",                              "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course",    "item_name": "Aloo Gosht",           "price_per_plate": Decimal("450"), "description": "Potato mutton curry",                              "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course",    "item_name": "Chicken Tikka Masala", "price_per_plate": Decimal("500"), "description": "Creamy chicken tikka masala",                      "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course",    "item_name": "Daal Chana",           "price_per_plate": Decimal("350"), "description": "Spiced chickpeas",                                 "is_vegetarian": True},
    {"hall_id": 1, "category": "Main Course",    "item_name": "Daal Masoor",          "price_per_plate": Decimal("300"), "description": "Red lentil curry",                                 "is_vegetarian": True},
    {"hall_id": 1, "category": "Main Course",    "item_name": "Mix Vegetable",        "price_per_plate": Decimal("350"), "description": "Seasonal mixed vegetables",                        "is_vegetarian": True},
    {"hall_id": 1, "category": "Appetizers",     "item_name": "Chicken Roll",         "price_per_plate": Decimal("200"), "description": "Paratha roll with chicken",                        "is_vegetarian": False},
    {"hall_id": 1, "category": "Appetizers",     "item_name": "Samosa",               "price_per_plate": Decimal("80"),  "description": "Spicy samosa",                                     "is_vegetarian": False},
    {"hall_id": 1, "category": "Appetizers",     "item_name": "Pakora",               "price_per_plate": Decimal("150"), "description": "Vegetable fritters",                               "is_vegetarian": True},
    {"hall_id": 1, "category": "Desserts",       "item_name": "Ras Malai",            "price_per_plate": Decimal("100"), "description": "Soft cheese dumplings in sweetened milk",          "is_vegetarian": True},
    {"hall_id": 1, "category": "Desserts",       "item_name": "Gulab Jamun",          "price_per_plate": Decimal("120"), "description": "Sweet milk dumplings in rose syrup",               "is_vegetarian": True},
    {"hall_id": 1, "category": "Desserts",       "item_name": "Kheer",                "price_per_plate": Decimal("90"),  "description": "Rice pudding with nuts",                           "is_vegetarian": True},
    {"hall_id": 1, "category": "Drinks",         "item_name": "Lassi",                "price_per_plate": Decimal("80"),  "description": "Yogurt drink with cardamom",                       "is_vegetarian": True},
    {"hall_id": 1, "category": "Drinks",         "item_name": "Rooh Afza",            "price_per_plate": Decimal("60"),  "description": "Rose syrup drink",                                 "is_vegetarian": True},
    {"hall_id": 1, "category": "Drinks",         "item_name": "Mineral Water",        "price_per_plate": Decimal("30"),  "description": "Bottled water",                                    "is_vegetarian": True},
    {"hall_id": 1, "category": "Salads",         "item_name": "Kachumber Salad",      "price_per_plate": Decimal("50"),  "description": "Tomato, onion, cucumber salad",                    "is_vegetarian": True},
    {"hall_id": 1, "category": "Salads",         "item_name": "Raita",                "price_per_plate": Decimal("70"),  "description": "Yogurt with cucumber",                             "is_vegetarian": True},
    {"hall_id": 2, "category": "Biryani & Rice", "item_name": "Chicken Biryani",      "price_per_plate": Decimal("400"), "description": "Lahore-style biryani",                             "is_vegetarian": False},
    {"hall_id": 2, "category": "Desserts",       "item_name": "Ras Malai",            "price_per_plate": Decimal("95"),  "description": "Soft cheese dumplings in sweetened milk",          "is_vegetarian": True},
    {"hall_id": 2, "category": "Desserts",       "item_name": "Gulab Jamun",          "price_per_plate": Decimal("115"), "description": "Sweet milk dumplings in rose syrup",               "is_vegetarian": True},
    {"hall_id": 2, "category": "Drinks",         "item_name": "Lassi",                "price_per_plate": Decimal("75"),  "description": "Yogurt drink with cardamom",                       "is_vegetarian": True},
    {"hall_id": 3, "category": "Main Course",    "item_name": "Chicken Karahi",       "price_per_plate": Decimal("500"), "description": "Faisalabad special",                               "is_vegetarian": False},
    {"hall_id": 3, "category": "Desserts",       "item_name": "Ras Malai",            "price_per_plate": Decimal("105"), "description": "Soft cheese dumplings in sweetened milk",          "is_vegetarian": True},
    {"hall_id": 3, "category": "Drinks",         "item_name": "Lassi",                "price_per_plate": Decimal("85"),  "description": "Yogurt drink with cardamom",                       "is_vegetarian": True},
    {"hall_id": 4, "category": "Main Course",    "item_name": "Chicken Karahi",       "price_per_plate": Decimal("520"), "description": "Spicy chicken karahi",                             "is_vegetarian": False},
    {"hall_id": 4, "category": "Desserts",       "item_name": "Ras Malai",            "price_per_plate": Decimal("100"), "description": "Soft cheese dumplings in sweetened milk",          "is_vegetarian": True},
    {"hall_id": 4, "category": "Drinks",         "item_name": "Lassi",                "price_per_plate": Decimal("80"),  "description": "Yogurt drink with cardamom",                       "is_vegetarian": True},
    {"hall_id": 5, "category": "Main Course",    "item_name": "Chicken Karahi",       "price_per_plate": Decimal("480"), "description": "Spicy chicken karahi",                             "is_vegetarian": False},
    {"hall_id": 5, "category": "Desserts",       "item_name": "Ras Malai",            "price_per_plate": Decimal("90"),  "description": "Soft cheese dumplings in sweetened milk",          "is_vegetarian": True},
    {"hall_id": 5, "category": "Drinks",         "item_name": "Lassi",                "price_per_plate": Decimal("70"),  "description": "Yogurt drink with cardamom",                       "is_vegetarian": True},
    {"hall_id": 6, "category": "Main Course",    "item_name": "Chicken Karahi",       "price_per_plate": Decimal("560"), "description": "Spicy chicken karahi",                             "is_vegetarian": False},
    {"hall_id": 6, "category": "Desserts",       "item_name": "Ras Malai",            "price_per_plate": Decimal("110"), "description": "Soft cheese dumplings in sweetened milk",          "is_vegetarian": True},
    {"hall_id": 6, "category": "Drinks",         "item_name": "Lassi",                "price_per_plate": Decimal("90"),  "description": "Yogurt drink with cardamom",                       "is_vegetarian": True},
    {"hall_id": 7, "category": "Main Course",    "item_name": "Chicken Karahi",       "price_per_plate": Decimal("500"), "description": "Spicy chicken karahi",                             "is_vegetarian": False},
    {"hall_id": 7, "category": "Desserts",       "item_name": "Ras Malai",            "price_per_plate": Decimal("95"),  "description": "Soft cheese dumplings in sweetened milk",          "is_vegetarian": True},
    {"hall_id": 7, "category": "Drinks",         "item_name": "Lassi",                "price_per_plate": Decimal("75"),  "description": "Yogurt drink with cardamom",                       "is_vegetarian": True},
    {"hall_id": 8, "category": "Main Course",    "item_name": "Chicken Karahi",       "price_per_plate": Decimal("530"), "description": "Spicy chicken karahi",                             "is_vegetarian": False},
    {"hall_id": 8, "category": "Desserts",       "item_name": "Ras Malai",            "price_per_plate": Decimal("105"), "description": "Soft cheese dumplings in sweetened milk",          "is_vegetarian": True},
    {"hall_id": 8, "category": "Drinks",         "item_name": "Lassi",                "price_per_plate": Decimal("85"),  "description": "Yogurt drink with cardamom",                       "is_vegetarian": True},
    {"hall_id": 9, "category": "Main Course",    "item_name": "Chicken Karahi",       "price_per_plate": Decimal("510"), "description": "Spicy chicken karahi",                             "is_vegetarian": False},
    {"hall_id": 9, "category": "Desserts",       "item_name": "Ras Malai",            "price_per_plate": Decimal("100"), "description": "Soft cheese dumplings in sweetened milk",          "is_vegetarian": True},
    {"hall_id": 9, "category": "Drinks",         "item_name": "Lassi",                "price_per_plate": Decimal("80"),  "description": "Yogurt drink with cardamom",                       "is_vegetarian": True},
    {"hall_id": 10, "category": "Main Course",   "item_name": "Chicken Karahi",       "price_per_plate": Decimal("570"), "description": "Spicy chicken karahi",                             "is_vegetarian": False},
    {"hall_id": 10, "category": "Desserts",      "item_name": "Ras Malai",            "price_per_plate": Decimal("115"), "description": "Soft cheese dumplings in sweetened milk",          "is_vegetarian": True},
    {"hall_id": 10, "category": "Drinks",        "item_name": "Lassi",                "price_per_plate": Decimal("95"),  "description": "Yogurt drink with cardamom",                       "is_vegetarian": True},
]

DEFAULT_HALLS = [
    {
        "name": "Royal Orchid Hall", "location": "Karachi", "capacity": 900,
        "rent": Decimal("180000.00"), "contact_person": "Ahmed Khan",
        "phone_number": "03001234567", "email": "royalorchid@example.com",
        "description": "Grand indoor venue with bridal lounge and stage lighting.",
        "image_urls": json.dumps(["assets/images/halls/royal_fort/hall1.jpg","assets/images/halls/royal_fort/hall2.jpg","assets/images/halls/royal_fort/hall3.jpg"]),
        "category": "Luxury", "is_featured": True,
    },
    {
        "name": "Dream Garden", "location": "Lahore", "capacity": 550,
        "rent": Decimal("120000.00"), "contact_person": "Sara Malik",
        "phone_number": "03111222333", "email": "dreamgarden@example.com",
        "description": "Open-air garden hall suited for weddings and mehndi events.",
        "image_urls": json.dumps(["assets/images/halls/dream_garden/hall1.jpg","assets/images/halls/dream_garden/hall2.jpg","assets/images/halls/dream_garden/hall3.jpg"]),
        "category": "Outdoor", "is_featured": True,
    },
    {
        "name": "Galaxy Hall", "location": "Faisalabad", "capacity": 700,
        "rent": Decimal("140000.00"), "contact_person": "Usman Sheikh",
        "phone_number": "03334445566", "email": "galaxyhall@example.com",
        "description": "Stylish wedding hall with ambient lighting, modern decor, and spacious dining.",
        "image_urls": json.dumps(["assets/images/halls/galaxy/hall1.jpg","assets/images/halls/galaxy/hall2.jpg","assets/images/halls/galaxy/hall3.jpg"]),
        "category": "Luxury", "is_featured": True,
    },
    {
        "name": "Pearl Palace", "location": "Islamabad", "capacity": 400,
        "rent": Decimal("95000.00"), "contact_person": "Hina Raza",
        "phone_number": "03219876543", "email": "pearlpalace@example.com",
        "description": "Modern banquet hall with valet parking and family suites.",
        "image_urls": json.dumps(["assets/images/halls/pearl_palace/hall1.jpg","assets/images/halls/pearl_palace/hall2.jpg","assets/images/halls/pearl_palace/hall3.jpg"]),
        "category": "Indoor", "is_featured": False,
    },
    {
        "name": "Sunshine Villa", "location": "Multan", "capacity": 250,
        "rent": Decimal("65000.00"), "contact_person": "Bilal Hussain",
        "phone_number": "03451112233", "email": "sunshinevilla@example.com",
        "description": "Budget-friendly hall for intimate gatherings and walima events.",
        "image_urls": json.dumps(["assets/images/halls/sunshine_villa/hall1.jpg","assets/images/halls/sunshine_villa/hall2.jpg","assets/images/halls/sunshine_villa/hall3.jpg"]),
        "category": "Budget", "is_featured": False,
    },
    {
        "name": "Celebration Center", "location": "Karachi", "capacity": 300,
        "rent": Decimal("80000.00"), "contact_person": "Ayesha Noor",
        "phone_number": "03005556677", "email": "celebrationcenter@example.com",
        "description": "Perfect for birthday parties, anniversaries, and small celebrations.",
        "image_urls": json.dumps(["assets/images/halls/celebration_center/hall1.jpg","assets/images/halls/celebration_center/hall2.jpg","assets/images/halls/celebration_center/hall3.jpg"]),
        "category": "Party", "is_featured": False,
    },
    {
        "name": "Corporate Plaza", "location": "Lahore", "capacity": 500,
        "rent": Decimal("100000.00"), "contact_person": "Zahid Ali",
        "phone_number": "03224445566", "email": "corporateplaza@example.com",
        "description": "Professional venue for corporate events, seminars, and conferences.",
        "image_urls": json.dumps(["assets/images/halls/corporate_plaza/hall1.jpg","assets/images/halls/corporate_plaza/hall2.jpg","assets/images/halls/corporate_plaza/hall3.jpg"]),
        "category": "Corporate", "is_featured": True,
    },
    {
        "name": "Garden Retreat", "location": "Islamabad", "capacity": 200,
        "rent": Decimal("70000.00"), "contact_person": "Fatima Khan",
        "phone_number": "03337778899", "email": "gardenretreat@example.com",
        "description": "Scenic outdoor venue for garden weddings and private parties.",
        "image_urls": json.dumps(["assets/images/halls/garden_retreat/hall1.jpg","assets/images/halls/garden_retreat/hall2.jpg","assets/images/halls/garden_retreat/hall3.jpg"]),
        "category": "Outdoor", "is_featured": False,
    },
    {
        "name": "Heritage Hall", "location": "Faisalabad", "capacity": 600,
        "rent": Decimal("110000.00"), "contact_person": "Imran Shah",
        "phone_number": "03446667788", "email": "heritagehall@example.com",
        "description": "Traditional hall with cultural decor for cultural events and weddings.",
        "image_urls": json.dumps(["assets/images/halls/heritage_hall/hall1.jpg","assets/images/halls/heritage_hall/hall2.jpg","assets/images/halls/heritage_hall/hall3.jpg"]),
        "category": "Cultural", "is_featured": False,
    },
    {
        "name": "Modern Arena", "location": "Peshawar", "capacity": 800,
        "rent": Decimal("130000.00"), "contact_person": "Nadia Begum",
        "phone_number": "03008889900", "email": "modernarena@example.com",
        "description": "State-of-the-art hall with advanced AV equipment for large events.",
        "image_urls": json.dumps(["assets/images/halls/modern_arena/hall1.jpg","assets/images/halls/modern_arena/hall2.jpg","assets/images/halls/modern_arena/hall3.jpg"]),
        "category": "Luxury", "is_featured": True,
    },
    {
        "name": "Cozy Corner", "location": "Quetta", "capacity": 150,
        "rent": Decimal("40000.00"), "contact_person": "Ahmed Baloch",
        "phone_number": "03119990011", "email": "cozycorner@example.com",
        "description": "Intimate setting for small family gatherings and ceremonies.",
        "image_urls": json.dumps(["assets/images/halls/cozy_corner/hall1.jpg","assets/images/halls/cozy_corner/hall2.jpg","assets/images/halls/cozy_corner/hall3.jpg"]),
        "category": "Intimate", "is_featured": False,
    },
    {
        "name": "Riverside Pavilion", "location": "Hyderabad", "capacity": 350,
        "rent": Decimal("85000.00"), "contact_person": "Sana Mughal",
        "phone_number": "03221112233", "email": "riversidepavilion@example.com",
        "description": "Riverside location perfect for romantic weddings and receptions.",
        "image_urls": json.dumps(["assets/images/halls/riverside_pavilion/hall1.jpg","assets/images/halls/riverside_pavilion/hall2.jpg","assets/images/halls/riverside_pavilion/hall3.jpg"]),
        "category": "Romantic", "is_featured": False,
    },
]


# ─────────────────────────────────────────────
#  MODELS
# ─────────────────────────────────────────────

class MarriageHall(db.Model):
    __tablename__ = "marriage_halls"
    hall_id        = db.Column(db.Integer, primary_key=True)
    name           = db.Column(db.String(255), nullable=False)
    location       = db.Column(db.String(255), nullable=False)
    capacity       = db.Column(db.Integer, nullable=False)
    rent           = db.Column(db.Numeric(10, 2), nullable=False)
    contact_person = db.Column(db.String(100), nullable=False)
    phone_number   = db.Column(db.String(20), nullable=False)
    email          = db.Column(db.String(120), nullable=False)
    description    = db.Column(db.Text, nullable=False, default="")
    image_urls     = db.Column(db.Text, nullable=False, default="[]")
    category       = db.Column(db.String(50), nullable=False, default="Indoor")
    is_featured    = db.Column(db.Boolean, nullable=False, default=False)
    bookings       = db.relationship("Booking", backref="hall",
                                     cascade="all, delete-orphan", lazy=True)


class Customer(db.Model):
    __tablename__     = "customers"
    id                = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name              = db.Column(db.String(255), nullable=False)
    email             = db.Column(db.String(255), unique=True, nullable=False)
    phone             = db.Column(db.String(20), nullable=False)
    password_hash     = db.Column(db.String(255), nullable=False)
    favorite_category = db.Column(db.String(50), nullable=False, default="Any")
    profile_image     = db.Column(db.Text, nullable=False, default="")
    created_at        = db.Column(db.DateTime, nullable=False, default=utc_now)
    bookings          = db.relationship("Booking", backref="customer",
                                        cascade="all, delete-orphan", lazy=True)


class Booking(db.Model):
    __tablename__           = "bookings"
    hall_booking_id         = db.Column(db.Integer, primary_key=True, autoincrement=True)
    hall_id                 = db.Column(db.Integer, db.ForeignKey("marriage_halls.hall_id"), nullable=False)
    customer_id             = db.Column(db.Integer, db.ForeignKey("customers.id"), nullable=False)
    customer_name           = db.Column(db.String(255), nullable=False)
    customer_contact_number = db.Column(db.String(20), nullable=False)
    booking_date            = db.Column(db.Date, nullable=False)
    event_type              = db.Column(db.String(50), nullable=False, default="Wedding")
    guest_count             = db.Column(db.Integer, nullable=False, default=100)
    special_request         = db.Column(db.Text, nullable=False, default="")
    additional_notes        = db.Column(db.Text, nullable=False, default="")
    menu_items              = db.Column(db.Text, nullable=False, default="[]")
    total_extra_cost        = db.Column(db.Numeric(10, 2), nullable=False, default=Decimal("0.00"))
    photographer_id         = db.Column(db.Integer, db.ForeignKey("photographers.photographer_id"), nullable=True)
    photographer_cost       = db.Column(db.Numeric(10, 2), nullable=False, default=Decimal("0.00"))
    status                  = db.Column(db.String(20), nullable=False, default="pending")
    payment_status          = db.Column(db.String(20), nullable=False, default="unpaid")
    payment_reference       = db.Column(db.String(100), nullable=False, default="")
    created_at              = db.Column(db.DateTime, nullable=False, default=utc_now)
    messages                = db.relationship(
        "BookingMessage", backref="booking",
        cascade="all, delete-orphan", lazy=True,
        order_by="BookingMessage.created_at.asc()",
    )


class BookingMessage(db.Model):
    __tablename__ = "booking_messages"
    message_id  = db.Column(db.Integer, primary_key=True, autoincrement=True)
    booking_id  = db.Column(db.Integer, db.ForeignKey("bookings.hall_booking_id"), nullable=False)
    sender_role = db.Column(db.String(20), nullable=False)
    sender_name = db.Column(db.String(255), nullable=False)
    message     = db.Column(db.Text, nullable=False)
    created_at  = db.Column(db.DateTime, nullable=False, default=utc_now)


class UserLog(db.Model):
    __tablename__ = "user_logs"
    log_id    = db.Column(db.Integer, primary_key=True, autoincrement=True)
    email     = db.Column(db.String(255), nullable=False)
    role      = db.Column(db.String(50), nullable=False)
    action    = db.Column(db.String(255), nullable=False)
    timestamp = db.Column(db.DateTime, nullable=False, default=utc_now)


class HallFeedback(db.Model):
    __tablename__ = "hall_feedback"
    feedback_id   = db.Column(db.Integer, primary_key=True, autoincrement=True)
    hall_id       = db.Column(db.Integer, db.ForeignKey("marriage_halls.hall_id"), nullable=False)
    customer_id   = db.Column(db.Integer, db.ForeignKey("customers.id"), nullable=False)
    customer_name = db.Column(db.String(255), nullable=False)
    rating        = db.Column(db.Integer, nullable=False)
    comment       = db.Column(db.Text, nullable=False, default="")
    created_at    = db.Column(db.DateTime, nullable=False, default=utc_now)


class FoodMenu(db.Model):
    __tablename__   = "food_menus"
    menu_id         = db.Column(db.Integer, primary_key=True, autoincrement=True)
    hall_id         = db.Column(db.Integer, db.ForeignKey("marriage_halls.hall_id"), nullable=False)
    category        = db.Column(db.String(100), nullable=False, default="Main Course")
    item_name       = db.Column(db.String(255), nullable=False)
    price_per_plate = db.Column(db.Numeric(8, 2), nullable=False)
    description     = db.Column(db.Text, default="")
    is_vegetarian   = db.Column(db.Boolean, default=False)
    is_available    = db.Column(db.Boolean, default=True)
    hall            = db.relationship("MarriageHall", backref="menus")


class Photographer(db.Model):
    __tablename__    = "photographers"
    photographer_id  = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name             = db.Column(db.String(255), nullable=False)
    phone            = db.Column(db.String(20), nullable=False)
    email            = db.Column(db.String(120), nullable=False, default="")
    city             = db.Column(db.String(100), nullable=False, default="")
    experience_years = db.Column(db.Integer, nullable=False, default=0)
    price_per_day    = db.Column(db.Numeric(10, 2), nullable=False, default=Decimal("0.00"))
    portfolio_url    = db.Column(db.Text, nullable=False, default="")
    description      = db.Column(db.Text, nullable=False, default="")
    is_available     = db.Column(db.Boolean, nullable=False, default=True)
    hall_ids         = db.Column(db.Text, nullable=False, default="[]")
    created_at       = db.Column(db.DateTime, nullable=False, default=utc_now)
    bookings         = db.relationship("Booking", backref="photographer", lazy=True,
                                       foreign_keys="Booking.photographer_id")


class Payment(db.Model):
    __tablename__     = "payments"
    payment_id        = db.Column(db.Integer, primary_key=True, autoincrement=True)
    booking_id        = db.Column(db.Integer, db.ForeignKey("bookings.hall_booking_id"), nullable=False)
    txn_ref_no        = db.Column(db.String(100), nullable=False, unique=True)
    amount            = db.Column(db.Numeric(12, 2), nullable=False)
    mobile_number     = db.Column(db.String(20), nullable=False, default="")
    jazzcash_response = db.Column(db.Text, nullable=False, default="{}")
    status            = db.Column(db.String(20), nullable=False, default="pending")
    created_at        = db.Column(db.DateTime, nullable=False, default=utc_now)
    updated_at        = db.Column(db.DateTime, nullable=False, default=utc_now)


# ─────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────

def parse_image_urls(value) -> list[str]:
    if isinstance(value, list):
        return [str(i).strip() for i in value if str(i).strip()]
    if not value:
        return []
    if isinstance(value, str):
        try:
            parsed = json.loads(value)
            if isinstance(parsed, list):
                return [str(i).strip() for i in parsed if str(i).strip()]
        except json.JSONDecodeError:
            pass
        return [i.strip() for i in value.split(",") if i.strip()]
    return []


def image_urls_as_full(value) -> list[str]:
    return [asset_path_to_url(p) for p in parse_image_urls(value)]


def parse_hall_ids(value) -> list[int]:
    if isinstance(value, list):
        return [int(i) for i in value if str(i).strip().isdigit()]
    if not value:
        return []
    try:
        parsed = json.loads(value)
        if isinstance(parsed, list):
            return [int(i) for i in parsed]
    except (json.JSONDecodeError, ValueError):
        pass
    return []


def validate_registration_payload(data: dict) -> str | None:
    name     = str(data.get("name", "")).strip()
    email    = str(data.get("email", "")).strip().lower()
    phone    = str(data.get("phone", "")).strip()
    password = str(data.get("password", ""))
    if not name:             return "Name is required."
    if not email:            return "Email is required."
    if "@" not in email:     return "Enter a valid email address."
    if not phone:            return "Phone number is required."
    if len(phone) < 10:      return "Phone number looks incomplete."
    if not password:         return "Password is required."
    if len(password) < 6:    return "Password must be at least 6 characters."
    return None


def parse_positive_int(value, field_name: str):
    try:
        parsed = int(str(value).strip())
    except (TypeError, ValueError):
        return None, f"{field_name} must be a valid number."
    if parsed < 1:
        return None, f"{field_name} must be at least 1."
    return parsed, None


def parse_non_negative_decimal(value, field_name: str):
    try:
        parsed = Decimal(str(value).strip())
    except (InvalidOperation, ValueError):
        return None, f"{field_name} must be a valid amount."
    if parsed < 0:
        return None, f"{field_name} cannot be negative."
    return parsed, None


def resolve_city_coordinates(city_name: str | None):
    if not city_name:
        return None
    normalized = city_name.strip().lower()
    if normalized in CITY_COORDINATES:
        return CITY_COORDINATES[normalized]
    for city, coords in CITY_COORDINATES.items():
        if city in normalized or normalized in city:
            return coords
    return None


def distance_km(first, second) -> float:
    lat1, lon1 = first
    lat2, lon2 = second
    r     = 6371.0
    dlat  = radians(lat2 - lat1)
    dlon  = radians(lon2 - lon1)
    a     = sin(dlat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
    return 2 * r * asin(sqrt(a))


def menu_to_dict(menu: FoodMenu) -> dict:
    return {
        "menu_id":         menu.menu_id,
        "hall_id":         menu.hall_id,
        "category":        menu.category,
        "item_name":       menu.item_name,
        "price_per_plate": float(menu.price_per_plate),
        "description":     menu.description or "",
        "is_vegetarian":   menu.is_vegetarian,
        "is_available":    menu.is_available,
    }


def photographer_to_dict(p: Photographer) -> dict:
    return {
        "photographer_id":  p.photographer_id,
        "name":             p.name,
        "phone":            p.phone,
        "email":            p.email,
        "city":             p.city,
        "experience_years": p.experience_years,
        "price_per_day":    float(p.price_per_day),
        "portfolio_url":    p.portfolio_url,
        "description":      p.description,
        "is_available":     p.is_available,
        "hall_ids":         parse_hall_ids(p.hall_ids),
        "created_at":       p.created_at.isoformat(),
    }


def payment_to_dict(pay: Payment) -> dict:
    return {
        "payment_id":        pay.payment_id,
        "booking_id":        pay.booking_id,
        "txn_ref_no":        pay.txn_ref_no,
        "amount":            float(pay.amount),
        "mobile_number":     pay.mobile_number,
        "status":            pay.status,
        "jazzcash_response": json.loads(pay.jazzcash_response or "{}"),
        "created_at":        pay.created_at.isoformat(),
        "updated_at":        pay.updated_at.isoformat(),
    }


def hall_to_dict(hall: MarriageHall) -> dict:
    feedback_summary  = hall_feedback_summary(hall.hall_id)
    menus             = [menu_to_dict(m) for m in getattr(hall, "menus", [])[:10]]
    all_photogs       = Photographer.query.filter_by(is_available=True).all()
    hall_photographers = [
        photographer_to_dict(p)
        for p in all_photogs
        if hall.hall_id in parse_hall_ids(p.hall_ids)
    ]
    return {
        "hall_id":        hall.hall_id,
        "name":           hall.name,
        "location":       hall.location,
        "capacity":       hall.capacity,
        "rent":           float(hall.rent),
        "contact_person": hall.contact_person,
        "phone_number":   hall.phone_number,
        "email":          hall.email,
        "description":    hall.description,
        "image_urls":     image_urls_as_full(hall.image_urls),
        "category":       hall.category,
        "is_featured":    hall.is_featured,
        "average_rating": feedback_summary["average_rating"],
        "feedback_count": feedback_summary["feedback_count"],
        "menus":          menus,
        "photographers":  hall_photographers,
    }


def feedback_to_dict(fb: HallFeedback) -> dict:
    return {
        "feedback_id":   fb.feedback_id,
        "hall_id":       fb.hall_id,
        "customer_id":   fb.customer_id,
        "customer_name": fb.customer_name,
        "rating":        fb.rating,
        "comment":       fb.comment,
        "created_at":    fb.created_at.isoformat(),
    }


def calculate_adjusted_cost(base_rent: float, guest_count: int) -> float:
    BASE_CAPACITY      = 30
    COST_PER_30_GUESTS = 20000
    if guest_count <= BASE_CAPACITY:
        return float(base_rent)
    additional_groups = (guest_count - BASE_CAPACITY) // BASE_CAPACITY
    return float(base_rent) + (additional_groups * COST_PER_30_GUESTS)


def booking_to_dict(booking: Booking) -> dict:
    base_rent     = float(booking.hall.rent) if booking.hall else 0
    adjusted_cost = calculate_adjusted_cost(base_rent, booking.guest_count)
    total_cost    = (
        adjusted_cost
        + float(booking.total_extra_cost or 0)
        + float(booking.photographer_cost or 0)
    )
    photographer_info = None
    if booking.photographer_id:
        p = Photographer.query.get(booking.photographer_id)
        if p:
            photographer_info = photographer_to_dict(p)
    return {
        "hall_booking_id":         booking.hall_booking_id,
        "hall_id":                 booking.hall_id,
        "hall_name":               booking.hall.name if booking.hall else "",
        "customer_id":             booking.customer_id,
        "customer_name":           booking.customer_name,
        "customer_contact_number": booking.customer_contact_number,
        "booking_date":            booking.booking_date.isoformat(),
        "event_type":              booking.event_type,
        "guest_count":             booking.guest_count,
        "special_request":         booking.special_request,
        "additional_notes":        booking.additional_notes,
        "menu_items":              json.loads(booking.menu_items or "[]"),
        "total_extra_cost":        float(booking.total_extra_cost or 0),
        "photographer":            photographer_info,
        "photographer_cost":       float(booking.photographer_cost or 0),
        "adjusted_cost":           adjusted_cost,
        "total_cost":              total_cost,
        "status":                  booking.status,
        "payment_status":          booking.payment_status,
        "payment_reference":       booking.payment_reference,
        "created_at":              booking.created_at.isoformat(),
        "messages":                [booking_message_to_dict(m) for m in booking.messages],
    }


def booking_message_to_dict(msg: BookingMessage) -> dict:
    return {
        "message_id":  msg.message_id,
        "booking_id":  msg.booking_id,
        "sender_role": msg.sender_role,
        "sender_name": msg.sender_name,
        "message":     msg.message,
        "created_at":  msg.created_at.isoformat(),
    }


def customer_to_dict(c: Customer) -> dict:
    return {
        "id":                c.id,
        "name":              c.name,
        "email":             c.email,
        "phone":             c.phone,
        "favorite_category": c.favorite_category,
        "profile_image":     c.profile_image,
        "created_at":        c.created_at.isoformat(),
    }


def hall_feedback_summary(hall_id: int) -> dict:
    entries = (
        HallFeedback.query
        .filter_by(hall_id=hall_id)
        .order_by(HallFeedback.created_at.desc())
        .all()
    )
    total   = len(entries)
    average = round(sum(e.rating for e in entries) / total, 1) if total else 0.0
    return {
        "average_rating": average,
        "feedback_count": total,
        "feedback":       [feedback_to_dict(e) for e in entries],
    }


def log_action(email: str, role: str, action: str) -> None:
    try:
        db.session.add(UserLog(email=email, role=role, action=action))
        db.session.commit()
    except Exception:
        db.session.rollback()


def create_booking_message(booking: Booking, sender_role: str, sender_name: str, message_text: str) -> BookingMessage:
    msg = BookingMessage(
        booking_id=booking.hall_booking_id,
        sender_role=sender_role,
        sender_name=sender_name,
        message=message_text,
    )
    db.session.add(msg)
    db.session.commit()
    return msg


# ─────────────────────────────────────────────
#  JAZZCASH UTILITIES
# ─────────────────────────────────────────────

def jazzcash_generate_hash(params: dict, integrity_salt: str) -> str:
    sorted_keys  = sorted(params.keys())
    hash_string  = integrity_salt + "&" + "&".join(str(params[k]) for k in sorted_keys)
    return hmac.new(
        integrity_salt.encode("utf-8"),
        hash_string.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def jazzcash_initiate_wallet_payment(txn_ref_no, amount_pkr, mobile_number, description):
    import requests as req_lib
    txn_datetime    = utc_now().strftime("%Y%m%d%H%M%S")
    expiry_datetime = (utc_now() + timedelta(hours=1)).strftime("%Y%m%d%H%M%S")
    amount_paisas   = str(int(amount_pkr * 100))
    params = {
        "pp_Version": "2.0", "pp_TxnType": "MWALLET", "pp_Language": "EN",
        "pp_MerchantID": JAZZCASH_MERCHANT_ID, "pp_Password": JAZZCASH_PASSWORD,
        "pp_TxnRefNo": txn_ref_no, "pp_Amount": amount_paisas,
        "pp_TxnCurrency": "PKR", "pp_TxnDateTime": txn_datetime,
        "pp_BillReference": "shaadi-ghar", "pp_Description": description[:100],
        "pp_TxnExpiryDateTime": expiry_datetime, "pp_ReturnURL": JAZZCASH_RETURN_URL,
        "pp_SecureHash": "", "ppmpf_1": mobile_number,
        "ppmpf_2": "", "ppmpf_3": "", "ppmpf_4": "", "ppmpf_5": "",
    }
    hash_params             = {k: v for k, v in params.items() if k != "pp_SecureHash"}
    params["pp_SecureHash"] = jazzcash_generate_hash(hash_params, JAZZCASH_INTEGRITY_SALT)
    try:
        response = req_lib.post(JAZZCASH_API_URL, json=params, timeout=30)
        return response.json()
    except Exception as exc:
        return {"pp_ResponseCode": "99", "pp_ResponseMessage": str(exc)}


# ─────────────────────────────────────────────
#  EMAIL UTILITIES
# ─────────────────────────────────────────────

def send_email(to_email: str, subject: str, html_content: str) -> None:
    email_configured = all(
        v and "your-email@gmail.com" not in v and "your-app-password" not in v
        for v in (SMTP_USERNAME, SMTP_PASSWORD, FROM_EMAIL)
    )
    if not email_configured:
        return
    try:
        import smtplib
        from email.mime.multipart import MIMEMultipart
        from email.mime.text import MIMEText
        msg            = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"]    = f"{FROM_NAME} <{FROM_EMAIL}>"
        msg["To"]      = to_email
        msg.attach(MIMEText(html_content, "html"))
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.sendmail(FROM_EMAIL, to_email, msg.as_string())
    except Exception as e:
        print(f"Failed to send email to {to_email}: {e}")


def send_booking_confirmation_email(customer_email, booking, hall):
    subject      = f"Booking Confirmation | {hall.name}"
    html_content = f"""<html><body>
<h2>Booking Confirmed – {hall.name}</h2>
<p>Date: {booking.booking_date.strftime('%B %d, %Y')}</p>
<p>Event: {booking.event_type} | Guests: {booking.guest_count}</p>
<p>Contact: {hall.contact_person} ({hall.phone_number})</p>
</body></html>"""
    send_email(customer_email, subject, html_content)


def send_booking_status_update_email(customer_email, booking, new_status):
    hall_name    = booking.hall.name if booking.hall else "Your booking"
    subject      = f"Booking Update | {hall_name}"
    html_content = f"""<html><body>
<h2>Booking Status Updated</h2>
<p>Your booking for <strong>{hall_name}</strong> is now: <strong>{new_status.capitalize()}</strong></p>
</body></html>"""
    send_email(customer_email, subject, html_content)


def send_booking_message_email(customer_email, booking, message):
    hall_name    = booking.hall.name if booking.hall else "Shaadi Ghar"
    subject      = f"Message about your booking at {hall_name}"
    html_content = f"""<html><body>
<h2>New message about your booking</h2><p>{message}</p>
</body></html>"""
    send_email(customer_email, subject, html_content)


# ─────────────────────────────────────────────
#  SEED / SYNC
# ─────────────────────────────────────────────

def seed_default_data() -> None:
    if MarriageHall.query.count() == 0:
        for hall in DEFAULT_HALLS:
            db.session.add(MarriageHall(**hall))
        db.session.commit()
    if FoodMenu.query.count() == 0:
        for menu_data in DEFAULT_MENUS:
            db.session.add(FoodMenu(**menu_data))
        db.session.commit()
    if Photographer.query.count() == 0:
        for photo_data in DEFAULT_PHOTOGRAPHERS:
            db.session.add(Photographer(**photo_data))
        db.session.commit()


def sync_default_halls() -> None:
    changed = False
    for hall_data in DEFAULT_HALLS:
        existing = MarriageHall.query.filter_by(name=hall_data["name"]).first()
        if existing is None:
            db.session.add(MarriageHall(**hall_data))
            changed = True
            continue
        if not existing.description.strip():
            existing.description = hall_data["description"]
            changed = True
        if not existing.category.strip():
            existing.category = hall_data["category"]
            changed = True
    if changed:
        db.session.commit()


# ─────────────────────────────────────────────
#  ROUTES — Auth
# ─────────────────────────────────────────────

@app.route("/register", methods=["POST"])
def register():
    data  = request.get_json(silent=True) or {}
    error = validate_registration_payload(data)
    if error:
        return jsonify({"error": error}), 400
    email = str(data["email"]).strip().lower()
    if Customer.query.filter_by(email=email).first():
        return jsonify({"error": "Email already registered."}), 409
    customer = Customer(
        name              =str(data["name"]).strip(),
        email             =email,
        phone             =str(data["phone"]).strip(),
        password_hash     =generate_password_hash(str(data["password"])),
        favorite_category =str(data.get("favorite_category", "Any")).strip(),
        profile_image     =str(data.get("profile_image", "")).strip(),
    )
    db.session.add(customer)
    db.session.commit()
    log_action(email, "customer", "registered")
    return jsonify({
        "message":  "Registration successful.",
        "customer": customer_to_dict(customer),
        "user":     customer_to_dict(customer),
    }), 201


@app.route("/login", methods=["POST"])
def login():
    data     = request.get_json(silent=True) or {}
    email    = str(data.get("email", "")).strip().lower()
    password = str(data.get("password", ""))

    if email == ADMIN_EMAIL.lower() and password == ADMIN_PASSWORD:
        log_action(email, "admin", "login")
        admin_user = {
            "id": 0, "name": "Admin", "email": email,
            "phone": "", "favorite_category": "Any",
            "profile_image": "", "created_at": utc_now().isoformat(),
        }
        return jsonify({
            "message": "Admin login successful.",
            "role": "admin", "email": email,
            "user": admin_user, "customer": admin_user,
        }), 200

    customer = Customer.query.filter_by(email=email).first()
    if not customer:
        return jsonify({"error": "Invalid email or password."}), 401

    stored = customer.password_hash
    if stored.startswith("PLAIN:"):
        plain = stored[len("PLAIN:"):]
        if password != plain:
            return jsonify({"error": "Invalid email or password."}), 401
        customer.password_hash = generate_password_hash(password)
        db.session.commit()
    elif not check_password_hash(stored, password):
        return jsonify({"error": "Invalid email or password."}), 401

    log_action(email, "customer", "login")
    return jsonify({
        "message":  "Login successful.",
        "role":     "customer",
        "customer": customer_to_dict(customer),
        "user":     customer_to_dict(customer),
    }), 200


# ─────────────────────────────────────────────
#  ROUTES — Halls (public)
# ─────────────────────────────────────────────

@app.route("/halls", methods=["GET"])
def get_halls():
    location     = request.args.get("location",     "").strip()
    category     = request.args.get("category",     "").strip()
    featured     = request.args.get("featured",     "").strip().lower()
    min_capacity = request.args.get("min_capacity", "").strip()
    max_rent     = request.args.get("max_rent",     "").strip()
    nearby_city  = request.args.get("nearby_city",  "").strip()
    radius_km_s  = request.args.get("radius_km",    "50").strip()
    search       = request.args.get("search",       "").strip()

    # Flutter also sends these query params — support them too
    q            = request.args.get("q",            "").strip()
    city_param   = request.args.get("city",         "").strip()
    nearest_to   = request.args.get("nearest_to",   "").strip()
    sort_by      = request.args.get("sort_by",       "featured").strip()
    min_cap2     = request.args.get("min_capacity",  "").strip()
    max_r2       = request.args.get("max_rent",      "").strip()
    feat2        = request.args.get("featured",      "").strip().lower()

    # Merge duplicates (Flutter uses q, city, nearest_to)
    if q and not search:
        search = q
    if city_param and not location:
        location = city_param
    if nearest_to and not nearby_city:
        nearby_city = nearest_to

    query = MarriageHall.query
    if location:
        query = query.filter(MarriageHall.location.ilike(f"%{location}%"))
    if category and category.lower() != "all":
        query = query.filter(MarriageHall.category.ilike(f"%{category}%"))
    if featured == "true" or feat2 == "true":
        query = query.filter(MarriageHall.is_featured == True)
    if min_capacity or min_cap2:
        try:
            query = query.filter(MarriageHall.capacity >= int(min_capacity or min_cap2))
        except ValueError:
            pass
    if max_rent or max_r2:
        try:
            query = query.filter(MarriageHall.rent <= Decimal(max_rent or max_r2))
        except (InvalidOperation, ValueError):
            pass
    if search:
        query = query.filter(or_(
            MarriageHall.name.ilike(f"%{search}%"),
            MarriageHall.location.ilike(f"%{search}%"),
            MarriageHall.description.ilike(f"%{search}%"),
        ))

    halls = query.all()

    if nearby_city:
        city_coords = resolve_city_coordinates(nearby_city)
        if city_coords:
            try:
                radius = float(radius_km_s)
            except ValueError:
                radius = 50.0
            halls = [
                h for h in halls
                if (coords := resolve_city_coordinates(h.location))
                   and distance_km(city_coords, coords) <= radius
            ]

    # Sort
    if sort_by == "price_low":
        halls.sort(key=lambda h: float(h.rent))
    elif sort_by == "price_high":
        halls.sort(key=lambda h: float(h.rent), reverse=True)
    elif sort_by == "capacity":
        halls.sort(key=lambda h: h.capacity, reverse=True)
    elif sort_by == "name":
        halls.sort(key=lambda h: h.name.lower())
    elif sort_by == "rating":
        halls.sort(key=lambda h: hall_feedback_summary(h.hall_id)["average_rating"], reverse=True)
    elif sort_by == "nearest" and nearby_city:
        city_coords = resolve_city_coordinates(nearby_city)
        if city_coords:
            halls.sort(key=lambda h: distance_km(city_coords, resolve_city_coordinates(h.location) or city_coords))
    # featured: featured halls first
    else:
        halls.sort(key=lambda h: (0 if h.is_featured else 1))

    return jsonify([hall_to_dict(h) for h in halls]), 200


@app.route("/halls/<int:hall_id>", methods=["GET"])
def get_hall(hall_id: int):
    hall = MarriageHall.query.get(hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404
    return jsonify(hall_to_dict(hall)), 200


# ─────────────────────────────────────────────
#  ROUTES — Availability & Feedback (Flutter paths)
# ─────────────────────────────────────────────

@app.route("/hall/<int:hall_id>/availability", methods=["GET"])
@app.route("/halls/<int:hall_id>/availability", methods=["GET"])
def hall_availability(hall_id: int):
    hall = MarriageHall.query.get(hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404

    month_str = request.args.get("month", "").strip()
    year_str  = request.args.get("year",  "").strip()
    try:
        month = int(month_str) if month_str else datetime.utcnow().month
        year  = int(year_str)  if year_str  else datetime.utcnow().year
    except ValueError:
        return jsonify({"error": "Invalid month or year."}), 400

    all_bookings = (
        Booking.query
        .filter(Booking.hall_id == hall_id, Booking.status != "cancelled")
        .all()
    )
    booked_dates = [
        b.booking_date.isoformat()
        for b in all_bookings
        if b.booking_date.month == month and b.booking_date.year == year
    ]

    try:
        first_of_month = date(year, month, 1)
    except ValueError:
        return jsonify({"error": "Invalid month or year."}), 400

    last_of_month = date(year, 12, 31) if month == 12 else date(year, month + 1, 1) - timedelta(days=1)

    available_dates = []
    current = first_of_month
    today   = date.today()
    while current <= last_of_month:
        if current.isoformat() not in booked_dates and current >= today:
            available_dates.append(current.isoformat())
        current += timedelta(days=1)

    return jsonify({
        "hall_id":         hall_id,
        "month":           month,
        "year":            year,
        "booked_dates":    booked_dates,
        "available_dates": available_dates,
    }), 200


@app.route("/hall/<int:hall_id>/feedback",  methods=["GET"])
@app.route("/halls/<int:hall_id>/feedback", methods=["GET"])
def get_feedback(hall_id: int):
    hall = MarriageHall.query.get(hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404
    return jsonify(hall_feedback_summary(hall_id)), 200


@app.route("/hall/<int:hall_id>/feedback",  methods=["POST"])
@app.route("/halls/<int:hall_id>/feedback", methods=["POST"])
def add_feedback(hall_id: int):
    hall = MarriageHall.query.get(hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404
    data          = request.get_json(silent=True) or {}
    customer_id   = data.get("customer_id")
    rating        = data.get("rating")
    comment       = str(data.get("comment", "")).strip()
    customer_name = str(data.get("customer_name", "")).strip()
    if not customer_id or rating is None:
        return jsonify({"error": "customer_id and rating are required."}), 400
    try:
        rating = int(rating)
    except (TypeError, ValueError):
        return jsonify({"error": "Rating must be an integer."}), 400
    if not (1 <= rating <= 5):
        return jsonify({"error": "Rating must be between 1 and 5."}), 400
    customer = Customer.query.get(customer_id)
    if not customer:
        return jsonify({"error": "Customer not found."}), 404

    # Upsert: update existing feedback if found
    existing = HallFeedback.query.filter_by(hall_id=hall_id, customer_id=customer_id).first()
    if existing:
        existing.rating    = rating
        existing.comment   = comment
        existing.created_at = utc_now()
        db.session.commit()
        return jsonify({"message": "Feedback updated.", "feedback": feedback_to_dict(existing)}), 200

    fb = HallFeedback(
        hall_id=hall_id, customer_id=customer_id,
        customer_name=customer_name or customer.name,
        rating=rating, comment=comment,
    )
    db.session.add(fb)
    db.session.commit()
    return jsonify({"message": "Feedback submitted.", "feedback": feedback_to_dict(fb)}), 201


# ─────────────────────────────────────────────
#  ROUTES — Book
# ─────────────────────────────────────────────

@app.route("/book", methods=["POST"])
@app.route("/bookings", methods=["POST"])
def create_booking():
    data = request.get_json(silent=True) or {}

    hall_id, err = parse_positive_int(data.get("hall_id"), "Hall ID")
    if err:
        return jsonify({"error": err}), 400
    customer_id, err = parse_positive_int(data.get("customer_id"), "Customer ID")
    if err:
        return jsonify({"error": err}), 400

    hall     = MarriageHall.query.get(hall_id)
    customer = Customer.query.get(customer_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404
    if not customer:
        return jsonify({"error": "Customer not found."}), 404

    booking_date_str = str(data.get("booking_date", "")).strip()
    try:
        booking_date = date.fromisoformat(booking_date_str)
    except ValueError:
        return jsonify({"error": "booking_date must be YYYY-MM-DD."}), 400
    if booking_date < date.today():
        return jsonify({"error": "Booking date cannot be in the past."}), 400

    conflict = (
        Booking.query
        .filter_by(hall_id=hall_id, booking_date=booking_date)
        .filter(Booking.status != "cancelled")
        .first()
    )
    if conflict:
        return jsonify({"error": "Hall is already booked for this date."}), 409

    guest_count, err = parse_positive_int(data.get("guest_count", 100), "Guest count")
    if err:
        return jsonify({"error": err}), 400

    # Menu items
    menu_items_raw   = data.get("menu_items", [])
    if not isinstance(menu_items_raw, list):
        menu_items_raw = []
    total_extra_cost = Decimal("0.00")
    valid_menu_items = []
    for item in menu_items_raw:
        menu_id  = item.get("menu_id")
        quantity = item.get("quantity", 1)
        menu     = FoodMenu.query.get(menu_id) if menu_id else None
        if menu and menu.is_available:
            qty               = max(1, int(quantity))
            total_extra_cost += menu.price_per_plate * qty
            valid_menu_items.append({"menu_id": menu.menu_id, "quantity": qty})

    # Photographer
    photographer_id_raw = data.get("photographer_id")
    photographer_cost   = Decimal("0.00")
    photographer_id     = None
    if photographer_id_raw:
        p = Photographer.query.get(int(photographer_id_raw))
        if p and p.is_available:
            photographer_id   = p.photographer_id
            photographer_cost = p.price_per_day
        else:
            return jsonify({"error": "Photographer not found or not available."}), 404

    booking = Booking(
        hall_id                 =hall_id,
        customer_id             =customer_id,
        customer_name           =str(data.get("customer_name", customer.name)).strip(),
        customer_contact_number =str(data.get("customer_contact_number", customer.phone)).strip(),
        booking_date            =booking_date,
        event_type              =str(data.get("event_type", "Wedding")).strip(),
        guest_count             =guest_count,
        special_request         =str(data.get("special_request", "")).strip(),
        additional_notes        =str(data.get("additional_notes", "")).strip(),
        menu_items              =json.dumps(valid_menu_items),
        total_extra_cost        =total_extra_cost,
        photographer_id         =photographer_id,
        photographer_cost       =photographer_cost,
        status                  ="pending",
        payment_status          ="unpaid",
    )
    db.session.add(booking)
    db.session.commit()

    send_booking_confirmation_email(customer.email, booking, hall)
    log_action(customer.email, "customer", f"booked hall {hall_id} on {booking_date}")
    return jsonify({"message": "Booking created.", "booking": booking_to_dict(booking)}), 201


# ─────────────────────────────────────────────
#  ROUTES — Customer (Flutter-specific paths)
# ─────────────────────────────────────────────

@app.route("/customer/bookings/<int:customer_id>", methods=["GET"])
def customer_get_bookings(customer_id: int):
    """GET /customer/bookings/<customerId> — Flutter MyBookingsPage"""
    customer = Customer.query.get(customer_id)
    if not customer:
        return jsonify({"error": "Customer not found."}), 404
    bookings = (
        Booking.query
        .filter_by(customer_id=customer_id)
        .order_by(Booking.created_at.desc())
        .all()
    )
    return jsonify([booking_to_dict(b) for b in bookings]), 200


@app.route("/customer/cancel_booking/<int:booking_id>", methods=["PUT"])
def customer_cancel_booking(booking_id: int):
    """PUT /customer/cancel_booking/<bookingId> — Flutter cancel button"""
    booking = Booking.query.get(booking_id)
    if not booking:
        return jsonify({"error": "Booking not found."}), 404
    data        = request.get_json(silent=True) or {}
    customer_id = data.get("customer_id")
    if customer_id and booking.customer_id != int(customer_id):
        return jsonify({"error": "Not authorized to cancel this booking."}), 403
    if booking.status not in ("pending",):
        return jsonify({"error": f"Cannot cancel a booking with status '{booking.status}'."}), 400
    booking.status = "cancelled"
    db.session.commit()
    log_action(
        booking.customer.email if booking.customer else "",
        "customer",
        f"cancelled booking {booking_id}",
    )
    return jsonify({"message": "Booking cancelled.", "booking": booking_to_dict(booking)}), 200


@app.route("/booking/<int:booking_id>/request_cancel", methods=["POST"])
def customer_request_cancel(booking_id: int):
    """POST /booking/<bookingId>/request_cancel — Flutter request cancel"""
    booking = Booking.query.get(booking_id)
    if not booking:
        return jsonify({"error": "Booking not found."}), 404
    data        = request.get_json(silent=True) or {}
    customer_id = data.get("customer_id")
    reason      = str(data.get("reason", "")).strip()
    if customer_id and booking.customer_id != int(customer_id):
        return jsonify({"error": "Not authorized."}), 403

    # Send a message to admin with the cancel request
    msg_text = f"Customer requests cancellation. Reason: {reason}" if reason else "Customer requests cancellation."
    create_booking_message(booking, "customer", booking.customer_name, msg_text)
    log_action(
        booking.customer.email if booking.customer else "",
        "customer",
        f"requested cancel for booking {booking_id}",
    )
    return jsonify({"message": "Cancellation request sent to admin."}), 200


@app.route("/booking/<int:booking_id>/update_date", methods=["PUT"])
def customer_update_booking_date(booking_id: int):
    """PUT /booking/<bookingId>/update_date — Flutter update date"""
    booking = Booking.query.get(booking_id)
    if not booking:
        return jsonify({"error": "Booking not found."}), 404
    data        = request.get_json(silent=True) or {}
    customer_id = data.get("customer_id")
    new_date    = str(data.get("new_date", "")).strip()
    if customer_id and booking.customer_id != int(customer_id):
        return jsonify({"error": "Not authorized."}), 403
    if booking.status not in ("pending",):
        return jsonify({"error": f"Cannot modify a booking with status '{booking.status}'."}), 400
    try:
        parsed_date = date.fromisoformat(new_date)
    except ValueError:
        return jsonify({"error": "new_date must be YYYY-MM-DD."}), 400
    if parsed_date < date.today():
        return jsonify({"error": "New date cannot be in the past."}), 400

    conflict = (
        Booking.query
        .filter_by(hall_id=booking.hall_id, booking_date=parsed_date)
        .filter(Booking.status != "cancelled")
        .filter(Booking.hall_booking_id != booking_id)
        .first()
    )
    if conflict:
        return jsonify({"error": "Hall is already booked on the new date."}), 409

    booking.booking_date = parsed_date
    db.session.commit()
    log_action(
        booking.customer.email if booking.customer else "",
        "customer",
        f"updated booking {booking_id} date to {new_date}",
    )
    return jsonify({"message": "Booking date updated.", "booking": booking_to_dict(booking)}), 200


@app.route("/booking/<int:booking_id>/update_guests", methods=["PUT"])
def customer_update_booking_guests(booking_id: int):
    """PUT /booking/<bookingId>/update_guests — Flutter update guests"""
    booking = Booking.query.get(booking_id)
    if not booking:
        return jsonify({"error": "Booking not found."}), 404
    data           = request.get_json(silent=True) or {}
    customer_id    = data.get("customer_id")
    new_guest_count = data.get("new_guest_count")
    if customer_id and booking.customer_id != int(customer_id):
        return jsonify({"error": "Not authorized."}), 403
    if booking.status not in ("pending",):
        return jsonify({"error": f"Cannot modify a booking with status '{booking.status}'."}), 400
    guests, err = parse_positive_int(new_guest_count, "Guest count")
    if err:
        return jsonify({"error": err}), 400
    booking.guest_count = guests
    db.session.commit()
    log_action(
        booking.customer.email if booking.customer else "",
        "customer",
        f"updated booking {booking_id} guests to {guests}",
    )
    return jsonify({"message": "Guest count updated.", "booking": booking_to_dict(booking)}), 200


@app.route("/customer/profile/<int:customer_id>", methods=["PUT"])
def customer_update_profile(customer_id: int):
    """PUT /customer/profile/<customerId> — Flutter CustomerProfilePage"""
    customer = Customer.query.get(customer_id)
    if not customer:
        return jsonify({"error": "Customer not found."}), 404
    data = request.get_json(silent=True) or {}
    if "name"              in data: customer.name              = str(data["name"]).strip()
    if "phone"             in data: customer.phone             = str(data["phone"]).strip()
    if "favorite_category" in data: customer.favorite_category = str(data["favorite_category"]).strip()
    if "profile_image"     in data: customer.profile_image     = str(data["profile_image"]).strip()
    if "password" in data and data["password"]:
        customer.password_hash = generate_password_hash(str(data["password"]))
    db.session.commit()
    log_action(customer.email, "customer", f"updated profile")
    return jsonify({"message": "Profile updated.", "user": customer_to_dict(customer)}), 200


@app.route("/customer/send_booking_message/<int:booking_id>", methods=["POST"])
def customer_send_booking_message(booking_id: int):
    """POST /customer/send_booking_message/<bookingId> — Flutter MessagesDialog"""
    booking = Booking.query.get(booking_id)
    if not booking:
        return jsonify({"error": "Booking not found."}), 404
    data         = request.get_json(silent=True) or {}
    customer_id  = data.get("customer_id")
    message_text = str(data.get("message", "")).strip()
    if not message_text:
        return jsonify({"error": "message is required."}), 400
    if customer_id and booking.customer_id != int(customer_id):
        return jsonify({"error": "Not authorized."}), 403
    sender_name = booking.customer_name
    msg = create_booking_message(booking, "customer", sender_name, message_text)
    return jsonify({"message": "Message sent.", "booking_message": booking_message_to_dict(msg)}), 201


# ─────────────────────────────────────────────
#  ROUTES — Food Menus
# ─────────────────────────────────────────────

@app.route("/hall/<int:hall_id>/menus",  methods=["GET"])
@app.route("/halls/<int:hall_id>/menus", methods=["GET"])
def get_hall_menus(hall_id: int):
    hall = MarriageHall.query.get(hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404
    menus = FoodMenu.query.filter_by(hall_id=hall_id).all()
    return jsonify([menu_to_dict(m) for m in menus]), 200


@app.route("/hall/<int:hall_id>/menus",  methods=["POST"])
@app.route("/halls/<int:hall_id>/menus", methods=["POST"])
def add_menu_item(hall_id: int):
    hall = MarriageHall.query.get(hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404
    data      = request.get_json(silent=True) or {}
    item_name = str(data.get("item_name", "")).strip()
    if not item_name:
        return jsonify({"error": "item_name is required."}), 400
    price, err = parse_non_negative_decimal(data.get("price_per_plate", 0), "Price per plate")
    if err:
        return jsonify({"error": err}), 400
    menu = FoodMenu(
        hall_id        =hall_id,
        category       =str(data.get("category", "Main Course")).strip(),
        item_name      =item_name,
        price_per_plate=price,
        description    =str(data.get("description", "")).strip(),
        is_vegetarian  =bool(data.get("is_vegetarian", False)),
        is_available   =bool(data.get("is_available", True)),
    )
    db.session.add(menu)
    db.session.commit()
    return jsonify({"message": "Menu item added.", "menu": menu_to_dict(menu)}), 201


@app.route("/menus/<int:menu_id>", methods=["PUT"])
def update_menu_item(menu_id: int):
    menu = FoodMenu.query.get(menu_id)
    if not menu:
        return jsonify({"error": "Menu item not found."}), 404
    data = request.get_json(silent=True) or {}
    if "item_name"     in data: menu.item_name     = str(data["item_name"]).strip()
    if "category"      in data: menu.category      = str(data["category"]).strip()
    if "description"   in data: menu.description   = str(data["description"]).strip()
    if "is_vegetarian" in data: menu.is_vegetarian = bool(data["is_vegetarian"])
    if "is_available"  in data: menu.is_available  = bool(data["is_available"])
    if "price_per_plate" in data:
        price, err = parse_non_negative_decimal(data["price_per_plate"], "Price per plate")
        if err:
            return jsonify({"error": err}), 400
        menu.price_per_plate = price
    db.session.commit()
    return jsonify({"message": "Menu item updated.", "menu": menu_to_dict(menu)}), 200


@app.route("/menus/<int:menu_id>", methods=["DELETE"])
def delete_menu_item(menu_id: int):
    menu = FoodMenu.query.get(menu_id)
    if not menu:
        return jsonify({"error": "Menu item not found."}), 404
    db.session.delete(menu)
    db.session.commit()
    return jsonify({"message": "Menu item deleted."}), 200


# ─────────────────────────────────────────────
#  ROUTES — Photographers
# ─────────────────────────────────────────────

@app.route("/photographers", methods=["GET"])
def get_photographers():
    city          = request.args.get("city",      "").strip()
    hall_id_str   = request.args.get("hall_id",   "").strip()
    available_str = request.args.get("available", "").strip().lower()

    query = Photographer.query
    if city:
        query = query.filter(Photographer.city.ilike(f"%{city}%"))
    if available_str == "true":
        query = query.filter(Photographer.is_available == True)

    photographers = query.order_by(Photographer.name).all()

    if hall_id_str:
        try:
            hid           = int(hall_id_str)
            photographers = [p for p in photographers if hid in parse_hall_ids(p.hall_ids)]
        except ValueError:
            pass

    return jsonify([photographer_to_dict(p) for p in photographers]), 200


@app.route("/photographers/<int:photographer_id>", methods=["GET"])
def get_photographer(photographer_id: int):
    p = Photographer.query.get(photographer_id)
    if not p:
        return jsonify({"error": "Photographer not found."}), 404
    return jsonify(photographer_to_dict(p)), 200


@app.route("/photographers", methods=["POST"])
def create_photographer():
    data  = request.get_json(silent=True) or {}
    name  = str(data.get("name",  "")).strip()
    phone = str(data.get("phone", "")).strip()
    if not name or not phone:
        return jsonify({"error": "name and phone are required."}), 400
    price, err = parse_non_negative_decimal(data.get("price_per_day", 0), "Price per day")
    if err:
        return jsonify({"error": err}), 400
    raw_hall_ids  = data.get("hall_ids", [])
    hall_ids_json = json.dumps([int(i) for i in raw_hall_ids]) if isinstance(raw_hall_ids, list) else "[]"
    p = Photographer(
        name             =name,
        phone            =phone,
        email            =str(data.get("email", "")).strip(),
        city             =str(data.get("city",  "")).strip(),
        experience_years =int(data.get("experience_years", 0)),
        price_per_day    =price,
        portfolio_url    =str(data.get("portfolio_url", "")).strip(),
        description      =str(data.get("description", "")).strip(),
        is_available     =bool(data.get("is_available", True)),
        hall_ids         =hall_ids_json,
    )
    db.session.add(p)
    db.session.commit()
    return jsonify({"message": "Photographer created.", "photographer": photographer_to_dict(p)}), 201


@app.route("/photographers/<int:photographer_id>", methods=["PUT"])
def update_photographer(photographer_id: int):
    p = Photographer.query.get(photographer_id)
    if not p:
        return jsonify({"error": "Photographer not found."}), 404
    data = request.get_json(silent=True) or {}
    if "name"             in data: p.name             = str(data["name"]).strip()
    if "phone"            in data: p.phone            = str(data["phone"]).strip()
    if "email"            in data: p.email            = str(data["email"]).strip()
    if "city"             in data: p.city             = str(data["city"]).strip()
    if "experience_years" in data: p.experience_years = int(data["experience_years"])
    if "portfolio_url"    in data: p.portfolio_url    = str(data["portfolio_url"]).strip()
    if "description"      in data: p.description      = str(data["description"]).strip()
    if "is_available"     in data: p.is_available     = bool(data["is_available"])
    if "price_per_day" in data:
        price, err = parse_non_negative_decimal(data["price_per_day"], "Price per day")
        if err:
            return jsonify({"error": err}), 400
        p.price_per_day = price
    if "hall_ids" in data:
        raw = data["hall_ids"]
        p.hall_ids = json.dumps([int(i) for i in raw]) if isinstance(raw, list) else "[]"
    db.session.commit()
    return jsonify({"message": "Photographer updated.", "photographer": photographer_to_dict(p)}), 200


@app.route("/photographers/<int:photographer_id>", methods=["DELETE"])
def delete_photographer(photographer_id: int):
    p = Photographer.query.get(photographer_id)
    if not p:
        return jsonify({"error": "Photographer not found."}), 404
    db.session.delete(p)
    db.session.commit()
    return jsonify({"message": "Photographer deleted."}), 200


@app.route("/halls/<int:hall_id>/photographers", methods=["GET"])
def get_hall_photographers(hall_id: int):
    hall = MarriageHall.query.get(hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404
    all_p  = Photographer.query.filter_by(is_available=True).all()
    linked = [p for p in all_p if hall_id in parse_hall_ids(p.hall_ids)]
    return jsonify([photographer_to_dict(p) for p in linked]), 200


# ─────────────────────────────────────────────
#  ROUTES — JazzCash Payments
# ─────────────────────────────────────────────

@app.route("/payments/jazzcash/initiate", methods=["POST"])
def jazzcash_initiate():
    data           = request.get_json(silent=True) or {}
    booking_id_raw = data.get("booking_id")
    mobile_number  = str(data.get("mobile_number", "")).strip()

    if not booking_id_raw:
        return jsonify({"error": "booking_id is required."}), 400
    if not mobile_number:
        return jsonify({"error": "mobile_number is required."}), 400

    booking = Booking.query.get(int(booking_id_raw))
    if not booking:
        return jsonify({"error": "Booking not found."}), 404
    if booking.payment_status == "paid":
        return jsonify({"error": "This booking is already paid."}), 409

    base_rent     = float(booking.hall.rent) if booking.hall else 0
    adjusted_cost = calculate_adjusted_cost(base_rent, booking.guest_count)
    total_amount  = (
        Decimal(str(adjusted_cost))
        + (booking.total_extra_cost  or Decimal("0"))
        + (booking.photographer_cost or Decimal("0"))
    )

    txn_ref_no = f"SG-{utc_now().strftime('%Y%m%d%H%M%S')}-{uuid.uuid4().hex[:6].upper()}"

    payment = Payment(
        booking_id   =booking.hall_booking_id,
        txn_ref_no   =txn_ref_no,
        amount       =total_amount,
        mobile_number=mobile_number,
        status       ="pending",
        created_at   =utc_now(),
        updated_at   =utc_now(),
    )
    db.session.add(payment)
    db.session.commit()

    jc_response   = jazzcash_initiate_wallet_payment(
        txn_ref_no   =txn_ref_no,
        amount_pkr   =total_amount,
        mobile_number=mobile_number,
        description  =f"Shaadi Ghar Booking #{booking.hall_booking_id}",
    )
    response_code             = jc_response.get("pp_ResponseCode", "99")
    payment.jazzcash_response = json.dumps(jc_response)
    payment.updated_at        = utc_now()

    if response_code == "000":
        payment.status            = "success"
        booking.payment_status    = "paid"
        booking.payment_reference = txn_ref_no
        db.session.commit()
        return jsonify({
            "message":           "Payment successful.",
            "txn_ref_no":        txn_ref_no,
            "jazzcash_response": jc_response,
            "payment":           payment_to_dict(payment),
        }), 200
    elif response_code == "001":
        payment.status = "pending"
        db.session.commit()
        return jsonify({
            "message":           "Payment initiated. Awaiting JazzCash confirmation.",
            "txn_ref_no":        txn_ref_no,
            "jazzcash_response": jc_response,
            "payment":           payment_to_dict(payment),
        }), 200
    else:
        payment.status         = "failed"
        booking.payment_status = "failed"
        db.session.commit()
        return jsonify({
            "error":             f"JazzCash payment failed: {jc_response.get('pp_ResponseMessage', 'Unknown error')}",
            "response_code":     response_code,
            "jazzcash_response": jc_response,
            "payment":           payment_to_dict(payment),
        }), 402


@app.route("/payments/jazzcash/callback", methods=["POST"])
def jazzcash_callback():
    if request.content_type and "json" in request.content_type:
        callback_data = request.get_json(silent=True) or {}
    else:
        callback_data = request.form.to_dict()

    txn_ref_no    = callback_data.get("pp_TxnRefNo",    "")
    response_code = callback_data.get("pp_ResponseCode","99")
    received_hash = callback_data.get("pp_SecureHash",  "")

    hash_params   = {k: v for k, v in callback_data.items() if k != "pp_SecureHash"}
    expected_hash = jazzcash_generate_hash(hash_params, JAZZCASH_INTEGRITY_SALT)
    if received_hash != expected_hash:
        return jsonify({"error": "Invalid secure hash."}), 400

    payment = Payment.query.filter_by(txn_ref_no=txn_ref_no).first()
    if not payment:
        return jsonify({"error": "Payment record not found."}), 404

    payment.jazzcash_response = json.dumps(callback_data)
    payment.updated_at        = utc_now()
    booking                   = Booking.query.get(payment.booking_id)

    if response_code == "000":
        payment.status = "success"
        if booking:
            booking.payment_status    = "paid"
            booking.payment_reference = txn_ref_no
    else:
        payment.status = "failed"
        if booking:
            booking.payment_status = "failed"

    db.session.commit()
    return jsonify({"message": "Callback processed."}), 200


@app.route("/payments/<int:booking_id>", methods=["GET"])
def get_payments_for_booking(booking_id: int):
    booking = Booking.query.get(booking_id)
    if not booking:
        return jsonify({"error": "Booking not found."}), 404
    payments = (
        Payment.query
        .filter_by(booking_id=booking_id)
        .order_by(Payment.created_at.desc())
        .all()
    )
    return jsonify({
        "booking_id":        booking_id,
        "payment_status":    booking.payment_status,
        "payment_reference": booking.payment_reference,
        "payments":          [payment_to_dict(p) for p in payments],
    }), 200


# ─────────────────────────────────────────────
#  ROUTES — Admin (Flutter-specific paths)
# ─────────────────────────────────────────────

@app.route("/admin/stats", methods=["GET"])
def admin_stats():
    total_halls         = MarriageHall.query.count()
    total_customers     = Customer.query.count()
    total_bookings      = Booking.query.count()
    total_photographers = Photographer.query.count()
    paid_bookings       = Booking.query.filter_by(payment_status="paid").count()
    pending_bookings    = Booking.query.filter_by(status="pending").count()

    paid_booking_objs = Booking.query.filter_by(payment_status="paid").all()
    total_revenue = sum(
        float(b.hall.rent if b.hall else 0)
        + float(b.total_extra_cost or 0)
        + float(b.photographer_cost or 0)
        for b in paid_booking_objs
    )

    return jsonify({
        "total_halls":           total_halls,
        "total_customers":       total_customers,
        "total_bookings":        total_bookings,
        "total_photographers":   total_photographers,
        "paid_bookings":         paid_bookings,
        "pending_bookings":      pending_bookings,
        "estimated_revenue_pkr": total_revenue,
        "bookings_by_status": {
            "pending":   pending_bookings,
            "approved":  Booking.query.filter_by(status="approved").count(),
            "rejected":  Booking.query.filter_by(status="rejected").count(),
            "cancelled": Booking.query.filter_by(status="cancelled").count(),
        },
        "bookings_by_payment": {
            "unpaid": Booking.query.filter_by(payment_status="unpaid").count(),
            "paid":   paid_bookings,
            "failed": Booking.query.filter_by(payment_status="failed").count(),
        },
    }), 200


@app.route("/admin/bookings", methods=["GET"])
def admin_get_bookings():
    customer_id    = request.args.get("customer_id",    "").strip()
    hall_id        = request.args.get("hall_id",        "").strip()
    status         = request.args.get("status",         "").strip()
    payment_status = request.args.get("payment_status", "").strip()
    search         = request.args.get("search",         "").strip()

    query = Booking.query
    if customer_id:
        try:
            query = query.filter_by(customer_id=int(customer_id))
        except ValueError:
            pass
    if hall_id:
        try:
            query = query.filter_by(hall_id=int(hall_id))
        except ValueError:
            pass
    if status:
        query = query.filter_by(status=status)
    if payment_status:
        query = query.filter_by(payment_status=payment_status)
    if search:
        query = query.filter(or_(
            Booking.customer_name.ilike(f"%{search}%"),
            Booking.event_type.ilike(f"%{search}%"),
        ))

    bookings = query.order_by(Booking.created_at.desc()).all()
    return jsonify([booking_to_dict(b) for b in bookings]), 200


@app.route("/admin/customers", methods=["GET"])
def admin_get_customers():
    search    = request.args.get("search", "").strip()
    query     = Customer.query
    if search:
        query = query.filter(or_(
            Customer.name.ilike(f"%{search}%"),
            Customer.email.ilike(f"%{search}%"),
            Customer.phone.ilike(f"%{search}%"),
        ))
    customers = query.order_by(Customer.created_at.desc()).all()
    return jsonify([customer_to_dict(c) for c in customers]), 200


@app.route("/admin/update_booking/<int:booking_id>", methods=["PUT"])
def admin_update_booking(booking_id: int):
    """PUT /admin/update_booking/<bookingId> — Flutter AdminDashboard approve/reject"""
    booking = Booking.query.get(booking_id)
    if not booking:
        return jsonify({"error": "Booking not found."}), 404
    data       = request.get_json(silent=True) or {}
    new_status = str(data.get("status", "")).strip().lower()
    # Flutter sends: approved, rejected, cancelled, pending
    valid = {"pending", "approved", "rejected", "cancelled", "confirmed", "completed"}
    if new_status not in valid:
        return jsonify({"error": f"Status must be one of {sorted(valid)}."}), 400
    booking.status = new_status
    db.session.commit()
    customer = Customer.query.get(booking.customer_id)
    if customer:
        send_booking_status_update_email(customer.email, booking, new_status)
    log_action(ADMIN_EMAIL, "admin", f"updated booking {booking_id} status to {new_status}")
    return jsonify({"message": "Booking updated.", "booking": booking_to_dict(booking)}), 200


@app.route("/admin/send_booking_message/<int:booking_id>", methods=["POST"])
def admin_send_booking_message(booking_id: int):
    """POST /admin/send_booking_message/<bookingId> — Flutter AdminDashboard messages"""
    booking = Booking.query.get(booking_id)
    if not booking:
        return jsonify({"error": "Booking not found."}), 404
    data         = request.get_json(silent=True) or {}
    message_text = str(data.get("message", "")).strip()
    if not message_text:
        return jsonify({"error": "message is required."}), 400
    msg = create_booking_message(booking, "admin", "Admin", message_text)
    customer = Customer.query.get(booking.customer_id)
    if customer:
        send_booking_message_email(customer.email, booking, message_text)
    return jsonify({"message": "Message sent.", "booking_message": booking_message_to_dict(msg)}), 201


@app.route("/admin/halls", methods=["GET"])
def admin_get_halls():
    halls = MarriageHall.query.order_by(MarriageHall.hall_id).all()
    return jsonify([hall_to_dict(h) for h in halls]), 200


@app.route("/admin/halls", methods=["POST"])
def admin_create_hall():
    data     = request.get_json(silent=True) or {}
    name     = str(data.get("name", "")).strip()
    location = str(data.get("location", "")).strip()
    if not name or not location:
        return jsonify({"error": "Name and location are required."}), 400
    capacity, err = parse_positive_int(data.get("capacity", 1), "Capacity")
    if err:
        return jsonify({"error": err}), 400
    rent, err = parse_non_negative_decimal(data.get("rent", 0), "Rent")
    if err:
        return jsonify({"error": err}), 400
    hall = MarriageHall(
        name           =name,
        location       =location,
        capacity       =capacity,
        rent           =rent,
        contact_person =str(data.get("contact_person", "")).strip(),
        phone_number   =str(data.get("phone_number", "")).strip(),
        email          =str(data.get("email", "")).strip(),
        description    =str(data.get("description", "")).strip(),
        image_urls     =json.dumps(parse_image_urls(data.get("image_urls", []))),
        category       =str(data.get("category", "Indoor")).strip(),
        is_featured    =bool(data.get("is_featured", False)),
    )
    db.session.add(hall)
    db.session.commit()
    log_action(ADMIN_EMAIL, "admin", f"created hall {hall.hall_id}")
    return jsonify({"message": "Hall created.", "hall": hall_to_dict(hall)}), 201


@app.route("/admin/update_hall/<int:hall_id>", methods=["PUT"])
def admin_update_hall(hall_id: int):
    """PUT /admin/update_hall/<hallId> — Flutter ManageHallsPage edit"""
    hall = MarriageHall.query.get(hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404
    data = request.get_json(silent=True) or {}
    if "name"           in data: hall.name           = str(data["name"]).strip()
    if "location"       in data: hall.location       = str(data["location"]).strip()
    if "contact_person" in data: hall.contact_person = str(data["contact_person"]).strip()
    if "phone_number"   in data: hall.phone_number   = str(data["phone_number"]).strip()
    if "email"          in data: hall.email          = str(data["email"]).strip()
    if "description"    in data: hall.description    = str(data["description"]).strip()
    if "category"       in data: hall.category       = str(data["category"]).strip()
    if "is_featured"    in data: hall.is_featured    = bool(data["is_featured"])
    if "capacity" in data:
        capacity, err = parse_positive_int(data["capacity"], "Capacity")
        if err:
            return jsonify({"error": err}), 400
        hall.capacity = capacity
    if "rent" in data:
        rent, err = parse_non_negative_decimal(data["rent"], "Rent")
        if err:
            return jsonify({"error": err}), 400
        hall.rent = rent
    if "image_urls" in data:
        hall.image_urls = json.dumps(parse_image_urls(data["image_urls"]))
    db.session.commit()
    log_action(ADMIN_EMAIL, "admin", f"updated hall {hall_id}")
    return jsonify({"message": "Hall updated.", "hall": hall_to_dict(hall)}), 200


@app.route("/admin/delete_hall/<int:hall_id>", methods=["DELETE"])
def admin_delete_hall(hall_id: int):
    """DELETE /admin/delete_hall/<hallId> — Flutter ManageHallsPage delete"""
    hall = MarriageHall.query.get(hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404
    db.session.delete(hall)
    db.session.commit()
    log_action(ADMIN_EMAIL, "admin", f"deleted hall {hall_id}")
    return jsonify({"message": "Hall deleted."}), 200


# Admin photographer / menu / feedback / logs (convenience aliases)

@app.route("/admin/photographers", methods=["GET"])
def admin_get_photographers():
    photographers = Photographer.query.order_by(Photographer.name).all()
    return jsonify([photographer_to_dict(p) for p in photographers]), 200

@app.route("/admin/photographers", methods=["POST"])
def admin_create_photographer():
    return create_photographer()

@app.route("/admin/photographers/<int:photographer_id>", methods=["PUT"])
def admin_update_photographer(photographer_id: int):
    return update_photographer(photographer_id)

@app.route("/admin/photographers/<int:photographer_id>", methods=["DELETE"])
def admin_delete_photographer(photographer_id: int):
    return delete_photographer(photographer_id)

@app.route("/admin/menus/<int:hall_id>", methods=["GET"])
def admin_get_menus(hall_id: int):
    return get_hall_menus(hall_id)

@app.route("/admin/menus/<int:hall_id>", methods=["POST"])
def admin_add_menu(hall_id: int):
    return add_menu_item(hall_id)

@app.route("/admin/menus/item/<int:menu_id>", methods=["PUT"])
def admin_update_menu(menu_id: int):
    return update_menu_item(menu_id)

@app.route("/admin/menus/item/<int:menu_id>", methods=["DELETE"])
def admin_delete_menu(menu_id: int):
    return delete_menu_item(menu_id)

@app.route("/admin/feedback/<int:hall_id>", methods=["GET"])
def admin_get_feedback(hall_id: int):
    return get_feedback(hall_id)

@app.route("/admin/logs", methods=["GET"])
def get_logs():
    logs = UserLog.query.order_by(UserLog.timestamp.desc()).limit(200).all()
    return jsonify([{
        "log_id":    log.log_id,
        "email":     log.email,
        "role":      log.role,
        "action":    log.action,
        "timestamp": log.timestamp.isoformat(),
    } for log in logs]), 200


# Customers CRUD (admin)
@app.route("/admin/customers/<int:customer_id>", methods=["GET"])
def admin_get_customer(customer_id: int):
    customer = Customer.query.get(customer_id)
    if not customer:
        return jsonify({"error": "Customer not found."}), 404
    return jsonify(customer_to_dict(customer)), 200

@app.route("/admin/customers/<int:customer_id>", methods=["PUT"])
def admin_update_customer(customer_id: int):
    customer = Customer.query.get(customer_id)
    if not customer:
        return jsonify({"error": "Customer not found."}), 404
    data = request.get_json(silent=True) or {}
    if "name"              in data: customer.name              = str(data["name"]).strip()
    if "phone"             in data: customer.phone             = str(data["phone"]).strip()
    if "favorite_category" in data: customer.favorite_category = str(data["favorite_category"]).strip()
    if "profile_image"     in data: customer.profile_image     = str(data["profile_image"]).strip()
    if "password" in data and data["password"]:
        customer.password_hash = generate_password_hash(str(data["password"]))
    db.session.commit()
    log_action(ADMIN_EMAIL, "admin", f"updated customer {customer_id}")
    return jsonify({"message": "Customer updated.", "customer": customer_to_dict(customer)}), 200

@app.route("/admin/customers/<int:customer_id>", methods=["DELETE"])
def admin_delete_customer(customer_id: int):
    customer = Customer.query.get(customer_id)
    if not customer:
        return jsonify({"error": "Customer not found."}), 404
    db.session.delete(customer)
    db.session.commit()
    log_action(ADMIN_EMAIL, "admin", f"deleted customer {customer_id}")
    return jsonify({"message": "Customer deleted."}), 200


# ─────────────────────────────────────────────
#  ROUTES — Health
# ─────────────────────────────────────────────

@app.route("/", methods=["GET"])
def health_check():
    return jsonify({
        "status":  "ok",
        "message": "Shaadi Ghar API is running (SQL Server – MHDB).",
    }), 200


# ─────────────────────────────────────────────
#  STARTUP
# ─────────────────────────────────────────────

with app.app_context():
    db.create_all()
    sync_default_halls()
    seed_default_data()

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)