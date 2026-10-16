-- ============================================================================
-- DBMS PROJECT: LABORATORY EQUIPMENT BOOKING & MAINTENANCE SYSTEM
-- REVIEW 2: ADVANCED DDL SCHEMA WITH INTEGRITY CONSTRAINTS, CHECKS & TRIGGERS
-- Normalized up to Third Normal Form (3NF)
-- Target: PostgreSQL 15+
-- ============================================================================
-- Table inventory (12): Laboratory, EquipmentCategory, Vendor, AppUser,
-- Equipment, TimeSlot, Booking, UsageLog, Calibration, Breakdown,
-- MaintenanceJob, Consumable
-- (the ER entity USER is implemented as AppUser because USER is reserved)
-- ============================================================================

-- ============================================================================
-- 1. MASTER DATA
-- ============================================================================

-- 1. LABORATORY TABLE
CREATE TABLE Laboratory (
    laboratory_id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    location VARCHAR(100) NOT NULL
);

-- 2. EQUIPMENT CATEGORY TABLE
CREATE TABLE EquipmentCategory (
    category_id INTEGER PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE,
    description VARCHAR(200) NOT NULL
);

-- 3. VENDOR TABLE
CREATE TABLE Vendor (
    vendor_id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(15) NOT NULL,
    email VARCHAR(100) NOT NULL CHECK (email LIKE '%_@_%._%')
);

-- 4. APPUSER TABLE (requesters, lab staff and administrators)
CREATE TABLE AppUser (
    user_id INTEGER PRIMARY KEY,
    name VARCHAR(80) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE CHECK (email LIKE '%_@_%._%'),
    role VARCHAR(12) NOT NULL CHECK (role IN ('STUDENT', 'LAB_STAFF', 'ADMIN'))
);

-- 5. EQUIPMENT TABLE (status drives bookability)
CREATE TABLE Equipment (
    equipment_id INTEGER PRIMARY KEY,
    laboratory_id INTEGER NOT NULL REFERENCES Laboratory(laboratory_id),
    category_id INTEGER NOT NULL REFERENCES EquipmentCategory(category_id),
    name VARCHAR(100) NOT NULL,
    serial_no VARCHAR(30) NOT NULL UNIQUE,
    purchase_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'UNDER_MAINTENANCE', 'BROKEN', 'RETIRED'))
);

-- ============================================================================
-- 2. BOOKING & USAGE
-- ============================================================================

-- 6. TIME_SLOT TABLE
CREATE TABLE TimeSlot (
    slot_id INTEGER PRIMARY KEY,
    slot_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    CONSTRAINT chk_slot_times CHECK (end_time > start_time),
    UNIQUE (slot_date, start_time, end_time)
);

-- 7. BOOKING TABLE
CREATE TABLE Booking (
    booking_id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES AppUser(user_id),
    equipment_id INTEGER NOT NULL REFERENCES Equipment(equipment_id),
    slot_id INTEGER NOT NULL REFERENCES TimeSlot(slot_id),
    status VARCHAR(12) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', 'COMPLETED')),
    requested_on TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    purpose VARCHAR(150) NOT NULL
);

CREATE INDEX idx_booking_equipment_status ON Booking(equipment_id, status);

-- 8. USAGE_LOG TABLE
CREATE TABLE UsageLog (
    usage_log_id INTEGER PRIMARY KEY,
    booking_id INTEGER NOT NULL REFERENCES Booking(booking_id) ON DELETE CASCADE,
    usage_date DATE NOT NULL,
    hours_used NUMERIC(4,2) NOT NULL CHECK (hours_used > 0 AND hours_used <= 12),
    details VARCHAR(200) NOT NULL
);

-- ============================================================================
-- 3. SAFETY & MAINTENANCE
-- ============================================================================

-- 9. CALIBRATION TABLE (next due date must be after calibration date)
CREATE TABLE Calibration (
    calibration_id INTEGER PRIMARY KEY,
    equipment_id INTEGER NOT NULL REFERENCES Equipment(equipment_id) ON DELETE CASCADE,
    calibration_date DATE NOT NULL,
    next_due_date DATE NOT NULL,
    performed_by VARCHAR(100) NOT NULL,
    CONSTRAINT chk_calibration_dates CHECK (next_due_date > calibration_date),
    UNIQUE (equipment_id, calibration_date)
);

