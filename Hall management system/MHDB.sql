-- =========================================================
-- MHDB_fixed.sql — Python Flask Backend ke saath 100% match
-- Ye file pehle wali MHDB.sql ki jagah use karo
-- SSMS mein: New Query > paste karo > F5
-- =========================================================

USE master;
GO

-- ─────────────────────────────────────────────
-- 1. Database drop aur recreate (fresh start)
-- ─────────────────────────────────────────────
IF DB_ID('MHDB') IS NOT NULL
BEGIN
    ALTER DATABASE MHDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE MHDB;
END
CREATE DATABASE MHDB;
GO
USE MHDB;
GO

-- ─────────────────────────────────────────────
-- 2. customers
--    Backend model: Customer
--    IMPORTANT: column name "password_hash" — backend yahi expect karta hai
--    "favorite_category", "profile_image", "created_at" bhi chahiye
-- ─────────────────────────────────────────────
CREATE TABLE customers (
    id               INT           PRIMARY KEY IDENTITY(1,1),
    name             NVARCHAR(255) NOT NULL,
    email            NVARCHAR(255) NOT NULL UNIQUE,
    phone            NVARCHAR(20)  NOT NULL DEFAULT '',
    password_hash    NVARCHAR(255) NOT NULL,
    favorite_category NVARCHAR(50) NOT NULL DEFAULT 'Any',
    profile_image    NVARCHAR(MAX) NOT NULL DEFAULT '',
    created_at       DATETIME      NOT NULL DEFAULT GETUTCDATE()
);
GO

-- ─────────────────────────────────────────────
-- 3. marriage_halls
--    Backend model: MarriageHall
--    Naye columns: description, image_urls, category, is_featured
-- ─────────────────────────────────────────────
CREATE TABLE marriage_halls (
    hall_id         INT           PRIMARY KEY IDENTITY(1,1),
    name            NVARCHAR(255) NOT NULL,
    location        NVARCHAR(255) NOT NULL,
    capacity        INT           NOT NULL,
    rent            DECIMAL(10,2) NOT NULL,
    contact_person  NVARCHAR(100) NOT NULL DEFAULT '',
    phone_number    NVARCHAR(20)  NOT NULL DEFAULT '',
    email           NVARCHAR(120) NOT NULL DEFAULT '',
    description     NVARCHAR(MAX) NOT NULL DEFAULT '',
    image_urls      NVARCHAR(MAX) NOT NULL DEFAULT '[]',  -- JSON array of URLs
    category        NVARCHAR(50)  NOT NULL DEFAULT 'Indoor',
    is_featured     BIT           NOT NULL DEFAULT 0
);
GO

-- ─────────────────────────────────────────────
-- 4. photographers
--    Backend model: Photographer
--    hall_ids: JSON array stored as text e.g. "[1,2,3]"
-- ─────────────────────────────────────────────
CREATE TABLE photographers (
    photographer_id  INT           PRIMARY KEY IDENTITY(1,1),
    name             NVARCHAR(255) NOT NULL,
    phone            NVARCHAR(20)  NOT NULL,
    email            NVARCHAR(120) NOT NULL DEFAULT '',
    city             NVARCHAR(100) NOT NULL DEFAULT '',
    experience_years INT           NOT NULL DEFAULT 0,
    price_per_day    DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    portfolio_url    NVARCHAR(MAX) NOT NULL DEFAULT '',
    description      NVARCHAR(MAX) NOT NULL DEFAULT '',
    is_available     BIT           NOT NULL DEFAULT 1,
    hall_ids         NVARCHAR(MAX) NOT NULL DEFAULT '[]',  -- JSON array
    created_at       DATETIME      NOT NULL DEFAULT GETUTCDATE()
);
GO

-- ─────────────────────────────────────────────
-- 5. bookings
--    Backend model: Booking
--    Naye columns: customer_id (FK), event_type, guest_count,
--    special_request, additional_notes, menu_items, total_extra_cost,
--    photographer_id, photographer_cost, payment_status, payment_reference
-- ─────────────────────────────────────────────
CREATE TABLE bookings (
    hall_booking_id          INT           PRIMARY KEY IDENTITY(1,1),
    hall_id                  INT           NOT NULL,
    customer_id              INT           NOT NULL,
    customer_name            NVARCHAR(255) NOT NULL,
    customer_contact_number  NVARCHAR(20)  NOT NULL,
    booking_date             DATE          NOT NULL,
    event_type               NVARCHAR(50)  NOT NULL DEFAULT 'Wedding',
    guest_count              INT           NOT NULL DEFAULT 100,
    special_request          NVARCHAR(MAX) NOT NULL DEFAULT '',
    additional_notes         NVARCHAR(MAX) NOT NULL DEFAULT '',
    menu_items               NVARCHAR(MAX) NOT NULL DEFAULT '[]',  -- JSON array
    total_extra_cost         DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    photographer_id          INT           NULL,
    photographer_cost        DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status                   NVARCHAR(20)  NOT NULL DEFAULT 'pending',
    payment_status           NVARCHAR(20)  NOT NULL DEFAULT 'unpaid',
    payment_reference        NVARCHAR(100) NOT NULL DEFAULT '',
    created_at               DATETIME      NOT NULL DEFAULT GETUTCDATE(),

    CONSTRAINT FK_bookings_hall       FOREIGN KEY (hall_id)         REFERENCES marriage_halls(hall_id),
    CONSTRAINT FK_bookings_customer   FOREIGN KEY (customer_id)     REFERENCES customers(id),
    CONSTRAINT FK_bookings_photographer FOREIGN KEY (photographer_id) REFERENCES photographers(photographer_id)
);
GO

