# ============================================================
# Physician Utilization & Compensation Reporting App
# Main Shiny Application Entry Point
# ============================================================

library(shiny)
library(bslib)
library(data.table)
library(DBI)
library(RSQLite)
library(DT)
library(reactable)
library(plotly)
library(ggplot2)
library(lubridate)
library(janitor)
library(readxl)
library(writexl)
library(glue)
library(logger)

# ── Source all project files ────────────────────────────────
source("R/utils/constants.R")
source("R/utils/formatting.R")
source("R/utils/logging.R")
source("R/utils/validation_rules.R")
source("R/data/import.R")
source("R/data/validate.R")
source("R/data/transform.R")
source("R/data/calculate_metrics.R")
source("R/database/init_db.R")
source("R/database/queries.R")
source("R/database/persistence.R")
source("R/reactive_helpers.R")
source("R/modules/upload_module.R")
source("R/modules/dashboard_module.R")
source("R/modules/physician_detail_module.R")
source("R/modules/department_module.R")
source("R/modules/reporting_module.R")

# ── App Configuration ───────────────────────────────────────
cfg <- config::get()
app_db_path <- cfg$database$path %||% "data/physician_utilization.sqlite"

# ── UI ──────────────────────────────────────────────────────
ui <- page_navbar(
  title = tags$span(
    tags$img(src = "images/logo.png", height = "30px", style = "margin-right: 8px;"),
    "Physician Utilization & Compensation"
  ),
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#1e6091",
    secondary = "#5a6c7d"
  ),
  header = tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
  ),

  # ── Home / Dashboard ──
  nav_panel(
    title = tagList(icon("gauge-high"), "Dashboard"),
    dashboardUI("dashboard")
  ),

  # ── Upload Data ──
  nav_panel(
    title = tagList(icon("upload"), "Upload Data"),
    uploadUI("upload")
  ),

  # ── Physician Detail ──
  nav_panel(
    title = tagList(icon("user-doctor"), "Physician View"),
    physicianDetailUI("physician_detail")
  ),

  # ── Department Analysis ──
  nav_panel(
    title = tagList(icon("building-columns"), "Department View"),
    departmentUI("department")
  ),

  # ── Reports ──
  nav_panel(
    title = tagList(icon("file-lines"), "Reports"),
    reportingUI("reporting")
  ),

  nav_spacer(),
  nav_item(
    tags$span(
      class = "navbar-text text-muted small",
      glue("v1.0 \u00b7 {format(Sys.Date(), '%b %Y')}")
    )
  )
)

# ── Server ──────────────────────────────────────────────────
server <- function(input, output, session) {

  # Initialize database
  con <- init_db(app_db_path)
  onStop(function() dbDisconnect(con))

  # Initialize app logger
  init_logger()
  log_info("Application started — session {session$token}")

  # ── Shared reactive state ──
  r <- reactiveValues(
    db_con       = con,
    upload_ts    = NULL,   # triggers downstream refresh after upload
    physician_id = NULL,   # selected physician for detail view
    dept_id      = NULL    # selected department
  )

  # ── Module servers ──
  uploadServer("upload",           r = r)
  dashboardServer("dashboard",     r = r)
  physicianDetailServer("physician_detail", r = r)
  departmentServer("department",   r = r)
  reportingServer("reporting",     r = r)
}

# ── Launch ──────────────────────────────────────────────────
shinyApp(ui = ui, server = server)
