# ============================================================
# transform.R — Data cleaning and standardisation
# ============================================================
library(data.table)
library(lubridate)
library(janitor)

#' Clean and standardise a validated data.table for database loading
#'
#' @param dt  data.table (output of validate_upload()$dt)
#' @return    Cleaned data.table ready for persistence
clean_and_standardise <- function(dt) {
  dt <- copy(dt)

  # ── Text fields ──────────────────────────────────────────
  if ("physician_name" %in% names(dt))
    dt[, physician_name := stringr::str_to_title(trimws(physician_name))]

  if ("physician_id" %in% names(dt))
    dt[, physician_id := trimws(as.character(physician_id))]

  if ("payment_type" %in% names(dt))
    dt[, payment_type := tolower(trimws(payment_type))]

  if ("department" %in% names(dt))
    dt[, department := stringr::str_to_title(trimws(department))]

  if ("specialty" %in% names(dt))
    dt[, specialty := stringr::str_to_title(trimws(specialty))]

  # ── Dates ────────────────────────────────────────────────
  if ("service_date" %in% names(dt))
    dt[, service_date := as.IDate(lubridate::parse_date_time(
      as.character(service_date),
      orders = c("Ymd", "mdY", "dmy", "Y-m-d"), quiet = TRUE
    ))]

  # ── Times ────────────────────────────────────────────────
  for (tcol in c("start_time", "end_time")) {
    if (tcol %in% names(dt))
      dt[, (tcol) := format(
        lubridate::parse_date_time(as.character(get(tcol)),
                                   orders = c("HM", "HMS", "IMS p", "IMp"),
                                   quiet = TRUE),
        "%H:%M:%S"
      )]
  }

  # ── Numerics ─────────────────────────────────────────────
  if ("payment_amount" %in% names(dt))
    dt[, payment_amount := as.numeric(gsub("[^0-9\\.]", "", as.character(payment_amount)))]

  if ("hours_worked" %in% names(dt))
    dt[, hours_worked := round(as.numeric(hours_worked), 4)]

  # ── Derived: year / month / week ─────────────────────────
  if ("service_date" %in% names(dt)) {
    dt[, year  := year(service_date)]
    dt[, month := month(service_date)]
    dt[, week  := isoweek(service_date)]
  }

  # ── Derived: shift_type if missing ───────────────────────
  if (!"shift_type" %in% names(dt) && "start_time" %in% names(dt)) {
    dt[, shift_type := classify_shift(start_time)]
  }

  # Drop internal validation helper column if present
  if ("row_flag" %in% names(dt)) dt[, row_flag := NULL]

  dt
}

#' Classify a shift based on start time string "HH:MM:SS"
#' @param start_time_str Character vector
classify_shift <- function(start_time_str) {
  hr <- as.integer(substr(start_time_str, 1, 2))
  dplyr::case_when(
    hr >= 7  & hr < 15 ~ "day",
    hr >= 15 & hr < 23 ~ "evening",
    TRUE               ~ "night"
  )
}
