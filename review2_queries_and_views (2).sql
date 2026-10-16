-- ============================================================================
-- DBMS PROJECT: LABORATORY EQUIPMENT BOOKING & MAINTENANCE SYSTEM
-- REVIEW 2: SAMPLE DATA POPULATION, 6 ANALYTICAL QUERIES / VIEWS & TEST CASES
-- Target: PostgreSQL 15+  (run the Review 2 DDL script first)
-- ============================================================================

-- ============================================================================
-- 1. POPULATE SAMPLE DATA (all people, vendors and equipment are fictional)
-- Insert order matters: bookings are validated by trg_validate_booking, and the
-- breakdown / maintenance triggers then move equipment status along its lifecycle.
-- ============================================================================

BEGIN;

INSERT INTO Laboratory (laboratory_id, name, location) VALUES
(1, 'Physics Laboratory',     'Science Block, Floor 1'),
(2, 'Chemistry Laboratory',   'Science Block, Floor 2'),
(3, 'Electronics Laboratory', 'Engineering Block, Floor 3');

INSERT INTO EquipmentCategory (category_id, name, description) VALUES
(1, 'Measurement',     'Balances, meters and precision measuring instruments'),
(2, 'Optical',         'Microscopes and optical inspection instruments'),
(3, 'Analytical',      'Spectroscopy and sample analysis instruments'),
(4, 'Electronic Test', 'Oscilloscopes, generators and signal test equipment');

INSERT INTO Vendor (vendor_id, name, phone, email) VALUES
(1, 'Sigma Scientific Services',    '9811000101', 'support@sigmascientific.example.com'),
(2, 'Precision Calibration Pvt Ltd','9811000102', 'service@precisioncal.example.com'),
(3, 'Orbit Instrument Care',        '9811000103', 'help@orbitcare.example.com');

INSERT INTO AppUser (user_id, name, email, role) VALUES
(1, 'Dr. Anita Rao',     'anita.rao@lab.example.edu',     'LAB_STAFF'),
(2, 'Rohan Mehta',       'rohan.mehta@lab.example.edu',   'STUDENT'),
(3, 'Sneha Kulkarni',    'sneha.kulkarni@lab.example.edu','STUDENT'),
(4, 'Arjun Nair',        'arjun.nair@lab.example.edu',    'STUDENT'),
(5, 'Prof. Kiran Desai', 'kiran.desai@lab.example.edu',   'ADMIN');

-- Equipment 4 and 5 start ACTIVE; the breakdown/maintenance triggers change their status below
INSERT INTO Equipment (equipment_id, laboratory_id, category_id, name, serial_no, purchase_date, status) VALUES
(1, 3, 4, 'Digital Oscilloscope', 'OSC-2023-0101', '2023-06-12', 'ACTIVE'),
(2, 2, 3, 'UV-Vis Spectrophotometer', 'SPC-2022-0207', '2022-11-03', 'ACTIVE'),
(3, 2, 1, 'Analytical Balance', 'BAL-2024-0310', '2024-02-19', 'ACTIVE'),
(4, 1, 2, 'Optical Microscope', 'MIC-2021-0412', '2021-08-25', 'ACTIVE'),
(5, 2, 1, 'Bench pH Meter', 'PHM-2022-0518', '2022-04-14', 'ACTIVE'),
(6, 2, 3, 'Hot Air Oven (old unit)', 'OVN-2015-0621', '2015-01-30', 'RETIRED');

-- Calibration history (equipment 1 has two records; the latest one counts)
INSERT INTO Calibration (calibration_id, equipment_id, calibration_date, next_due_date, performed_by) VALUES
(1, 1, '2025-04-10', '2026-04-10', 'Precision Calibration Pvt Ltd'),
(2, 1, '2026-04-10', '2027-04-10', 'Precision Calibration Pvt Ltd'),
(3, 2, '2026-05-01', '2026-11-01', 'Sigma Scientific Services'),
(4, 3, '2026-08-20', '2027-02-20', 'Precision Calibration Pvt Ltd'),
(5, 4, '2026-02-10', '2026-08-10', 'Orbit Instrument Care'),
(6, 5, '2026-01-15', '2026-07-15', 'Precision Calibration Pvt Ltd');

