-- =====================================================================
-- Safety Equipment Compliance Analytics — Reporting Views
-- These views power the Power BI dataflows / dashboard report pages.
-- =====================================================================

-- 1. Equipment compliance status by region and industry
DROP VIEW IF EXISTS vw_ComplianceByRegion;
CREATE VIEW vw_ComplianceByRegion AS
SELECT
    c.Region,
    c.Industry,
    COUNT(e.EquipmentID)                                   AS TotalEquipment,
    SUM(CASE WHEN e.Status = 'Compliant' THEN 1 ELSE 0 END) AS CompliantCount,
    SUM(CASE WHEN e.Status = 'Overdue'   THEN 1 ELSE 0 END) AS OverdueCount,
    ROUND(100.0 * SUM(CASE WHEN e.Status = 'Compliant' THEN 1 ELSE 0 END)
          / COUNT(e.EquipmentID), 1)                        AS CompliancePct
FROM Equipment e
JOIN Sites s     ON s.SiteID = e.SiteID
JOIN Customers c ON c.CustomerID = s.CustomerID
GROUP BY c.Region, c.Industry;

-- 2. Overdue equipment detail (actionable list for field teams)
DROP VIEW IF EXISTS vw_OverdueEquipment;
CREATE VIEW vw_OverdueEquipment AS
SELECT
    e.EquipmentID,
    e.EquipmentType,
    s.SiteName,
    c.CustomerName,
    c.Region,
    e.LastInspectionDate,
    e.NextDueDate,
    CAST(julianday('2026-06-30') - julianday(e.NextDueDate) AS INTEGER) AS DaysOverdue
FROM Equipment e
JOIN Sites s     ON s.SiteID = e.SiteID
JOIN Customers c ON c.CustomerID = s.CustomerID
WHERE e.Status = 'Overdue'
ORDER BY DaysOverdue DESC;

-- 3. Technician performance (volume + quality of inspections)
DROP VIEW IF EXISTS vw_TechnicianPerformance;
CREATE VIEW vw_TechnicianPerformance AS
SELECT
    t.TechnicianID,
    t.FullName,
    t.Region,
    t.CertificationLevel,
    COUNT(i.InspectionID)                                        AS InspectionsCompleted,
    SUM(CASE WHEN i.Result = 'Fail' THEN 1 ELSE 0 END)            AS FailedInspections,
    SUM(i.DeficienciesFound)                                      AS TotalDeficienciesFound,
    ROUND(1.0 * SUM(i.DeficienciesFound) / COUNT(i.InspectionID), 2) AS AvgDeficienciesPerInspection
FROM Inspections i
JOIN Technicians t ON t.TechnicianID = i.TechnicianID
GROUP BY t.TechnicianID, t.FullName, t.Region, t.CertificationLevel
ORDER BY InspectionsCompleted DESC;

-- 4. Incident trends by industry and severity
DROP VIEW IF EXISTS vw_IncidentTrends;
CREATE VIEW vw_IncidentTrends AS
SELECT
    strftime('%Y-%m', inc.IncidentDate) AS IncidentMonth,
    c.Industry,
    inc.Severity,
    COUNT(*) AS IncidentCount
FROM Incidents inc
JOIN Sites s     ON s.SiteID = inc.SiteID
JOIN Customers c ON c.CustomerID = s.CustomerID
GROUP BY IncidentMonth, c.Industry, inc.Severity;

-- 5. Customer risk score — combines overdue equipment rate, deficiency rate,
--    and recent incidents into a single 0-100 score for account prioritization
DROP VIEW IF EXISTS vw_CustomerRiskScore;
CREATE VIEW vw_CustomerRiskScore AS
WITH equip_stats AS (
    SELECT s.CustomerID,
           COUNT(e.EquipmentID) AS TotalEquipment,
           SUM(CASE WHEN e.Status = 'Overdue' THEN 1 ELSE 0 END) AS OverdueEquipment
    FROM Equipment e
    JOIN Sites s ON s.SiteID = e.SiteID
    GROUP BY s.CustomerID
),
incident_stats AS (
    SELECT s.CustomerID, COUNT(*) AS IncidentCount
    FROM Incidents inc
    JOIN Sites s ON s.SiteID = inc.SiteID
    GROUP BY s.CustomerID
)
SELECT
    c.CustomerID,
    c.CustomerName,
    c.Region,
    c.Industry,
    COALESCE(es.OverdueEquipment, 0)                       AS OverdueEquipment,
    COALESCE(es.TotalEquipment, 0)                         AS TotalEquipment,
    COALESCE(ist.IncidentCount, 0)                         AS IncidentCount,
    ROUND(
        (100.0 * COALESCE(es.OverdueEquipment, 0) / NULLIF(es.TotalEquipment, 0)) * 0.6
        + (COALESCE(ist.IncidentCount, 0) * 5.0) * 0.4
    , 1) AS RiskScore
FROM Customers c
LEFT JOIN equip_stats es    ON es.CustomerID = c.CustomerID
LEFT JOIN incident_stats ist ON ist.CustomerID = c.CustomerID
WHERE c.CustomerName != ''
ORDER BY RiskScore DESC;

-- 6. Training coverage and effectiveness by customer
DROP VIEW IF EXISTS vw_TrainingSummary;
CREATE VIEW vw_TrainingSummary AS
SELECT
    c.CustomerName,
    c.Industry,
    COUNT(ts.SessionID)            AS SessionsDelivered,
    SUM(ts.AttendeeCount)          AS TotalAttendees,
    ROUND(AVG(ts.PassRate) * 100, 1) AS AvgPassRatePct
FROM TrainingSessions ts
JOIN Customers c ON c.CustomerID = ts.CustomerID
GROUP BY c.CustomerName, c.Industry;
