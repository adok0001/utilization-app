# ============================================================
# formatting.R — Currency, date, number, and table helpers
# ============================================================

#' Format a number as USD currency
#' @param x Numeric value
#' @param digits Decimal places (default 0)
fmt_currency <- function(x, digits = 0) {
  scales::dollar(x, accuracy = 10^(-digits), prefix = "$")
}

#' Format a number with comma thousands separator
#' @param x Numeric value
#' @param digits Decimal places (default 1)
fmt_number <- function(x, digits = 1) {
  formatC(round(x, digits), format = "f", digits = digits, big.mark = ",")
}

#' Format a proportion as a percentage
#' @param x Numeric 0–1
#' @param digits Decimal places (default 1)
fmt_pct <- function(x, digits = 1) {
  paste0(round(x * 100, digits), "%")
}

#' Format hours worked
#' @param x Numeric hours
fmt_hours <- function(x) {
  paste0(fmt_number(x, 1), " hrs")
}

#' Format FTE (full-time equivalent)
#' @param x Numeric FTE value
fmt_fte <- function(x) {
  paste0(fmt_number(x, 2), " FTE")
}

#' Format a date as "Month DD, YYYY"
#' @param x Date or character
fmt_date <- function(x) {
  format(as.Date(x), "%B %d, %Y")
}

#' Format a date range as "Jan 2025 – Mar 2025"
#' @param start_date,end_date Date objects
fmt_date_range <- function(start_date, end_date) {
  glue::glue("{format(as.Date(start_date), '%b %Y')} \u2013 {format(as.Date(end_date), '%b %Y')}")
}

#' Color-coded badge HTML for a value relative to a threshold
#' @param value Numeric
#' @param good_above Logical — TRUE if value above threshold is good
#' @param threshold Threshold numeric
fmt_badge <- function(value, good_above = TRUE, threshold = 0) {
  direction <- if (good_above) value >= threshold else value <= threshold
  cls <- if (direction) "badge bg-success" else "badge bg-danger"
  tags$span(class = cls, fmt_number(value, 1))
}

#' Variance display: +5% / -3% with colour
#' @param actual,budget Numeric
fmt_variance <- function(actual, budget) {
  if (is.na(actual) || is.na(budget) || budget == 0) return("N/A")
  var_pct <- (actual - budget) / budget
  color <- if (var_pct >= 0) COL_SUCCESS else COL_DANGER
  sign <- if (var_pct >= 0) "+" else ""
  htmltools::span(
    style = glue::glue("color:{color}; font-weight:600;"),
    paste0(sign, fmt_pct(var_pct))
  )
}