-- ─────────────────────────────────────────────
-- 6. booking_messages
--    Backend model: BookingMessage
-- ─────────────────────────────────────────────
CREATE TABLE booking_messages (
    message_id   INT           PRIMARY KEY IDENTITY(1,1),
    booking_id   INT           NOT NULL,
    sender_role  NVARCHAR(20)  NOT NULL,
    sender_name  NVARCHAR(255) NOT NULL DEFAULT '',
    message      NVARCHAR(MAX) NOT NULL,
    created_at   DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT FK_messages_booking FOREIGN KEY (booking_id) REFERENCES bookings(hall_booking_id)
);
GO

-- ─────────────────────────────────────────────
-- 7. user_logs
--    Backend model: UserLog
--    Column name "email" (pehle user_email tha) — fix karo
-- ─────────────────────────────────────────────
CREATE TABLE user_logs (
    log_id    INT           PRIMARY KEY IDENTITY(1,1),
    email     NVARCHAR(255) NOT NULL,
    role      NVARCHAR(50)  NOT NULL,
    action    NVARCHAR(255) NOT NULL,
    timestamp DATETIME      NOT NULL DEFAULT GETUTCDATE()
);
GO

-- ─────────────────────────────────────────────
-- 8. hall_feedback
--    Backend model: HallFeedback
-- ─────────────────────────────────────────────
CREATE TABLE hall_feedback (
    feedback_id   INT           PRIMARY KEY IDENTITY(1,1),
    hall_id       INT           NOT NULL,
    customer_id   INT           NOT NULL,
    customer_name NVARCHAR(255) NOT NULL,
    rating        INT           NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment       NVARCHAR(MAX) NOT NULL DEFAULT '',
    created_at    DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT FK_feedback_hall     FOREIGN KEY (hall_id)     REFERENCES marriage_halls(hall_id),
    CONSTRAINT FK_feedback_customer FOREIGN KEY (customer_id) REFERENCES customers(id)
);
GO

-- ─────────────────────────────────────────────
-- 9. food_menus
--    Backend model: FoodMenu
-- ─────────────────────────────────────────────
CREATE TABLE food_menus (
    menu_id         INT           PRIMARY KEY IDENTITY(1,1),
    hall_id         INT           NOT NULL,
    category        NVARCHAR(100) NOT NULL DEFAULT 'Main Course',
    item_name       NVARCHAR(255) NOT NULL,
    price_per_plate DECIMAL(8,2)  NOT NULL,
    description     NVARCHAR(MAX) DEFAULT '',
    is_vegetarian   BIT           DEFAULT 0,
    is_available    BIT           DEFAULT 1,
    CONSTRAINT FK_menus_hall FOREIGN KEY (hall_id) REFERENCES marriage_halls(hall_id)
);
GO

-- ─────────────────────────────────────────────
-- 10. payments
--     Backend model: Payment (JazzCash integration)
-- ─────────────────────────────────────────────
CREATE TABLE payments (
    payment_id         INT           PRIMARY KEY IDENTITY(1,1),
    booking_id         INT           NOT NULL,
    txn_ref_no         NVARCHAR(100) NOT NULL UNIQUE,
    amount             DECIMAL(12,2) NOT NULL,
    mobile_number      NVARCHAR(20)  NOT NULL DEFAULT '',
    jazzcash_response  NVARCHAR(MAX) NOT NULL DEFAULT '{}',
    status             NVARCHAR(20)  NOT NULL DEFAULT 'pending',
    created_at         DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    updated_at         DATETIME      NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT FK_payments_booking FOREIGN KEY (booking_id) REFERENCES bookings(hall_booking_id)
);
GO

-- ─────────────────────────────────────────────
-- 11. Seed data — Admin customer
--     Backend "PLAIN:" prefix se plain text password store hota hai
--     First login par werkzeug hash mein upgrade ho jata hai
-- ─────────────────────────────────────────────
INSERT INTO customers (name, email, phone, password_hash, favorite_category)
VALUES ('Admin User', 'admin@admin.com', '03001234567', 'PLAIN:admin123', 'Any');
GO

-- Sample customers (password = "1234" plain text, upgrade on first login)
INSERT INTO customers (name, email, phone, password_hash, favorite_category)
VALUES
('Mufrah Jawaid', 'mufrah@gmail.com',   '03123456789', 'PLAIN:1234', 'Any'),
('Hashir Ahmed',  'hashir@gmail.com',   '03111234567', 'PLAIN:1234', 'Any'),
('Lucky Khan',    'lucky@gmail.com',    '03119876543', 'PLAIN:1234', 'Any');
GO

-- ─────────────────────────────────────────────
-- NOTE: marriage_halls, photographers, food_menus ka seed data
-- Python backend khud insert karta hai startup par (seed_default_data function)
-- Isliye SSMS se manually insert karne ki zaroorat nahi
-- ─────────────────────────────────────────────

PRINT 'MHDB_fixed.sql complete — sab tables Python backend ke saath compatible hain.';
GO

USE MHDB;
SELECT * FROM customers;