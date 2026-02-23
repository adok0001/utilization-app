# ============================================================
# test_database.R — Integration tests for DB interactions
# ============================================================
library(testthat)
library(DBI)
library(RSQLite)
library(data.table)
library(withr)

source("R/utils/constants.R")
source("R/utils/logging.R")
source("R/data/calculate_metrics.R")
source("R/database/init_db.R")
source("R/database/queries.R")
source("R/database/persistence.R")

# ── Shared test database ─────────────────────────────────────
make_test_db <- function() {
  tmp <- withr::local_tempfile(fileext = ".sqlite")
  con <- init_db(tmp)
  con
}

make_test_data <- function() {
  data.table(
    physician_id   = c("P001","P001","P002"),
    physician_name = c("Dr. Alpha","Dr. Alpha","Dr. Beta"),
    service_date   = c("2026-01-10","2026-01-11","2026-01-10"),
    start_time     = "07:00:00",
    end_time       = "15:00:00",
    hours_worked   = c(8, 8, 9),
    payment_amount = c(960, 960, 1035),
    payment_type   = "hourly",
    department     = c("EM","EM","IM"),
    specialty      = "NA",
    shift_type     = "day",
    is_on_call     = 0L,
    year           = 2026L,
    month          = 1L,
    week           = 2L,
    notes          = NA_character_
  )
}

# ── init_db ──────────────────────────────────────────────────
test_that("init_db creates all required tables", {
  con     <- make_test_db()
  tables  <- dbListTables(con)
  expect_true("physician_hours_raw"      %in% tables)
  expect_true("physician_monthly_summary" %in% tables)
  expect_true("physician_annual_summary"  %in% tables)
  expect_true("physician_master"          %in% tables)
  expect_true("upload_log"               %in% tables)
  expect_true("validation_issues"        %in% tables)
  dbDisconnect(con)
})

# ── insert_upload_log ─────────────────────────────────────────
test_that("insert_upload_log writes to upload_log", {
  con <- make_test_db()
  insert_upload_log(con, "test.csv", "abc123", 50L, 0L, 2L, "success", "tester")
  hist <- get_upload_history(con)
  expect_equal(nrow(hist), 1L)
  expect_equal(hist$file_name, "test.csv")
  dbDisconnect(con)
})

# ── persist_upload ────────────────────────────────────────────
test_that("persist_upload writes raw rows and builds summaries", {
  con <- make_test_db()
  dt  <- make_test_data()
  persist_upload(con, dt)

  raw <- db_query(con, "SELECT COUNT(*) AS n FROM physician_hours_raw")
  expect_equal(raw$n, 3L)

  summary <- db_query(con, "SELECT COUNT(*) AS n FROM physician_monthly_summary")
  expect_true(summary$n >= 2L)   # At least one row per physician
  dbDisconnect(con)
})

# ── is_duplicate_upload ───────────────────────────────────────
test_that("is_duplicate_upload detects already-loaded file hash", {
  con <- make_test_db()
  insert_upload_log(con, "test.csv", "zyx987", 10L, 0L, 0L, "success")
  expect_true(is_duplicate_upload(con, "zyx987"))
  expect_false(is_duplicate_upload(con, "new_hash_999"))
  dbDisconnect(con)
})

# ── get_dashboard_kpis ───────────────────────────────────────
test_that("get_dashboard_kpis returns expected columns", {
  con  <- make_test_db()
  dt   <- make_test_data()
  persist_upload(con, dt)
  kpis <- get_dashboard_kpis(con)
  expect_true("total_physicians"  %in% names(kpis))
  expect_true("total_hours"       %in% names(kpis))
  expect_true("total_compensation" %in% names(kpis))
  expect_equal(kpis$total_physicians, 2L)
  dbDisconnect(con)
})
