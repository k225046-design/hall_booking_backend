-- DROP OLD TABLES IF EXIST
IF OBJECT_ID('customer_bookings', 'U') IS NOT NULL DROP TABLE customer_bookings;
IF OBJECT_ID('bookings', 'U') IS NOT NULL DROP TABLE bookings;
IF OBJECT_ID('hall_availability', 'U') IS NOT NULL DROP TABLE hall_availability;
IF OBJECT_ID('hall_expenses', 'U') IS NOT NULL DROP TABLE hall_expenses;
IF OBJECT_ID('hall_grocery', 'U') IS NOT NULL DROP TABLE hall_grocery;
IF OBJECT_ID('hall_bills', 'U') IS NOT NULL DROP TABLE hall_bills;
IF OBJECT_ID('appointment', 'U') IS NOT NULL DROP TABLE appointment;
IF OBJECT_ID('marriage_halls', 'U') IS NOT NULL DROP TABLE marriage_halls;
IF OBJECT_ID('customers', 'U') IS NOT NULL DROP TABLE customers;
IF OBJECT_ID('user_logs', 'U') IS NOT NULL DROP TABLE user_logs;
GO

-- CREATE DATABASE IF NOT EXISTS
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'marriage_halls_db')
BEGIN
    CREATE DATABASE marriage_halls_db;
END;
GO

USE marriage_halls_db;
GO

-- MARRIAGE HALLS TABLE
CREATE TABLE marriage_halls (
    hall_id INT PRIMARY KEY IDENTITY(1,1),
    name VARCHAR(255),
    location VARCHAR(255),
    capacity INT,
    rent INT,
    contact_person VARCHAR(100),
    phone_number VARCHAR(15),
    email VARCHAR(100)
);

-- HALL AVAILABILITY
CREATE TABLE hall_availability (
    availability_id INT PRIMARY KEY IDENTITY(1,1),
    hall_id INT,
    available_date DATE NOT NULL,
    is_booked BIT DEFAULT 0,
    FOREIGN KEY (hall_id) REFERENCES marriage_halls(hall_id)
);

-- BOOKINGS
CREATE TABLE bookings (
    hall_booking_id INT PRIMARY KEY IDENTITY(1,1),
    hall_id INT, 
    customer_name NVARCHAR(255),
    customer_contact_number NVARCHAR(15),
    booking_date DATE,
    status NVARCHAR(20) DEFAULT 'pending',
    customer_email VARCHAR(255),
    FOREIGN KEY (hall_id) REFERENCES marriage_halls(hall_id)
);
GO

-- CUSTOMER BOOKINGS
CREATE TABLE customer_bookings (
    booking_id INT PRIMARY KEY IDENTITY(1,1),
    hall_id INT,
    availability_id INT,
    customer_name VARCHAR(100),
    customer_phone VARCHAR(20),
    customer_email VARCHAR(100),
    status NVARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'canceled', 'confirmation')),
    FOREIGN KEY (hall_id) REFERENCES marriage_halls(hall_id),
    FOREIGN KEY (availability_id) REFERENCES hall_availability(availability_id)
);
GO

-- EXPENSES
CREATE TABLE hall_expenses (
    id INT PRIMARY KEY IDENTITY(1,1),
    hall_id INT,  
    amount DECIMAL(10,2),
    FOREIGN KEY (hall_id) REFERENCES marriage_halls(hall_id)
);

-- GROCERY
CREATE TABLE hall_grocery (
    grocery_id INT PRIMARY KEY IDENTITY(1,1),
    hall_id INT,
    item VARCHAR(100),
    quantity INT,
    cost DECIMAL(10,2),
    FOREIGN KEY (hall_id) REFERENCES marriage_halls(hall_id)
);

-- BILLS
CREATE TABLE hall_bills (
    id INT PRIMARY KEY IDENTITY(1,1),
    hall_id INT,
    bill_type VARCHAR(50),  
    amount DECIMAL(10,2),
    FOREIGN KEY (hall_id) REFERENCES marriage_halls(hall_id)
);

-- PLACEHOLDER
CREATE TABLE appointment (
    appointment_id INT PRIMARY KEY IDENTITY(1,1)
);

-- CUSTOMERS
CREATE TABLE customers (
    id INT PRIMARY KEY IDENTITY(1,1),
    name VARCHAR(100),
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(15),
    password VARCHAR(100)
);