-- Time slots
INSERT INTO TimeSlot (slot_id, slot_date, start_time, end_time) VALUES
(1, '2026-10-20', '09:00', '11:00'),
(2, '2026-10-20', '10:00', '12:00'),   -- overlaps slot 1
(3, '2026-10-20', '11:00', '13:00'),   -- touches slot 1 at 11:00 (no overlap)
(4, '2026-10-21', '14:00', '16:00'),
(5, '2026-10-14', '09:00', '12:00'),
(6, '2026-10-15', '10:00', '12:00'),
(7, '2026-10-12', '13:00', '15:00'),
(8, '2026-10-22', '09:00', '11:00'),
(9, '2026-10-20', '14:00', '16:00');

-- Bookings (history first, then upcoming; every PENDING/APPROVED row passes the trigger)
INSERT INTO Booking (booking_id, user_id, equipment_id, slot_id, status, requested_on, purpose) VALUES
(1,  2, 1, 5, 'COMPLETED', '2026-10-10 10:15', 'Waveform analysis for signals lab'),
(2,  3, 2, 6, 'COMPLETED', '2026-10-11 09:30', 'Absorbance measurement of dye samples'),
(3,  4, 3, 7, 'COMPLETED', '2026-10-08 16:45', 'Mass measurement for titration practical'),
(8,  2, 4, 7, 'COMPLETED', '2026-10-09 11:00', 'Slide observation for physics practical'),
(9,  4, 2, 6, 'CANCELLED', '2026-10-12 08:20', 'Duplicate request for the same slot'),
(10, 2, 5, 7, 'REJECTED',  '2026-10-09 12:10', 'Buffer pH check (calibration had expired)'),
(4,  2, 1, 1, 'APPROVED',  '2026-10-14 09:00', 'Filter circuit measurements'),
(5,  3, 2, 2, 'APPROVED',  '2026-10-14 09:40', 'Kinetics study using UV-Vis'),
(6,  4, 1, 3, 'APPROVED',  '2026-10-15 10:05', 'Signal generator output testing'),
(7,  3, 3, 4, 'PENDING',   '2026-10-15 14:25', 'Precision weighing for sample preparation'),
(11, 3, 1, 8, 'APPROVED',  '2026-10-15 15:00', 'Project demo capture');

-- Usage logs (hours_used is logged against completed sessions)
INSERT INTO UsageLog (usage_log_id, booking_id, usage_date, hours_used, details) VALUES
(1, 1, '2026-10-14', 2.50, 'Captured and saved waveforms for three circuits'),
(2, 2, '2026-10-15', 1.50, 'Measured absorbance of five dye dilutions'),
(3, 3, '2026-10-12', 2.00, 'Weighed samples for titration batch'),
(4, 8, '2026-10-12', 1.00, 'Observed prepared slides, stage began to jam');

-- Breakdowns (open breakdowns set the equipment status to BROKEN via trigger)
INSERT INTO Breakdown (breakdown_id, equipment_id, reported_on, resolved_on, description, status) VALUES
(1, 1, '2026-08-03', '2026-08-07', 'Display flicker caused by power board fault',        'RESOLVED'),
(2, 4, '2026-10-05', NULL,         'Illumination lamp failure and stage jam',            'REPORTED'),
(3, 3, '2026-09-12', '2026-09-14', 'Drifting readings from the load cell',               'RESOLVED'),
(4, 5, '2026-10-10', NULL,         'Electrode response very slow, readings unstable',    'REPORTED');

-- Maintenance jobs (status changes update Equipment and Breakdown via trigger)
INSERT INTO MaintenanceJob (maintenance_id, equipment_id, vendor_id, breakdown_id, description, start_date, completion_date, status, cost) VALUES
(1, 1, 1, 1,    'Power board replacement',                  '2026-08-04', '2026-08-07', 'COMPLETED',   4200.00),
(2, 3, 2, 3,    'Load cell recalibration and cleaning',     '2026-09-13', '2026-09-14', 'COMPLETED',   2500.00),
(3, 4, 3, 2,    'Lamp replacement and stage mechanism repair','2026-10-07', NULL,       'IN_PROGRESS',     0.00),
(4, 2, 2, NULL, 'Annual preventive maintenance',            '2026-11-02', NULL,         'SCHEDULED',       0.00);

-- Consumables
INSERT INTO Consumable (consumable_id, equipment_id, item_name, unit, stock_quantity, reorder_level) VALUES
(1, 2, 'Quartz cuvettes',              'pcs',     12, 10),
(2, 2, 'Reference standard solution',  'bottles',  3,  5),
(3, 3, 'Weighing paper',               'sheets',   0, 50),
(4, 5, 'pH 7 buffer solution',         'bottles',  4,  6),
(5, 1, 'Probe tips',                   'pcs',     20,  8),
(6, 4, 'Lens cleaning tissue',         'sheets',  40, 25);

