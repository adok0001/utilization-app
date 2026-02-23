# ============================================================
# queries.R — All database read/write helpers
# NOTE: ALL database access must go through these helpers only
# ============================================================
library(DBI)
library(data.table)

# ── Generic helpers ───────────────────────────────────────────

#' Execute a parameterised query and return a data.table
#' @param con  DBI connection
#' @param sql  SQL string (may contain ? placeholders)
#' @param ...  Values for placeholders (passed to dbGetQuery)
db_query <- function(con, sql, ...) {
  as.data.table(dbGetQuery(con, sql, ...))
}

#' Execute a DML statement (INSERT/UPDATE/DELETE)
#' @param con  DBI connection
#' @param sql  SQL string
#' @param ...  Bind values
db_execute <- function(con, sql, ...) {
  dbExecute(con, sql, ...)
}

# ── Upload log ────────────────────────────────────────────────

#' Insert a record into upload_log
insert_upload_log <- function(con, file_name, file_hash, n_rows,
                               n_errors, n_warnings, status, uploaded_by = "system") {
  db_execute(con,
    "INSERT INTO upload_log
       (file_name, file_hash, uploaded_at, uploaded_by, n_rows, n_errors, n_warnings, status)
     VALUES (?, ?, datetime('now'), ?, ?, ?, ?, ?)",
    list(file_name, file_hash, uploaded_by, n_rows, n_errors, n_warnings, status)
  )
  log_db_write("upload_log", 1L)
}

#' Get recent upload history
get_upload_history <- function(con, n = 20) {
  db_query(con,
    glue::glue("SELECT * FROM upload_log ORDER BY uploaded_at DESC LIMIT {n}")
  )
}

# ── Raw data ──────────────────────────────────────────────────

#' Fetch raw hours data with optional filters
#' @param con       DBI connection
#' @param physician_id  Optional physician ID filter
#' @param year      Optional year filter
#' @param month     Optional month filter
get_raw_hours <- function(con, physician_id = NULL, year = NULL, month = NULL) {
  clauses <- "WHERE 1=1"
  params  <- list()
  if (!is.null(physician_id)) { clauses <- paste(clauses, "AND physician_id = ?"); params <- c(params, list(physician_id)) }
  if (!is.null(year))         { clauses <- paste(clauses, "AND year = ?");          params <- c(params, list(year)) }
  if (!is.null(month))        { clauses <- paste(clauses, "AND month = ?");         params <- c(params, list(month)) }
  db_query(con, paste("SELECT * FROM physician_hours_raw", clauses), params)
}

# ── Monthly summary ───────────────────────────────────────────

#' Get monthly summary for one or all physicians
get_monthly_summary <- function(con, physician_id = NULL, year = NULL) {
  clauses <- "WHERE 1=1"
  params  <- list()
  if (!is.null(physician_id)) { clauses <- paste(clauses, "AND physician_id = ?"); params <- c(params, list(physician_id)) }
  if (!is.null(year))         { clauses <- paste(clauses, "AND year = ?");          params <- c(params, list(year)) }
  db_query(con, paste("SELECT * FROM physician_monthly_summary", clauses,
                      "ORDER BY year, month"), params)
}

#' Get aggregated department monthly totals
get_department_summary <- function(con, dept = NULL, year = NULL) {
  clauses <- "WHERE 1=1"
  params  <- list()
  if (!is.null(dept)) { clauses <- paste(clauses, "AND department = ?"); params <- c(params, list(dept)) }
  if (!is.null(year)) { clauses <- paste(clauses, "AND year = ?");       params <- c(params, list(year)) }
  db_query(con,
    paste("SELECT department, year, month,
                  SUM(total_hours) AS total_hours,
                  SUM(total_compensation) AS total_compensation,
                  SUM(fte_pct) AS total_fte,
                  COUNT(DISTINCT physician_id) AS physician_count,
                  AVG(avg_hourly_rate) AS avg_hourly_rate
           FROM physician_monthly_summary",
          clauses,
          "GROUP BY department, year, month
           ORDER BY year, month"),
    params
  )
}

# ── Physician master ──────────────────────────────────────────

#' Get all physicians in the master table
get_physician_list <- function(con) {
  db_query(con, "SELECT * FROM physician_master ORDER BY physician_name")
}

#' Upsert a physician into physician_master
upsert_physician <- function(con, physician_id, physician_name,
                              department = NA, specialty = NA) {
  db_execute(con,
    "INSERT INTO physician_master (physician_id, physician_name, department, specialty, first_seen)
     VALUES (?, ?, ?, ?, date('now'))
     ON CONFLICT(physician_id) DO UPDATE SET
       physician_name = excluded.physician_name,
       department     = COALESCE(excluded.department, physician_master.department),
       specialty      = COALESCE(excluded.specialty,  physician_master.specialty)",
    list(physician_id, physician_name, department, specialty)
  )
}

# ── Dashboard KPIs ────────────────────────────────────────────

#' Get high-level KPI counts for the dashboard header
get_dashboard_kpis <- function(con) {
  db_query(con,
    "SELECT
       (SELECT COUNT(DISTINCT physician_id) FROM physician_hours_raw) AS total_physicians,
       (SELECT COALESCE(SUM(hours_worked), 0) FROM physician_hours_raw) AS total_hours,
       (SELECT COALESCE(SUM(payment_amount), 0) FROM physician_hours_raw) AS total_compensation,
       (SELECT MAX(uploaded_at) FROM upload_log WHERE status = 'success') AS last_upload"
  )
}
