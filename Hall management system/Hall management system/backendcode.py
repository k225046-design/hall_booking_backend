from __future__ import annotations

import json
import os
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal, InvalidOperation
from math import asin, cos, radians, sin, sqrt

from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import or_, text
from werkzeug.security import check_password_hash, generate_password_hash
from dotenv import load_dotenv


app = Flask(__name__)
load_dotenv()
CORS(app, resources={r"/*": {"origins": "*"}})
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///hallbooking.db"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)

ADMIN_EMAIL = os.getenv('ADMIN_EMAIL', 'admin@admin.com')
ADMIN_PASSWORD = os.getenv('ADMIN_PASSWORD', 'admin123')

# Email settings (used for booking confirmations and status updates).
# If you use Gmail, create an App Password and set it here.
SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 587
SMTP_USERNAME = "your-email@gmail.com"
SMTP_PASSWORD = "your-app-password"
FROM_EMAIL = "your-email@gmail.com"
FROM_NAME = "Shaadi Ghar"

# Serve Flutter web assets (images) so Image.network can display them in web.
_BASE_DIR = os.path.dirname(os.path.abspath(__file__))
_FLUTTER_ASSETS_DIR = os.path.join(_BASE_DIR, "hall_booking_app", "assets")


@app.route("/app_assets/<path:relpath>")
def app_assets(relpath: str):
    """
    Serve static files from the Flutter project's `assets/` directory.

    Example relpath:
      images/halls/dream_garden/hall1.jpg
    """
    if not os.path.isdir(_FLUTTER_ASSETS_DIR):
        return jsonify({"error": "Assets directory not found."}), 404
    return send_from_directory(_FLUTTER_ASSETS_DIR, relpath)


def utc_now() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)

DEFAULT_MENUS = [
    # Pakistani Wedding Menu - Comprehensive Desi Menu
    {"hall_id": 1, "category": "Biryani & Rice", "item_name": "Chicken Biryani", "price_per_plate": Decimal("450"), "description": "Sindhi-style aromatic basmati rice with chicken", "is_vegetarian": False},
    {"hall_id": 1, "category": "Biryani & Rice", "item_name": "Mutton Biryani", "price_per_plate": Decimal("650"), "description": "Rich mutton biryani with saffron", "is_vegetarian": False},
    {"hall_id": 1, "category": "Biryani & Rice", "item_name": "Vegetable Biryani", "price_per_plate": Decimal("400"), "description": "Veg biryani with fresh vegetables", "is_vegetarian": True},
    {"hall_id": 1, "category": "Main Course", "item_name": "Chicken Karahi", "price_per_plate": Decimal("550"), "description": "Spicy chicken karahi with ginger & green chilies", "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course", "item_name": "Mutton Karahi", "price_per_plate": Decimal("750"), "description": "Tender mutton karahi", "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course", "item_name": "Nihari", "price_per_plate": Decimal("600"), "description": "Slow-cooked beef shank nihari with bone marrow", "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course", "item_name": "Haleem", "price_per_plate": Decimal("500"), "description": "Lentil & meat haleem", "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course", "item_name": "Chicken Haleem", "price_per_plate": Decimal("450"), "description": "Chicken haleem", "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course", "item_name": "Palak Gosht", "price_per_plate": Decimal("550"), "description": "Spinach with mutton", "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course", "item_name": "Aloo Gosht", "price_per_plate": Decimal("450"), "description": "Potato mutton curry", "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course", "item_name": "Chicken Tikka Masala", "price_per_plate": Decimal("500"), "description": "Creamy chicken tikka masala", "is_vegetarian": False},
    {"hall_id": 1, "category": "Main Course", "item_name": "Daal Chana", "price_per_plate": Decimal("350"), "description": "Spiced chickpeas", "is_vegetarian": True},
    {"hall_id": 1, "category": "Main Course", "item_name": "Daal Masoor", "price_per_plate": Decimal("300"), "description": "Red lentil curry", "is_vegetarian": True},
    {"hall_id": 1, "category": "Main Course", "item_name": "Mix Vegetable", "price_per_plate": Decimal("350"), "description": "Seasonal mixed vegetables", "is_vegetarian": True},
    {"hall_id": 1, "category": "Appetizers", "item_name": "Chicken Roll", "price_per_plate": Decimal("200"), "description": "Paratha roll with chicken", "is_vegetarian": False},
    {"hall_id": 1, "category": "Appetizers", "item_name": "Samosa", "price_per_plate": Decimal("80"), "description": "Spicy samosa", "is_vegetarian": False},
    {"hall_id": 1, "category": "Appetizers", "item_name": "Pakora", "price_per_plate": Decimal("150"), "description": "Vegetable fritters", "is_vegetarian": True},
    # Add for other halls similarly (truncated for brevity)
    {"hall_id": 2, "category": "Biryani & Rice", "item_name": "Chicken Biryani", "price_per_plate": Decimal("400"), "description": "Lahore-style biryani", "is_vegetarian": False},
    {"hall_id": 3, "category": "Main Course", "item_name": "Chicken Karahi", "price_per_plate": Decimal("500"), "description": "Faisalabad special", "is_vegetarian": False},
    # ... more items for all halls
    # Expanding menu for all halls
    {"hall_id": 1, "category": "Desserts", "item_name": "Ras Malai", "price_per_plate": Decimal("100"), "description": "Soft cheese dumplings in sweetened milk", "is_vegetarian": True},
    {"hall_id": 1, "category": "Desserts", "item_name": "Gulab Jamun", "price_per_plate": Decimal("120"), "description": "Sweet milk dumplings in rose syrup", "is_vegetarian": True},
    {"hall_id": 1, "category": "Desserts", "item_name": "Kheer", "price_per_plate": Decimal("90"), "description": "Rice pudding with nuts", "is_vegetarian": True},
    {"hall_id": 1, "category": "Drinks", "item_name": "Lassi", "price_per_plate": Decimal("80"), "description": "Yogurt drink with cardamom", "is_vegetarian": True},
    {"hall_id": 1, "category": "Drinks", "item_name": "Rooh Afza", "price_per_plate": Decimal("60"), "description": "Rose syrup drink", "is_vegetarian": True},
    {"hall_id": 1, "category": "Drinks", "item_name": "Mineral Water", "price_per_plate": Decimal("30"), "description": "Bottled water", "is_vegetarian": True},
    {"hall_id": 1, "category": "Salads", "item_name": "Kachumber Salad", "price_per_plate": Decimal("50"), "description": "Tomato, onion, cucumber salad", "is_vegetarian": True},
    {"hall_id": 1, "category": "Salads", "item_name": "Raita", "price_per_plate": Decimal("70"), "description": "Yogurt with cucumber", "is_vegetarian": True},
    # Add similar items for halls 2-10
    {"hall_id": 2, "category": "Desserts", "item_name": "Ras Malai", "price_per_plate": Decimal("95"), "description": "Soft cheese dumplings in sweetened milk", "is_vegetarian": True},
    {"hall_id": 2, "category": "Desserts", "item_name": "Gulab Jamun", "price_per_plate": Decimal("115"), "description": "Sweet milk dumplings in rose syrup", "is_vegetarian": True},
    {"hall_id": 2, "category": "Drinks", "item_name": "Lassi", "price_per_plate": Decimal("75"), "description": "Yogurt drink with cardamom", "is_vegetarian": True},
    {"hall_id": 3, "category": "Desserts", "item_name": "Ras Malai", "price_per_plate": Decimal("105"), "description": "Soft cheese dumplings in sweetened milk", "is_vegetarian": True},
    {"hall_id": 3, "category": "Drinks", "item_name": "Lassi", "price_per_plate": Decimal("85"), "description": "Yogurt drink with cardamom", "is_vegetarian": True},
    {"hall_id": 4, "category": "Desserts", "item_name": "Ras Malai", "price_per_plate": Decimal("100"), "description": "Soft cheese dumplings in sweetened milk", "is_vegetarian": True},
    {"hall_id": 4, "category": "Drinks", "item_name": "Lassi", "price_per_plate": Decimal("80"), "description": "Yogurt drink with cardamom", "is_vegetarian": True},
    {"hall_id": 5, "category": "Desserts", "item_name": "Ras Malai", "price_per_plate": Decimal("90"), "description": "Soft cheese dumplings in sweetened milk", "is_vegetarian": True},
    {"hall_id": 5, "category": "Drinks", "item_name": "Lassi", "price_per_plate": Decimal("70"), "description": "Yogurt drink with cardamom", "is_vegetarian": True},
    {"hall_id": 6, "category": "Desserts", "item_name": "Ras Malai", "price_per_plate": Decimal("110"), "description": "Soft cheese dumplings in sweetened milk", "is_vegetarian": True},
    {"hall_id": 6, "category": "Drinks", "item_name": "Lassi", "price_per_plate": Decimal("90"), "description": "Yogurt drink with cardamom", "is_vegetarian": True},
    {"hall_id": 7, "category": "Desserts", "item_name": "Ras Malai", "price_per_plate": Decimal("95"), "description": "Soft cheese dumplings in sweetened milk", "is_vegetarian": True},
    {"hall_id": 7, "category": "Drinks", "item_name": "Lassi", "price_per_plate": Decimal("75"), "description": "Yogurt drink with cardamom", "is_vegetarian": True},
    {"hall_id": 8, "category": "Desserts", "item_name": "Ras Malai", "price_per_plate": Decimal("105"), "description": "Soft cheese dumplings in sweetened milk", "is_vegetarian": True},
    {"hall_id": 8, "category": "Drinks", "item_name": "Lassi", "price_per_plate": Decimal("85"), "description": "Yogurt drink with cardamom", "is_vegetarian": True},
    {"hall_id": 9, "category": "Desserts", "item_name": "Ras Malai", "price_per_plate": Decimal("100"), "description": "Soft cheese dumplings in sweetened milk", "is_vegetarian": True},
    {"hall_id": 9, "category": "Drinks", "item_name": "Lassi", "price_per_plate": Decimal("80"), "description": "Yogurt drink with cardamom", "is_vegetarian": True},
    {"hall_id": 10, "category": "Desserts", "item_name": "Ras Malai", "price_per_plate": Decimal("115"), "description": "Soft cheese dumplings in sweetened milk", "is_vegetarian": True},
    {"hall_id": 10, "category": "Drinks", "item_name": "Lassi", "price_per_plate": Decimal("95"), "description": "Yogurt drink with cardamom", "is_vegetarian": True},
    # Add more main courses for all halls
    {"hall_id": 4, "category": "Main Course", "item_name": "Chicken Karahi", "price_per_plate": Decimal("520"), "description": "Spicy chicken karahi", "is_vegetarian": False},
    {"hall_id": 5, "category": "Main Course", "item_name": "Chicken Karahi", "price_per_plate": Decimal("480"), "description": "Spicy chicken karahi", "is_vegetarian": False},
    {"hall_id": 6, "category": "Main Course", "item_name": "Chicken Karahi", "price_per_plate": Decimal("560"), "description": "Spicy chicken karahi", "is_vegetarian": False},
    {"hall_id": 7, "category": "Main Course", "item_name": "Chicken Karahi", "price_per_plate": Decimal("500"), "description": "Spicy chicken karahi", "is_vegetarian": False},
    {"hall_id": 8, "category": "Main Course", "item_name": "Chicken Karahi", "price_per_plate": Decimal("530"), "description": "Spicy chicken karahi", "is_vegetarian": False},
    {"hall_id": 9, "category": "Main Course", "item_name": "Chicken Karahi", "price_per_plate": Decimal("510"), "description": "Spicy chicken karahi", "is_vegetarian": False},
    {"hall_id": 10, "category": "Main Course", "item_name": "Chicken Karahi", "price_per_plate": Decimal("570"), "description": "Spicy chicken karahi", "is_vegetarian": False},
]


