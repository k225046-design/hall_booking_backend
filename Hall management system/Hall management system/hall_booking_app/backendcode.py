from flask import Flask, request, jsonify, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from werkzeug.utils import secure_filename
from datetime import datetime, date, timedelta
import os
import socket
from sqlalchemy import text
import json

# ------------------- Flask App Setup -------------------
app = Flask(__name__)

# ------------------- CORS -------------------
CORS(app, resources={r"/*": {"origins": "*"}}, supports_credentials=True)

# ------------------- Database Config -------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SQLSERVER_URI = (
    'mssql+pyodbc://HO-MIS-TEMP\\ALMIRAH@localhost/MHDB?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes'
)
SQLITE_URI = f"sqlite:///{os.path.join(BASE_DIR, 'hall_booking_dev.db').replace(os.sep, '/')}"


def _is_port_open(host, port, timeout=1.0):
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


USE_SQLITE_FALLBACK = not _is_port_open('127.0.0.1', 1433)
app.config['SQLALCHEMY_DATABASE_URI'] = SQLITE_URI if USE_SQLITE_FALLBACK else SQLSERVER_URI
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# ------------------- Upload Folder -------------------
app.config['UPLOAD_FOLDER'] = 'Uploads'

# Initialize SQLAlchemy
db = SQLAlchemy()
db.init_app(app)

# === Models ===
class Customer(db.Model):
    __tablename__ = 'customers'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    phone = db.Column(db.String(15))
    password = db.Column(db.String(255), nullable=False)
    role = db.Column(db.String(20), default='customer')  # 'customer', 'admin', or 'client'
    profile_image = db.Column(db.String(255))
    RegistrationStatus = db.Column(db.Boolean, default=False)  # Whether client has completed registration and is approved
    UpdatedAt = db.Column(db.DateTime, default=datetime.utcnow)

class MarriageHall(db.Model):
    __tablename__ = 'marriage_halls'

    hall_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    hall_name = db.Column(db.String(255), nullable=False)
    location = db.Column(db.String(255), nullable=False)
    capacity = db.Column(db.Integer, nullable=False)
    rent = db.Column(db.Integer, nullable=False)
    contact_person = db.Column(db.String(100), nullable=True)
    phone_number = db.Column(db.String(15), nullable=True)
    client_email = db.Column(db.String(100), db.ForeignKey('customers.email'), nullable=False)

    # ✅ NEW COLUMN: To track admin approval status
    is_approved = db.Column(db.Boolean, default=False)

    # Reverse relationship (optional)
    client = db.relationship('Customer', backref=db.backref('marriage_halls', lazy=True))

    def to_dict(self):
        return {
            'hall_id': self.hall_id,
            'hall_name': self.hall_name,
            'location': self.location,
            'capacity': self.capacity,
            'rent': self.rent,
            'contact_person': self.contact_person,
            'phone_number': self.phone_number,
            'client_email': self.client_email,
            'is_approved': self.is_approved
        }

    def __repr__(self):
        return f"<MarriageHall {self.hall_name} - {self.client_email}>"



class Booking(db.Model):
    __tablename__ = 'bookings'
    hall_booking_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    hall_id = db.Column(db.Integer, db.ForeignKey('marriage_halls.hall_id'), nullable=False)
    customer_name = db.Column(db.String(255), nullable=False)
    customer_contact_number = db.Column(db.String(20))
    booking_date = db.Column(db.Date, nullable=False)
    customer_email = db.Column(db.String(255), nullable=False)
    status = db.Column(db.String(30), default='pending')  # pending, confirmed, cancelled
    payment_status = db.Column(db.String(30), default='pending')  # pending, paid, failed
    txn_ref = db.Column(db.String(100))  # Payment transaction reference

class UserLog(db.Model):
    __tablename__ = 'user_logs'
    log_id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_email = db.Column(db.String(255))
    role = db.Column(db.String(20))  # admin, client, customer
    action = db.Column(db.String(255))  # login, submit request, etc.
    details = db.Column(db.Text)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

class RegistrationRequest(db.Model):
    __tablename__ = 'RegistrationRequests'
    RequestID = db.Column(db.Integer, primary_key=True, autoincrement=True)
    ClientEmail = db.Column(db.String(100), db.ForeignKey('customers.email'), nullable=False)
    HallName = db.Column(db.String(255), nullable=False)
    HallCapacity = db.Column(db.Integer, nullable=False)
    HallRate = db.Column(db.Numeric(10, 2), nullable=False)
    Location = db.Column(db.String(255), nullable=False)
    ContactPerson = db.Column(db.String(100))
    PhoneNumber = db.Column(db.String(15))
    OtherInfo = db.Column(db.String(500))
    RequestStatus = db.Column(db.String(20), default='Pending')  # Pending, Approved, Rejected
    SubmittedAt = db.Column(db.DateTime, default=datetime.utcnow)
    ReviewedAt = db.Column(db.DateTime)
    AdminComments = db.Column(db.String(500))


