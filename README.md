# Safety Equipment Compliance & Risk Analytics

An independent BI project simulating the data platform of a fire & life
safety inspection company (equipment inspections, compliance tracking,
technician performance, and incident/risk reporting) — the same kind of
reporting a Business Intelligence team supports at a safety solutions
provider like Levitt-Safety.

## What this demonstrates

- **Relational data modeling** — 7-table schema (Customers, Sites,
  Equipment, Inspections, Technicians, Incidents, TrainingSessions)
  representing a realistic field-services business.
- **SQL query & view development** — 6 optimized reporting views
  (`sql/01_views.sql`) covering compliance rates, overdue equipment,
  technician performance, incident trends, customer risk scoring, and
  training coverage.
- **Data quality validation** — a 5-check SQL validation suite
  (`sql/02_data_quality_checks.sql`) that catches broken foreign keys,
  missing required fields, duplicate records, and logical inconsistencies.
- **Power BI-ready design** — data exported to `csv_export/` for direct
  Dataflow ingestion, with a full Power Query (M) and DAX build guide in
  `POWER_BI_GUIDE.md`.
- **Dashboard prototype** — `dashboard.html`, an interactive Chart.js
  mockup of the finished report (compliance by region, incident severity,
  technician performance, top-risk accounts) for fast visual iteration
  before building the same pages natively in Power BI.

## Project structure

```
safety-analytics-project/
├── generate_data.py           # synthetic data generator (Faker + SQLite)
├── safety_analytics.db        # SQLite database (source of truth)
├── sql/
│   ├── 01_views.sql           # reporting views
│   └── 02_data_quality_checks.sql
├── csv_export/                # tables + views exported for Power BI
├── dashboard_data.json        # aggregated data feeding the prototype
├── dashboard.html             # interactive dashboard prototype
├── POWER_BI_GUIDE.md          # Power Query M + DAX build guide
└── README.md
```

## How to reproduce

```bash
pip install faker
python3 generate_data.py                       # builds safety_analytics.db
sqlite3 safety_analytics.db < sql/01_views.sql  # creates reporting views
sqlite3 safety_analytics.db < sql/02_data_quality_checks.sql  # validate
```

Then open `dashboard.html` in a browser, or follow `POWER_BI_GUIDE.md` to
load `csv_export/*.csv` into Power BI Desktop.
