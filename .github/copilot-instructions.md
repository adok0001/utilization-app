# Physician Utilization & Compensation Reporting App

## Project Overview
R Shiny application for physician time and compensation data ingestion, utilization metric calculation, and interactive dashboard reporting.

## Tech Stack
- **Framework**: R Shiny (modules, reactivity, file upload)
- **Data Processing**: data.table, tidyverse, lubridate
- **File I/O**: readxl, janitor, writexl
- **Database**: SQLite (RSQLite, DBI)
- **Reporting**: Quarto, blastula
- **Visualization**: ggplot2, plotly, echarts4r
- **Tables**: DT, reactable
- **Testing**: testthat, shinytest2
- **Deployment**: Docker

## Project Structure
```
physician-utilization-app/
├── R/
│   ├── app.R                        # Main Shiny app
│   ├── modules/                     # Shiny modules
│   ├── data/                        # Import, validate, transform, metrics
│   ├── database/                    # DB init, queries, persistence
│   ├── utils/                       # Formatting, constants, logging
│   └── reactive_helpers.R
├── sql/                             # SQL schema and queries
├── quarto/                          # Report templates
├── www/                             # CSS, images
├── data/                            # Sample input files
├── tests/                           # Unit and integration tests
├── config/                          # YAML configuration
├── sample_data/                     # Demo data
└── docker/                          # Dockerfile
```

## Coding Conventions
- Use data.table for all heavy data operations
- Shiny modules follow `<name>UI()` / `<name>Server()` naming convention
- Database operations go through `R/database/queries.R` helpers only
- All validation rules are configurable via `config/validation_rules.yaml`
- Log all user actions with `utils/logging.R`
- Format currency, dates, and numbers with helpers in `utils/formatting.R`
