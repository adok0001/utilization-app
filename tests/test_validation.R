# ============================================================
# test_validation.R — Unit tests for validation logic
# ============================================================
library(testthat)
library(data.table)

# Source dependencies
source("../R/utils/constants.R")
source("../R/utils/logging.R")
source("../R/utils/validation_rules.R")

# ── check_required_columns ───────────────────────────────────
test_that("check_required_columns passes with all required cols", {
  cols   <- c("physician_id", "physician_name", "service_date",
              "start_time", "end_time", "hours_worked",
              "payment_amount", "payment_type")
  result <- check_required_columns(cols)
  expect_true(result$pass)
  expect_length(result$missing, 0)
})

test_that("check_required_columns is case-insensitive", {
  cols   <- c("Physician_ID", "PHYSICIAN_NAME", "Service_Date",
              "Start_Time", "End_Time", "Hours_Worked",
              "Payment_Amount", "Payment_Type")
  result <- check_required_columns(cols)
  expect_true(result$pass)
})

test_that("check_required_columns reports missing columns", {
  cols   <- c("physician_id", "physician_name")   # many missing
  result <- check_required_columns(cols)
  expect_false(result$pass)
  expect_true(length(result$missing) > 0)
})

# ── check_data_types ─────────────────────────────────────────
test_that("check_data_types passes clean data", {
  dt <- data.table(
    service_date   = "2026-01-15",
    payment_amount = "1200.00",
    hours_worked   = "8"
  )
  issues <- check_data_types(dt)
  expect_equal(nrow(issues), 0)
})

test_that("check_data_types flags invalid payment_amount", {
  dt <- data.table(
    service_date   = "2026-01-15",
    payment_amount = "not_a_number",
    hours_worked   = "8"
  )
  issues <- check_data_types(dt)
  expect_true(nrow(issues) > 0)
  expect_true("payment_amount" %in% issues$column)
})

test_that("check_data_types flags unparseable date", {
  dt <- data.table(
    service_date   = "not-a-date",
    payment_amount = "1200",
    hours_worked   = "8"
  )
  issues <- check_data_types(dt)
  expect_true(nrow(issues) > 0)
  expect_true("service_date" %in% issues$column)
})

# ── check_outliers ───────────────────────────────────────────
test_that("check_outliers flags shifts >24h", {
  dt <- data.table(
    physician_id   = "P001",
    service_date   = "2026-01-15",
    hours_worked   = 25,
    payment_amount = 3000,
    payment_type   = "hourly"
  )
  issues <- check_outliers(dt)
  expect_true(any(grepl("Shift >", issues$issue)))
})

test_that("check_outliers flags negative payment", {
  dt <- data.table(
    physician_id   = "P001",
    service_date   = "2026-01-15",
    hours_worked   = 8,
    payment_amount = -500,
    payment_type   = "hourly"
  )
  issues <- check_outliers(dt)
  expect_true(any(grepl("[Nn]egative", issues$issue)))
})

test_that("check_outliers passes normal data", {
  dt <- data.table(
    physician_id   = "P001",
    service_date   = "2026-01-15",
    hours_worked   = 8,
    payment_amount = 960,
    payment_type   = "hourly"
  )
  issues <- check_outliers(dt)
  expect_equal(nrow(issues), 0)
})

# ── check_duplicates ─────────────────────────────────────────
test_that("check_duplicates detects exact duplicates", {
  dt <- data.table(
    physician_id = c("P001", "P001"),
    service_date = c("2026-01-15", "2026-01-15"),
    start_time   = c("07:00:00", "07:00:00"),
    end_time     = c("15:00:00", "15:00:00")
  )
  issues <- check_duplicates(dt)
  expect_true(nrow(issues) > 0)
})

test_that("check_duplicates passes unique rows", {
  dt <- data.table(
    physician_id = c("P001", "P001"),
    service_date = c("2026-01-15", "2026-01-16"),
    start_time   = c("07:00:00", "07:00:00"),
    end_time     = c("15:00:00", "15:00:00")
  )
  issues <- check_duplicates(dt)
  expect_equal(nrow(issues), 0)
})

# ── run_all_validations ──────────────────────────────────────
test_that("run_all_validations returns empty table for clean data", {
  dt <- data.table(
    physician_id   = "P001",
    physician_name = "Dr. Smith",
    service_date   = "2026-01-15",
    start_time     = "07:00:00",
    end_time       = "15:00:00",
    hours_worked   = 8,
    payment_amount = 960,
    payment_type   = "hourly"
  )
  issues <- run_all_validations(dt)
  expect_equal(nrow(issues), 0)
})
