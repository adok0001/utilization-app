# ============================================================
# test_calculations.R — Unit tests for metric calculations
# ============================================================
library(testthat)
library(data.table)

source("../R/utils/constants.R")
source("../R/utils/logging.R")
source("../R/data/calculate_metrics.R")

# ── Helper: build a minimal raw data.table ───────────────────
make_raw_dt <- function() {
  data.table(
    physician_id   = c("P001","P001","P001","P002","P002"),
    physician_name = c("Dr. A","Dr. A","Dr. A","Dr. B","Dr. B"),
    service_date   = as.IDate(c("2026-01-10","2026-01-11","2026-01-12",
                                  "2026-01-10","2026-01-11")),
    hours_worked   = c(8, 8, 10, 9, 9),
    payment_amount = c(960, 960, 1200, 1035, 1035),
    payment_type   = c("hourly","hourly","hourly","hourly","hourly"),
    year           = 2026L,
    month          = 1L,
    shift_type     = "day",
    department     = "Emergency Medicine"
  )
}

# ── summarise_hours_monthly ──────────────────────────────────
test_that("summarise_hours_monthly sums hours correctly", {
  dt <- make_raw_dt()
  result <- summarise_hours_monthly(dt)
  p001 <- result[physician_id == "P001"]
  expect_equal(p001$total_hours, 26)     # 8+8+10
  expect_equal(p001$days_worked, 3L)
  expect_equal(p001$shift_count, 3L)
})

# ── calc_fte ─────────────────────────────────────────────────
test_that("calc_fte computes FTE fraction", {
  dt <- data.table(physician_id = "P001", physician_name = "Dr. A",
                    year = 2026L, month = 1L, total_hours = FTE_MONTHLY_HOURS)
  result <- calc_fte(dt)
  expect_equal(result$fte_pct, 1.0)
})

test_that("calc_fte is 0.5 for half-time", {
  dt <- data.table(physician_id = "P001", physician_name = "Dr. A",
                    year = 2026L, month = 1L, total_hours = FTE_MONTHLY_HOURS / 2)
  result <- calc_fte(dt)
  expect_equal(result$fte_pct, 0.5)
})

# ── summarise_compensation_monthly ───────────────────────────
test_that("summarise_compensation_monthly sums payment correctly", {
  dt <- make_raw_dt()
  result <- summarise_compensation_monthly(dt)
  p001 <- result[physician_id == "P001"]
  expect_equal(p001$total_compensation, 3120)   # 960+960+1200
})

# ── calc_hourly_rate ─────────────────────────────────────────
test_that("calc_hourly_rate divides compensation by hours", {
  dt <- data.table(
    physician_id = "P001", physician_name = "Dr. A",
    year = 2026L, month = 1L,
    total_hours = 10, total_compensation = 1500
  )
  result <- calc_hourly_rate(dt)
  expect_equal(result$avg_hourly_rate, 150.0)
})

test_that("calc_hourly_rate returns NA when hours are 0", {
  dt <- data.table(
    physician_id = "P001", physician_name = "Dr. A",
    year = 2026L, month = 1L,
    total_hours = 0, total_compensation = 500
  )
  result <- calc_hourly_rate(dt)
  expect_true(is.na(result$avg_hourly_rate))
})

# ── build_monthly_summary ────────────────────────────────────
test_that("build_monthly_summary returns one row per physician-month", {
  dt <- make_raw_dt()
  result <- build_monthly_summary(dt)
  expect_equal(nrow(result), 2L)   # P001 and P002, both in Jan 2026
  expect_true("fte_pct" %in% names(result))
  expect_true("avg_hourly_rate" %in% names(result))
})

# ── build_annual_summary ──────────────────────────────────────
test_that("build_annual_summary rolls up to one row per physician-year", {
  monthly <- data.table(
    physician_id = c("P001","P001","P002"),
    physician_name = c("Dr. A","Dr. A","Dr. B"),
    year  = c(2026L, 2026L, 2026L),
    month = c(1L, 2L, 1L),
    total_hours = c(80, 76, 90),
    total_compensation = c(9600, 9120, 11700),
    days_worked = c(10, 9, 10),
    shift_count = c(10, 9, 10)
  )
  result <- build_annual_summary(monthly)
  expect_equal(nrow(result), 2L)
  p001 <- result[physician_id == "P001"]
  expect_equal(p001$total_hours, 156)
  expect_equal(p001$months_active, 2L)
})
