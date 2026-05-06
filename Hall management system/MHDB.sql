
-- ===========================
-- 0. Drop Old Constraints and Tables Safely
-- ===========================
USE MHDB;
GO

-- Drop all foreign keys
DECLARE @fkSQL NVARCHAR(MAX) = '';
SELECT @fkSQL += 'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + '.' + QUOTENAME(t.name) +
                 ' DROP CONSTRAINT ' + QUOTENAME(fk.name) + ';' + CHAR(13)
FROM sys.foreign_keys fk
JOIN sys.tables t ON fk.parent_object_id = t.object_id;
IF @fkSQL <> '' EXEC sp_executesql @fkSQL;

-- Drop all default constraints
DECLARE @dcSQL NVARCHAR(MAX) = '';
SELECT @dcSQL += 'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + '.' + QUOTENAME(t.name) +
                 ' DROP CONSTRAINT ' + QUOTENAME(dc.name) + ';' + CHAR(13)
FROM sys.default_constraints dc
JOIN sys.tables t ON dc.parent_object_id = t.object_id;
IF @dcSQL <> '' EXEC sp_executesql @dcSQL;

-- Drop tables if they exist
DROP TABLE IF EXISTS hall_availability;
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS marriage_halls;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS user_logs;
DROP TABLE IF EXISTS RegistrationRequests;

-- ===========================
-- 1. Create Database if Not Exists
-- ===========================
IF DB_ID('MHDB') IS NULL
    CREATE DATABASE MHDB;
GO
USE MHDB;
GO

-- ===========================
-- 2. Customers Table
-- ===========================
CREATE TABLE customers (
    id INT PRIMARY KEY IDENTITY(1,1),
    name VARCHAR(100),
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(15),
    password VARCHAR(255),
    role VARCHAR(20) DEFAULT 'customer',
    profile_image VARCHAR(255),
    RegistrationStatus BIT DEFAULT 0,
    UpdatedAt DATETIME
);

-- ===========================
-- 3. Marriage Halls Table
-- ===========================
CREATE TABLE marriage_halls (
    hall_id INT PRIMARY KEY IDENTITY(1,1),
    hall_name VARCHAR(255),
    location VARCHAR(255),
    capacity INT,
    rent INT,
    contact_person VARCHAR(100),
    phone_number VARCHAR(15),
    client_email VARCHAR(100)
);

-- ===========================
-- 4. Hall Availability Table
-- ===========================
CREATE TABLE hall_availability (
    availability_id INT PRIMARY KEY IDENTITY(1,1),
    hall_id INT,
    available_date DATE NOT NULL,
    is_booked BIT DEFAULT 0,
    FOREIGN KEY (hall_id) REFERENCES marriage_halls(hall_id),
    UNIQUE(hall_id, available_date)
);

-- ===========================
-- 5. Bookings Table
-- ===========================
CREATE TABLE bookings (
    hall_booking_id INT PRIMARY KEY IDENTITY(1,1),
    hall_id INT,
    customer_name NVARCHAR(255),
    customer_contact_number NVARCHAR(20),
    booking_date DATE,
    status NVARCHAR(30) DEFAULT 'pending'
        CHECK (status IN ('pending', 'confirmation', 'canceled', 'approved_by_admin', 'approved_by_client')),
    customer_email VARCHAR(255),
    FOREIGN KEY (hall_id) REFERENCES marriage_halls(hall_id),
    CONSTRAINT uq_customer_booking UNIQUE (customer_email, hall_id, booking_date)
);

-- ===========================
-- 6. User Logs Table
-- ===========================
CREATE TABLE user_logs (
    log_id INT PRIMARY KEY IDENTITY(1,1),
    user_email VARCHAR(255),
    role VARCHAR(20),
    action VARCHAR(255),
    details TEXT,
    timestamp DATETIME DEFAULT GETDATE()
);
use mhdb;
-- ===========================
-- 7. Registration Requests Table
-- ===========================
CREATE TABLE RegistrationRequests (
    RequestID INT IDENTITY(1,1) PRIMARY KEY,
    ClientEmail VARCHAR(255) NOT NULL,
    HallName VARCHAR(255) NOT NULL,
    HallCapacity INT NOT NULL,
    HallRate DECIMAL(10,2) NOT NULL,
    ContactPerson VARCHAR(255) NOT NULL,
    PhoneNumber VARCHAR(50) NOT NULL,
    Location VARCHAR(255) NOT NULL,
    OtherInfo TEXT,
    RequestStatus VARCHAR(50) DEFAULT 'Pending',
    RequestedAt DATETIME DEFAULT GETDATE(),
    ReviewedAt DATETIME
);


