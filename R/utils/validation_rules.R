# ============================================================
# validation_rules.R — Configurable validation logic
# ============================================================
# Rules can be overridden via config/validation_rules.yaml

#' Load validation thresholds from YAML (with hard-coded defaults)
get_validation_config <- function() {
  defaults <- list(
    max_shift_hours    = MAX_SHIFT_HOURS,
    min_hourly_rate    = MIN_HOURLY_RATE,
    max_hourly_rate    = MAX_HOURLY_RATE,
    min_payment_amount = MIN_PAYMENT_AMOUNT
  )
  # Try validation_rules.yaml first; fall back to defaults on any error
  vc <- tryCatch({
    yaml_path <- if (file.exists("config/validation_rules.yaml")) {
      "config/validation_rules.yaml"
    } else if (file.exists("../config/validation_rules.yaml")) {
      "../config/validation_rules.yaml"
    } else {
      return(defaults)
    }
    raw <- yaml::read_yaml(yaml_path)
    vals <- raw[["default"]][["validation"]]
    if (is.null(vals)) defaults else modifyList(defaults, vals)
  }, error = function(e) defaults)
  vc
}

#' Check that all required columns are present (case-insensitive)
#' @param col_names Character vector of column names in the file
#' @return List with $pass (logical) and $missing (character vector)
check_required_columns <- function(col_names) {
  normalised <- tolower(trimws(col_names))
  required   <- tolower(REQUIRED_COLS)
  missing    <- required[!required %in% normalised]
  list(pass = length(missing) == 0, missing = missing)
}

#' Check data types of critical columns
#' @param dt data.table
#' @return data.table of issues: row, column, issue
check_data_types <- function(dt) {
  issues <- list()
  if ("service_date" %in% names(dt)) {
    bad <- which(is.na(as.Date(as.character(dt$service_date), optional = TRUE)))
    if (length(bad))
      issues <- c(issues, list(data.table(row = bad, column = "service_date",
                                          issue = "Cannot parse as date")))
  }
  if ("payment_amount" %in% names(dt)) {
    bad <- which(is.na(suppressWarnings(as.numeric(dt$payment_amount))))
    if (length(bad))
      issues <- c(issues, list(data.table(row = bad, column = "payment_amount",
                                          issue = "Non-numeric payment amount")))
  }
  if ("hours_worked" %in% names(dt)) {
    bad <- which(is.na(suppressWarnings(as.numeric(dt$hours_worked))))
    if (length(bad))
      issues <- c(issues, list(data.table(row = bad, column = "hours_worked",
                                          issue = "Non-numeric hours_worked")))
  }
  if (length(issues)) rbindlist(issues) else data.table()
}

#' Check time logic: end_time > start_time, hours match
#' @param dt data.table
#' @return data.table of issues
check_time_logic <- function(dt) {
  issues <- list()
  if (all(c("start_time", "end_time", "hours_worked") %in% names(dt))) {
    dt_copy <- copy(dt)[, row_num := .I]
    dt_copy[, start_dt := as.POSIXct(paste(service_date, start_time),
                                      format = "%Y-%m-%d %H:%M:%S", tz = "UTC")]
    dt_copy[, end_dt   := as.POSIXct(paste(service_date, end_time),
                                      format = "%Y-%m-%d %H:%M:%S", tz = "UTC")]
    dt_copy[, calc_hrs := as.numeric(difftime(end_dt, start_dt, units = "hours"))]

    # End before start
    bad_order <- dt_copy[!is.na(start_dt) & !is.na(end_dt) & end_dt <= start_dt, row_num]
    if (length(bad_order))
      issues <- c(issues, list(data.table(row = bad_order, column = "end_time",
                                          issue = "end_time is not after start_time")))

    # Reported hours mismatch calc hours by >0.1h
    bad_hrs <- dt_copy[!is.na(calc_hrs) & !is.na(hours_worked) &
                         abs(calc_hrs - as.numeric(hours_worked)) > 0.1, row_num]
    if (length(bad_hrs))
      issues <- c(issues, list(data.table(row = bad_hrs, column = "hours_worked",
                                          issue = "Reported hours_worked does not match start/end times")))
  }
  if (length(issues)) rbindlist(issues) else data.table()
}

#' Outlier detection — long shifts, extreme rates, negative payments
#' @param dt data.table
#' @return data.table of issues
check_outliers <- function(dt) {
  vc  <- get_validation_config()
  issues <- list()
  dt_copy <- copy(dt)[, row_num := .I]

  if ("hours_worked" %in% names(dt)) {
    bad <- dt_copy[as.numeric(hours_worked) > vc$max_shift_hours, row_num]
    if (length(bad))
      issues <- c(issues, list(data.table(row = bad, column = "hours_worked",
                                          issue = as.character(glue::glue("Shift > {vc$max_shift_hours} hours")))))
  }
  if ("payment_amount" %in% names(dt)) {
    neg <- dt_copy[as.numeric(payment_amount) < vc$min_payment_amount, row_num]
    if (length(neg))
      issues <- c(issues, list(data.table(row = neg, column = "payment_amount",
                                          issue = "Negative payment amount")))
  }
  if (all(c("payment_amount", "hours_worked") %in% names(dt))) {
    dt_copy[, rate := as.numeric(payment_amount) / as.numeric(hours_worked)]
    low_rate <- dt_copy[!is.na(rate) & rate < vc$min_hourly_rate & as.numeric(hours_worked) > 0, row_num]
    hi_rate  <- dt_copy[!is.na(rate) & rate > vc$max_hourly_rate, row_num]
    if (length(low_rate))
      issues <- c(issues, list(data.table(row = low_rate, column = "payment_amount",
                                          issue = as.character(glue::glue("Hourly rate below ${vc$min_hourly_rate}")))))
    if (length(hi_rate))
      issues <- c(issues, list(data.table(row = hi_rate, column = "payment_amount",
                                          issue = as.character(glue::glue("Hourly rate above ${vc$max_hourly_rate}")))))
  }
  if (length(issues)) rbindlist(issues) else data.table()
}

#' Duplicate detection within a data.table
#' @param dt data.table
#' @return data.table of duplicate rows (row indices)
check_duplicates <- function(dt) {
  key_cols <- intersect(c("physician_id", "service_date", "start_time", "end_time"), names(dt))
  if (length(key_cols) < 2) return(data.table())
  dt_copy  <- copy(dt)[, row_num := .I]
  dupes    <- dt_copy[duplicated(dt_copy, by = key_cols) |
                        duplicated(dt_copy, by = key_cols, fromLast = TRUE)]
  if (nrow(dupes) > 0)
    data.table(row = dupes$row_num, column = "all",
               issue = "Duplicate record (same physician, date, start/end times)")
  else
    data.table()
}

#' Run all validation checks and return a combined issues table
#' @param dt data.table
#' @return data.table with columns: row, column, issue, severity
run_all_validations <- function(dt) {
  issues <- rbindlist(list(
    check_data_types(dt),
    check_time_logic(dt),
    check_outliers(dt),
    check_duplicates(dt)
  ), fill = TRUE)

  if (nrow(issues) > 0) {
    issues[, severity := fifelse(
      grepl("Negative|Cannot parse|Non-numeric|not after", issue), "error", "warning"
    )]
  }
  issues
}
