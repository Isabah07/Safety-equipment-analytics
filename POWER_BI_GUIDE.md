# Power BI Build Guide

This project is designed so the SQL layer (done) plugs directly into Power BI
Dataflows and a report. Follow these steps in Power BI Desktop to complete
the build.

## 1. Load data as a Dataflow

In Power BI Service (or Desktop's Power Query Editor):

1. Create a new Dataflow → **Get data** → **Text/CSV** (or connect directly
   to `safety_analytics.db` via an ODBC/SQLite connector if available).
2. Import each file from `csv_export/`: `Customers`, `Sites`, `Equipment`,
   `Inspections`, `Technicians`, `Incidents`, `TrainingSessions`.
3. Apply these Power Query (M) transformations per table — example for
   `Equipment`:

```m
let
    Source = Csv.Document(File.Contents("Equipment.csv"),[Delimiter=",", Columns=7, Encoding=65001, QuoteStyle=QuoteStyle.None]),
    PromotedHeaders = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),
    TypedColumns = Table.TransformColumnTypes(PromotedHeaders,{
        {"EquipmentID", Int64.Type}, {"SiteID", Int64.Type},
        {"EquipmentType", type text}, {"InstallDate", type date},
        {"LastInspectionDate", type date}, {"NextDueDate", type date},
        {"Status", type text}}),
    AddDaysOverdue = Table.AddColumn(TypedColumns, "DaysOverdue",
        each if [Status] = "Overdue" then Duration.Days(Date.From(DateTime.LocalNow()) - [NextDueDate]) else 0, Int64.Type)
in
    AddDaysOverdue
```

4. Load the six reporting **views** (`vw_ComplianceByRegion`,
   `vw_OverdueEquipment`, `vw_TechnicianPerformance`, `vw_IncidentTrends`,
   `vw_CustomerRiskScore`, `vw_TrainingSummary`) either as pre-aggregated
   dataflow entities (recommended for performance) or recreate their logic
   as Power Query steps on the raw tables.

## 2. Model relationships

Build a star schema in the Power BI model view:

```
Customers (1) ─── (∞) Sites (1) ─── (∞) Equipment (1) ─── (∞) Inspections
                              └────── (∞) Incidents
Customers (1) ─── (∞) TrainingSessions
Technicians (1) ─── (∞) Inspections
```

## 3. Key DAX measures

```dax
Compliance Rate % =
DIVIDE(
    CALCULATE(COUNTROWS(Equipment), Equipment[Status] = "Compliant"),
    COUNTROWS(Equipment)
)

Overdue Equipment Count =
CALCULATE(COUNTROWS(Equipment), Equipment[Status] = "Overdue")

Avg Deficiencies per Inspection =
DIVIDE(SUM(Inspections[DeficienciesFound]), COUNTROWS(Inspections))

Incident Rate per 100 Sites =
DIVIDE(COUNTROWS(Incidents), DISTINCTCOUNT(Sites[SiteID])) * 100

Customer Risk Score =
VAR OverdueRatio = DIVIDE([Overdue Equipment Count], COUNTROWS(Equipment))
VAR IncidentPenalty = COUNTROWS(Incidents) * 5
RETURN (OverdueRatio * 100 * 0.6) + (IncidentPenalty * 0.4)
```

## 4. Report pages

- **Compliance Overview** — KPI cards (compliance %, overdue count),
  stacked bar of compliant vs. overdue by region, slicer by industry.
- **Technician Performance** — bar chart of inspections completed,
  line overlay of average deficiencies found, table with drill-through
  to individual inspection records.
- **Incident & Risk** — trend line of incidents by month/severity,
  table of top-risk customer accounts sorted by `Customer Risk Score`.

## 5. Data quality gate

Before publishing, run `sql/02_data_quality_checks.sql` against the
source database (or its Power BI equivalent using Power Query's
`Table.SelectRows` filters) and confirm all checks return 0 issues,
except where intentionally flagged for review.

---
`dashboard.html` in this repo is a static prototype (Chart.js) that mirrors
what the finished Power BI report should show, useful for reviewing the
visual design before building it natively in Power BI.