DEFAULT_HALLS = [
    {
        "name": "Royal Orchid Hall",
        "location": "Karachi",
        "capacity": 900,
        "rent": Decimal("180000.00"),
        "contact_person": "Ahmed Khan",
        "phone_number": "03001234567",
        "email": "royalorchid@example.com",
        "description": "Grand indoor venue with bridal lounge and stage lighting.",
        "image_urls": json.dumps(
            [
                "assets/images/halls/royal_fort/hall1.jpg",
                "assets/images/halls/royal_fort/hall2.jpg",
                "assets/images/halls/royal_fort/hall3.jpg",
            ]
        ),
        "category": "Luxury",
        "is_featured": True,
    },
    {
        "name": "Dream Garden",
        "location": "Lahore",
        "capacity": 550,
        "rent": Decimal("120000.00"),
        "contact_person": "Sara Malik",
        "phone_number": "03111222333",
        "email": "dreamgarden@example.com",
        "description": "Open-air garden hall suited for weddings and mehndi events.",
        "image_urls": json.dumps(
            [
                "assets/images/halls/dream_garden/hall1.jpg",
                "assets/images/halls/dream_garden/hall2.jpg",
                "assets/images/halls/dream_garden/hall3.jpg",
            ]
        ),
        "category": "Outdoor",
        "is_featured": True,
    },
    {
        "name": "Galaxy Hall",
        "location": "Faisalabad",
        "capacity": 700,
        "rent": Decimal("140000.00"),
        "contact_person": "Usman Sheikh",
        "phone_number": "03334445566",
        "email": "galaxyhall@example.com",
        "description": "Stylish wedding hall with ambient lighting, modern decor, and spacious dining.",
        "image_urls": json.dumps(
            [
                "assets/images/halls/galaxy/hall1.jpg",
                "assets/images/halls/galaxy/hall2.jpg",
                "assets/images/halls/galaxy/hall3.jpg",
            ]
        ),
        "category": "Luxury",
        "is_featured": True,
    },
    {
        "name": "Pearl Palace",
        "location": "Islamabad",
        "capacity": 400,
        "rent": Decimal("95000.00"),
        "contact_person": "Hina Raza",
        "phone_number": "03219876543",
        "email": "pearlpalace@example.com",
        "description": "Modern banquet hall with valet parking and family suites.",
        "image_urls": json.dumps(
            [
                "assets/images/halls/pearl_palace/hall1.jpg",
                "assets/images/halls/pearl_palace/hall2.jpg",
                "assets/images/halls/pearl_palace/hall3.jpg",
            ]
        ),
        "category": "Indoor",
        "is_featured": False,
    },
    {
        "name": "Sunshine Villa",
        "location": "Multan",
        "capacity": 250,
        "rent": Decimal("65000.00"),
        "contact_person": "Bilal Hussain",
        "phone_number": "03451112233",
        "email": "sunshinevilla@example.com",
        "description": "Budget-friendly hall for intimate gatherings and walima events.",
        "image_urls": json.dumps(
            [
                "assets/images/halls/sunshine_villa/hall1.jpg",
                "assets/images/halls/sunshine_villa/hall2.jpg",
                "assets/images/halls/sunshine_villa/hall3.jpg",
            ]
        ),
        "category": "Budget",
        "is_featured": False,
    },
    {
        "name": "Celebration Center",
        "location": "Karachi",
        "capacity": 300,
        "rent": Decimal("80000.00"),
        "contact_person": "Ayesha Noor",
        "phone_number": "03005556677",
        "email": "celebrationcenter@example.com",
        "description": "Perfect for birthday parties, anniversaries, and small celebrations.",
        "image_urls": json.dumps(
            [
                "assets/images/halls/celebration_center/hall1.jpg",
                "assets/images/halls/celebration_center/hall2.jpg",
            ]
        ),
        "category": "Party",
        "is_featured": False,
    },
    {
        "name": "Corporate Plaza",
        "location": "Lahore",
        "capacity": 500,
        "rent": Decimal("100000.00"),
        "contact_person": "Zahid Ali",
        "phone_number": "03224445566",
        "email": "corporateplaza@example.com",
        "description": "Professional venue for corporate events, seminars, and conferences.",
        "image_urls": json.dumps(
            [
                "assets/images/halls/corporate_plaza/hall1.jpg",
                "assets/images/halls/corporate_plaza/hall2.jpg",
            ]
        ),
        "category": "Corporate",
        "is_featured": True,
    },
    {
        "name": "Garden Retreat",
        "location": "Islamabad",
        "capacity": 200,
        "rent": Decimal("70000.00"),
        "contact_person": "Fatima Khan",
        "phone_number": "03337778899",
        "email": "gardenretreat@example.com",
        "description": "Scenic outdoor venue for garden weddings and private parties.",
        "image_urls": json.dumps(
            [
                "assets/images/halls/garden_retreat/hall1.jpg",
                "assets/images/halls/garden_retreat/hall2.jpg",
            ]
        ),
        "category": "Outdoor",
        "is_featured": False,
    },
    {
        "name": "Heritage Hall",
        "location": "Faisalabad",
        "capacity": 600,
        "rent": Decimal("110000.00"),
        "contact_person": "Imran Shah",
        "phone_number": "03446667788",
        "email": "heritagehall@example.com",
        "description": "Traditional hall with cultural decor for cultural events and weddings.",
        "image_urls": json.dumps(
            [
                "assets/images/halls/heritage_hall/hall1.jpg",
                "assets/images/halls/heritage_hall/hall2.jpg",
            ]
        ),
        "category": "Cultural",
        "is_featured": False,
    },
    {
        "name": "Modern Arena",
        "location": "Peshawar",
        "capacity": 800,
        "rent": Decimal("130000.00"),
        "contact_person": "Nadia Begum",
        "phone_number": "03008889900",
        "email": "modernarena@example.com",
        "description": "State-of-the-art hall with advanced AV equipment for large events.",
        "image_urls": json.dumps(
            [
                "assets/images/halls/modern_arena/hall1.jpg",
                "assets/images/halls/modern_arena/hall2.jpg",
            ]
        ),
        "category": "Luxury",
        "is_featured": True,
    },
    {
        "name": "Cozy Corner",
        "location": "Quetta",
        "capacity": 150,
        "rent": Decimal("40000.00"),
        "contact_person": "Ahmed Baloch",
        "phone_number": "03119990011",
        "email": "cozycorner@example.com",
        "description": "Intimate setting for small family gatherings and ceremonies.",
        "image_urls": json.dumps(
            [
                "assets/images/halls/cozy_corner/hall1.jpg",
                "assets/images/halls/cozy_corner/hall2.jpg",
            ]
        ),
        "category": "Intimate",
        "is_featured": False,
    },
    {
        "name": "Riverside Pavilion",
        "location": "Hyderabad",
        "capacity": 350,
        "rent": Decimal("85000.00"),
        "contact_person": "Sana Mughal",
        "phone_number": "03221112233",
        "email": "riversidepavilion@example.com",
        "description": "Riverside location perfect for romantic weddings and receptions.",
        "image_urls": json.dumps(
            [
                "assets/images/halls/riverside_pavilion/hall1.jpg",
                "assets/images/halls/riverside_pavilion/hall2.jpg",
            ]
        ),
        "category": "Romantic",
        "is_featured": False,
    },
]