COMMIT;


-- ============================================================================
-- 2. THE 6 ANALYTICAL QUERIES & VIEWS FOR REVIEW 2
-- ============================================================================

-- ----------------------------------------------------------------------------
-- REPORT 1: AVAILABILITY REPORT (ACTIVE EQUIPMENT x TIME SLOTS ON A DATE)
-- Demonstrates: MULTI-TABLE JOIN, LATERAL SUBQUERY, CASE, CORRELATED EXISTS
-- (BOOKED = overlaps an approved booking; NOT READY = calibration expires before the slot)
-- ----------------------------------------------------------------------------
SELECT
    e.equipment_id,
    e.name AS equipment_name,
    l.name AS laboratory,
    t.slot_date,
    t.start_time,
    t.end_time,
    CASE
        WHEN cal.next_due < t.slot_date THEN 'NOT READY - CALIBRATION OVERDUE'
        WHEN EXISTS (
                SELECT 1
                FROM Booking b
                JOIN TimeSlot bt ON bt.slot_id = b.slot_id
                WHERE b.equipment_id = e.equipment_id
                  AND b.status = 'APPROVED'
                  AND bt.slot_date = t.slot_date
                  AND bt.start_time < t.end_time
                  AND bt.end_time > t.start_time
             ) THEN 'BOOKED'
        ELSE 'FREE'
    END AS availability
FROM Equipment e
JOIN Laboratory l ON l.laboratory_id = e.laboratory_id
CROSS JOIN TimeSlot t
LEFT JOIN LATERAL (
        SELECT c.next_due_date AS next_due
        FROM Calibration c
        WHERE c.equipment_id = e.equipment_id
        ORDER BY c.calibration_date DESC
        LIMIT 1
     ) cal ON TRUE
WHERE e.status = 'ACTIVE'
  AND t.slot_date = DATE '2026-10-20'
ORDER BY e.equipment_id, t.start_time;


-- ----------------------------------------------------------------------------
-- REPORT 2: UTILIZATION REPORT (BOOKED HOURS vs AVAILABLE HOURS)
-- Demonstrates: CREATE VIEW, CTE, LEFT JOIN, GROUP BY, SUM, COALESCE, ROUND
-- Window: 12 Oct - 22 Oct 2026, weekdays only, 8 working hours per day
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_EquipmentUtilization AS
WITH win AS (
    SELECT DATE '2026-10-12' AS d_from, DATE '2026-10-23' AS d_to   -- d_to is exclusive
),
work AS (
    SELECT COUNT(*) AS working_days
    FROM win, generate_series(win.d_from, win.d_to - 1, INTERVAL '1 day') AS g(d)
    WHERE EXTRACT(ISODOW FROM g.d) < 6
)
SELECT
    e.equipment_id,
    e.name AS equipment_name,
    c.name AS category,
    l.name AS laboratory,
    COALESCE(SUM(EXTRACT(EPOCH FROM (t.end_time - t.start_time)) / 3600.0), 0) AS booked_hours,
    work.working_days * 8 AS available_hours,
    ROUND(100.0 * COALESCE(SUM(EXTRACT(EPOCH FROM (t.end_time - t.start_time)) / 3600.0), 0)
          / (work.working_days * 8), 2) AS utilization_pct
FROM Equipment e
JOIN EquipmentCategory c ON c.category_id = e.category_id
JOIN Laboratory l ON l.laboratory_id = e.laboratory_id
CROSS JOIN win
CROSS JOIN work
LEFT JOIN Booking b
       ON b.equipment_id = e.equipment_id
      AND b.status IN ('APPROVED', 'COMPLETED')
LEFT JOIN TimeSlot t
       ON t.slot_id = b.slot_id
      AND t.slot_date >= win.d_from
      AND t.slot_date <  win.d_to
WHERE e.status <> 'RETIRED'
GROUP BY e.equipment_id, e.name, c.name, l.name, work.working_days;

-- Test View: utilization per equipment, busiest first
SELECT * FROM vw_EquipmentUtilization ORDER BY utilization_pct DESC, equipment_id;

-- Category-level roll-up from the view
SELECT
    category,
    COUNT(*) AS equipment_count,
    SUM(booked_hours) AS booked_hours,
    SUM(available_hours) AS available_hours,
    ROUND(100.0 * SUM(booked_hours) / SUM(available_hours), 2) AS utilization_pct
