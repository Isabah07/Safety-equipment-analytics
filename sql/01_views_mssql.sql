-- =====================================================================
-- Safety Equipment Compliance Analytics — Reporting Views (T-SQL)
-- Run after 00_schema.sql and after loading data (see 03_import_guide.md)
-- =====================================================================

-- 1. Equipment compliance status by region and industry
IF OBJECT_ID('dbo.vw_ComplianceByRegion', 'V') IS NOT NULL
    DROP VIEW dbo.vw_ComplianceByRegion;
GO
CREATE VIEW dbo.vw_ComplianceByRegion AS
SELECT
    c.Region,
    c.Industry,
    COUNT(e.EquipmentID)                                     AS TotalEquipment,
    SUM(CASE WHEN e.Status = 'Compliant' THEN 1 ELSE 0 END)  AS CompliantCount,
    SUM(CASE WHEN e.Status = 'Overdue'   THEN 1 ELSE 0 END)  AS OverdueCount,
    CAST(ROUND(100.0 * SUM(CASE WHEN e.Status = 'Compliant' THEN 1 ELSE 0 END)
          / COUNT(e.EquipmentID), 1) AS DECIMAL(5,1))         AS CompliancePct
FROM dbo.Equipment e
JOIN dbo.Sites s     ON s.SiteID = e.SiteID
JOIN dbo.Customers c ON c.CustomerID = s.CustomerID
GROUP BY c.Region, c.Industry;
GO

-- 2. Overdue equipment detail (actionable list for field teams)
IF OBJECT_ID('dbo.vw_OverdueEquipment', 'V') IS NOT NULL
    DROP VIEW dbo.vw_OverdueEquipment;
GO
CREATE VIEW dbo.vw_OverdueEquipment AS
SELECT
    e.EquipmentID,
    e.EquipmentType,
    s.SiteName,
    c.CustomerName,
    c.Region,
    e.LastInspectionDate,
    e.NextDueDate,
    DATEDIFF(DAY, e.NextDueDate, GETDATE()) AS DaysOverdue
FROM dbo.Equipment e
JOIN dbo.Sites s     ON s.SiteID = e.SiteID
JOIN dbo.Customers c ON c.CustomerID = s.CustomerID
WHERE e.Status = 'Overdue';
GO
-- Usage: SELECT TOP 10 * FROM dbo.vw_OverdueEquipment ORDER BY DaysOverdue DESC;

-- 3. Technician performance (volume + quality of inspections)
IF OBJECT_ID('dbo.vw_TechnicianPerformance', 'V') IS NOT NULL
    DROP VIEW dbo.vw_TechnicianPerformance;
GO
CREATE VIEW dbo.vw_TechnicianPerformance AS
SELECT
    t.TechnicianID,
    t.FullName,
    t.Region,
    t.CertificationLevel,
    COUNT(i.InspectionID)                                          AS InspectionsCompleted,
    SUM(CASE WHEN i.Result = 'Fail' THEN 1 ELSE 0 END)             AS FailedInspections,
    SUM(i.DeficienciesFound)                                       AS TotalDeficienciesFound,
    CAST(ROUND(1.0 * SUM(i.DeficienciesFound) / COUNT(i.InspectionID), 2) AS DECIMAL(5,2))
                                                                    AS AvgDeficienciesPerInspection
FROM dbo.Inspections i
JOIN dbo.Technicians t ON t.TechnicianID = i.TechnicianID
GROUP BY t.TechnicianID, t.FullName, t.Region, t.CertificationLevel;
GO
-- Usage: SELECT TOP 10 * FROM dbo.vw_TechnicianPerformance ORDER BY InspectionsCompleted DESC;

-- 4. Incident trends by industry and severity
IF OBJECT_ID('dbo.vw_IncidentTrends', 'V') IS NOT NULL
    DROP VIEW dbo.vw_IncidentTrends;
GO
CREATE VIEW dbo.vw_IncidentTrends AS
SELECT
    FORMAT(inc.IncidentDate, 'yyyy-MM') AS IncidentMonth,
    c.Industry,
    inc.Severity,
    COUNT(*) AS IncidentCount
FROM dbo.Incidents inc
JOIN dbo.Sites s     ON s.SiteID = inc.SiteID
JOIN dbo.Customers c ON c.CustomerID = s.CustomerID
GROUP BY FORMAT(inc.IncidentDate, 'yyyy-MM'), c.Industry, inc.Severity;
GO

-- 5. Customer risk score — CTE combining overdue equipment rate,
--    deficiency rate, and recent incidents into a single 0-100 score
IF OBJECT_ID('dbo.vw_CustomerRiskScore', 'V') IS NOT NULL
    DROP VIEW dbo.vw_CustomerRiskScore;
GO
CREATE VIEW dbo.vw_CustomerRiskScore AS
WITH EquipStats AS (
    SELECT s.CustomerID,
           COUNT(e.EquipmentID) AS TotalEquipment,
           SUM(CASE WHEN e.Status = 'Overdue' THEN 1 ELSE 0 END) AS OverdueEquipment
    FROM dbo.Equipment e
    JOIN dbo.Sites s ON s.SiteID = e.SiteID
    GROUP BY s.CustomerID
),
IncidentStats AS (
    SELECT s.CustomerID, COUNT(*) AS IncidentCount
    FROM dbo.Incidents inc
    JOIN dbo.Sites s ON s.SiteID = inc.SiteID
    GROUP BY s.CustomerID
)
SELECT
    c.CustomerID,
    c.CustomerName,
    c.Region,
    c.Industry,
    ISNULL(es.OverdueEquipment, 0) AS OverdueEquipment,
    ISNULL(es.TotalEquipment, 0)   AS TotalEquipment,
    ISNULL(ist.IncidentCount, 0)   AS IncidentCount,
    CAST(ROUND(
        (100.0 * ISNULL(es.OverdueEquipment, 0) / NULLIF(es.TotalEquipment, 0)) * 0.6
        + (ISNULL(ist.IncidentCount, 0) * 5.0) * 0.4
    , 1) AS DECIMAL(6,1)) AS RiskScore
FROM dbo.Customers c
LEFT JOIN EquipStats es    ON es.CustomerID = c.CustomerID
LEFT JOIN IncidentStats ist ON ist.CustomerID = c.CustomerID
WHERE c.CustomerName <> '';
GO
-- Usage: SELECT TOP 10 * FROM dbo.vw_CustomerRiskScore ORDER BY RiskScore DESC;

-- 6. Training coverage and effectiveness by customer
IF OBJECT_ID('dbo.vw_TrainingSummary', 'V') IS NOT NULL
    DROP VIEW dbo.vw_TrainingSummary;
GO
CREATE VIEW dbo.vw_TrainingSummary AS
SELECT
    c.CustomerName,
    c.Industry,
    COUNT(ts.SessionID)              AS SessionsDelivered,
    SUM(ts.AttendeeCount)            AS TotalAttendees,
    CAST(ROUND(AVG(ts.PassRate) * 100, 1) AS DECIMAL(5,1)) AS AvgPassRatePct
FROM dbo.TrainingSessions ts
JOIN dbo.Customers c ON c.CustomerID = ts.CustomerID
GROUP BY c.CustomerName, c.Industry;
GO