CITY_COORDINATES = {
    "karachi": (24.8607, 67.0011),
    "lahore": (31.5204, 74.3587),
    "islamabad": (33.6844, 73.0479),
    "rawalpindi": (33.5651, 73.0169),
    "faisalabad": (31.4504, 73.1350),
    "multan": (30.1575, 71.5249),
    "peshawar": (34.0151, 71.5249),
    "quetta": (30.1798, 66.9750),
    "hyderabad": (25.3960, 68.3578),
    "gujranwala": (32.1877, 74.1945),
    "sialkot": (32.4945, 74.5229),
    "sargodha": (32.0836, 72.6711),
    "bahawalpur": (29.3956, 71.6836),
}


class MarriageHall(db.Model):
    __tablename__ = "marriage_halls"

    hall_id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    location = db.Column(db.String(255), nullable=False)
    capacity = db.Column(db.Integer, nullable=False)
    rent = db.Column(db.Numeric(10, 2), nullable=False)
    contact_person = db.Column(db.String(100), nullable=False)
    phone_number = db.Column(db.String(20), nullable=False)
    email = db.Column(db.String(120), nullable=False)
    description = db.Column(db.Text, nullable=False, default="")
    image_urls = db.Column(db.Text, nullable=False, default="[]")
    category = db.Column(db.String(50), nullable=False, default="Indoor")
    is_featured = db.Column(db.Boolean, nullable=False, default=False)

    bookings = db.relationship(
        "Booking", backref="hall", cascade="all, delete-orphan", lazy=True
    )


class Customer(db.Model):
    __tablename__ = "customers"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(255), nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False)
    phone = db.Column(db.String(20), nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    favorite_category = db.Column(db.String(50), nullable=False, default="Any")
    profile_image = db.Column(db.Text, nullable=False, default="")
    created_at = db.Column(db.DateTime, nullable=False, default=utc_now)

    bookings = db.relationship(
        "Booking", backref="customer", cascade="all, delete-orphan", lazy=True
    )


class Booking(db.Model):
    __tablename__ = "bookings"

    hall_booking_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    hall_id = db.Column(db.Integer, db.ForeignKey("marriage_halls.hall_id"), nullable=False)
    customer_id = db.Column(db.Integer, db.ForeignKey("customers.id"), nullable=False)
    customer_name = db.Column(db.String(255), nullable=False)
    customer_contact_number = db.Column(db.String(20), nullable=False)
    booking_date = db.Column(db.Date, nullable=False)
    event_type = db.Column(db.String(50), nullable=False, default="Wedding")
    guest_count = db.Column(db.Integer, nullable=False, default=100)
    special_request = db.Column(db.Text, nullable=False, default="")
    additional_notes = db.Column(db.Text, nullable=False, default="")
    menu_items = db.Column(db.Text, nullable=False, default="[]")  # JSON array of {"menu_id": id, "quantity": num}
    total_extra_cost = db.Column(db.Numeric(10, 2), nullable=False, default=Decimal("0.00"))
    status = db.Column(db.String(20), nullable=False, default="pending")
    created_at = db.Column(db.DateTime, nullable=False, default=utc_now)

    messages = db.relationship(
        "BookingMessage",
        backref="booking",
        cascade="all, delete-orphan",
        lazy=True,
        order_by="BookingMessage.created_at.asc()",
    )


class BookingMessage(db.Model):
    __tablename__ = "booking_messages"

    message_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    booking_id = db.Column(
        db.Integer, db.ForeignKey("bookings.hall_booking_id"), nullable=False
    )
    sender_role = db.Column(db.String(20), nullable=False)
    sender_name = db.Column(db.String(255), nullable=False)
    message = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=utc_now)


class UserLog(db.Model):
    __tablename__ = "user_logs"

    log_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    email = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(50), nullable=False)
    action = db.Column(db.String(255), nullable=False)
    timestamp = db.Column(db.DateTime, nullable=False, default=utc_now)


class HallFeedback(db.Model):
    __tablename__ = "hall_feedback"

    feedback_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    hall_id = db.Column(
        db.Integer, db.ForeignKey("marriage_halls.hall_id"), nullable=False
    )
    customer_id = db.Column(
        db.Integer, db.ForeignKey("customers.id"), nullable=False
    )
    customer_name = db.Column(db.String(255), nullable=False)
    rating = db.Column(db.Integer, nullable=False)
    comment = db.Column(db.Text, nullable=False, default="")
    created_at = db.Column(db.DateTime, nullable=False, default=utc_now)


class FoodMenu(db.Model):
    __tablename__ = "food_menus"

    menu_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    hall_id = db.Column(db.Integer, db.ForeignKey("marriage_halls.hall_id"), nullable=False)
    category = db.Column(db.String(100), nullable=False, default="Main Course")
    item_name = db.Column(db.String(255), nullable=False)
    price_per_plate = db.Column(db.Numeric(8, 2), nullable=False)
    description = db.Column(db.Text, default="")
    is_vegetarian = db.Column(db.Boolean, default=False)
    is_available = db.Column(db.Boolean, default=True)

    hall = db.relationship("MarriageHall", backref="menus")


def parse_image_urls(value: str | list | None) -> list[str]:
    if isinstance(value, list):
        return [str(item).strip() for item in value if str(item).strip()]
    if not value:
        return []
    if isinstance(value, str):
        try:
            parsed = json.loads(value)
            if isinstance(parsed, list):
                return [str(item).strip() for item in parsed if str(item).strip()]
        except json.JSONDecodeError:
            pass
        return [item.strip() for item in value.split(",") if item.strip()]
    return []


def validate_registration_payload(data: dict) -> str | None:
    name = str(data.get("name", "")).strip()
    email = str(data.get("email", "")).strip().lower()
    phone = str(data.get("phone", "")).strip()
    password = str(data.get("password", ""))

    if not name:
        return "Name is required."
    if not email:
        return "Email is required."
    if "@" not in email or "." not in email.split("@")[-1]:
        return "Enter a valid email address."
    if not phone:
        return "Phone number is required."
    if len(phone) < 10:
        return "Phone number looks incomplete."
    if not password:
        return "Password is required."
    if len(password) < 6:
        return "Password must be at least 6 characters."
    return None


def parse_positive_int(value: object, field_name: str) -> tuple[int | None, str | None]:
    try:
        parsed = int(str(value).strip())
    except (TypeError, ValueError):
        return None, f"{field_name} must be a valid number."
    if parsed < 1:
        return None, f"{field_name} must be at least 1."
    return parsed, None


def parse_non_negative_decimal(
    value: object, field_name: str
) -> tuple[Decimal | None, str | None]:
    try:
        parsed = Decimal(str(value).strip())
    except (InvalidOperation, ValueError):
        return None, f"{field_name} must be a valid amount."
    if parsed < 0:
        return None, f"{field_name} cannot be negative."
    return parsed, None