FROM vw_EquipmentUtilization
GROUP BY category
ORDER BY utilization_pct DESC;


-- ----------------------------------------------------------------------------
-- REPORT 3: CALIBRATION DUE VIEW
-- Demonstrates: CREATE VIEW, CORRELATED MAX SUBQUERY, CASE, DATE ARITHMETIC
-- (latest calibration per equipment; OVERDUE, DUE SOON within 30 days, or OK)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_CalibrationDue AS
SELECT
    e.equipment_id,
    e.name AS equipment_name,
    e.status AS equipment_status,
    l.name AS laboratory,
    c.calibration_date AS last_calibrated,
    c.next_due_date,
    c.next_due_date - CURRENT_DATE AS days_to_due,
    CASE
        WHEN c.next_due_date < CURRENT_DATE THEN 'OVERDUE'
        WHEN c.next_due_date <= CURRENT_DATE + 30 THEN 'DUE SOON'
        ELSE 'OK'
    END AS calibration_status
FROM Equipment e
JOIN Laboratory l ON l.laboratory_id = e.laboratory_id
JOIN Calibration c ON c.equipment_id = e.equipment_id
WHERE e.status <> 'RETIRED'
  AND c.calibration_date = (
        SELECT MAX(c2.calibration_date)
        FROM Calibration c2
        WHERE c2.equipment_id = e.equipment_id
  );

-- Test View: equipment needing attention, most urgent first
SELECT * FROM vw_CalibrationDue WHERE calibration_status <> 'OK' ORDER BY days_to_due;


-- ----------------------------------------------------------------------------
-- REPORT 4: DOWNTIME REPORT
-- Demonstrates: MULTI-TABLE LEFT JOIN, COALESCE, DATE ARITHMETIC, SUBQUERY IN FROM,
--               GROUP BY, COUNT ... FILTER, SUM, CREATE VIEW
-- ----------------------------------------------------------------------------

-- 4a. Breakdown detail with maintenance completion (open breakdowns count up to today)
SELECT
    bd.breakdown_id,
    e.name AS equipment_name,
    bd.reported_on,
    bd.resolved_on,
    COALESCE(bd.resolved_on, CURRENT_DATE) - bd.reported_on AS downtime_days,
    bd.status AS breakdown_status,
    v.name AS vendor_name,
    mj.status AS maintenance_status,
    COALESCE(mj.cost, 0) AS maintenance_cost
FROM Breakdown bd
JOIN Equipment e ON e.equipment_id = bd.equipment_id
LEFT JOIN MaintenanceJob mj ON mj.breakdown_id = bd.breakdown_id
LEFT JOIN Vendor v ON v.vendor_id = mj.vendor_id
ORDER BY downtime_days DESC, bd.breakdown_id;

-- 4b. Per-equipment downtime summary view
CREATE OR REPLACE VIEW vw_DowntimeSummary AS
SELECT
    e.equipment_id,
    e.name AS equipment_name,
    e.status AS equipment_status,
    d.breakdown_count,
    d.total_downtime_days,
    d.open_breakdowns
FROM Equipment e
JOIN (
        SELECT
            equipment_id,
            COUNT(*) AS breakdown_count,
            SUM(COALESCE(resolved_on, CURRENT_DATE) - reported_on) AS total_downtime_days,
            COUNT(*) FILTER (WHERE status <> 'RESOLVED') AS open_breakdowns
        FROM Breakdown
        GROUP BY equipment_id
     ) d ON d.equipment_id = e.equipment_id;

-- Test View: most downtime first
SELECT * FROM vw_DowntimeSummary ORDER BY total_downtime_days DESC;


-- ----------------------------------------------------------------------------
-- REPORT 5: CONSUMABLE STOCK VIEW (LOW-STOCK FLAGS)
-- Demonstrates: CREATE VIEW, MULTI-TABLE JOIN, CASE, ARITHMETIC EXPRESSIONS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_LowStock AS
SELECT
    cs.consumable_id,
    cs.item_name,
    e.name AS equipment_name,
    l.name AS laboratory,
    cs.unit,
    cs.stock_quantity,
    cs.reorder_level,
    GREATEST(cs.reorder_level - cs.stock_quantity, 0) AS shortfall,
    CASE
        WHEN cs.stock_quantity = 0 THEN 'OUT OF STOCK'
        WHEN cs.stock_quantity < cs.reorder_level THEN 'LOW STOCK'
        ELSE 'OK'
    END AS stock_status