-- ===========================
-- 8. Trigger for Registration Approval
-- ===========================
CREATE TRIGGER UpdateMarriageHallsOnApproval
ON RegistrationRequests
AFTER UPDATE
AS
BEGIN
    IF UPDATE(RequestStatus)
    BEGIN
        INSERT INTO marriage_halls (hall_name, capacity, rent, client_email)
        SELECT HallName, HallCapacity, HallRate, ClientEmail
        FROM inserted
        WHERE RequestStatus = 'Approved'
        AND NOT EXISTS (
            SELECT 1 FROM marriage_halls mh
            WHERE mh.hall_name = inserted.HallName
            AND mh.client_email = inserted.ClientEmail
        );

        UPDATE c
        SET c.RegistrationStatus = 1,
            c.UpdatedAt = GETDATE()
        FROM customers c
        INNER JOIN inserted i ON c.email = i.ClientEmail
        WHERE i.RequestStatus = 'Approved';
    END
END;

-- ===========================
-- 9. Sample Admin, Clients, Customers, Halls and Data
-- ===========================
INSERT INTO customers (name, email, phone, password, role, RegistrationStatus)
VALUES ('Admin User', 'admin@admin.com', '03001234567', 'admin123', 'admin', 1);

INSERT INTO customers (name, email, password, phone, role, RegistrationStatus)
VALUES 
('Bilal Client', 'bilal@client.com', '123', '03001234567', 'client', 1),
('Ebad Client', 'ebad@client.com', '123', '03111234567', 'client', 1),
('Arsalan Client', 'arsalan@client.com', '123', '03211234567', 'client', 1);

INSERT INTO customers (name, email, phone, password, role, RegistrationStatus)
VALUES 
('Mufrah Jawaid', 'mufrah@client.com', '03123456789', '1234', 'customer', 1),
('Hashir', 'hashir@gmail.com', '03111234567', '1234', 'customer', 1),
('Lucky', 'lucky@gmail.com', '03119876543', '1234', 'customer', 1);

INSERT INTO marriage_halls (hall_name, location, capacity, rent, contact_person, phone_number, client_email)
VALUES 
('Galaxy Banquet', 'Karachi', 300, 250000, 'Ali Khan', '03111222333', 'bilal@client.com'),
('Pearl Palace', 'Lahore', 400, 275000, 'Sara Ahmed', '03211234567', 'bilal@client.com'),
('Royal Fort', 'Islamabad', 500, 300000, 'Ahmed Raza', '03012345678', 'ebad@client.com'),
('Dream Garden', 'Karachi', 350, 260000, 'Fatima Noor', '03451234567', 'arsalan@client.com'),
('Sunshine Villa', 'Rawalpindi', 450, 285000, 'Bilal Hussain', '03331234567', 'arsalan@client.com');

-- ===========================
-- 10. Insert 10 Years Availability
-- ===========================
DECLARE @startDate DATE = CAST(GETDATE() AS DATE);
DECLARE @endDate DATE = DATEADD(DAY, 3649, @startDate);
WHILE @startDate <= @endDate
BEGIN
    INSERT INTO hall_availability (hall_id, available_date, is_booked)
    SELECT hall_id, @startDate, 0
    FROM marriage_halls
    WHERE NOT EXISTS (
        SELECT 1 FROM hall_availability ha
        WHERE ha.hall_id = marriage_halls.hall_id
        AND ha.available_date = @startDate
    );
    SET @startDate = DATEADD(DAY, 1, @startDate);
END;

-- ===========================
-- 11. Sample Booking and Logs
-- ===========================
INSERT INTO bookings (hall_id, customer_name, customer_contact_number, booking_date, status, customer_email)
VALUES (1, 'Mufrah Jawaid', '03123456789', '2025-07-25', 'confirmation', 'mufrah@client.com');

INSERT INTO user_logs (user_email, role, action, details)
VALUES 
('admin@admin.com', 'admin', 'Viewed Dashboard', 'Admin opened dashboard'),
('mufrah@client.com', 'customer', 'Booked Hall', 'Hall ID 1 booked on 2025-07-25');


ALTER TABLE marriage_halls
ADD registration_request_id INT NULL,
CONSTRAINT FK_MarriageHall_RegistrationRequest
FOREIGN KEY (registration_request_id) REFERENCES RegistrationRequests(RequestID);

ALTER TABLE RegistrationRequests
ADD contact_person NVARCHAR(100),
    phone_number NVARCHAR(15),
    location NVARCHAR(255);

SELECT @@SERVERNAME

SELECT hall_id, hall_name FROM marriage_halls
WHERE client_email = 'ebad@client.com';

DELETE FROM hall_availability
WHERE hall_id = 3;

DELETE FROM marriage_halls
WHERE hall_id = 3;


-----------naya hall id 3 k liye---------------------

