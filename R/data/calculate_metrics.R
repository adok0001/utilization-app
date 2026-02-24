# ============================================================
# calculate_metrics.R — KPI and metric calculations
# ============================================================
library(data.table)

# ── Hours Metrics ─────────────────────────────────────────────

#' Summarise hours per physician per month
#' @param dt data.table  (physician_hours_raw)
#' @return   data.table  with columns: physician_id, year, month,
#'                       total_hours, days_worked, shift_count
summarise_hours_monthly <- function(dt) {
  hrs <- dt[, .(
    physician_name = physician_name[1L],
    total_hours    = sum(hours_worked, na.rm = TRUE),
    days_worked    = uniqueN(service_date),
    shift_count    = .N
  ), by = .(physician_id, year, month)]
  hrs
}

#' Calculate FTE % for each physician-month
#' @param monthly_dt  Output of summarise_hours_monthly()
calc_fte <- function(monthly_dt) {
  monthly_dt[, fte_pct := round(total_hours / FTE_MONTHLY_HOURS, 4)]
  monthly_dt
}

# ── Compensation Metrics ──────────────────────────────────────

#' Summarise compensation per physician per month
#' @param dt data.table (physician_hours_raw)
summarise_compensation_monthly <- function(dt) {
  dt[, .(
    total_compensation = sum(payment_amount, na.rm = TRUE),
    hourly_pay_total   = sum(payment_amount[payment_type == "hourly"],   na.rm = TRUE),
    stipend_total      = sum(payment_amount[payment_type == "stipend"],  na.rm = TRUE),
    bonus_total        = sum(payment_amount[payment_type == "bonus"],    na.rm = TRUE),
    incentive_total    = sum(payment_amount[payment_type == "incentive"],na.rm = TRUE),
    n_payment_records  = .N
  ), by = .(physician_id, year, month)]
}

#' Calculate average hourly rate (compensation / hours)
#' @param monthly_dt  Merged monthly hours & compensation summary
calc_hourly_rate <- function(monthly_dt) {
  monthly_dt[, avg_hourly_rate := fifelse(
    total_hours > 0,
    round(total_compensation / total_hours, 2),
    NA_real_
  )]
  monthly_dt
}

# ── Combined Monthly Summary ──────────────────────────────────

#' Build the full physician_monthly_summary table from raw data
#' @param dt data.table (physician_hours_raw, cleaned)
#' @return   data.table ready for database upsert
build_monthly_summary <- function(dt) {
  hrs  <- summarise_hours_monthly(dt)
  comp <- summarise_compensation_monthly(dt)

  merged <- merge(hrs, comp,
                  by = c("physician_id", "year", "month"),
                  all = TRUE)

  merged <- calc_fte(merged)
  merged <- calc_hourly_rate(merged)

  # Shift type breakdown
  if ("shift_type" %in% names(dt)) {
    shift_wide <- dcast(
      dt[, .(hrs = sum(hours_worked, na.rm = TRUE)),
         by = .(physician_id, year, month, shift_type)],
      physician_id + year + month ~ shift_type,
      value.var = "hrs", fill = 0
    )
    for (col in c("day", "evening", "night", "weekend", "holiday", "on_call")) {
      if (!col %in% names(shift_wide)) shift_wide[, (col) := 0]
    }
    # Remove any NA-named column produced by dcast (rows with NA shift_type)
    # Must catch both R's NA and the string "NA" that dcast produces
    na_cols <- names(shift_wide)[is.na(names(shift_wide)) | names(shift_wide) == "NA"]
    if (length(na_cols)) shift_wide[, (na_cols) := NULL]

    shift_cols <- c("day", "evening", "night", "weekend", "holiday", "on_call")
    existing   <- base::intersect(shift_cols, names(shift_wide))
    setnames(shift_wide, existing, paste0("hours_", existing))
    merged <- merge(merged, shift_wide, by = c("physician_id","year","month"), all.x = TRUE)
  }

  merged[order(year, month, physician_id)]
}

# ── Annual Summary ────────────────────────────────────────────

#' Roll monthly summaries up to annual
#' @param monthly_dt  Output of build_monthly_summary()
build_annual_summary <- function(monthly_dt) {
  monthly_dt[, .(
    physician_name     = physician_name[1L],
    total_hours        = sum(total_hours,        na.rm = TRUE),
    total_compensation = sum(total_compensation, na.rm = TRUE),
    days_worked        = sum(days_worked,         na.rm = TRUE),
    shift_count        = sum(shift_count,         na.rm = TRUE),
    months_active      = uniqueN(month)
  ), by = .(physician_id, year)] |>
    (\(dt) { dt[, fte_pct := round(total_hours / FTE_ANNUAL_HOURS, 4)]; dt })() |>
    calc_hourly_rate()
}

# ── Peer Comparison ───────────────────────────────────────────

#' Add peer average columns to monthly summary
#' @param monthly_dt  data.table with physician_monthly_summary data
#' @param group_col   Column to group peers by, default "department"
add_peer_comparison <- function(monthly_dt, group_col = "department") {
  if (!group_col %in% names(monthly_dt)) {
    monthly_dt[, peer_avg_hours := mean(total_hours, na.rm = TRUE),
               by = .(year, month)]
    monthly_dt[, peer_avg_rate  := mean(avg_hourly_rate, na.rm = TRUE),
               by = .(year, month)]
  } else {
    monthly_dt[, peer_avg_hours := mean(total_hours, na.rm = TRUE),
               by = c("year", "month", group_col)]
    monthly_dt[, peer_avg_rate  := mean(avg_hourly_rate, na.rm = TRUE),
               by = c("year", "month", group_col)]
  }
  monthly_dt[, vs_peer_hours_pct := round((total_hours - peer_avg_hours) / peer_avg_hours, 4)]
  monthly_dt[, vs_peer_rate_pct  := round((avg_hourly_rate - peer_avg_rate) / peer_avg_rate, 4)]
  monthly_dt
}

# ── Variance Analysis ─────────────────────────────────────────

#' Compare actual hours to contracted hours (if available)
#' @param actual_dt     data.table with actual monthly sums
#' @param contract_dt   data.table with contracted hours (physician_id, year, month, contracted_hours)
calc_variance <- function(actual_dt, contract_dt) {
  merged <- merge(actual_dt, contract_dt,
                  by = c("physician_id", "year", "month"), all.x = TRUE)
  merged[, hours_variance     := total_hours - contracted_hours]
  merged[, hours_variance_pct := round(hours_variance / contracted_hours, 4)]
  merged
}
