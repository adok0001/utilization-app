# ============================================================
# test_import.R — Unit tests for file import functions
# ============================================================
library(testthat)
library(data.table)
library(withr)

source("../R/utils/constants.R")
source("../R/utils/logging.R")
source("../R/data/import.R")

# ── read_csv_upload ──────────────────────────────────────────
test_that("read_csv_upload reads a valid CSV correctly", {
  tmp <- withr::local_tempfile(fileext = ".csv")
  fwrite(data.table(
    physician_id   = "P001",
    physician_name = "Dr. Smith",
    service_date   = "2026-01-15",
    start_time     = "07:00:00",
    end_time       = "15:00:00",
    hours_worked   = 8,
    payment_amount = 960,
    payment_type   = "hourly"
  ), tmp)

  result <- read_csv_upload(tmp)
  expect_s3_class(result, "data.table")
  expect_equal(nrow(result), 1L)
  expect_true("physician_id" %in% names(result))
})

# ── normalise_column_names ───────────────────────────────────
test_that("normalise_column_names maps known aliases", {
  dt <- data.table(
    phys_id     = "P001",
    doctor_name = "Dr. Smith",
    dos         = "2026-01-15",
    time_in     = "07:00:00",
    time_out    = "15:00:00",
    hours       = 8,
    pay         = 960,
    pay_type    = "hourly"
  )
  result <- normalise_column_names(dt)
  expect_true("physician_id"   %in% names(result))
  expect_true("physician_name" %in% names(result))
  expect_true("service_date"   %in% names(result))
  expect_true("start_time"     %in% names(result))
  expect_true("end_time"       %in% names(result))
  expect_true("hours_worked"   %in% names(result))
  expect_true("payment_amount" %in% names(result))
  expect_true("payment_type"   %in% names(result))
})

# ── read_upload dispatches on extension ──────────────────────
test_that("read_upload throws for unsupported extension", {
  tmp <- withr::local_tempfile(fileext = ".txt")
  writeLines("a,b", tmp)
  expect_error(read_upload(tmp, "file.txt"), regexp = "Unsupported")
})

test_that("read_upload reads sample CSV correctly", {
  result <- read_upload("../sample_data/sample_upload_1.csv",
                         "sample_upload_1.csv")
  expect_s3_class(result, "data.table")
  expect_true(nrow(result) > 0)
  expect_true(all(c("physician_id", "physician_name") %in% names(result)))
})

# ── preview_upload ───────────────────────────────────────────
test_that("preview_upload returns at most n rows", {
  dt     <- data.table(x = 1:50)
  result <- preview_upload(dt, n = 10)
  expect_equal(nrow(result), 10L)
})
