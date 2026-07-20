-- =====================================================================
-- Safety Equipment Compliance & Risk Analytics — SQL Server schema
-- Run this first in SSMS / Azure Data Studio against a new database,
-- e.g.:  CREATE DATABASE SafetyAnalytics;  GO  USE SafetyAnalytics;  GO
-- =====================================================================

IF OBJECT_ID('dbo.Incidents', 'U') IS NOT NULL DROP TABLE dbo.Incidents;
IF OBJECT_ID('dbo.Inspections', 'U') IS NOT NULL DROP TABLE dbo.Inspections;
IF OBJECT_ID('dbo.Equipment', 'U') IS NOT NULL DROP TABLE dbo.Equipment;
IF OBJECT_ID('dbo.Sites', 'U') IS NOT NULL DROP TABLE dbo.Sites;
IF OBJECT_ID('dbo.TrainingSessions', 'U') IS NOT NULL DROP TABLE dbo.TrainingSessions;
IF OBJECT_ID('dbo.Customers', 'U') IS NOT NULL DROP TABLE dbo.Customers;
IF OBJECT_ID('dbo.Technicians', 'U') IS NOT NULL DROP TABLE dbo.Technicians;
GO

CREATE TABLE dbo.Technicians (
    TechnicianID        INT IDENTITY(1,1) PRIMARY KEY,
    FullName             NVARCHAR(100) NOT NULL,
    Region               NVARCHAR(50)  NOT NULL,
    CertificationLevel   NVARCHAR(30)  NOT NULL,
    HireDate             DATE          NOT NULL
);
GO

CREATE TABLE dbo.Customers (
    CustomerID     INT IDENTITY(1,1) PRIMARY KEY,
    CustomerName   NVARCHAR(150) NOT NULL,
    Industry       NVARCHAR(50)  NOT NULL,
    Region         NVARCHAR(50)  NOT NULL,
    ContractType   NVARCHAR(30)  NOT NULL
);
GO

CREATE TABLE dbo.Sites (
    SiteID       INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID   INT NOT NULL,
    SiteName     NVARCHAR(200) NOT NULL,
    Province     NVARCHAR(50)  NOT NULL,
    CONSTRAINT FK_Sites_Customers FOREIGN KEY (CustomerID)
        REFERENCES dbo.Customers(CustomerID)
);
GO

CREATE TABLE dbo.Equipment (
    EquipmentID          INT IDENTITY(1,1) PRIMARY KEY,
    SiteID               INT NOT NULL,
    EquipmentType        NVARCHAR(50) NOT NULL,
    InstallDate          DATE NOT NULL,
    LastInspectionDate   DATE NULL,
    NextDueDate          DATE NOT NULL,
    Status               NVARCHAR(20) NOT NULL,
    CONSTRAINT FK_Equipment_Sites FOREIGN KEY (SiteID)
        REFERENCES dbo.Sites(SiteID)
);
GO

CREATE TABLE dbo.Inspections (
    InspectionID          INT IDENTITY(1,1) PRIMARY KEY,
    EquipmentID           INT NOT NULL,
    TechnicianID          INT NOT NULL,
    InspectionDate        DATE NOT NULL,
    Result                NVARCHAR(30) NOT NULL,
    DeficienciesFound     INT NOT NULL DEFAULT 0,
    Notes                 NVARCHAR(500) NULL,
    CONSTRAINT FK_Inspections_Equipment FOREIGN KEY (EquipmentID)
        REFERENCES dbo.Equipment(EquipmentID),
    CONSTRAINT FK_Inspections_Technicians FOREIGN KEY (TechnicianID)
        REFERENCES dbo.Technicians(TechnicianID)
);
GO

CREATE TABLE dbo.Incidents (
    IncidentID      INT IDENTITY(1,1) PRIMARY KEY,
    SiteID          INT NOT NULL,
    IncidentDate    DATE NOT NULL,
    IncidentType    NVARCHAR(50) NOT NULL,
    Severity        NVARCHAR(20) NOT NULL,
    RootCause       NVARCHAR(300) NULL,
    CONSTRAINT FK_Incidents_Sites FOREIGN KEY (SiteID)
        REFERENCES dbo.Sites(SiteID)
);
GO

CREATE TABLE dbo.TrainingSessions (
    SessionID       INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID      INT NOT NULL,
    TrainingType    NVARCHAR(50) NOT NULL,
    SessionDate     DATE NOT NULL,
    AttendeeCount   INT NOT NULL,
    PassRate        DECIMAL(4,3) NOT NULL,
    CONSTRAINT FK_Training_Customers FOREIGN KEY (CustomerID)
        REFERENCES dbo.Customers(CustomerID)
);
GO

-- Helpful indexes on foreign key / join columns (good talking point on
-- query optimization if asked)
CREATE INDEX IX_Sites_CustomerID ON dbo.Sites(CustomerID);
CREATE INDEX IX_Equipment_SiteID ON dbo.Equipment(SiteID);
CREATE INDEX IX_Inspections_EquipmentID ON dbo.Inspections(EquipmentID);
CREATE INDEX IX_Inspections_TechnicianID ON dbo.Inspections(TechnicianID);
CREATE INDEX IX_Incidents_SiteID ON dbo.Incidents(SiteID);
CREATE INDEX IX_Training_CustomerID ON dbo.TrainingSessions(CustomerID);
GO
