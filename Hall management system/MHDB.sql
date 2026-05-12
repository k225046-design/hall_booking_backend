-- ===========================
-- 0. USE DATABASE
-- ===========================
IF DB_ID('MHDB') IS NULL
    CREATE DATABASE MHDB;
GO

USE MHDB;
GO

-- ===========================
-- 1. SAFE DROP (NO ERRORS)
-- ===========================
IF OBJECT_ID('user_logs', 'U') IS NOT NULL DROP TABLE user_logs;
IF OBJECT_ID('bookings', 'U') IS NOT NULL DROP TABLE bookings;
IF OBJECT_ID('hall_availability', 'U') IS NOT NULL DROP TABLE hall_availability;
IF OBJECT_ID('marriage_halls', 'U') IS NOT NULL DROP TABLE marriage_halls;
IF OBJECT_ID('RegistrationRequests', 'U') IS NOT NULL DROP TABLE RegistrationRequests;
IF OBJECT_ID('customers', 'U') IS NOT NULL DROP TABLE customers;
GO

-- ===========================
-- 2. CUSTOMERS
-- ===========================
CREATE TABLE customers (
    id INT IDENTITY(1,1) PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(15),
    password VARCHAR(255),
    role VARCHAR(20) DEFAULT 'customer',
    profile_image VARCHAR(255),
    RegistrationStatus BIT DEFAULT 0,
    UpdatedAt DATETIME DEFAULT GETDATE()
);

-- ===========================
-- 3. MARRIAGE HALLS
-- ===========================
CREATE TABLE marriage_halls (
    hall_id INT IDENTITY(1,1) PRIMARY KEY,
    hall_name VARCHAR(255),
    location VARCHAR(255),
    capacity INT,
    rent INT,
    contact_person VARCHAR(100),
    phone_number VARCHAR(15),
    client_email VARCHAR(100),
    is_approved BIT DEFAULT 0
);

-- ===========================
-- 4. HALL AVAILABILITY
-- ===========================
CREATE TABLE hall_availability (
    availability_id INT IDENTITY(1,1) PRIMARY KEY,
    hall_id INT,
    available_date DATE NOT NULL,
    is_booked BIT DEFAULT 0,
    FOREIGN KEY (hall_id) REFERENCES marriage_halls(hall_id),
    UNIQUE(hall_id, available_date)
);

-- ===========================
-- 5. BOOKINGS
-- ===========================
CREATE TABLE bookings (
    hall_booking_id INT IDENTITY(1,1) PRIMARY KEY,
    hall_id INT,
    customer_name NVARCHAR(255),
    customer_contact_number NVARCHAR(20),
    booking_date DATE,
    status NVARCHAR(30) DEFAULT 'pending',
    customer_email VARCHAR(255),
    FOREIGN KEY (hall_id) REFERENCES marriage_halls(hall_id),
    CONSTRAINT uq_booking UNIQUE (customer_email, hall_id, booking_date)
);

-- ===========================
-- 6. USER LOGS
-- ===========================
CREATE TABLE user_logs (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    user_email VARCHAR(255),
    role VARCHAR(20),
    action VARCHAR(255),
    details TEXT,
    timestamp DATETIME DEFAULT GETDATE()
);

-- ===========================
-- 7. REGISTRATION REQUESTS
-- ===========================
CREATE TABLE RegistrationRequests (
    RequestID INT IDENTITY(1,1) PRIMARY KEY,
    ClientEmail VARCHAR(255),
    HallName VARCHAR(255),
    HallCapacity INT,
    HallRate DECIMAL(10,2),
    ContactPerson VARCHAR(255),
    PhoneNumber VARCHAR(50),
    Location VARCHAR(255),
    OtherInfo TEXT,
    RequestStatus VARCHAR(50) DEFAULT 'Pending',
    RequestedAt DATETIME DEFAULT GETDATE(),
    ReviewedAt DATETIME
);

-- ===========================
-- 8. SAMPLE DATA
-- ===========================
INSERT INTO customers (name, email, phone, password, role, RegistrationStatus)
VALUES ('Admin User', 'admin@admin.com', '03001234567', 'admin123', 'admin', 1);

INSERT INTO customers (name, email, phone, password, role, RegistrationStatus)
VALUES 
('Bilal Client', 'bilal@client.com', '03001234567', '123', 'client', 1),
('Ebad Client', 'ebad@client.com', '03111234567', '123', 'client', 1),
('Arsalan Client', 'arsalan@client.com', '03211234567', '123', 'client', 1);

INSERT INTO customers (name, email, phone, password, role, RegistrationStatus)
VALUES 
('Mufrah Jawaid', 'mufrah@client.com', '03123456789', '1234', 'customer', 1);

-- ===========================
-- 9. SAMPLE HALLS
-- ===========================
INSERT INTO marriage_halls (hall_name, location, capacity, rent, contact_person, phone_number, client_email)
VALUES 
('Galaxy Banquet', 'Karachi', 300, 250000, 'Ali Khan', '03111222333', 'bilal@client.com'),
('Pearl Palace', 'Lahore', 400, 275000, 'Sara Ahmed', '03211234567', 'bilal@client.com');

-- ===========================
-- 10. FIXED QUERY (IMPORTANT)
-- ===========================
-- ❌ WRONG (your error)
-- WHERE role = NT_CLIENT

-- ✅ CORRECT
SELECT * FROM customers WHERE role = 'client';

-- ===========================
-- 11. FIX FOR YOUR ERROR (is_approved)
-- ===========================
IF COL_LENGTH('marriage_halls', 'is_approved') IS NULL
BEGIN
    ALTER TABLE marriage_halls ADD is_approved BIT DEFAULT 0;
END;