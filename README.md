# Physician Utilization & Compensation Reporting App

A production-grade R Shiny application for ingesting physician time and compensation data, calculating utilization metrics, and providing interactive dashboards and automated reports.

---

## Features

| Feature | Description |
|---|---|
| **File Upload** | CSV and Excel upload with drag-and-drop, preview, and validation |
| **Validation** | Schema, data type, time logic, outlier, and duplicate detection |
| **Metrics** | Hours, FTE %, compensation, hourly rates, peer comparison, variance |
| **Dashboards** | Physician detail, department analytics, executive KPIs |
| **Reports** | Parameterized Quarto reports (monthly, department, executive, equity audit) |
| **Exports** | CSV, Excel, PDF |
| **Audit trail** | Full upload log with file hash, row counts, validation results |

---

## Quick Start

### Prerequisites

- R 4.3+
- [renv](https://rstudio.github.io/renv/) (`install.packages("renv")`)
- Quarto CLI (for report generation — optional)

### Install & Run

```bash
# 1. Clone the repo
git clone https://github.com/your-org/utilization-app.git
cd utilization-app

# 2. Restore R packages
Rscript -e "renv::restore()"

# 3. Seed the database with sample data (optional)
Rscript seed_db.R

# 4. Launch the app
Rscript -e "shiny::runApp('app.R')"
```

The app will open at [http://127.0.0.1:3838](http://127.0.0.1:3838).

---

## Project Structure

```
utilization-app/
├── app.R                              # Shiny app entry point (root)
├── seed_db.R                          # Load sample data into DB
├── run_tests.R                        # Run test suite
├── config.yml                         # App & DB settings
├── R/
│   ├── modules/
│   │   ├── upload_module.R            # File upload & validation workflow
│   │   ├── dashboard_module.R         # Main KPI dashboard
│   │   ├── physician_detail_module.R  # Individual physician view
│   │   ├── department_module.R        # Department-level analytics
│   │   └── reporting_module.R         # Report generation & export
│   ├── data/
│   │   ├── import.R                   # CSV/Excel reading, column normalisation
│   │   ├── validate.R                 # Validation orchestration
│   │   ├── transform.R                # Cleaning & standardisation
│   │   └── calculate_metrics.R        # Hours, FTE, compensation, peer KPIs
│   ├── database/
│   │   ├── init_db.R                  # SQLite schema creation
│   │   ├── queries.R                  # All DB read/write helpers
│   │   └── persistence.R              # Upload → DB pipeline
│   ├── utils/
│   │   ├── constants.R                # Thresholds, column lists, colours
│   │   ├── formatting.R               # Currency, date, percentage helpers
│   │   ├── logging.R                  # Structured logger (logger package)
│   │   └── validation_rules.R         # Rule implementations
│   └── reactive_helpers.R             # Shared reactive expressions
├── sql/
│   ├── schema.sql                     # Table definitions
│   ├── indexes.sql                    # Performance indexes
│   └── queries/
│       ├── monthly_summary.sql
│       ├── peer_comparison.sql
│       └── variance_analysis.sql
├── quarto/
│   ├── monthly_compensation.qmd       # Monthly physician report
│   ├── department_summary.qmd         # Department rollup
│   ├── executive_review.qmd           # C-level summary
│   └── equity_audit.qmd               # Compensation equity
├── www/
│   └── custom.css                     # Custom Shiny styling
├── data/
│   └── sample_input.csv               # Upload template
├── sample_data/
│   ├── physicians.csv                 # Physician master demo data
│   ├── sample_upload_1.csv            # Clean upload example
│   └── sample_upload_2.csv            # Mixed valid/invalid rows
├── tests/
│   ├── test_validation.R
│   ├── test_calculations.R
│   ├── test_import.R
│   └── test_database.R
├── config/
│   ├── validation_rules.yaml          # Configurable thresholds
│   └── constants.yaml                 # Payment/shift types, departments
├── docker/
│   └── Dockerfile
└── .github/
    ├── workflows/ci_cd.yaml
    └── copilot-instructions.md
```

---

## Upload File Format

The app accepts CSV or XLSX files with the following columns (case-insensitive, many aliases supported):

| Column | Required | Type | Example |
|---|---|---|---|
| `physician_id` | ✅ | text | `P001` |
| `physician_name` | ✅ | text | `Dr. Jane Smith` |
| `service_date` | ✅ | date | `2026-01-15` |
| `start_time` | ✅ | time | `07:00:00` |
| `end_time` | ✅ | time | `15:00:00` |
| `hours_worked` | ✅ | numeric | `8` |
| `payment_amount` | ✅ | numeric | `960.00` |
| `payment_type` | ✅ | text | `hourly` |
| `department` | optional | text | `Emergency Medicine` |
| `specialty` | optional | text | `Emergency Medicine` |
| `shift_type` | optional | text | `day` |
| `is_on_call` | optional | 0/1 | `0` |
| `notes` | optional | text | — |

See [data/sample_input.csv](data/sample_input.csv) for a template.

---

## Running Tests

```r
library(testthat)
test_dir("tests", reporter = "progress")
```

---

## Docker Deployment

```bash
# Build
docker build -f docker/Dockerfile -t physician-utilization-app .

# Run
docker run -p 3838:3838 \
  -v $(pwd)/data:/app/data \
  physician-utilization-app
```

---

## Configuration

Edit [`config.yml`](config.yml) to change database path, logging level, file size limits, and authentication settings.

Validation thresholds (max shift hours, hourly rate bounds, etc.) are in [`config/validation_rules.yaml`](config/validation_rules.yaml).

---

## Dependencies

Core packages: `shiny`, `bslib`, `data.table`, `DBI`, `RSQLite`, `DT`, `plotly`, `ggplot2`, `lubridate`, `readxl`, `writexl`, `janitor`, `glue`, `logger`, `config`, `quarto`, `scales`, `stringr`

All dependencies are managed via [renv](https://rstudio.github.io/renv/). Run `renv::restore()` to install.
