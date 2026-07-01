"""
Generate a synthetic dataset modeling a fire & life-safety equipment
inspection/compliance business (mirrors Levitt-Safety's business model).

Tables: Regions, Technicians, Customers, Sites, Equipment, Inspections,
Incidents, TrainingSessions
"""
import sqlite3
import random
from datetime import date, timedelta
from faker import Faker

fake = Faker("en_CA")
Faker.seed(42)
random.seed(42)

DB_PATH = "safety_analytics.db"

REGIONS = ["Ontario", "Quebec", "Atlantic", "Prairies", "British Columbia"]
INDUSTRIES = ["Manufacturing", "Oil & Gas", "Healthcare", "Warehousing",
              "Construction", "Education", "Retail", "Mining"]
EQUIPMENT_TYPES = ["Fire Extinguisher", "Fire Alarm Panel", "Sprinkler System",
                    "Emergency Lighting", "SCBA Unit", "Gas Detector",
                    "Eyewash Station", "Exit Sign"]
CERT_LEVELS = ["Level 1", "Level 2", "Level 3", "Master Technician"]
INCIDENT_TYPES = ["False Alarm", "Equipment Failure", "Near Miss",
                   "Fire", "Chemical Spill", "Injury"]
SEVERITIES = ["Low", "Medium", "High", "Critical"]
TRAINING_TYPES = ["Fire Extinguisher Use", "Emergency Evacuation",
                   "WHMIS", "First Aid & CPR", "Confined Space Entry"]


def rand_date(start_year=2024, end_year=2026):
    start = date(start_year, 1, 1)
    end = date(end_year, 6, 30)
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))