def resolve_city_coordinates(city_name: str | None) -> tuple[float, float] | None:
    if not city_name:
        return None
    normalized = city_name.strip().lower()
    if not normalized:
        return None
    if normalized in CITY_COORDINATES:
        return CITY_COORDINATES[normalized]
    for city, coordinates in CITY_COORDINATES.items():
        if city in normalized or normalized in city:
            return coordinates
    return None


def distance_km(
    first: tuple[float, float], second: tuple[float, float]
) -> float:
    lat1, lon1 = first
    lat2, lon2 = second
    radius = 6371.0
    d_lat = radians(lat2 - lat1)
    d_lon = radians(lon2 - lon1)
    a = (
        sin(d_lat / 2) ** 2
        + cos(radians(lat1)) * cos(radians(lat2)) * sin(d_lon / 2) ** 2
    )
    return 2 * radius * asin(sqrt(a))


def menu_to_dict(menu: FoodMenu) -> dict:
    return {
        "menu_id": menu.menu_id,
        "hall_id": menu.hall_id,
        "category": menu.category,
        "item_name": menu.item_name,
        "price_per_plate": float(menu.price_per_plate),
        "description": menu.description or "",
        "is_vegetarian": menu.is_vegetarian,
        "is_available": menu.is_available,
    }


def hall_to_dict(hall: MarriageHall) -> dict:
    feedback_summary = hall_feedback_summary(hall.hall_id)
    menus = [menu_to_dict(menu) for menu in getattr(hall, 'menus', [])[:10]]  # First 10 menus
    return {
        "hall_id": hall.hall_id,
        "name": hall.name,
        "location": hall.location,
        "capacity": hall.capacity,
        "rent": float(hall.rent),
        "contact_person": hall.contact_person,
        "phone_number": hall.phone_number,
        "email": hall.email,
        "description": hall.description,
        "image_urls": parse_image_urls(hall.image_urls),
        "category": hall.category,
        "is_featured": hall.is_featured,
        "average_rating": feedback_summary["average_rating"],
        "feedback_count": feedback_summary["feedback_count"],
        "menus": menus,
    }


def feedback_to_dict(feedback: HallFeedback) -> dict:
    return {
        "feedback_id": feedback.feedback_id,
        "hall_id": feedback.hall_id,
        "customer_id": feedback.customer_id,
        "customer_name": feedback.customer_name,
        "rating": feedback.rating,
        "comment": feedback.comment,
        "created_at": feedback.created_at.isoformat(),
    }


def calculate_adjusted_cost(base_rent: float, guest_count: int) -> float:
    """
    Calculate adjusted cost based on guest count.
    Base setup: 30 people
    For every additional 30 people: +20,000
    Formula: base_rent + floor((guest_count - 30) / 30) * 20000 if guest_count > 30
    """
    BASE_CAPACITY = 30
    COST_PER_30_GUESTS = 20000
    
    if guest_count <= BASE_CAPACITY:
        return float(base_rent)
    
    additional_groups = (guest_count - BASE_CAPACITY) // BASE_CAPACITY
    adjusted_cost = float(base_rent) + (additional_groups * COST_PER_30_GUESTS)
    return adjusted_cost


def booking_to_dict(booking: Booking) -> dict:
    base_rent = float(booking.hall.rent) if booking.hall else 0
    adjusted_cost = calculate_adjusted_cost(base_rent, booking.guest_count)
    total_cost = adjusted_cost + float(booking.total_extra_cost or 0)
    
    return {
        "hall_booking_id": booking.hall_booking_id,
        "hall_id": booking.hall_id,
        "hall_name": booking.hall.name if booking.hall else "",
        "customer_id": booking.customer_id,
        "customer_name": booking.customer_name,
        "customer_contact_number": booking.customer_contact_number,
        "booking_date": booking.booking_date.isoformat(),
        "event_type": booking.event_type,
        "guest_count": booking.guest_count,
        "special_request": booking.special_request,
        "additional_notes": booking.additional_notes,
        "menu_items": json.loads(booking.menu_items or "[]"),
        "total_extra_cost": float(booking.total_extra_cost or 0),
        "total_cost": total_cost,
        "status": booking.status,
        "created_at": booking.created_at.isoformat(),
        "messages": [booking_message_to_dict(message) for message in booking.messages],
    }


def booking_message_to_dict(message: BookingMessage) -> dict:
    return {
        "message_id": message.message_id,
        "booking_id": message.booking_id,
        "sender_role": message.sender_role,
        "sender_name": message.sender_name,
        "message": message.message,
        "created_at": message.created_at.isoformat(),
    }


def customer_to_dict(customer: Customer) -> dict:
    return {
        "id": customer.id,
        "name": customer.name,
        "email": customer.email,
        "phone": customer.phone,
        "favorite_category": customer.favorite_category,
        "profile_image": customer.profile_image,
        "created_at": customer.created_at.isoformat(),
    }


def hall_feedback_summary(hall_id: int) -> dict:
    feedback_entries = (
        HallFeedback.query.filter_by(hall_id=hall_id)
        .order_by(HallFeedback.created_at.desc())
        .all()
    )
    total = len(feedback_entries)
    average = (
        round(sum(item.rating for item in feedback_entries) / total, 1)
        if total
        else 0.0
    )
    return {
        "average_rating": average,
        "feedback_count": total,
        "feedback": [feedback_to_dict(item) for item in feedback_entries],
    }


def log_action(email: str, role: str, action: str) -> None:
    db.session.add(UserLog(email=email, role=role, action=action))
    db.session.commit()


def seed_default_data() -> None:
    if MarriageHall.query.count() == 0:
        for hall in DEFAULT_HALLS:
            db.session.add(MarriageHall(**hall))
        db.session.commit()
    
    # Seed Pakistani menus for default halls
    if FoodMenu.query.count() == 0:
        for menu_data in DEFAULT_MENUS:
            db.session.add(FoodMenu(**menu_data))
        db.session.commit()


def sync_default_halls() -> None:
    changed = False
    for hall_data in DEFAULT_HALLS:
        existing_hall = MarriageHall.query.filter_by(name=hall_data["name"]).first()
        if existing_hall is None:
            db.session.add(MarriageHall(**hall_data))
            changed = True
            continue

        if not parse_image_urls(existing_hall.image_urls):
            existing_hall.image_urls = hall_data["image_urls"]
            changed = True
        if not existing_hall.description.strip():
            existing_hall.description = hall_data["description"]
            changed = True
        if not existing_hall.category.strip():
            existing_hall.category = hall_data["category"]
            changed = True

    if changed:
        db.session.commit()


def ensure_schema() -> None:
    with db.engine.begin() as connection:
        hall_columns = {
            row[1] for row in connection.execute(text("PRAGMA table_info(marriage_halls)"))
        }
        if "image_urls" not in hall_columns:
            connection.execute(
                text(
                    "ALTER TABLE marriage_halls "
                    "ADD COLUMN image_urls TEXT NOT NULL DEFAULT '[]'"
                )
            )

        booking_columns = {
            row[1] for row in connection.execute(text("PRAGMA table_info(bookings)"))
        }
        if "additional_notes" not in booking_columns:
            connection.execute(
                text(
                    "ALTER TABLE bookings "
                    "ADD COLUMN additional_notes TEXT NOT NULL DEFAULT ''"
                )
            )
        if "menu_items" not in booking_columns:
            connection.execute(
                text(
                    "ALTER TABLE bookings "
                    "ADD COLUMN menu_items TEXT NOT NULL DEFAULT '[]'"
                )
            )
        if "total_extra_cost" not in booking_columns:
            connection.execute(
                text(
                    "ALTER TABLE bookings "
                    "ADD COLUMN total_extra_cost NUMERIC(10,2) NOT NULL DEFAULT 0.00"
                )
            )
        connection.execute(
            text(
                "CREATE TABLE IF NOT EXISTS booking_messages ("
                "message_id INTEGER PRIMARY KEY AUTOINCREMENT, "
                "booking_id INTEGER NOT NULL, "
                "sender_role VARCHAR(20) NOT NULL, "
                "sender_name VARCHAR(255) NOT NULL, "
                "message TEXT NOT NULL, "
                "created_at DATETIME NOT NULL, "
                "FOREIGN KEY(booking_id) REFERENCES bookings(hall_booking_id)"
                ")"
            )
        )
        connection.execute(
            text(
                "CREATE TABLE IF NOT EXISTS hall_feedback ("
                "feedback_id INTEGER PRIMARY KEY AUTOINCREMENT, "
                "hall_id INTEGER NOT NULL, "
                "customer_id INTEGER NOT NULL, "
                "customer_name VARCHAR(255) NOT NULL, "
                "rating INTEGER NOT NULL, "
                "comment TEXT NOT NULL DEFAULT '', "
                "created_at DATETIME NOT NULL, "
                "FOREIGN KEY(hall_id) REFERENCES marriage_halls(hall_id), "
                "FOREIGN KEY(customer_id) REFERENCES customers(id)"
                ")"
            )
        )
        connection.execute(
            text(
                "CREATE TABLE IF NOT EXISTS food_menus ("
                "menu_id INTEGER PRIMARY KEY AUTOINCREMENT, "
                "hall_id INTEGER NOT NULL, "
                "category VARCHAR(100) NOT NULL DEFAULT 'Main Course', "
                "item_name VARCHAR(255) NOT NULL, "
                "price_per_plate NUMERIC(8,2) NOT NULL, "
                "description TEXT DEFAULT '', "
                "is_vegetarian BOOLEAN DEFAULT 0, "
                "is_available BOOLEAN DEFAULT 1, "
                "FOREIGN KEY(hall_id) REFERENCES marriage_halls(hall_id)"
                ")"
            )
        )


