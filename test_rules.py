"""
Rule tests for the Laboratory Equipment Booking & Maintenance System (PostgreSQL).
Needs the Review 2 DDL + sample data loaded.  Run:  pip install pytest psycopg2-binary && pytest -v
Every test runs inside a transaction that is rolled back, so the sample data is never changed.
"""
import os
import psycopg2
import psycopg2.errors as pgerr
import pytest

DSN = dict(
    host=os.environ.get("PGHOST", "localhost"),
    port=os.environ.get("PGPORT", "5432"),
    dbname=os.environ.get("PGDATABASE", "labequipment"),
    user=os.environ.get("PGUSER", "postgres"),
    password=os.environ.get("PGPASSWORD", "postgres"),
)


@pytest.fixture
def cur():
    conn = psycopg2.connect(**DSN)
    c = conn.cursor()
    yield c
    conn.rollback()
    conn.close()


def one(cur, sql, params=()):
    cur.execute(sql, params)
    return cur.fetchone()[0]


# --- Test 1: overlapping booking is rejected -------------------------------
def test_overlapping_booking_rejected(cur):
    # equipment 1 is approved 09:00-11:00 on 20 Oct (slot 1); slot 2 is 10:00-12:00
    with pytest.raises(pgerr.CheckViolation, match="overlapping"):
        cur.execute("INSERT INTO Booking (booking_id,user_id,equipment_id,slot_id,status,purpose) "
                    "VALUES (901,3,1,2,'APPROVED','overlap test')")


def test_adjacent_booking_allowed(cur):
    # slot 3 (11:00-13:00) only touches slot 1 at 11:00, so it must be accepted
    cur.execute("SAVEPOINT s")
    cur.execute("DELETE FROM Booking WHERE booking_id = 6")
    cur.execute("INSERT INTO Booking (booking_id,user_id,equipment_id,slot_id,status,purpose) "
                "VALUES (902,4,1,3,'APPROVED','adjacent test')")
    assert one(cur, "SELECT status FROM Booking WHERE booking_id = 902") == "APPROVED"


# --- Test 2: inactive equipment cannot be booked -----------------------------
@pytest.mark.parametrize("equipment_id", [4, 5, 6])   # UNDER_MAINTENANCE, BROKEN, RETIRED
def test_inactive_equipment_rejected(cur, equipment_id):
    with pytest.raises(pgerr.CheckViolation, match="not ACTIVE"):
        cur.execute("INSERT INTO Booking (booking_id,user_id,equipment_id,slot_id,status,purpose) "
                    "VALUES (903,2,%s,9,'PENDING','inactive test')", (equipment_id,))


def test_expired_calibration_rejected(cur):
    # equipment 2 calibration is valid until 2026-11-01; slot on a later date must be refused
    cur.execute("INSERT INTO TimeSlot (slot_id,slot_date,start_time,end_time) VALUES (990,'2026-12-01','09:00','10:00')")
    with pytest.raises(pgerr.CheckViolation, match="calibration"):
        cur.execute("INSERT INTO Booking (booking_id,user_id,equipment_id,slot_id,status,purpose) "
                    "VALUES (904,2,2,990,'PENDING','calibration test')")


# --- Test 3: invalid calibration dates are rejected ---------------------------
def test_invalid_calibration_dates_rejected(cur):
    with pytest.raises(pgerr.CheckViolation):
        cur.execute("INSERT INTO Calibration (calibration_id,equipment_id,calibration_date,next_due_date,performed_by) "
                    "VALUES (905,1,'2026-10-01','2026-09-01','date test')")


# --- Test 4: stock cannot fall below zero -------------------------------------
def test_stock_cannot_go_negative(cur):
    with pytest.raises(pgerr.CheckViolation):
        cur.execute("UPDATE Consumable SET stock_quantity = stock_quantity - 10 WHERE consumable_id = 2")


# --- Test 5: completed maintenance updates the lifecycle record ---------------
def test_completed_maintenance_updates_lifecycle(cur):
    assert one(cur, "SELECT status FROM Equipment WHERE equipment_id = 4") == "UNDER_MAINTENANCE"
    cur.execute("UPDATE MaintenanceJob SET status='COMPLETED', completion_date='2026-10-16', cost=3500 "
                "WHERE maintenance_id = 3")
    assert one(cur, "SELECT status FROM Equipment WHERE equipment_id = 4") == "ACTIVE"
    assert one(cur, "SELECT status FROM Breakdown WHERE breakdown_id = 2") == "RESOLVED"
    assert str(one(cur, "SELECT resolved_on FROM Breakdown WHERE breakdown_id = 2")) == "2026-10-16"


def test_breakdown_marks_equipment_broken(cur):
    cur.execute("INSERT INTO Breakdown (breakdown_id,equipment_id,reported_on,description,status) "
                "VALUES (906,2,CURRENT_DATE,'trigger test','REPORTED')")
    assert one(cur, "SELECT status FROM Equipment WHERE equipment_id = 2") == "BROKEN"


# --- Reports / views ----------------------------------------------------------
def test_calibration_view_flags_overdue(cur):
    cur.execute("SELECT equipment_id FROM vw_CalibrationDue WHERE calibration_status = 'OVERDUE'")
    assert {r[0] for r in cur.fetchall()} >= {4, 5}


def test_low_stock_view(cur):
    cur.execute("SELECT item_name FROM vw_LowStock WHERE stock_status = 'OUT OF STOCK'")
    assert [r[0] for r in cur.fetchall()] == ["Weighing paper"]