ALTER TABLE customers
ADD profile_image VARCHAR(MAX) NULL;


-- USER LOGS
CREATE TABLE user_logs (
    log_id INT PRIMARY KEY IDENTITY(1,1),
    user_email VARCHAR(255),
    role VARCHAR(20),
    action VARCHAR(255),
    details TEXT,
    timestamp DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- INSERT HALLS
INSERT INTO marriage_halls 
(name, location, capacity, rent, contact_person, phone_number, email)
VALUES 
('Royal Grand Hall', 'Karachi', 300, 50000, 'Mufrah Jawaid', '03123456789', 'mufrah@gmail.com'),
('Pearl Banquet', 'Gulshan-e-Iqbal, Karachi', 400, 60000, 'Baasim', '03211234567', 'baasim@gmail.com'),
('The Palace Hall', 'DHA Phase 6, Karachi', 500, 85000, 'Arsalan', '03331234567', 'arsalan@gmail.com'),
('Empire Marquee', 'North Nazimabad, Karachi', 300, 45000, 'Bilal', '03111234567', 'bilal@gmail.com'),
('Regal Wedding Lawn', 'Nazimabad, Karachi', 350, 52000, 'Ebaad', '03011234567', 'ebaad@gmail.com');
GO

-- INSERT AVAILABILITY
INSERT INTO hall_availability (hall_id, available_date, is_booked)
VALUES 
(1, '2025-07-01', 0),
(1, '2025-07-02', 0),
(1, '2025-07-03', 1),
(2, '2025-07-01', 0),
(2, '2025-07-05', 0),
(3, '2025-07-10', 0),
(4, '2025-07-03', 1),
(5, '2025-07-07', 0),
(5, '2025-07-08', 0),
(5, '2025-07-09', 0);
GO

-- ADMIN BOOKINGS
INSERT INTO bookings (hall_id, customer_name, customer_contact_number, booking_date, status, customer_email)
VALUES 
(1, 'Mufrah Jawaid', '03123456789', '2025-07-03', 'pending', 'mufrah@example.com');
GO

-- CUSTOMER BOOKINGS
INSERT INTO customer_bookings (hall_id, availability_id, customer_name, customer_phone, customer_email, status) 
VALUES 
(1, 3, 'Mufrah Jawaid', '03123456789', 'mufrah@example.com', 'pending');
GO

-- INSERT LOGS
INSERT INTO user_logs (user_email, role, action, details)
VALUES
('mufrah@example.com', 'customer', 'Login', 'User logged in successfully'),
('mufrah@example.com', 'customer', 'Booked Hall', 'Hall 1 booked for 2025-07-03'),
('admin@admin.com', 'admin', 'Viewed Dashboard', 'Admin opened the dashboard'),
('test@example.com', 'customer', 'Test Login', 'User tested logging system');
GO

-- FIX OLD STATUSES IF ANY EXIST
UPDATE bookings SET status = 'confirmation' WHERE status = 'approved';
UPDATE bookings SET status = 'canceled' WHERE status = 'rejected';
GO

-- DROP OLD CONSTRAINT IF EXISTS (safe)
DECLARE @sql NVARCHAR(MAX) = '';
SELECT @sql = 'ALTER TABLE bookings DROP CONSTRAINT ' + QUOTENAME(name)
FROM sys.check_constraints
WHERE parent_object_id = OBJECT_ID('bookings') AND name LIKE 'CK__bookings__status%';
EXEC sp_executesql @sql;
GO

-- ADD NEW STATUS CONSTRAINT
ALTER TABLE bookings
ADD CONSTRAINT CK_bookings_status CHECK (status IN ('pending', 'canceled', 'confirmation'));
GO

-- VERIFY NO INVALID VALUES LEFT
SELECT * FROM bookings WHERE status NOT IN ('pending', 'canceled', 'confirmation');
GO

SELECT DISTINCT status FROM bookings;

SELECT * FROM bookings;

SELECT * FROM bookings WHERE status IN ('approved', 'rejected');

ALTER TABLE customers ALTER COLUMN password VARCHAR(500);

SELECT email FROM customers WHERE LOWER(LTRIM(RTRIM(email))) = LOWER('testuser@example.com');

SELECT email , * FROM customers;

SELECT * FROM bookings WHERE customer_email = 'newuser@example.com';