def create_booking_message(
    booking: Booking, sender_role: str, sender_name: str, message_text: str
) -> BookingMessage:
    booking_message = BookingMessage(
        booking_id=booking.hall_booking_id,
        sender_role=sender_role,
        sender_name=sender_name,
        message=message_text,
    )
    db.session.add(booking_message)
    db.session.commit()
    return booking_message


def send_email(to_email: str, subject: str, html_content: str) -> None:
    """Send an HTML email using SMTP."""
    email_configured = all(
        value
        and "your-email@gmail.com" not in value
        and "your-app-password" not in value
        for value in (SMTP_USERNAME, SMTP_PASSWORD, FROM_EMAIL)
    )
    if not email_configured:
        return

    try:
        import smtplib
        from email.mime.multipart import MIMEMultipart
        from email.mime.text import MIMEText

        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = f"{FROM_NAME} <{FROM_EMAIL}>"
        msg["To"] = to_email

        msg.attach(MIMEText(html_content, "html"))

        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.sendmail(FROM_EMAIL, to_email, msg.as_string())
    except Exception as e:
        # Log the email failure but do not stop request processing.
        print(f"Failed to send email to {to_email}: {e}")


def send_booking_confirmation_email(
    customer_email: str, booking: Booking, hall: MarriageHall
) -> None:
    subject = f"Booking Confirmation | {hall.name}"
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8" />
      <title>Booking Confirmation</title>
      <style>
        body {{ font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 16px; }}
        .card {{ max-width: 600px; margin: 0 auto; background: #fff; padding: 24px; border-radius: 12px; box-shadow: 0 10px 20px rgba(0,0,0,0.08); }}
        .header {{ text-align: center; margin-bottom: 18px; }}
        .header h1 {{ margin: 0; color: #B6465F; }}
        .field {{ margin-bottom: 12px; }}
        .label {{ font-weight: bold; color: #333; }}
        .value {{ color: #555; }}
        .footer {{ margin-top: 22px; text-align: center; color: #888; font-size: 13px; }}
      </style>
    </head>
    <body>
      <div class="card">
        <div class="header">
          <h1>Booking Confirmed</h1>
          <p>Thank you for trusting Shaadi Ghar.</p>
        </div>
        <div class="field">
          <div class="label">Hall</div>
          <div class="value">{hall.name}</div>
        </div>
        <div class="field">
          <div class="label">Date</div>
          <div class="value">{booking.booking_date.strftime('%B %d, %Y')}</div>
        </div>
        <div class="field">
          <div class="label">Event type</div>
          <div class="value">{booking.event_type}</div>
        </div>
        <div class="field">
          <div class="label">Guests</div>
          <div class="value">{booking.guest_count}</div>
        </div>
        <div class="field">
          <div class="label">Status</div>
          <div class="value">{booking.status.capitalize()}</div>
        </div>
        {f'<div class="field"><div class="label">Special request</div><div class="value">{booking.special_request}</div></div>' if booking.special_request else ''}
        {f'<div class="field"><div class="label">Additional notes</div><div class="value">{booking.additional_notes}</div></div>' if booking.additional_notes else ''}
        <div class="footer">
          <p>If you have questions, reply to this email or contact us at {hall.contact_person} ({hall.phone_number}).</p>
        </div>
      </div>
    </body>
    </html>
    """
    send_email(customer_email, subject, html_content)


def send_booking_status_update_email(
    customer_email: str, booking: Booking, new_status: str
) -> None:
    status_label = new_status.capitalize()
    subject = f"Booking Update | {booking.hall.name if booking.hall else 'Your booking'}"
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset=\"UTF-8\" />
      <title>Booking Status Update</title>
      <style>
        body {{ font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 16px; }}
        .card {{ max-width: 600px; margin: 0 auto; background: #fff; padding: 24px; border-radius: 12px; box-shadow: 0 10px 20px rgba(0,0,0,0.08); }}
        .header {{ text-align: center; margin-bottom: 18px; }}
        .header h1 {{ margin: 0; color: #B6465F; }}
        .badge {{ display: inline-block; padding: 8px 14px; border-radius: 999px; background: #f0f0f0; font-weight: bold; margin-top: 10px; }}
        .footer {{ margin-top: 22px; text-align: center; color: #888; font-size: 13px; }}
      </style>
    </head>
    <body>
      <div class=\"card\">
        <div class=\"header\">
          <h1>Booking Status Updated</h1>
          <div class=\"badge\">{status_label}</div>
        </div>
        <p>Your booking for <strong>{booking.hall.name if booking.hall else ''}</strong> has been updated to <strong>{status_label}</strong>.</p>
        <p>
          If you have questions, please reply to this email or contact the hall management.
        </p>
        <div class=\"footer\">
          <p>Shaadi Ghar Team</p>
        </div>
      </div>
    </body>
    </html>
    """
    send_email(customer_email, subject, html_content)


def send_booking_message_email(
    customer_email: str, booking: Booking, message: str
) -> None:
    subject = f"Message about your booking at {booking.hall.name if booking.hall else 'Shaadi Ghar'}"
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset=\"UTF-8\" />
      <title>Message about your booking</title>
      <style>
        body {{ font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 16px; }}
        .card {{ max-width: 600px; margin: 0 auto; background: #fff; padding: 24px; border-radius: 12px; box-shadow: 0 10px 20px rgba(0,0,0,0.08); }}
        .header {{ text-align: center; margin-bottom: 18px; }}
        .header h1 {{ margin: 0; color: #B6465F; }}
        .footer {{ margin-top: 22px; text-align: center; color: #888; font-size: 13px; }}
      </style>
    </head>
    <body>
      <div class=\"card\">
        <div class=\"header\">
          <h1>Message about your booking</h1>
        </div>
        <p>{message}</p>
        <div class=\"footer\">
          <p>Shaadi Ghar Team</p>
        </div>
      </div>
    </body>
    </html>
    """
    send_email(customer_email, subject, html_content)


@app.route("/")
def home():
    return jsonify(
        {
            "message": "Shaadi Ghar API is running.",
        }
    )


@app.route("/health")
def health():
    return jsonify({"status": "ok", "date": datetime.now(UTC).isoformat()})


@app.route("/register", methods=["POST"])
def register():
    data = request.get_json(silent=True) or {}
    validation_error = validate_registration_payload(data)
    if validation_error:
        return jsonify({"error": validation_error}), 400

    email = str(data["email"]).strip().lower()
    if Customer.query.filter_by(email=email).first():
        return jsonify({"error": "User already registered."}), 409

    customer = Customer(
        name=str(data["name"]).strip(),
        email=email,
        phone=str(data["phone"]).strip(),
        password_hash=generate_password_hash(str(data["password"])),
        favorite_category=str(data.get("favorite_category", "Any")).strip() or "Any",
        profile_image=str(data.get("profile_image", "")).strip(),
    )
    db.session.add(customer)
    db.session.commit()
    log_action(email, "customer", "Registered new account")
    return jsonify({"message": "Registration successful. Please log in."}), 201


@app.route("/login", methods=["POST"])
def login():
    data = request.get_json(silent=True) or {}
    email = str(data.get("email", "")).strip().lower()
    password = str(data.get("password", ""))

    if not email or not password:
        return jsonify({"error": "Email and password are required."}), 400

    if email == ADMIN_EMAIL and password == ADMIN_PASSWORD:
        log_action(email, "admin", "Logged in")
        return jsonify(
            {
                "message": "Admin login successful.",
                "role": "admin",
                "user": {"email": ADMIN_EMAIL, "name": "Administrator"},
            }
        )

    customer = Customer.query.filter_by(email=email).first()
    if not customer or not check_password_hash(customer.password_hash, password):
        return jsonify({"error": "Invalid email or password."}), 401

    log_action(email, "customer", "Logged in")
    return jsonify(
        {
            "message": "Login successful.",
            "role": "customer",
            "user": customer_to_dict(customer),
        }
    )


@app.route("/halls", methods=["GET"])
def get_halls():
    query = MarriageHall.query

    search_term = str(request.args.get("q", "")).strip()
    city = str(request.args.get("city", "")).strip()
    nearest_to = str(request.args.get("nearest_to", "")).strip()
    category = str(request.args.get("category", "")).strip()
    sort_by = str(request.args.get("sort_by", "featured")).strip().lower()
    featured = request.args.get("featured")
    min_capacity = request.args.get("min_capacity", type=int)
    max_rent = request.args.get("max_rent", type=float)

    if search_term:
        like_term = f"%{search_term}%"
        query = query.filter(
            or_(
                MarriageHall.name.ilike(like_term),
                MarriageHall.location.ilike(like_term),
            )
        )
    if city:
        query = query.filter(MarriageHall.location.ilike(f"%{city}%"))
    if category:
        query = query.filter(MarriageHall.category.ilike(f"%{category}%"))
    if featured == "true":
        query = query.filter_by(is_featured=True)
    if min_capacity:
        query = query.filter(MarriageHall.capacity >= min_capacity)
    if max_rent:
        query = query.filter(MarriageHall.rent <= max_rent)

    halls = query.order_by(MarriageHall.is_featured.desc(), MarriageHall.rent.asc()).all()
    hall_items = [hall_to_dict(hall) for hall in halls]

    origin = resolve_city_coordinates(nearest_to)
    if nearest_to and sort_by == "featured" and origin is not None:
        sort_by = "nearest"

    enriched_items = []
    for hall_item in hall_items:
        hall_coordinates = resolve_city_coordinates(hall_item.get("location", ""))
        distance = (
            round(distance_km(origin, hall_coordinates), 1)
            if origin is not None and hall_coordinates is not None
            else None
        )
        hall_item["distance_km"] = distance
        enriched_items.append(hall_item)

    if sort_by == "price_low":
        enriched_items.sort(key=lambda item: (item["rent"], item["name"].lower()))
    elif sort_by == "price_high":
        enriched_items.sort(key=lambda item: (-item["rent"], item["name"].lower()))
    elif sort_by == "rating":
        enriched_items.sort(
            key=lambda item: (
                -(item["average_rating"] or 0),
                -(item["feedback_count"] or 0),
                item["rent"],
            )
        )
    elif sort_by == "capacity":
        enriched_items.sort(
            key=lambda item: (-(item["capacity"] or 0), item["rent"])
        )
    elif sort_by == "name":
        enriched_items.sort(key=lambda item: item["name"].lower())
    elif sort_by == "nearest" and origin is not None:
        enriched_items.sort(
            key=lambda item: (
                item["distance_km"] is None,
                item["distance_km"] if item["distance_km"] is not None else 10**9,
                item["rent"],
            )
        )
    else:
        enriched_items.sort(
            key=lambda item: (
                not bool(item["is_featured"]),
                item["rent"],
                item["name"].lower(),
            )
        )

    return jsonify(enriched_items)


@app.route("/hall/<int:hall_id>/availability", methods=["GET"])
def get_hall_availability(hall_id: int):
    hall = db.session.get(MarriageHall, hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404

    today = date.today()
    booked_dates = {
        booking.booking_date
        for booking in Booking.query.filter(
            Booking.hall_id == hall_id,
            Booking.status.in_(["pending", "approved"]),
        ).all()
    }
    available_dates = []
    for offset in range(0, 120):
        current = today + timedelta(days=offset)
        if current not in booked_dates:
            available_dates.append(current.isoformat())
    return jsonify({"hall": hall_to_dict(hall), "available_dates": available_dates})


@app.route("/hall/<int:hall_id>/feedback", methods=["GET"])
def get_hall_feedback(hall_id: int):
    hall = db.session.get(MarriageHall, hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404
    return jsonify(hall_feedback_summary(hall_id))


@app.route("/hall/<int:hall_id>/feedback", methods=["POST"])
def submit_hall_feedback(hall_id: int):
    hall = db.session.get(MarriageHall, hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404

    data = request.get_json(silent=True) or {}
    customer_id, customer_id_error = parse_positive_int(
        data.get("customer_id"), "Customer ID"
    )
    if customer_id_error:
        return jsonify({"error": customer_id_error}), 400

    customer = db.session.get(Customer, customer_id)
    if not customer:
        return jsonify({"error": "Customer not found."}), 404

    existing_booking = Booking.query.filter_by(
        hall_id=hall_id,
        customer_id=customer_id,
    ).first()
    if existing_booking is None:
        return jsonify(
            {"error": "You can leave feedback after making a booking for this hall."}
        ), 403

    rating, rating_error = parse_positive_int(data.get("rating"), "Rating")
    if rating_error:
        return jsonify({"error": rating_error}), 400
    if rating is None or rating > 5:
        return jsonify({"error": "Rating must be between 1 and 5."}), 400

    comment = str(data.get("comment", "")).strip()
    if not comment:
        return jsonify({"error": "Feedback comment is required."}), 400

    existing_feedback = HallFeedback.query.filter_by(
        hall_id=hall_id,
        customer_id=customer_id,
    ).first()
    if existing_feedback is not None:
        existing_feedback.rating = rating
        existing_feedback.comment = comment
        existing_feedback.customer_name = customer.name
        existing_feedback.created_at = utc_now()
        db.session.commit()
        log_action(customer.email, "customer", f"Updated feedback for hall #{hall_id}")
        return jsonify(
            {
                "message": "Feedback updated successfully.",
                "feedback": feedback_to_dict(existing_feedback),
                "summary": hall_feedback_summary(hall_id),
            }
        )

    feedback = HallFeedback(
        hall_id=hall_id,
        customer_id=customer.id,
        customer_name=customer.name,
        rating=rating,
        comment=comment,
    )
    db.session.add(feedback)
    db.session.commit()
    log_action(customer.email, "customer", f"Submitted feedback for hall #{hall_id}")
    return jsonify(
        {
            "message": "Feedback submitted successfully.",
            "feedback": feedback_to_dict(feedback),
            "summary": hall_feedback_summary(hall_id),
        }
    ), 201


@app.route("/book", methods=["POST"])
def book_hall():
    data = request.get_json(silent=True) or {}
    hall_id, hall_id_error = parse_positive_int(data.get("hall_id"), "Hall ID")
    customer_id, customer_id_error = parse_positive_int(
        data.get("customer_id"), "Customer ID"
    )
    booking_date_raw = str(data.get("booking_date", "")).strip()

    if hall_id_error:
        return jsonify({"error": hall_id_error}), 400
    if customer_id_error:
        return jsonify({"error": customer_id_error}), 400
    if not booking_date_raw:
        return jsonify({"error": "Hall, customer, and booking date are required."}), 400

    guest_count, guest_count_error = parse_positive_int(
        data.get("guest_count", 100), "Guest count"
    )
    if guest_count_error:
        return jsonify({"error": guest_count_error}), 400

    hall = db.session.get(MarriageHall, hall_id)
    customer = db.session.get(Customer, customer_id)
    if not hall:
        return jsonify({"error": "Selected hall does not exist."}), 404
    if not customer:
        return jsonify({"error": "Customer account not found."}), 404

    try:
        booking_date_value = datetime.strptime(booking_date_raw, "%Y-%m-%d").date()
    except ValueError:
        return jsonify({"error": "Booking date must use YYYY-MM-DD format."}), 400

    if booking_date_value < date.today():
        return jsonify({"error": "Booking date cannot be in the past."}), 400

    existing_booking = Booking.query.filter(
        Booking.hall_id == hall_id,
        Booking.booking_date == booking_date_value,
        Booking.status.in_(["pending", "approved"]),
    ).first()
    if existing_booking:
        return jsonify({"error": "This hall is already booked for that date."}), 409

    menu_items_data = data.get("menu_items", [])
    total_extra_cost = Decimal("0.00")
    if menu_items_data:
        for item in menu_items_data:
            menu_id = item.get("menu_id")
            quantity = item.get("quantity", 0)
            if menu_id and quantity > 0:
                menu = FoodMenu.query.get(menu_id)
                if menu:
                    total_extra_cost += menu.price_per_plate * quantity

    booking = Booking(
        hall_id=hall_id,
        customer_id=customer.id,
        customer_name=customer.name,
        customer_contact_number=customer.phone,
        booking_date=booking_date_value,
        event_type=str(data.get("event_type", "Wedding")).strip() or "Wedding",
        guest_count=guest_count,
        special_request=str(data.get("special_request", "")).strip(),
        additional_notes=str(data.get("additional_notes", "")).strip(),
        menu_items=json.dumps(menu_items_data),
        total_extra_cost=total_extra_cost,
        status="pending",
    )
    db.session.add(booking)
    db.session.commit()
    log_action(customer.email, "customer", f"Created booking #{booking.hall_booking_id}")

    # Send confirmation email (best-effort)
    try:
        send_booking_confirmation_email(customer.email, booking, hall)
    except Exception:
        pass

    return jsonify({"message": "Booking request submitted.", "booking": booking_to_dict(booking)}), 201


@app.route("/customer/bookings/<int:customer_id>", methods=["GET"])
def customer_bookings(customer_id: int):
    customer = db.session.get(Customer, customer_id)
    if not customer:
        return jsonify({"error": "Customer not found."}), 404
    bookings = (
        Booking.query.filter_by(customer_id=customer_id)
        .order_by(Booking.booking_date.asc())
        .all()
    )
    return jsonify([booking_to_dict(booking) for booking in bookings])


@app.route("/customer/cancel_booking/<int:booking_id>", methods=["PUT"])
def cancel_customer_booking(booking_id: int):
    data = request.get_json(silent=True) or {}
    customer_id = data.get("customer_id")

    if not customer_id:
        return jsonify({"error": "Customer ID is required."}), 400

    booking = Booking.query.filter_by(
        hall_booking_id=booking_id, customer_id=customer_id
    ).first()
    if not booking:
        return jsonify({"error": "Booking not found."}), 404
    if booking.status != "pending":
        return jsonify({"error": "Only pending bookings can be cancelled."}), 400

    booking.status = "cancelled"
    db.session.commit()
    if booking.customer:
        log_action(
            booking.customer.email,
            "customer",
            f"Cancelled booking #{booking.hall_booking_id}",
        )
    return jsonify(
        {"message": "Booking cancelled successfully.", "booking": booking_to_dict(booking)}
    )


@app.route("/customer/profile/<int:customer_id>", methods=["GET", "PUT"])
def customer_profile(customer_id: int):
    customer = db.session.get(Customer, customer_id)
    if not customer:
        return jsonify({"error": "Customer not found."}), 404

    if request.method == "GET":
        return jsonify(customer_to_dict(customer))

    data = request.get_json(silent=True) or {}
    customer.name = str(data.get("name", customer.name)).strip() or customer.name
    customer.phone = str(data.get("phone", customer.phone)).strip() or customer.phone
    customer.favorite_category = (
        str(data.get("favorite_category", customer.favorite_category)).strip()
        or customer.favorite_category
    )
    customer.profile_image = str(data.get("profile_image", customer.profile_image)).strip()
    db.session.commit()
    log_action(customer.email, "customer", "Updated profile")
    return jsonify({"message": "Profile updated.", "user": customer_to_dict(customer)})


@app.route("/admin/stats", methods=["GET"])
def admin_stats():
    total_halls = MarriageHall.query.count()
    total_customers = Customer.query.count()
    total_bookings = Booking.query.count()
    pending_bookings = Booking.query.filter_by(status="pending").count()
    approved_bookings = Booking.query.filter_by(status="approved").count()
    return jsonify(
        {
            "total_halls": total_halls,
            "total_customers": total_customers,
            "total_bookings": total_bookings,
            "pending_bookings": pending_bookings,
            "approved_bookings": approved_bookings,
        }
    )


@app.route("/admin/bookings", methods=["GET"])
def admin_bookings():
    bookings = Booking.query.order_by(Booking.created_at.desc()).all()
    return jsonify([booking_to_dict(booking) for booking in bookings])


@app.route("/admin/update_booking/<int:booking_id>", methods=["PUT"])
def update_booking(booking_id: int):
    booking = db.session.get(Booking, booking_id)
    if not booking:
        return jsonify({"error": "Booking not found."}), 404

    status = str((request.get_json(silent=True) or {}).get("status", "")).strip().lower()
    if status not in {"pending", "approved", "rejected", "cancelled"}:
        return jsonify({"error": "Status must be pending, approved, rejected, or cancelled."}), 400

    booking.status = status
    db.session.commit()
    log_action(ADMIN_EMAIL, "admin", f"Updated booking #{booking_id} to {status}")

    try:
        if booking.customer:
            send_booking_status_update_email(booking.customer.email, booking, status)
    except Exception:
        pass

    return jsonify({"message": "Booking status updated.", "booking": booking_to_dict(booking)})


@app.route("/admin/send_booking_message/<int:booking_id>", methods=["POST"])
def send_booking_message(booking_id: int):
    booking = db.session.get(Booking, booking_id)
    if not booking:
        return jsonify({"error": "Booking not found."}), 404

    data = request.get_json(silent=True) or {}
    message = str(data.get("message", "")).strip()
    if not message:
        return jsonify({"error": "Message is required."}), 400

    booking_message = create_booking_message(booking, "admin", "Admin", message)

    try:
        if booking.customer:
            send_booking_message_email(booking.customer.email, booking, message)
            log_action(ADMIN_EMAIL, "admin", f"Sent message for booking #{booking_id}")
            return jsonify(
                {
                    "message": "Message sent.",
                    "booking_message": booking_message_to_dict(booking_message),
                }
            )
        return jsonify({"error": "Booking has no associated customer."}), 400
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/customer/send_booking_message/<int:booking_id>", methods=["POST"])
def customer_send_booking_message(booking_id: int):
    booking = db.session.get(Booking, booking_id)
    if not booking:
        return jsonify({"error": "Booking not found."}), 404

    data = request.get_json(silent=True) or {}
    customer_id, customer_id_error = parse_positive_int(
        data.get("customer_id"), "Customer ID"
    )
    if customer_id_error:
        return jsonify({"error": customer_id_error}), 400
    if booking.customer_id != customer_id:
        return jsonify({"error": "This booking does not belong to that customer."}), 403

    message = str(data.get("message", "")).strip()
    if not message:
        return jsonify({"error": "Message is required."}), 400

    booking_message = create_booking_message(
        booking,
        "customer",
        booking.customer_name or "Customer",
        message,
    )
    if booking.customer:
        log_action(
            booking.customer.email,
            "customer",
            f"Sent message for booking #{booking_id}",
        )
    return jsonify(
        {
            "message": "Message sent.",
            "booking_message": booking_message_to_dict(booking_message),
        }
    )


@app.route("/admin/halls", methods=["POST"])
def add_hall():
    data = request.get_json(silent=True) or {}
    required_fields = [
        "name",
        "location",
        "capacity",
        "rent",
        "contact_person",
        "phone_number",
        "email",
    ]
    for field in required_fields:
        if not str(data.get(field, "")).strip():
            return jsonify({"error": f"{field.replace('_', ' ').title()} is required."}), 400

    capacity, capacity_error = parse_positive_int(data.get("capacity"), "Capacity")
    if capacity_error:
        return jsonify({"error": capacity_error}), 400

    rent, rent_error = parse_non_negative_decimal(data.get("rent"), "Rent")
    if rent_error:
        return jsonify({"error": rent_error}), 400

    hall = MarriageHall(
        name=str(data["name"]).strip(),
        location=str(data["location"]).strip(),
        capacity=capacity,
        rent=rent,
        contact_person=str(data["contact_person"]).strip(),
        phone_number=str(data["phone_number"]).strip(),
        email=str(data["email"]).strip(),
        description=str(data.get("description", "")).strip(),
        image_urls=json.dumps(parse_image_urls(data.get("image_urls", []))),
        category=str(data.get("category", "Indoor")).strip() or "Indoor",
        is_featured=bool(data.get("is_featured", False)),
    )
    db.session.add(hall)
    db.session.commit()
    log_action(ADMIN_EMAIL, "admin", f"Added hall {hall.name}")
    return jsonify({"message": "Hall added successfully.", "hall": hall_to_dict(hall)}), 201


@app.route("/admin/update_hall/<int:hall_id>", methods=["PUT"])
def update_hall(hall_id: int):
    hall = db.session.get(MarriageHall, hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404

    data = request.get_json(silent=True) or {}
    capacity, capacity_error = parse_positive_int(
        data.get("capacity", hall.capacity), "Capacity"
    )
    if capacity_error:
        return jsonify({"error": capacity_error}), 400

    rent, rent_error = parse_non_negative_decimal(data.get("rent", hall.rent), "Rent")
    if rent_error:
        return jsonify({"error": rent_error}), 400

    hall.name = str(data.get("name", hall.name)).strip() or hall.name
    hall.location = str(data.get("location", hall.location)).strip() or hall.location
    hall.capacity = capacity
    hall.rent = rent
    hall.contact_person = (
        str(data.get("contact_person", hall.contact_person)).strip() or hall.contact_person
    )
    hall.phone_number = (
        str(data.get("phone_number", hall.phone_number)).strip() or hall.phone_number
    )
    hall.email = str(data.get("email", hall.email)).strip() or hall.email
    hall.description = str(data.get("description", hall.description)).strip()
    hall.image_urls = json.dumps(parse_image_urls(data.get("image_urls", hall.image_urls)))
    hall.category = str(data.get("category", hall.category)).strip() or hall.category
    hall.is_featured = bool(data.get("is_featured", hall.is_featured))
    db.session.commit()
    log_action(ADMIN_EMAIL, "admin", f"Updated hall #{hall_id}")
    return jsonify({"message": "Hall updated successfully.", "hall": hall_to_dict(hall)})


@app.route("/admin/delete_hall/<int:hall_id>", methods=["DELETE"])
def delete_hall(hall_id: int):
    hall = db.session.get(MarriageHall, hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404
    db.session.delete(hall)
    db.session.commit()
    log_action(ADMIN_EMAIL, "admin", f"Deleted hall #{hall_id}")
    return jsonify({"message": "Hall deleted successfully."})


@app.route("/admin/customers", methods=["GET"])
def get_customers():
    customers = Customer.query.order_by(Customer.created_at.desc()).all()
    return jsonify([customer_to_dict(customer) for customer in customers])


@app.route("/hall/<int:hall_id>/menus", methods=["GET"])
def get_hall_menus(hall_id: int):
    hall = db.session.get(MarriageHall, hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404
    menus = FoodMenu.query.filter_by(hall_id=hall_id, is_available=True).order_by(FoodMenu.category, FoodMenu.item_name).all()
    return jsonify([menu_to_dict(menu) for menu in menus])


@app.route("/admin/halls/<int:hall_id>/menus", methods=["POST"])
def add_menu_item(hall_id: int):
    hall = db.session.get(MarriageHall, hall_id)
    if not hall:
        return jsonify({"error": "Hall not found."}), 404
    
    data = request.get_json() or {}
    menu = FoodMenu(
        hall_id=hall_id,
        category=str(data.get("category", "Main Course")),
        item_name=str(data["item_name"]),
        price_per_plate=Decimal(str(data["price_per_plate"])),
        description=str(data.get("description", "")),
        is_vegetarian=bool(data.get("is_vegetarian", False)),
        is_available=bool(data.get("is_available", True)),
    )
    db.session.add(menu)
    db.session.commit()
    log_action(ADMIN_EMAIL, "admin", f"Added menu item {menu.item_name} for hall #{hall_id}")
    return jsonify({"message": "Menu item added.", "menu": menu_to_dict(menu)}), 201


@app.route("/admin/halls/<int:hall_id>/menus/<int:menu_id>", methods=["PUT"])
def update_menu_item(hall_id: int, menu_id: int):
    menu = db.session.get(FoodMenu, menu_id)
    if not menu or menu.hall_id != hall_id:
        return jsonify({"error": "Menu item not found."}), 404
    
    data = request.get_json() or {}
    menu.category = str(data.get("category", menu.category))
    menu.item_name = str(data.get("item_name", menu.item_name))
    menu.price_per_plate = Decimal(str(data.get("price_per_plate", menu.price_per_plate)))
    menu.description = str(data.get("description", menu.description))
    menu.is_vegetarian = bool(data.get("is_vegetarian", menu.is_vegetarian))
    menu.is_available = bool(data.get("is_available", menu.is_available))
    db.session.commit()
    log_action(ADMIN_EMAIL, "admin", f"Updated menu item #{menu_id}")
    return jsonify({"message": "Menu item updated.", "menu": menu_to_dict(menu)})


@app.route("/admin/halls/<int:hall_id>/menus/<int:menu_id>", methods=["DELETE"])
def delete_menu_item(hall_id: int, menu_id: int):
    menu = db.session.get(FoodMenu, menu_id)
    if not menu or menu.hall_id != hall_id:
        return jsonify({"error": "Menu item not found."}), 404
    item_name = menu.item_name
    db.session.delete(menu)
    db.session.commit()
    log_action(ADMIN_EMAIL, "admin", f"Deleted menu item {item_name}")
    return jsonify({"message": "Menu item deleted."})


@app.route("/booking/<int:booking_id>/request_cancel", methods=["POST"])
def request_cancel(booking_id: int):
    booking = db.session.get(Booking, booking_id)
    if not booking:
        return jsonify({"error": "Booking not found."}), 404
    
    data = request.get_json() or {}
    customer_id = data.get("customer_id")
    reason = str(data.get("reason", ""))
    
    if booking.customer_id != customer_id:
        return jsonify({"error": "Unauthorized."}), 403
    
    if booking.status not in ["pending", "approved"]:
        return jsonify({"error": "Cannot cancel this booking status."}), 400
    
    # Policy: >1 week before date
    days_to_event = (booking.booking_date - date.today()).days
    if days_to_event <= 7:
        return jsonify({"error": "Cancellation allowed only more than 1 week before event."}), 400
    
    booking.status = "cancel_requested"
    create_booking_message(booking, "customer", booking.customer_name, f"Cancel request: {reason}")
    db.session.commit()
    return jsonify({"message": "Cancel request submitted for admin review.", "booking": booking_to_dict(booking)})


@app.route("/booking/<int:booking_id>/update_date", methods=["PUT"])
def update_booking_date(booking_id: int):
    booking = db.session.get(Booking, booking_id)
    if not booking:
        return jsonify({"error": "Booking not found."}), 404
    
    data = request.get_json() or {}
    customer_id = data.get("customer_id")
    new_date_str = str(data["new_date"])
    
    if booking.customer_id != customer_id:
        return jsonify({"error": "Unauthorized."}), 403
    
    try:
        new_date = datetime.strptime(new_date_str, "%Y-%m-%d").date()
    except ValueError:
        return jsonify({"error": "Invalid date format."}), 400
    
    # Check availability
    conflict = Booking.query.filter(
        Booking.hall_id == booking.hall_id,
        Booking.booking_date == new_date,
        Booking.status.in_(["pending", "approved"]),
        Booking.hall_booking_id != booking_id
    ).first()
    if conflict:
        return jsonify({"error": "Date not available."}), 409
    
    old_date = booking.booking_date
    booking.booking_date = new_date
    create_booking_message(booking, "customer", booking.customer_name, f"Date change request: {old_date.isoformat()} to {new_date.isoformat()}")
    db.session.commit()
    return jsonify({"message": "Date update requested (admin approval needed).", "booking": booking_to_dict(booking)})


@app.route("/booking/<int:booking_id>/update_guests", methods=["PUT"])
def update_booking_guests(booking_id: int):
    booking = db.session.get(Booking, booking_id)
    if not booking:
        return jsonify({"error": "Booking not found."}), 404
    
    data = request.get_json() or {}
    customer_id = data.get("customer_id")
    new_guests = int(data["new_guest_count"])
    
    if booking.customer_id != customer_id:
        return jsonify({"error": "Unauthorized."}), 403
    
    if new_guests < 1 or new_guests > booking.hall.capacity * 2:  # Reasonable limit
        return jsonify({"error": "Invalid guest count."}), 400
    
    booking.guest_count = new_guests
    base_rent = float(booking.hall.rent)
    booking.adjusted_cost = Decimal(str(calculate_adjusted_cost(base_rent, new_guests)))  # Wait, add adjusted_cost field if needed
    create_booking_message(booking, "customer", booking.customer_name, f"Guest count changed to {new_guests}")
    db.session.commit()
    return jsonify({"message": "Guest count updated (admin approval needed).", "booking": booking_to_dict(booking)})


@app.route("/admin/logs", methods=["GET"])
def get_logs():
    logs = UserLog.query.order_by(UserLog.timestamp.desc()).limit(200).all()
    return jsonify(
        [
            {
                "email": log.email,
                "role": log.role,
                "action": log.action,
                "timestamp": log.timestamp.isoformat(),
            }
            for log in logs
        ]
    )


with app.app_context():
    db.create_all()
    ensure_schema()
    seed_default_data()
    sync_default_halls()


if __name__ == "__main__":
    app.run(debug=False, host="0.0.0.0", port=5000)