FROM Consumable cs
JOIN Equipment e ON e.equipment_id = cs.equipment_id
JOIN Laboratory l ON l.laboratory_id = e.laboratory_id;

-- Test View: items needing replenishment, largest shortfall first
SELECT * FROM vw_LowStock WHERE stock_status <> 'OK' ORDER BY shortfall DESC, item_name;


-- ----------------------------------------------------------------------------
-- REPORT 6: BOOKING AUDIT VIEW
-- Demonstrates: SIX-TABLE JOIN, SUBQUERY IN FROM (usage totals), LEFT JOIN, COALESCE
-- (requester, equipment, booking status and usage log traced together)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_BookingAudit AS
SELECT
    b.booking_id,
    u.name AS requester,
    u.role AS requester_role,
    e.name AS equipment_name,
    l.name AS laboratory,
    t.slot_date,
    t.start_time,
    t.end_time,
    b.status AS booking_status,
    COALESCE(ul.log_entries, 0) AS usage_entries,
    COALESCE(ul.total_hours, 0) AS hours_logged
FROM Booking b
JOIN AppUser u ON u.user_id = b.user_id
JOIN Equipment e ON e.equipment_id = b.equipment_id
JOIN Laboratory l ON l.laboratory_id = e.laboratory_id
JOIN TimeSlot t ON t.slot_id = b.slot_id
LEFT JOIN (
        SELECT booking_id, COUNT(*) AS log_entries, SUM(hours_used) AS total_hours
        FROM UsageLog
        GROUP BY booking_id
     ) ul ON ul.booking_id = b.booking_id;

-- Test View: full audit trail in chronological order
SELECT * FROM vw_BookingAudit ORDER BY slot_date, start_time, booking_id;


-- ============================================================================
-- 3. TEST CASES TO DEMONSTRATE (each prints PASSED when the rule rejects the change)
-- ============================================================================

-- TEST 1: Overlapping booking is rejected (equipment 1 already approved 09:00-11:00 on 20 Oct)
DO $$
BEGIN
    INSERT INTO Booking (booking_id, user_id, equipment_id, slot_id, status, purpose)
    VALUES (101, 3, 1, 2, 'APPROVED', 'Overlap test');
    RAISE EXCEPTION 'TEST 1 FAILED: overlapping booking was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'TEST 1 PASSED: %', SQLERRM;
END $$;

-- TEST 2: Inactive equipment cannot be booked (equipment 6 is RETIRED)
DO $$
BEGIN
    INSERT INTO Booking (booking_id, user_id, equipment_id, slot_id, status, purpose)
    VALUES (102, 2, 6, 9, 'PENDING', 'Inactive equipment test');
    RAISE EXCEPTION 'TEST 2 FAILED: booking for inactive equipment was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'TEST 2 PASSED: %', SQLERRM;
END $$;

-- TEST 3: Invalid calibration dates are rejected (next due before calibration date)
DO $$
BEGIN
    INSERT INTO Calibration (calibration_id, equipment_id, calibration_date, next_due_date, performed_by)
    VALUES (99, 1, DATE '2026-10-01', DATE '2026-09-01', 'Date validation test');
    RAISE EXCEPTION 'TEST 3 FAILED: invalid calibration dates were accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'TEST 3 PASSED: %', SQLERRM;
END $$;

-- TEST 4: Stock cannot fall below zero (only 3 bottles of reference solution in stock)
DO $$
BEGIN
    UPDATE Consumable SET stock_quantity = stock_quantity - 10 WHERE consumable_id = 2;
    RAISE EXCEPTION 'TEST 4 FAILED: negative stock was accepted';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'TEST 4 PASSED: %', SQLERRM;
END $$;

-- TEST 5: Completed maintenance updates the lifecycle record
-- (equipment 4 and breakdown 2 move to ACTIVE / RESOLVED; rolled back so sample data stays intact)
BEGIN;
SELECT e.status AS equipment_status_before, bd.status AS breakdown_status_before
FROM Equipment e JOIN Breakdown bd ON bd.equipment_id = e.equipment_id
WHERE e.equipment_id = 4;

UPDATE MaintenanceJob
SET status = 'COMPLETED', completion_date = DATE '2026-10-16', cost = 3500.00
WHERE maintenance_id = 3;

SELECT e.status AS equipment_status_after, bd.status AS breakdown_status_after, bd.resolved_on
FROM Equipment e JOIN Breakdown bd ON bd.equipment_id = e.equipment_id
WHERE e.equipment_id = 4;
ROLLBACK;
