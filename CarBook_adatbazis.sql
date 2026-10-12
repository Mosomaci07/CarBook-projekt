-- ==========================================================
-- CarBook - Webes autonyilvantarto rendszer
-- Adatbazisterv / MySQL-MariaDB (phpMyAdmin)
-- Az adatbazis 10 tablat tartalmaz.
-- Az autokhoz kapcsolt rekordokat az auto torlese torli.
-- ==========================================================

CREATE DATABASE IF NOT EXISTS carbook_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE carbook_db;

-- 1. Felhasznalok
CREATE TABLE IF NOT EXISTS users (
    user_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('user', 'admin') NOT NULL DEFAULT 'user',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Autok (egy auto egy felhasznalohoz tartozik)
CREATE TABLE IF NOT EXISTS cars (
    car_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    brand VARCHAR(80) NOT NULL,
    model VARCHAR(80) NOT NULL,
    manufacture_year SMALLINT UNSIGNED NOT NULL,
    engine VARCHAR(100),
    fuel_type VARCHAR(30) NOT NULL,
    power_hp SMALLINT UNSIGNED,
    mileage_km INT UNSIGNED NOT NULL DEFAULT 0,
    license_plate VARCHAR(20),
    vin VARCHAR(17) UNIQUE,
    image_path VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_cars_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_cars_user (user_id)
) ENGINE=InnoDB;

-- 3. Szervizek nyilvantartasa
CREATE TABLE IF NOT EXISTS service_centers (
    service_center_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    address VARCHAR(255),
    phone VARCHAR(30)
) ENGINE=InnoDB;

-- 4. Digitalis szerviznaplo
CREATE TABLE IF NOT EXISTS services (
    service_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    car_id INT UNSIGNED NOT NULL,
    service_center_id INT UNSIGNED NULL,
    service_date DATE NOT NULL,
    mileage_km INT UNSIGNED NOT NULL,
    work_description TEXT NOT NULL,
    parts_cost DECIMAL(12,2) NOT NULL DEFAULT 0,
    labor_cost DECIMAL(12,2) NOT NULL DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_services_car FOREIGN KEY (car_id)
        REFERENCES cars(car_id) ON DELETE CASCADE,
    CONSTRAINT fk_services_center FOREIGN KEY (service_center_id)
        REFERENCES service_centers(service_center_id) ON DELETE SET NULL,
    CONSTRAINT chk_services_cost CHECK (parts_cost >= 0 AND labor_cost >= 0),
    INDEX idx_services_car_date (car_id, service_date)
) ENGINE=InnoDB;

-- 5. Tankolasok
CREATE TABLE IF NOT EXISTS fuelings (
    fueling_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    car_id INT UNSIGNED NOT NULL,
    fueling_date DATE NOT NULL,
    mileage_km INT UNSIGNED NOT NULL,
    liters DECIMAL(8,2) NOT NULL,
    price_per_liter DECIMAL(10,2) NOT NULL,
    total_cost DECIMAL(12,2) NOT NULL,
    is_full_tank BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    CONSTRAINT fk_fuelings_car FOREIGN KEY (car_id)
        REFERENCES cars(car_id) ON DELETE CASCADE,
    CONSTRAINT chk_fuelings_values CHECK (
        liters > 0 AND price_per_liter >= 0 AND total_cost >= 0
    ),
    INDEX idx_fuelings_car_date (car_id, fueling_date)
) ENGINE=InnoDB;

-- 6. Koltsegkategoriak (csak az egyeb kiadasokhoz)
CREATE TABLE IF NOT EXISTS expense_categories (
    category_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- 7. Egyeb koltsegek (a tankolasokat es szervizeket kulon kezeljuk)
CREATE TABLE IF NOT EXISTS expenses (
    expense_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    car_id INT UNSIGNED NOT NULL,
    category_id INT UNSIGNED NOT NULL,
    expense_date DATE NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    description VARCHAR(255),
    CONSTRAINT fk_expenses_car FOREIGN KEY (car_id)
        REFERENCES cars(car_id) ON DELETE CASCADE,
    CONSTRAINT fk_expenses_category FOREIGN KEY (category_id)
        REFERENCES expense_categories(category_id) ON DELETE RESTRICT,
    CONSTRAINT chk_expenses_amount CHECK (amount >= 0),
    INDEX idx_expenses_car_date (car_id, expense_date)
) ENGINE=InnoDB;

-- 8. Hibak es OBD-hibakodok
CREATE TABLE IF NOT EXISTS fault_codes (
    fault_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    car_id INT UNSIGNED NOT NULL,
    fault_code VARCHAR(20),
    title VARCHAR(150) NOT NULL,
    description TEXT,
    detected_date DATE NOT NULL,
    mileage_km INT UNSIGNED,
    status ENUM('active', 'resolved') NOT NULL DEFAULT 'active',
    resolved_date DATE,
    CONSTRAINT fk_faults_car FOREIGN KEY (car_id)
        REFERENCES cars(car_id) ON DELETE CASCADE,
    INDEX idx_faults_car_status (car_id, status)
) ENGINE=InnoDB;

-- 9. Datumhoz es/vagy kilometerhez kotott emlekeztetok
CREATE TABLE IF NOT EXISTS reminders (
    reminder_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    car_id INT UNSIGNED NOT NULL,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    due_date DATE,
    due_mileage_km INT UNSIGNED,
    status ENUM('active', 'completed', 'cancelled') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_reminders_car FOREIGN KEY (car_id)
        REFERENCES cars(car_id) ON DELETE CASCADE,
    CONSTRAINT chk_reminders_due CHECK (
        due_date IS NOT NULL OR due_mileage_km IS NOT NULL
    ),
    INDEX idx_reminders_car_status (car_id, status)
) ENGINE=InnoDB;

-- 10. Autokhoz kapcsolodo dokumentumok
-- A fajl fizikailag a szerveren tarolodik, itt csak az utvonala szerepel.
CREATE TABLE IF NOT EXISTS documents (
    document_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    car_id INT UNSIGNED NOT NULL,
    title VARCHAR(150) NOT NULL,
    document_type VARCHAR(60) NOT NULL,
    file_path VARCHAR(255) NOT NULL,
    expiration_date DATE,
    uploaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_documents_car FOREIGN KEY (car_id)
        REFERENCES cars(car_id) ON DELETE CASCADE,
    INDEX idx_documents_car (car_id)
) ENGINE=InnoDB;

-- Alap kategoriak (ismetelt futtatas eseten sem duplikalodnak)
INSERT IGNORE INTO expense_categories (name) VALUES
    ('Biztosítás'),
    ('Gépjárműadó'),
    ('Parkolás'),
    ('Autópálya-matrica'),
    ('Mosatás'),
    ('Egyéb');

-- PELDA OSSZESITES: az osszes auto osszesitese koltsegtipusok szerint
-- A tankolas, szerviz es egyeb kiadas kulon forrasban van, nem duplazodik.
-- Az eredmenyhez majd user_id-re es/vagy car_id-re lehet szurni.
-- SELECT car_id, SUM(osszeg) AS osszes_koltseg FROM (
--     SELECT car_id, total_cost AS osszeg FROM fuelings
--     UNION ALL
--     SELECT car_id, parts_cost + labor_cost FROM services
--     UNION ALL
--     SELECT car_id, amount FROM expenses
-- ) AS t GROUP BY car_id;