def build():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.executescript("""
    DROP TABLE IF EXISTS Incidents;
    DROP TABLE IF EXISTS Inspections;
    DROP TABLE IF EXISTS Equipment;
    DROP TABLE IF EXISTS Sites;
    DROP TABLE IF EXISTS TrainingSessions;
    DROP TABLE IF EXISTS Customers;
    DROP TABLE IF EXISTS Technicians;

    CREATE TABLE Technicians (
        TechnicianID INTEGER PRIMARY KEY,
        FullName TEXT NOT NULL,
        Region TEXT NOT NULL,
        CertificationLevel TEXT NOT NULL,
        HireDate TEXT NOT NULL
    );

    CREATE TABLE Customers (
        CustomerID INTEGER PRIMARY KEY,
        CustomerName TEXT NOT NULL,
        Industry TEXT NOT NULL,
        Region TEXT NOT NULL,
        ContractType TEXT NOT NULL
    );

    CREATE TABLE Sites (
        SiteID INTEGER PRIMARY KEY,
        CustomerID INTEGER NOT NULL,
        SiteName TEXT NOT NULL,
        Province TEXT NOT NULL,
        FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
    );

    CREATE TABLE Equipment (
        EquipmentID INTEGER PRIMARY KEY,
        SiteID INTEGER NOT NULL,
        EquipmentType TEXT NOT NULL,
        InstallDate TEXT NOT NULL,
        LastInspectionDate TEXT,
        NextDueDate TEXT NOT NULL,
        Status TEXT NOT NULL,
        FOREIGN KEY (SiteID) REFERENCES Sites(SiteID)
    );

    CREATE TABLE Inspections (
        InspectionID INTEGER PRIMARY KEY,
        EquipmentID INTEGER NOT NULL,
        TechnicianID INTEGER NOT NULL,
        InspectionDate TEXT NOT NULL,
        Result TEXT NOT NULL,
        DeficienciesFound INTEGER NOT NULL,
        Notes TEXT,
        FOREIGN KEY (EquipmentID) REFERENCES Equipment(EquipmentID),
        FOREIGN KEY (TechnicianID) REFERENCES Technicians(TechnicianID)
    );

    CREATE TABLE Incidents (
        IncidentID INTEGER PRIMARY KEY,
        SiteID INTEGER NOT NULL,
        IncidentDate TEXT NOT NULL,
        IncidentType TEXT NOT NULL,
        Severity TEXT NOT NULL,
        RootCause TEXT,
        FOREIGN KEY (SiteID) REFERENCES Sites(SiteID)
    );

    CREATE TABLE TrainingSessions (
        SessionID INTEGER PRIMARY KEY,
        CustomerID INTEGER NOT NULL,
        TrainingType TEXT NOT NULL,
        SessionDate TEXT NOT NULL,
        AttendeeCount INTEGER NOT NULL,
        PassRate REAL NOT NULL,
        FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
    );
    """)

    # Technicians
    technicians = []
    for i in range(1, 26):
        technicians.append((i, fake.name(), random.choice(REGIONS),
                             random.choice(CERT_LEVELS),
                             rand_date(2018, 2025).isoformat()))
    cur.executemany("INSERT INTO Technicians VALUES (?,?,?,?,?)", technicians)

    # Customers
    customers = []
    for i in range(1, 121):
        customers.append((i, fake.company(), random.choice(INDUSTRIES),
                           random.choice(REGIONS),
                           random.choice(["Annual", "Multi-Year", "Per-Visit"])))
    cur.executemany("INSERT INTO Customers VALUES (?,?,?,?,?)", customers)

    # Sites (1-3 per customer)
    sites = []
    site_id = 1
    for cust in customers:
        for _ in range(random.randint(1, 3)):
            sites.append((site_id, cust[0], f"{cust[1]} - {fake.city()} Site",
                           fake.province()))
            site_id += 1
    cur.executemany("INSERT INTO Sites VALUES (?,?,?,?)", sites)

    # Equipment (3-10 per site)
    equipment = []
    eq_id = 1
    today = date(2026, 6, 30)
    for site in sites:
        for _ in range(random.randint(3, 10)):
            install = rand_date(2019, 2025)
            last_insp = rand_date(2025, 2026) if random.random() > 0.1 else None
            # inspection cycle ~ 12 months from last inspection
            base = last_insp if last_insp else install
            next_due = base + timedelta(days=365)
            status = "Overdue" if next_due < today else "Compliant"
            equipment.append((eq_id, site[0], random.choice(EQUIPMENT_TYPES),
                               install.isoformat(),
                               last_insp.isoformat() if last_insp else None,
                               next_due.isoformat(), status))
            eq_id += 1
    cur.executemany("INSERT INTO Equipment VALUES (?,?,?,?,?,?,?)", equipment)

    # Inspections (historical, tied to equipment that has LastInspectionDate)
    inspections = []
    insp_id = 1
    for eq in equipment:
        if eq[4]:  # LastInspectionDate not null
            n_history = random.randint(1, 3)
            for _ in range(n_history):
                tech = random.choice(technicians)
                result = random.choices(
                    ["Pass", "Pass with Deficiency", "Fail"],
                    weights=[70, 22, 8])[0]
                deficiencies = 0 if result == "Pass" else random.randint(1, 4)
                inspections.append((
                    insp_id, eq[0], tech[0],
                    rand_date(2024, 2026).isoformat(),
                    result, deficiencies,
                    fake.sentence(nb_words=8) if deficiencies else None
                ))
                insp_id += 1
    cur.executemany("INSERT INTO Inspections VALUES (?,?,?,?,?,?,?)", inspections)

    # Incidents (sparser)
    incidents = []
    inc_id = 1
    for site in sites:
        if random.random() < 0.35:
            for _ in range(random.randint(1, 2)):
                incidents.append((
                    inc_id, site[0], rand_date(2024, 2026).isoformat(),
                    random.choice(INCIDENT_TYPES), random.choice(SEVERITIES),
                    fake.sentence(nb_words=6)
                ))
                inc_id += 1
    cur.executemany("INSERT INTO Incidents VALUES (?,?,?,?,?,?)", incidents)

    # Training sessions
    training = []
    sess_id = 1
    for cust in customers:
        for _ in range(random.randint(0, 3)):
            attendees = random.randint(5, 40)
            training.append((
                sess_id, cust[0], random.choice(TRAINING_TYPES),
                rand_date(2024, 2026).isoformat(), attendees,
                round(random.uniform(0.75, 1.0), 2)
            ))
            sess_id += 1
    cur.executemany("INSERT INTO TrainingSessions VALUES (?,?,?,?,?,?)", training)

    conn.commit()

    # Introduce a controlled set of data-quality issues for validation demo
    cur.execute("UPDATE Equipment SET SiteID = 99999 WHERE EquipmentID = 5")  # broken FK
    cur.execute("INSERT INTO Customers VALUES (121, '', 'Retail', 'Ontario', 'Annual')")  # missing name
    dup = cur.execute("SELECT * FROM Inspections WHERE InspectionID = 1").fetchone()
    dup_row = (99999,) + dup[1:]
    cur.execute("INSERT INTO Inspections VALUES (?,?,?,?,?,?,?)", dup_row)  # near-duplicate row
    conn.commit()

    counts = {}
    for t in ["Technicians", "Customers", "Sites", "Equipment", "Inspections",
              "Incidents", "TrainingSessions"]:
        counts[t] = cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
    print(counts)
    conn.close()


if __name__ == "__main__":
    build()