INSERT INTO customers (name, email, password, phone, role, RegistrationStatus)
VALUES ('Murtaza Client', 'murtaza@client.com', '123', '03451234567', 'client', 0);



SELECT * FROM customers 

ALTER TABLE customers
ADD RegistrationStatus BIT DEFAULT 0;

ALTER TABLE user_logs
ADD request_id INT NULL,
    FOREIGN KEY (request_id) REFERENCES RegistrationRequests(RequestID);

ALTER TABLE marriage_halls
ADD CONSTRAINT FK_MarriageHall_Client
FOREIGN KEY (client_email) REFERENCES customers(email);


SELECT *
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'customers' AND COLUMN_NAME = 'RegistrationStatus';

ALTER TABLE customers
ADD RegistrationStatus BIT DEFAULT 0;

ALTER TABLE customers DROP COLUMN RegistrationStatus;

IF OBJECT_ID('RegistrationRequests', 'U') IS NOT NULL
DROP TABLE RegistrationRequests;

SELECT f.name AS ForeignKey,
       OBJECT_NAME(f.parent_object_id) AS ReferencingTable,
       COL_NAME(fc.parent_object_id, fc.parent_column_id) AS ReferencingColumn
FROM sys.foreign_keys AS f
INNER JOIN sys.foreign_key_columns AS fc
    ON f.object_id = fc.constraint_object_id
WHERE f.referenced_object_id = OBJECT_ID('RegistrationRequests');


ALTER TABLE marriage_halls
DROP CONSTRAINT FK_MarriageHall_RegistrationRequest;

DROP TABLE RegistrationRequests;

ALTER TABLE marriage_halls
ADD RequestID INT;


ALTER TABLE marriage_halls
ADD CONSTRAINT FK_MarriageHalls_RegistrationRequests
FOREIGN KEY (RequestID)
REFERENCES RegistrationRequests(RequestID);

INSERT INTO customers (name, email, phone, password, role, RegistrationStatus, UpdatedAt)
VALUES (
    'Ali Khan',
    'newclient@example.com',
    '03121234567',
    'dummyhashedpassword123',  -- 🔐 Replace with real hashed password if needed
    'client',
    0,  -- Not registered yet
    GETDATE()
);

select * from customers where role = NT_CLIENT

INSERT INTO Customers (
    name,
    email,
    phone,
    password,
    role,
    profile_image,
    RegistrationStatus,
    UpdatedAt
)
VALUES (
    'Client User',
    'client1@gmail.com',
    '03001234567',
    'hashedpassword123', -- placeholder, your backend might hash this anyway
    'client',
    NULL,
    0,
    GETDATE()
);



ALTER TABLE RegistrationRequests
ADD SubmittedAt DATETIME DEFAULT GETDATE(),
    AdminComments VARCHAR(500);


SELECT * FROM customers WHERE email = 'murtaza@client.com';

SELECT * FROM RegistrationRequests WHERE ClientEmail = 'murtaza@client.com' AND RequestStatus = 'Pending';

SELECT * FROM RegistrationRequests WHERE RequestID = 1;

SELECT * FROM customers WHERE email = 'murtaza@client.com';


INSERT INTO Customers (
    name,
    email,
    phone,
    password,
    role,
    profile_image,
    RegistrationStatus,
    UpdatedAt
)
VALUES (
    'Inaam',
    'inaam@gmail.com',
    '03011234567',
    'inaam123',  -- plain text password
    'client',
    NULL,
    0,
    GETDATE()
);
use mhdb

select * from [dbo].[RegistrationRequests]

INSERT INTO customers (name, email, phone, password, role)
VALUES ('Faizan', 'faizan@gmail.com', '03123456789', 'hashed_password_here', 'client');

UPDATE customers
SET password = 'faizan123'
WHERE email = 'faizan@example.com';

INSERT INTO customers (name, email, phone, password, role)
VALUES ('Faizan', 'adnan@gmail.com', '03123456789', 'adnan123', 'client');

INSERT INTO customers (name, email, phone, password, role)
VALUES ('Faizan', 'sameer@gmail.com', '03123456789', '1234', 'client');

SELECT *
FROM customers
WHERE role = 'client';

SELECT * FROM marriage_halls;

ALTER TABLE marriage_halls ADD is_approved BIT DEFAULT 0;

SELECT * FROM marriage_halls WHERE client_email = 'sameer@gmail.com' AND is_approved = 1;

ALTER TABLE marriage_halls
ADD is_approved BIT NOT NULL DEFAULT 0;

SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'marriage_halls' AND COLUMN_NAME = 'is_approved';

UPDATE marriage_halls SET is_approved = 0 WHERE is_approved IS NULL;

ALTER TABLE marriage_halls
ALTER COLUMN is_approved BIT NOT NULL;