-- 10. BREAKDOWN TABLE
CREATE TABLE Breakdown (
    breakdown_id INTEGER PRIMARY KEY,
    equipment_id INTEGER NOT NULL REFERENCES Equipment(equipment_id) ON DELETE CASCADE,
    reported_on DATE NOT NULL,
    resolved_on DATE,
    description VARCHAR(200) NOT NULL,
    status VARCHAR(12) NOT NULL DEFAULT 'REPORTED'
        CHECK (status IN ('REPORTED', 'IN_REPAIR', 'RESOLVED')),
    CONSTRAINT chk_breakdown_dates CHECK (resolved_on IS NULL OR resolved_on >= reported_on),
    CONSTRAINT chk_breakdown_resolved CHECK ((status = 'RESOLVED') = (resolved_on IS NOT NULL)),
    UNIQUE (breakdown_id, equipment_id)
);

-- 11. MAINTENANCE_JOB TABLE (traceable: dates, status, vendor, related breakdown)
CREATE TABLE MaintenanceJob (
    maintenance_id INTEGER PRIMARY KEY,
    equipment_id INTEGER NOT NULL REFERENCES Equipment(equipment_id) ON DELETE CASCADE,
    vendor_id INTEGER NOT NULL REFERENCES Vendor(vendor_id),
    breakdown_id INTEGER,
    description VARCHAR(200) NOT NULL,
    start_date DATE NOT NULL,
    completion_date DATE,
    status VARCHAR(12) NOT NULL DEFAULT 'SCHEDULED'
        CHECK (status IN ('SCHEDULED', 'IN_PROGRESS', 'COMPLETED')),
    cost NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (cost >= 0),
    CONSTRAINT chk_maintenance_dates CHECK (completion_date IS NULL OR completion_date >= start_date),
    CONSTRAINT chk_maintenance_completed CHECK ((status = 'COMPLETED') = (completion_date IS NOT NULL)),
    -- a linked breakdown must belong to the same equipment (ignored when breakdown_id is NULL)
    FOREIGN KEY (breakdown_id, equipment_id) REFERENCES Breakdown(breakdown_id, equipment_id)
);

-- ============================================================================
-- 4. STOCK CONTROL
-- ============================================================================

-- 12. CONSUMABLE TABLE (stock can never go below zero)
CREATE TABLE Consumable (
    consumable_id INTEGER PRIMARY KEY,
    equipment_id INTEGER NOT NULL REFERENCES Equipment(equipment_id) ON DELETE CASCADE,
    item_name VARCHAR(100) NOT NULL,
    unit VARCHAR(15) NOT NULL,
    stock_quantity INTEGER NOT NULL CHECK (stock_quantity >= 0),
    reorder_level INTEGER NOT NULL CHECK (reorder_level >= 0),
    UNIQUE (equipment_id, item_name)
);

-- ============================================================================
-- ADVANCED TRIGGER 1: CONFLICT-AWARE BOOKING VALIDATION
-- Sequence: equipment must be ACTIVE -> calibration must be valid on the slot
-- date -> no overlapping APPROVED booking for the same equipment.
-- Overlap condition: existing.start < requested.end AND existing.end > requested.start
-- The equipment row is locked (FOR UPDATE) so concurrent approvals are serialised.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_validate_booking()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_equip_status VARCHAR(20);
    v_slot_date    DATE;
    v_start        TIME;
    v_end          TIME;
    v_cal_due      DATE;
    v_conflicts    INTEGER;