def ensure_dev_data():
    if not USE_SQLITE_FALLBACK:
        return

    db.create_all()
    db.session.execute(text("""
        CREATE TABLE IF NOT EXISTS hall_availability (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hall_id INTEGER NOT NULL,
            available_date DATE NOT NULL,
            is_booked INTEGER NOT NULL DEFAULT 0
        )
    """))

    admin = Customer.query.filter_by(email='admin@admin.com').first()
    if not admin:
        admin = Customer(
            name='Admin User',
            email='admin@admin.com',
            phone='03000000000',
            password='admin123',
            role='admin',
            RegistrationStatus=True,
        )
        db.session.add(admin)

    customer = Customer.query.filter_by(email='customer@example.com').first()
    if not customer:
        customer = Customer(
            name='Demo Customer',
            email='customer@example.com',
            phone='03001111111',
            password='customer123',
            role='customer',
            RegistrationStatus=True,
        )
        db.session.add(customer)

    owner = Customer.query.filter_by(email='owner@example.com').first()
    if not owner:
        owner = Customer(
            name='Hall Owner',
            email='owner@example.com',
            phone='03002222222',
            password='owner123',
            role='client',
            RegistrationStatus=True,
        )
        db.session.add(owner)

    db.session.commit()

    if MarriageHall.query.count() == 0:
        sample_halls = [
            MarriageHall(
                hall_name='Royal Orchid Hall',
                location='Karachi',
                capacity=500,
                rent=250000,
                contact_person='Hall Owner',
                phone_number='03002222222',
                client_email='owner@example.com',
                is_approved=True,
            ),
            MarriageHall(
                hall_name='Dream Garden',
                location='Lahore',
                capacity=350,
                rent=180000,
                contact_person='Hall Owner',
                phone_number='03002222222',
                client_email='owner@example.com',
                is_approved=True,
            ),
        ]
        db.session.add_all(sample_halls)
        db.session.commit()

        start_date = date.today() + timedelta(days=1)
        for hall in sample_halls:
            for offset in range(21):
                db.session.execute(
                    text("""
                        INSERT INTO hall_availability (hall_id, available_date, is_booked)
                        VALUES (:hall_id, :available_date, 0)
                    """),
                    {
                        'hall_id': hall.hall_id,
                        'available_date': start_date + timedelta(days=offset),
                    }
                )
        db.session.commit()

# === Helper Function ===
def log_action(email, role, action, details=None):
    try:
        log = UserLog(
            user_email=email,
            role=role,
            action=action,
            details=details
        )
        db.session.add(log)
        db.session.commit()
    except Exception as e:
        db.session.rollback()
        print(f"Logging failed: {e}")


def serialize_customer(user):
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "phone": user.phone or '',
        "role": user.role,
        "profile_image": user.profile_image or '',
        "favorite_category": getattr(user, 'favorite_category', None) or 'Any',
        "registration_status": bool(user.RegistrationStatus),
    }


with app.app_context():
    ensure_dev_data()

# === Routes ===
@app.route('/')
def home():
    return jsonify({
        "message": "Hall Booking API Running",
        "database": "sqlite" if USE_SQLITE_FALLBACK else "sqlserver"
    }), 200

