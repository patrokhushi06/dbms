-- Laboratory Equipment Booking & Maintenance System
-- MySQL 8.0+
-- Based on the DBMS PBL PDF: booking, usage, calibration, breakdown,
-- maintenance, consumables, availability and utilization reporting.

CREATE DATABASE IF NOT EXISTS LaboratoryDB;
USE LaboratoryDB;

CREATE TABLE Lab_User (
    UserID INT AUTO_INCREMENT PRIMARY KEY,
    FullName VARCHAR(120) NOT NULL,
    Email VARCHAR(150) NOT NULL UNIQUE,
    Role ENUM('Student','Faculty','Lab Technician','Admin') NOT NULL,
    Phone VARCHAR(20),
    Status ENUM('Active','Inactive') NOT NULL DEFAULT 'Active'
);

CREATE TABLE Equipment (
    EquipmentID INT AUTO_INCREMENT PRIMARY KEY,
    EquipmentName VARCHAR(150) NOT NULL,
    Category VARCHAR(100),
    SerialNumber VARCHAR(100) UNIQUE,
    Location VARCHAR(120),
    PurchaseDate DATE,
    EquipmentStatus ENUM('Active','Inactive','Under Maintenance','Out of Service')
        NOT NULL DEFAULT 'Active',
    CalibrationRequired BOOLEAN NOT NULL DEFAULT FALSE,
    LastCalibrationDate DATE,
    NextCalibrationDate DATE,
    Notes VARCHAR(255),
    CHECK (NextCalibrationDate IS NULL OR LastCalibrationDate IS NULL
           OR NextCalibrationDate >= LastCalibrationDate)
);

CREATE TABLE Booking (
    BookingID BIGINT AUTO_INCREMENT PRIMARY KEY,
    EquipmentID INT NOT NULL,
    UserID INT NOT NULL,
    StartDateTime DATETIME NOT NULL,
    EndDateTime DATETIME NOT NULL,
    Purpose VARCHAR(255) NOT NULL,
    BookingStatus ENUM('Pending','Approved','Rejected','Cancelled','Completed')
        NOT NULL DEFAULT 'Pending',
    ApprovedBy INT,
    CreatedAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (EquipmentID) REFERENCES Equipment(EquipmentID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (UserID) REFERENCES Lab_User(UserID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (ApprovedBy) REFERENCES Lab_User(UserID)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CHECK (EndDateTime > StartDateTime)
);

CREATE TABLE Equipment_Usage (
    UsageID BIGINT AUTO_INCREMENT PRIMARY KEY,
    BookingID BIGINT NOT NULL UNIQUE,
    ActualStart DATETIME,
    ActualEnd DATETIME,
    UsageNotes VARCHAR(255),
    ConditionAfterUse ENUM('Good','Needs Attention','Damaged') NOT NULL DEFAULT 'Good',
    RecordedBy INT,
    FOREIGN KEY (BookingID) REFERENCES Booking(BookingID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (RecordedBy) REFERENCES Lab_User(UserID)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CHECK (ActualEnd IS NULL OR ActualStart IS NULL OR ActualEnd >= ActualStart)
);

CREATE TABLE Calibration (
    CalibrationID BIGINT AUTO_INCREMENT PRIMARY KEY,
    EquipmentID INT NOT NULL,
    CalibrationDate DATE NOT NULL,
    DueDate DATE NOT NULL,
    PerformedBy VARCHAR(120),
    Result ENUM('Passed','Failed','Pending') NOT NULL DEFAULT 'Pending',
    CertificateNumber VARCHAR(100),
    Notes VARCHAR(255),
    FOREIGN KEY (EquipmentID) REFERENCES Equipment(EquipmentID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (DueDate >= CalibrationDate)
);

CREATE TABLE Breakdown (
    BreakdownID BIGINT AUTO_INCREMENT PRIMARY KEY,
    EquipmentID INT NOT NULL,
    ReportedBy INT,
    ReportedAt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ProblemDescription VARCHAR(255) NOT NULL,
    Severity ENUM('Low','Medium','High','Critical') NOT NULL DEFAULT 'Medium',
    Status ENUM('Open','In Progress','Resolved','Closed') NOT NULL DEFAULT 'Open',
    ResolvedAt DATETIME,
    FOREIGN KEY (EquipmentID) REFERENCES Equipment(EquipmentID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (ReportedBy) REFERENCES Lab_User(UserID)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CHECK (ResolvedAt IS NULL OR ResolvedAt >= ReportedAt)
);

CREATE TABLE Maintenance (
    MaintenanceID BIGINT AUTO_INCREMENT PRIMARY KEY,
    EquipmentID INT NOT NULL,
    BreakdownID BIGINT,
    MaintenanceType ENUM('Preventive','Corrective','Repair','Inspection','Other')
        NOT NULL DEFAULT 'Preventive',
    ScheduledDate DATE NOT NULL,
    CompletedDate DATE,
    PerformedBy VARCHAR(120),
    Cost DECIMAL(10,2) NOT NULL DEFAULT 0,
    Status ENUM('Scheduled','In Progress','Completed','Cancelled')
        NOT NULL DEFAULT 'Scheduled',
    Details VARCHAR(255),
    NextMaintenanceDate DATE,
    FOREIGN KEY (EquipmentID) REFERENCES Equipment(EquipmentID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (BreakdownID) REFERENCES Breakdown(BreakdownID)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CHECK (Cost >= 0),
    CHECK (CompletedDate IS NULL OR CompletedDate >= ScheduledDate),
    CHECK (NextMaintenanceDate IS NULL OR NextMaintenanceDate >= ScheduledDate)
);

CREATE TABLE Consumable (
    ConsumableID INT AUTO_INCREMENT PRIMARY KEY,
    ConsumableName VARCHAR(150) NOT NULL,
    Unit VARCHAR(30) NOT NULL,
    QuantityInStock DECIMAL(10,2) NOT NULL DEFAULT 0,
    ReorderLevel DECIMAL(10,2) NOT NULL DEFAULT 0,
    StorageLocation VARCHAR(120),
    Status ENUM('Available','Low Stock','Out of Stock','Inactive')
        NOT NULL DEFAULT 'Available',
    CHECK (QuantityInStock >= 0),
    CHECK (ReorderLevel >= 0)
);

CREATE TABLE Consumable_Transaction (
    TransactionID BIGINT AUTO_INCREMENT PRIMARY KEY,
    ConsumableID INT NOT NULL,
    UserID INT,
    TransactionType ENUM('Stock In','Issued','Adjustment') NOT NULL,
    Quantity DECIMAL(10,2) NOT NULL,
    TransactionDate DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Purpose VARCHAR(255),
    FOREIGN KEY (ConsumableID) REFERENCES Consumable(ConsumableID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (UserID) REFERENCES Lab_User(UserID)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CHECK (Quantity > 0)
);

-- Helpful indexes for booking availability and reports.
CREATE INDEX idx_booking_equipment_time
    ON Booking(EquipmentID, BookingStatus, StartDateTime, EndDateTime);
CREATE INDEX idx_booking_user
    ON Booking(UserID, StartDateTime);
CREATE INDEX idx_equipment_status
    ON Equipment(EquipmentStatus);
CREATE INDEX idx_calibration_due
    ON Calibration(EquipmentID, DueDate, Result);
CREATE INDEX idx_breakdown_status
    ON Breakdown(Status, ReportedAt);
CREATE INDEX idx_maintenance_status_date
    ON Maintenance(Status, ScheduledDate);
CREATE INDEX idx_consumable_stock
    ON Consumable(Status, QuantityInStock);
