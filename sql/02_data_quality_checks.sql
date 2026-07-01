-- =====================================================================
-- Data Quality & Validation Checks
-- Run against safety_analytics.db to catch broken references, missing
-- required fields, and duplicate records before data reaches reporting.
-- =====================================================================

-- Check 1: Orphaned equipment (SiteID does not exist in Sites)
SELECT 'Orphaned Equipment (broken FK)' AS CheckName, COUNT(*) AS IssuesFound
FROM Equipment e
LEFT JOIN Sites s ON s.SiteID = e.SiteID
WHERE s.SiteID IS NULL;

-- Check 2: Customers with missing required name field
SELECT 'Customers Missing Name' AS CheckName, COUNT(*) AS IssuesFound
FROM Customers
WHERE CustomerName IS NULL OR TRIM(CustomerName) = '';

-- Check 3: Duplicate inspection records (same equipment, technician, date, result)
SELECT 'Duplicate Inspections' AS CheckName, COUNT(*) AS IssuesFound
FROM (
    SELECT EquipmentID, TechnicianID, InspectionDate, Result, COUNT(*) AS n
    FROM Inspections
    GROUP BY EquipmentID, TechnicianID, InspectionDate, Result
    HAVING COUNT(*) > 1
);

-- Check 4: Equipment with NextDueDate before InstallDate (logical inconsistency)
SELECT 'Illogical Due Dates' AS CheckName, COUNT(*) AS IssuesFound
FROM Equipment
WHERE NextDueDate < InstallDate;

-- Check 5: Inspections referencing a non-existent technician
SELECT 'Inspections With Invalid Technician' AS CheckName, COUNT(*) AS IssuesFound
FROM Inspections i
LEFT JOIN Technicians t ON t.TechnicianID = i.TechnicianID
WHERE t.TechnicianID IS NULL;