@app.route('/debug_db', methods=['GET'])
def debug_db():
    try:
        result = db.session.execute(text("SELECT DB_NAME() as dbname"))
        dbname = result.fetchone()[0]

        tables_result = db.session.execute(text("""
            SELECT TABLE_NAME 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_TYPE = 'BASE TABLE'
        """))

        tables = [row[0] for row in tables_result]

        return jsonify({
            "connected_database": dbname,
            "tables": tables
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json(silent=True) or {}

    name = (data.get('name') or '').strip()
    email = (data.get('email') or '').strip().lower()
    phone = (data.get('phone') or '').strip()
    password = data.get('password') or ''
    role = (data.get('role') or 'customer').strip().lower()

    if not name or not email or not password or not phone:
        return jsonify({"error": "Missing required fields"}), 400

    existing_user = Customer.query.filter(
        db.func.lower(Customer.email) == email
    ).first()
    if existing_user:
        return jsonify({"error": "Email already registered"}), 409

    new_user = Customer(
        name=name,
        email=email,
        phone=phone,
        password=password,  # Store as plain text
        role=role,
        RegistrationStatus=False if role == 'client' else True  # Clients start with unapproved status
    )

    db.session.add(new_user)
    db.session.commit()

    log_action(email, role, 'Registered', 'New user registered')
    return jsonify({
        "message": "User registered successfully.",
        "role": new_user.role,
        "user": serialize_customer(new_user),
    }), 201

@app.route('/login', methods=['POST'])
def login():
    try:
        data = request.get_json(silent=True) or {}

        email = data.get('email', '').strip().lower()
        password = data.get('password', '').strip()

        user = Customer.query.filter(db.func.lower(Customer.email) == email).first()

        if user and user.password == password:
            pending_request = RegistrationRequest.query.filter_by(
                ClientEmail=email, RequestStatus='Pending'
            ).first() if user.role == 'client' else None

            rejected_request = RegistrationRequest.query.filter_by(
                ClientEmail=email, RequestStatus='Rejected'
            ).first() if user.role == 'client' else None

            response = {
                "message": "Login successful",
                "role": user.role,
                "user": serialize_customer(user),
            }

            if user.role == 'client':
                response.update({
                    "needs_hall_form": not user.RegistrationStatus and not pending_request and not rejected_request,
                    "has_pending_request": bool(pending_request),
                    "is_rejected": bool(rejected_request)
                })

            log_action(email, user.role, "Login", "User successfully logged in")
            return jsonify(response), 200

        return jsonify({"error": "Invalid credentials"}), 401

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/upload_profile_image', methods=['POST'])
def upload_profile_image():
    if 'image' not in request.files or 'email' not in request.form:
        return jsonify({"error": "Image or email missing"}), 400

    file = request.files['image']
    email = request.form['email'].strip().lower()

    if file.filename == '':
        return jsonify({"error": "No file selected"}), 400

    filename = secure_filename(file.filename)
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(filepath)

    user = Customer.query.filter_by(email=email).first()
    if user:
        user.profile_image = f"/Uploads/{filename}"
        db.session.commit()
        log_action(email, user.role, "Uploaded Profile Image", f"Image: {filename}")
        return jsonify({"status": "success", "profile_image": user.profile_image})

    return jsonify({"error": "User not found"}), 404

@app.route('/remove_profile_image', methods=['POST'])
def remove_profile_image():
    email = request.form.get('email')
    if not email:
        return jsonify({"error": "Email missing"}), 400

    user = Customer.query.filter_by(email=email).first()
    if not user:
        return jsonify({"error": "User not found"}), 404

    if user.profile_image:
        image_path = user.profile_image.replace("/Uploads/", "")
        full_path = os.path.join(app.config['UPLOAD_FOLDER'], image_path)

        if os.path.exists(full_path):
            os.remove(full_path)

        user.profile_image = None
        db.session.commit()
        log_action(email, user.role, "Removed Profile Image")

    return jsonify({"status": "success", "message": "Profile image removed"})

@app.route('/Uploads/<filename>')
def serve_uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

@app.route('/halls', methods=['GET'])
def get_halls():
    email = request.args.get('email', 'guest')
    log_action(email, 'customer', 'Viewed halls')

    try:
        # Fetch only admin-approved client halls
        approved_halls = MarriageHall.query.filter_by(is_approved=True).all()

        return jsonify([{
            "hall_id": h.hall_id,
            "name": h.hall_name,
            "location": h.location,
            "capacity": h.capacity,
            "rent": str(h.rent),
            "contact_person": h.contact_person,
            "phone_number": h.phone_number,
            "email": h.client_email,
            "image_url": h.image_url if hasattr(h, 'image_url') else ""  # if you use images later
        } for h in approved_halls])

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/hall/<int:hall_id>/availability', methods=['GET'])
def get_availability(hall_id):
    try:
        records = db.session.execute(
            text("SELECT available_date FROM hall_availability WHERE hall_id = :hall_id AND is_booked = 0"),
            {"hall_id": hall_id}
        ).fetchall()

        available_dates = [row.available_date.strftime('%Y-%m-%d') for row in records]
        log_action(request.args.get('email', 'guest'), 'customer', f"Viewed availability for hall {hall_id}")
        return jsonify({"available_dates": available_dates})

    except Exception as e:
        return jsonify({"error": f"Failed to fetch availability: {str(e)}"}), 500

@app.route('/hall/<int:hall_id>/calendar_availability', methods=['GET'])
def calendar_availability(hall_id):
    try:
        today = date.today()
        results = db.session.execute(
            text("SELECT available_date FROM hall_availability WHERE hall_id = :hall_id AND is_booked = 0 AND available_date >= :today ORDER BY available_date"),
            {"hall_id": hall_id, "today": today}
        ).fetchall()

        available_dates = [row[0].strftime('%Y-%m-%d') for row in results]
        log_action(request.args.get('email', 'guest'), 'customer', f"Viewed calendar availability for hall {hall_id}")
        return jsonify({
            "hall_id": hall_id,
            "available_calendar_dates": available_dates
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/all_halls/availability', methods=['GET'])
def get_all_hall_availability():
    try:
        records = db.session.execute(
            text("SELECT hall_id, available_date FROM hall_availability WHERE is_booked = 0")
        ).fetchall()

        result = {}
        for row in records:
            date_str = row.available_date.strftime('%Y-%m-%d')
            result.setdefault(row.hall_id, []).append(date_str)

        log_action(request.args.get('email', 'guest'), 'customer', "Viewed all halls availability")
        return jsonify(result)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/book', methods=['GET'])
def book():
    email = request.args.get('email')
    hall_id = request.args.get('hall_id')
    booking_date = request.args.get('booking_date')
    customer_name = request.args.get('customer_name')
    customer_contact_number = request.args.get('customer_contact_number')

    if not all([email, hall_id, booking_date, customer_name, customer_contact_number]):
        return jsonify({"error": "Missing fields"}), 400

    try:
        booking_date_obj = datetime.strptime(booking_date, '%Y-%m-%d').date()
        hall_id_int = int(hall_id)

        duplicate = db.session.execute(
            text("""
                SELECT 1 FROM bookings
                WHERE customer_email = :email AND hall_id = :hall_id AND booking_date = :booking_date
            """),
            {"email": email, "hall_id": hall_id_int, "booking_date": booking_date_obj}
        ).fetchone()

        if duplicate:
            return jsonify({"error": "Booking already requested for this date by this customer."}), 409

        record = db.session.execute(
            text("""
                SELECT * FROM hall_availability
                WHERE hall_id = :hall_id AND available_date = :booking_date AND is_booked = 0
            """),
            {"hall_id": hall_id_int, "booking_date": booking_date_obj}
        ).fetchone()

        if not record:
            return jsonify({"error": "Date not found for this hall or already booked"}), 409

        new_booking = Booking(
            customer_email=email,
            hall_id=hall_id_int,
            booking_date=booking_date_obj,
            status="pending",
            customer_name=customer_name,
            customer_contact_number=customer_contact_number
        )
        db.session.add(new_booking)
        db.session.commit()

        log_action(email, 'customer', "Booking Request", f"Hall ID: {hall_id}, Date: {booking_date}")
        return jsonify({"message": "Booking requested successfully."}), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"Server error: {str(e)}"}), 500

@app.route('/my_bookings', methods=['GET'])
def my_bookings():
    email = request.args.get('email')
    if not email:
        return jsonify({"error": "Email is required"}), 400

    try:
        bookings = db.session.query(Booking, MarriageHall).join(
            MarriageHall, Booking.hall_id == MarriageHall.hall_id
        ).filter(
            Booking.customer_email == email
        ).order_by(Booking.booking_date.desc()).all()

        result = []
        for booking, hall in bookings:
            status_message = {
                'pending': 'Waiting for approval',
                'approved_by_admin': 'Approved by admin',
                'approved_by_client': 'Approved by hall owner',
                'rejected': 'Not available (rejected)',
                'canceled': 'Canceled by you'
            }.get(booking.status, booking.status)

            result.append({
                "booking_id": booking.hall_booking_id,
                "hall_name": hall.hall_name,
                "booking_date": booking.booking_date.strftime('%Y-%m-%d'),
                "status": booking.status,
                "payment_status": booking.payment_status,
                "txn_ref": booking.txn_ref,
                "status_message": status_message,
                "can_cancel": booking.status in ['pending', 'approved_by_admin']
            })

        log_action(email, 'customer', "Viewed My Bookings")
        return jsonify({"bookings": result}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/approve_booking', methods=['GET'])
def approve_booking():
    booking_id = request.args.get('booking_id')
    new_status = request.args.get('status')
    approver_email = request.args.get('email')

    if new_status not in ['approved_by_admin', 'approved_by_client']:
        return jsonify({'error': 'Invalid status'}), 400

    booking = db.session.query(Booking, MarriageHall).join(
        MarriageHall, Booking.hall_id == MarriageHall.hall_id
    ).filter(Booking.hall_booking_id == booking_id).first()

    if not booking:
        return jsonify({'error': 'Booking not found'}), 404

    booking_obj, hall = booking
    hall_id = booking_obj.hall_id
    booking_date = booking_obj.booking_date

    try:
        if new_status in ['approved_by_admin', 'approved_by_client']:
            db.session.execute(
                text("""
                    UPDATE bookings
                    SET status = 'rejected'
                    WHERE hall_id = :hall_id 
                    AND booking_date = :booking_date 
                    AND hall_booking_id != :id
                    AND status = 'pending'
                """),
                {'hall_id': hall_id, 'booking_date': booking_date, 'id': booking_id}
            )

            db.session.execute(
                text("""
                    UPDATE hall_availability
                    SET is_booked = 1
                    WHERE hall_id = :hall_id AND available_date = :booking_date
                """),
                {'hall_id': hall_id, 'booking_date': booking_date}
            )

            booking_obj.status = new_status
            db.session.commit()

            log_action(approver_email, 'admin' if 'admin' in new_status else 'client',
                      f"Approved booking {booking_id}",
                      f"Hall: {hall.hall_name}, Date: {booking_date}")

            rejected_bookings = Booking.query.filter(
                Booking.hall_id == hall_id,
                Booking.booking_date == booking_date,
                Booking.hall_booking_id != booking_id,
                Booking.status == 'rejected'
            ).all()

            for rb in rejected_bookings:
                log_action(rb.customer_email, 'system', "Booking auto-rejected",
                          f"Due to another booking being approved for {hall.hall_name} on {booking_date}")

            return jsonify({
                'message': 'Booking approved successfully',
                'rejected_count': len(rejected_bookings)
            })

    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500

@app.route('/admin/stats', methods=['GET'])
def admin_stats():
    log_action('admin@admin.com', 'admin', 'Viewed stats')
    return jsonify({
        "total_halls": MarriageHall.query.count(),
        "total_customers": Customer.query.count(),
        "total_bookings": Booking.query.count(),
        "upcoming_bookings": Booking.query.filter(Booking.booking_date >= datetime.today()).count()
    })

@app.route('/admin/bookings', methods=['GET'])
def all_bookings():
    bookings = db.session.query(Booking, MarriageHall).join(
        MarriageHall, Booking.hall_id == MarriageHall.hall_id, isouter=True
    ).order_by(Booking.booking_date.desc()).all()

    log_action('admin@admin.com', 'admin', 'Viewed all bookings')
    return jsonify([
        {
            "booking_id": b.hall_booking_id,
            "hall_id": b.hall_id,
            "hall_name": h.hall_name if h else "Unknown Hall",
            "booking_date": b.booking_date.strftime('%Y-%m-%d') if b.booking_date else None,
            "status": b.status,
            "customer_email": b.customer_email or "",
        }
        for b, h in bookings
    ])

@app.route('/admin/update_booking/<int:booking_id>', methods=['PUT'])
def update_booking(booking_id):
    data = request.get_json()
    booking = Booking.query.get(booking_id)

    if not booking:
        return jsonify({"error": "Booking not found"}), 404

    booking.status = data.get('status', booking.status)
    db.session.commit()

    log_action('admin@admin.com', 'admin', f"Updated booking {booking_id}", f"Status changed to {booking.status}")
    return jsonify({"message": f"Booking {booking_id} updated"})

@app.route('/admin/logs', methods=['GET'])
def admin_logs():
    logs = UserLog.query.order_by(UserLog.timestamp.desc()).limit(100).all()
    log_action('admin@admin.com', 'admin', 'Viewed logs')
    return jsonify([{
        "email": l.user_email,
        "role": l.role,
        "action": l.action,
        "timestamp": l.timestamp.strftime('%Y-%m-%d %H:%M:%S')
    } for l in logs])

@app.route('/user_logs', methods=['GET'])
def get_user_logs():
    logs = UserLog.query.order_by(UserLog.timestamp.desc()).all()
    log_action(request.args.get('email', 'admin@admin.com'), 'admin', 'Viewed user logs')
    return jsonify([{
        "user_email": l.user_email,
        "role": l.role,
        "action": l.action,
        "details": l.details,
        "timestamp": l.timestamp.strftime("%Y-%m-%d %H:%M:%S")
    } for l in logs])

@app.route('/get_user_name/<string:email>', methods=['GET'])
def get_user_name(email):
    user = Customer.query.filter_by(email=email).first()
    if user:
        return jsonify({"name": user.name})
    else:
        return jsonify({"error": "User not found"}), 404

@app.route('/client/halls/<email>', methods=['GET'])
def get_client_halls(email):
    try:
        halls = MarriageHall.query.filter_by(client_email=email).all()
        if not halls:
            return jsonify({'message': 'No halls found for this client.'}), 404

        result = []
        for hall in halls:
            result.append({
                'hall_id': hall.hall_id,
                'hall_name': hall.hall_name,
                'location': hall.location,
                'capacity': hall.capacity,
                'rent': hall.rent,
                'contact_person': hall.contact_person,
                'phone_number': hall.phone_number,
            })
        log_action(email, 'client', 'Viewed client halls')
        return jsonify({'client_halls': result}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/client/bookings/<client_email>', methods=['GET'])
def get_client_bookings(client_email):
    try:
        halls = MarriageHall.query.filter_by(client_email=client_email).all()
        hall_ids = [h.hall_id for h in halls]

        if not hall_ids:
            return jsonify({"bookings": []})

        bookings = db.session.query(Booking, MarriageHall).join(
            MarriageHall, Booking.hall_id == MarriageHall.hall_id
        ).filter(Booking.hall_id.in_(hall_ids)).order_by(Booking.booking_date.desc()).all()

        result = []
        for booking, hall in bookings:
            result.append({
                "booking_id": booking.hall_booking_id,
                "booking_date": booking.booking_date.strftime("%Y-%m-%d"),
                "customer_name": booking.customer_name,
                "customer_email": booking.customer_email,
                "customer_contact_number": booking.customer_contact_number,
                "hall_name": hall.hall_name,
                "status": booking.status
            })

        log_action(client_email, 'client', 'Viewed client bookings')
        return jsonify({"bookings": result})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/update_booking/<int:booking_id>', methods=['PUT'])
def update_booking_universal(booking_id):
    data = request.get_json()

    status = data.get('status')
    role = data.get('role')
    email = data.get('email')

    allowed_statuses = ['pending', 'confirmation', 'canceled', 'approved_by_admin', 'approved_by_client']
    if status not in allowed_statuses:
        return jsonify({"error": "Invalid status value"}), 400

    booking = Booking.query.get(booking_id)
    if not booking:
        return jsonify({"error": "Booking not found"}), 404

    try:
        booking.status = status
        db.session.commit()
        log_action(email, role, f"Booking {status}", f"Booking ID: {booking_id}")

        if status in ['approved_by_admin', 'approved_by_client']:
            hall_id = booking.hall_id
            booking_date = booking.booking_date

            other_bookings = Booking.query.filter(
                Booking.hall_id == hall_id,
                Booking.booking_date == booking_date,
                Booking.hall_booking_id != booking_id,
                Booking.status == "pending"
            ).all()

            for b in other_bookings:
                b.status = "rejected"
                log_action(email, role, "Booking rejected (auto)", f"Booking ID: {b.hall_booking_id}")

            db.session.commit()

        return jsonify({"message": f"Booking {status} successfully."}), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500

@app.route('/hall/<int:hall_id>/booked_dates', methods=['GET'])
def get_booked_dates(hall_id):
    try:
        results = db.session.execute(
            text("""
                SELECT available_date 
                FROM hall_availability 
                WHERE hall_id = :hall_id AND is_booked = 1
                ORDER BY available_date
            """),
            {"hall_id": hall_id}
        ).fetchall()

        booked_dates = [row[0].strftime('%Y-%m-%d') for row in results]
        log_action(request.args.get('email', 'guest'), 'customer', f"Viewed booked dates for hall {hall_id}")
        return jsonify({
            "hall_id": hall_id,
            "booked_dates": booked_dates
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/client/register_hall', methods=['POST'])
def register_hall():
    data = request.get_json()

    required_fields = [
        'client_email', 'hall_name', 'hall_capacity',
        'hall_rate', 'location', 'contact_person', 'phone_number'
    ]

    if not all(field in data and data[field] for field in required_fields):
        return jsonify({"error": "Missing required fields"}), 400

    client = db.session.execute(
        text("SELECT * FROM customers WHERE email = :email AND role = 'client'"),
        {'email': data['client_email']}
    ).fetchone()

    if not client:
        return jsonify({"error": "Client not found or not authorized"}), 404

    existing_request = RegistrationRequest.query.filter_by(
        ClientEmail=data['client_email'],
        HallName=data['hall_name'],
        RequestStatus='Pending'
    ).first()

    if existing_request:
        return jsonify({"error": "You already have a pending request for this hall"}), 400

    new_request = RegistrationRequest(
        ClientEmail=data['client_email'],
        HallName=data['hall_name'],
        HallCapacity=data['hall_capacity'],
        HallRate=data['hall_rate'],
        Location=data['location'],
        ContactPerson=data['contact_person'],
        PhoneNumber=data['phone_number'],
        OtherInfo=data.get('other_info', ''),
        RequestStatus='Pending',
        SubmittedAt=datetime.utcnow()
    )

    db.session.add(new_request)
    db.session.commit()

    log_action(data['client_email'], 'client', "Submitted Hall Registration")
    return jsonify({"message": "Registration request submitted for admin approval"}), 201


@app.route('/client/status/<email>', methods=['GET'])
def check_client_status(email):
    client = Customer.query.filter_by(email=email, role='client').first()
    if not client:
        return jsonify({"error": "Client not found"}), 404

    pending_request = RegistrationRequest.query.filter_by(
        ClientEmail=email, RequestStatus='Pending'
    ).first()

    rejected_request = RegistrationRequest.query.filter_by(
        ClientEmail=email, RequestStatus='Rejected'
    ).order_by(RegistrationRequest.SubmittedAt.desc()).first()

    return jsonify({
        "registration_status": client.RegistrationStatus,
        "has_pending_request": bool(pending_request),
        "is_rejected": bool(rejected_request),
        "rejection_message": rejected_request.AdminComments if rejected_request else None
    })


@app.route('/approve_client', methods=['POST'])
def approve_client():
    data = request.get_json()
    request_id = data.get('request_id')
    admin_comments = data.get('admin_comments', '')

    try:
        request_record = RegistrationRequest.query.filter_by(RequestID=request_id).first()
        if not request_record:
            return jsonify({"error": "Request not found"}), 404

        new_hall = MarriageHall(
            hall_name=request_record.HallName,
            location=request_record.Location,
            capacity=request_record.HallCapacity,
            rent=request_record.HallRate,
            contact_person=request_record.ContactPerson,
            phone_number=request_record.PhoneNumber,
            client_email=request_record.ClientEmail,
            is_approved=True
        )

        client = Customer.query.filter_by(email=request_record.ClientEmail).first()
        if not client:
            return jsonify({"error": "Client not found"}), 404

        client.RegistrationStatus = True
        request_record.RequestStatus = 'Approved'
        request_record.ReviewedAt = datetime.utcnow()
        request_record.AdminComments = admin_comments

        db.session.add(new_hall)
        db.session.commit()

        log_action(request_record.ClientEmail, 'admin', "Approved Client Hall Registration",
                   f"Hall: {request_record.HallName}, Comments: {admin_comments}")
        return jsonify({"message": "Client request approved and hall registered successfully"})

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500


@app.route('/reject_client', methods=['POST'])
def reject_client():
    data = request.get_json()
    email = data.get('email')
    admin_comments = data.get('admin_comments', '')

    try:
        pending_request = RegistrationRequest.query.filter_by(
            ClientEmail=email, RequestStatus='Pending'
        ).order_by(RegistrationRequest.SubmittedAt.desc()).first()

        if not pending_request:
            return jsonify({"error": "No pending request found for this client"}), 404

        pending_request.RequestStatus = 'Rejected'
        pending_request.ReviewedAt = datetime.utcnow()
        pending_request.AdminComments = admin_comments
        db.session.commit()

        log_action(email, 'admin', "Rejected Client Registration", f"Comments: {admin_comments}")
        return jsonify({"message": "Client's registration request rejected successfully"})

    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500


@app.route('/pending_requests', methods=['GET'])
def get_pending_requests():
    try:
        pending_requests = RegistrationRequest.query.filter_by(RequestStatus='Pending').order_by(
            RegistrationRequest.SubmittedAt.desc()
        ).all()

        pending = [{
            "request_id": r.RequestID,
            "client_email": r.ClientEmail,
            "hall_name": r.HallName,
            "hall_capacity": r.HallCapacity,
            "hall_rate": float(r.HallRate),
            "location": r.Location,
            "contact_person": r.ContactPerson,
            "phone_number": r.PhoneNumber,
            "other_info": r.OtherInfo,
            "submitted_at": r.SubmittedAt.strftime("%Y-%m-%d %H:%M:%S")
        } for r in pending_requests]

        log_action('admin@admin.com', 'admin', "Viewed pending registration requests")
        return jsonify(pending)

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/client/halls', methods=['GET'])
def get_halls_by_client_email():
    client_email = request.args.get('email')

    if not client_email:
        return jsonify({"error": "Missing client email"}), 400

    client = Customer.query.filter_by(email=client_email, role='client').first()
    if not client:
        return jsonify({"error": "Client not found"}), 404

    if not client.RegistrationStatus:
        return jsonify({"error": "Client not approved yet"}), 403

    halls = MarriageHall.query.filter_by(client_email=client_email).all()

    return jsonify({
        "halls": [{
            "hall_id": h.hall_id,
            "hall_name": h.hall_name,
            "location": h.location,
            "capacity": h.capacity,
            "rent": float(h.rent),
            "contact_person": h.contact_person,
            "phone_number": h.phone_number,
            "image": h.image_url if hasattr(h, 'image_url') else "",
            "images": []
        } for h in halls]
    })
    
    #naye client k liye by default form khule
@app.route('/get_client_hall_status/<email>', methods=['GET'])
def get_client_hall_status(email):
    client = Client.query.filter_by(Email=email).first()
    if not client:
        return jsonify({'error': 'Client not found'}), 404

    has_hall = MarriageHall.query.filter_by(ClientEmail=email).first() is not None
    return jsonify({'has_hall': has_hall})

@app.route('/payments/create_order', methods=['POST'])
def create_payment_order():
    data = request.get_json()
    booking_id = data['booking_id']
    amount = data['amount']
    gateway = data['gateway'].lower()  # 'jazzcash' or 'easypaisa'
    
    booking = Booking.query.get(booking_id)
    if not booking or booking.status not in ['approved_by_admin', 'approved_by_client']:
        return jsonify({'error': 'Booking not ready for payment'}), 400
    
    # Calculate 50% advance
    hall = MarriageHall.query.get(booking.hall_id)
    advance_amount = amount * 0.5  # or hall.rent * 0.5 / num_days
    
    # Generate txn ref
    txn_ref = f"SHADI{booking_id}{int(datetime.now().timestamp())}"
    booking.payment_status = 'initiated'
    booking.txn_ref = txn_ref
    db.session.commit()
    
    # Sandbox payment URL (replace with real keys)
    if gateway == 'jazzcash':
        payment_url = f"https://sandbox.jazzcash.com.pk/CustomerPortal/transactionmanagement/merchantform/?pp_Version=1.1&amp;pp_TxnType=NPG&amp;pp_Language=EN&amp;pp_MerchantID=PLACEHOLDER_STOREID&amp;pp_PassPhrase=PLACEHOLDER&amp;pp_TxnRefNo={txn_ref}&amp;pp_Amount={advance_amount*100}&amp;pp_TxnCurrency=PKR&amp;pp_TxnDateTime={datetime.now().strftime('%Y%m%d%H%M%s')}&amp;pp_BillReference={booking_id}&amp;pp_Description=Hall+Booking+Advance&amp;pp_ClientID=PLACEHOLDER&amp;pp_ReturnURL={baseUrl}/payments/verify?txn_ref={txn_ref}"
    elif gateway == 'easypaisa':
        payment_url = f"https://sandbox.easypaisa.com.pk/easypay/index.jsf?txtBnktxnId={txn_ref}&amp;txtAmt={advance_amount}&amp;txtExpiryDateTime={datetime.now().strftime('%Y-%m-%d %H:%M:%S')}&amp;txtSubBnktxnId=1&amp;txtCustEmail={booking.customer_email}&amp;txtCustCell={booking.customer_contact_number}&amp;txtPayOption=0&amp;txtCNIC=&amp;txtRemPymntID=&amp;mpin="
    else:
        return jsonify({'error': 'Unsupported gateway'}), 400
    
    log_action(booking.customer_email, 'customer', 'Payment initiated', f"Gateway: {gateway}, Amount: PKR {advance_amount}, Txn: {txn_ref}")
    
    return jsonify({
        'payment_url': payment_url,
        'txn_ref': txn_ref,
        'advance_amount': advance_amount,
        'gateway': gateway
    })

@app.route('/payments/verify', methods=['GET'])
def verify_payment():
    txn_ref = request.args.get('txn_ref')
    status = request.args.get('status', 'failed')  # From redirect
    
    booking = Booking.query.filter_by(txn_ref=txn_ref).first()
    if booking:
        booking.payment_status = 'paid' if status == 'success' else 'failed'
        db.session.commit()
        log_action(booking.customer_email, 'system', 'Payment callback', f"Status: {status}")
    
    return jsonify({'message': 'Payment status updated'})

# === Run ===
if __name__ == '__main__':
    if not os.path.exists('Uploads'):
        os.makedirs('Uploads')
    app.run(host='0.0.0.0', port=5000, debug=True)
