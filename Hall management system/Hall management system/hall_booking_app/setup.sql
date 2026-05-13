-- ===========================
-- SQLITE VERSION OF MHDB
-- ===========================

PRAGMA foreign_keys = ON;

-- ===========================
-- DROP TABLES
-- ===========================

DROP TABLE IF EXISTS user_logs;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS hall_availability;
DROP TABLE IF EXISTS marriage_halls;
DROP TABLE IF EXISTS RegistrationRequests;
DROP TABLE IF EXISTS customers;

-- ===========================
-- CUSTOMERS
-- ===========================

CREATE TABLE customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    email TEXT UNIQUE,
    phone TEXT,
    password TEXT,
    role TEXT DEFAULT 'customer',
    profile_image TEXT,
    RegistrationStatus INTEGER DEFAULT 0,
    UpdatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ===========================
-- MARRIAGE HALLS
-- ===========================

CREATE TABLE marriage_halls (
    hall_id INTEGER PRIMARY KEY AUTOINCREMENT,
    hall_name TEXT,
    location TEXT,
    capacity INTEGER,
    rent INTEGER,
    contact_person TEXT,
    phone_number TEXT,
    client_email TEXT,
    is_approved INTEGER DEFAULT 0
);

-- ===========================
-- HALL AVAILABILITY
-- ===========================

CREATE TABLE hall_availability (
    availability_id INTEGER PRIMARY KEY AUTOINCREMENT,
    hall_id INTEGER,
    available_date DATE NOT NULL,
    is_booked INTEGER DEFAULT 0,

    FOREIGN KEY (hall_id)
    REFERENCES marriage_halls(hall_id),

    UNIQUE(hall_id, available_date)
);

-- ===========================
-- BOOKINGS
-- ===========================

CREATE TABLE bookings (
    hall_booking_id INTEGER PRIMARY KEY AUTOINCREMENT,
    hall_id INTEGER,
    customer_name TEXT,
    customer_contact_number TEXT,
    booking_date DATE,
    status TEXT DEFAULT 'pending',
    customer_email TEXT,

    FOREIGN KEY (hall_id)
    REFERENCES marriage_halls(hall_id),

    UNIQUE(customer_email, hall_id, booking_date)
);

-- ===========================
-- USER LOGS
-- ===========================

CREATE TABLE user_logs (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_email TEXT,
    role TEXT,
    action TEXT,
    details TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ===========================
-- REGISTRATION REQUESTS
-- ===========================

CREATE TABLE RegistrationRequests (
    RequestID INTEGER PRIMARY KEY AUTOINCREMENT,
    ClientEmail TEXT,
    HallName TEXT,
    HallCapacity INTEGER,
    HallRate REAL,
    ContactPerson TEXT,
    PhoneNumber TEXT,
    Location TEXT,
    OtherInfo TEXT,
    RequestStatus TEXT DEFAULT 'Pending',
    RequestedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    ReviewedAt DATETIME
);

-- ===========================
-- SAMPLE CUSTOMERS
-- ===========================

INSERT INTO customers
(name, email, phone, password, role, RegistrationStatus)
VALUES
('Admin User', 'admin@admin.com', '03001234567', 'admin123', 'admin', 1);

INSERT INTO customers
(name, email, phone, password, role, RegistrationStatus)
VALUES
('Bilal Client', 'bilal@client.com', '03001234567', '123', 'client', 1),

('Ebad Client', 'ebad@client.com', '03111234567', '123', 'client', 1),

('Arsalan Client', 'arsalan@client.com', '03211234567', '123', 'client', 1);

INSERT INTO customers
(name, email, phone, password, role, RegistrationStatus)
VALUES
('Mufrah Jawaid', 'mufrah@client.com', '03123456789', '1234', 'customer', 1);

-- ===========================
-- SAMPLE HALLS
-- ===========================

INSERT INTO marriage_halls
(hall_name, location, capacity, rent,
contact_person, phone_number, client_email)
VALUES

('Galaxy Banquet', 'Karachi', 300, 250000,
'Ali Khan', '03111222333', 'bilal@client.com'),

('Pearl Palace', 'Lahore', 400, 275000,
'Sara Ahmed', '03211234567', 'bilal@client.com');

-- ===========================
-- SAMPLE BOOKINGS
-- ===========================

INSERT INTO bookings
(hall_id, customer_name,
customer_contact_number,
booking_date,
status,
customer_email)
VALUES

(1, 'Mufrah Jawaid',
'03123456789',
'2026-06-15',
'pending',
'mufrah@client.com');

-- ===========================
-- SAMPLE LOGS
-- ===========================

INSERT INTO user_logs
(user_email, role, action, details)
VALUES

('admin@admin.com',
'admin',
'Created Hall',
'Galaxy Banquet hall added');

-- ===========================
-- SAMPLE REGISTRATION REQUESTS
-- ===========================

INSERT INTO RegistrationRequests
(ClientEmail, HallName, HallCapacity,
HallRate, ContactPerson,
PhoneNumber, Location, OtherInfo)
VALUES

('newclient@example.com',
'Royal Garden',
500,
350000,
'Usman Ali',
'03009998888',
'Islamabad',
'Need approval for new hall');

-- ===========================
-- CHECK CLIENTS
-- ===========================

SELECT * FROM customers
WHERE role = 'client';

-- ===========================
-- VIEW ALL TABLES
-- ===========================

SELECT * FROM customers;

SELECT * FROM marriage_halls;

SELECT * FROM bookings;

SELECT * FROM user_logs;

SELECT * FROM RegistrationRequests;