BEGIN
    -- Only live requests are validated; history (completed/cancelled/rejected) is left alone
    IF NEW.status NOT IN ('PENDING', 'APPROVED') THEN
        RETURN NEW;
    END IF;

    -- Lock the equipment row and read its status
    SELECT status INTO v_equip_status
    FROM Equipment WHERE equipment_id = NEW.equipment_id FOR UPDATE;

    IF v_equip_status IS DISTINCT FROM 'ACTIVE' THEN
        RAISE EXCEPTION 'Booking rejected: equipment % is not ACTIVE (current status: %).',
            NEW.equipment_id, v_equip_status USING ERRCODE = 'check_violation';
    END IF;

    SELECT slot_date, start_time, end_time INTO v_slot_date, v_start, v_end
    FROM TimeSlot WHERE slot_id = NEW.slot_id;

    -- Calibration readiness: latest calibration must still be valid on the slot date
    SELECT next_due_date INTO v_cal_due
    FROM Calibration
    WHERE equipment_id = NEW.equipment_id
    ORDER BY calibration_date DESC
    LIMIT 1;

    IF v_cal_due IS NOT NULL AND v_cal_due < v_slot_date THEN
        RAISE EXCEPTION 'Booking rejected: calibration of equipment % expires on % (before slot date %).',
            NEW.equipment_id, v_cal_due, v_slot_date USING ERRCODE = 'check_violation';
    END IF;

    -- Overlap check against other APPROVED bookings of the same equipment
    IF NEW.status = 'APPROVED' THEN
        SELECT COUNT(*) INTO v_conflicts
        FROM Booking b
        JOIN TimeSlot t ON t.slot_id = b.slot_id
        WHERE b.equipment_id = NEW.equipment_id
          AND b.status = 'APPROVED'
          AND b.booking_id <> NEW.booking_id
          AND t.slot_date = v_slot_date
          AND t.start_time < v_end
          AND t.end_time > v_start;

        IF v_conflicts > 0 THEN
            RAISE EXCEPTION 'Booking rejected: equipment % already has an approved booking overlapping this time slot.',
                NEW.equipment_id USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_booking
BEFORE INSERT OR UPDATE OF equipment_id, slot_id, status ON Booking
FOR EACH ROW
EXECUTE FUNCTION fn_validate_booking();

-- ============================================================================
-- ADVANCED TRIGGER 2: A REPORTED BREAKDOWN TAKES ACTIVE EQUIPMENT OUT OF SERVICE
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_breakdown_reported()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE Equipment
    SET status = 'BROKEN'
    WHERE equipment_id = NEW.equipment_id
      AND status = 'ACTIVE';
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_breakdown_reported
AFTER INSERT ON Breakdown
FOR EACH ROW
WHEN (NEW.status <> 'RESOLVED')
EXECUTE FUNCTION fn_breakdown_reported();

-- ============================================================================
-- ADVANCED TRIGGER 3: MAINTENANCE JOB UPDATES THE EQUIPMENT LIFECYCLE RECORD
-- IN_PROGRESS -> equipment UNDER_MAINTENANCE, breakdown IN_REPAIR
-- COMPLETED   -> breakdown RESOLVED (resolved_on = completion_date) and equipment
--                back to ACTIVE when no unresolved breakdown remains
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_maintenance_lifecycle()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status = 'IN_PROGRESS' THEN
        UPDATE Equipment
        SET status = 'UNDER_MAINTENANCE'
        WHERE equipment_id = NEW.equipment_id
          AND status IN ('ACTIVE', 'BROKEN');

        UPDATE Breakdown
        SET status = 'IN_REPAIR'
        WHERE breakdown_id = NEW.breakdown_id
          AND status = 'REPORTED';

    ELSIF NEW.status = 'COMPLETED' THEN
        UPDATE Breakdown
        SET status = 'RESOLVED',
            resolved_on = NEW.completion_date
        WHERE breakdown_id = NEW.breakdown_id
          AND status <> 'RESOLVED';

        UPDATE Equipment
        SET status = 'ACTIVE'
        WHERE equipment_id = NEW.equipment_id
          AND status IN ('BROKEN', 'UNDER_MAINTENANCE')
          AND NOT EXISTS (
                SELECT 1 FROM Breakdown bd
                WHERE bd.equipment_id = NEW.equipment_id
                  AND bd.status <> 'RESOLVED'
          );
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_maintenance_lifecycle
AFTER INSERT OR UPDATE OF status ON MaintenanceJob
FOR EACH ROW
EXECUTE FUNCTION fn_maintenance_lifecycle();
