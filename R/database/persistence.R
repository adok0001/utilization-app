# ============================================================
# persistence.R — Load validated data into the database
# ============================================================
library(DBI)
library(data.table)

#' Persist cleaned raw data and rebuild summary tables
#'
#' @param con            DBI connection
#' @param dt             Cleaned data.table (output of clean_and_standardise)
#' @param upload_log_id  Row ID of the upload_log entry (for audit trail link)
persist_upload <- function(con, dt, upload_log_id = NULL) {
  dbWithTransaction(con, {

    # 1. Append to raw table
    dt_insert <- copy(dt)
    if (!is.null(upload_log_id)) dt_insert[, upload_id := upload_log_id]
    dt_insert[, loaded_at := as.character(Sys.time())]

    dbWriteTable(con, "physician_hours_raw", dt_insert,
                 append = TRUE, row.names = FALSE)
    log_db_write("physician_hours_raw", nrow(dt_insert))

    # 2. Upsert physician master records
    unique_physicians <- unique(data.table(
      physician_id   = dt[["physician_id"]],
      physician_name = dt[["physician_name"]],
      department     = if ("department" %in% names(dt)) dt[["department"]] else rep(NA_character_, nrow(dt)),
      specialty      = if ("specialty"  %in% names(dt)) dt[["specialty"]]  else rep(NA_character_, nrow(dt))
    ))
    for (i in seq_len(nrow(unique_physicians))) {
      p <- unique_physicians[i]
      upsert_physician(con, p$physician_id, p$physician_name, p$department, p$specialty)
    }

    # 3. Rebuild monthly summary for affected months
    affected_months <- unique(dt[, .(year, month)])
    for (i in seq_len(nrow(affected_months))) {
      yr <- affected_months$year[i]
      mo <- affected_months$month[i]

      # Fetch all raw data for this year/month
      all_raw_month <- get_raw_hours(con, year = yr, month = mo)

      if (nrow(all_raw_month) > 0) {
        # Rebuild summary for all physicians in this month
        new_summary <- build_monthly_summary(all_raw_month)
        db_execute(con,
          "DELETE FROM physician_monthly_summary WHERE year = ? AND month = ?",
          list(yr, mo)
        )
        dbWriteTable(con, "physician_monthly_summary", as.data.frame(new_summary),
                     append = TRUE, row.names = FALSE)
        log_db_write("physician_monthly_summary", nrow(new_summary))
      }
    }

    affected_years <- unique(dt$year)
    for (yr in affected_years) {
      monthly_yr <- get_monthly_summary(con, year = yr)
      if (nrow(monthly_yr) > 0) {
        annual_summary <- build_annual_summary(monthly_yr)
        db_execute(con,
          "DELETE FROM physician_annual_summary WHERE year = ?", list(yr))
        dbWriteTable(con, "physician_annual_summary", as.data.frame(annual_summary),
                     append = TRUE, row.names = FALSE)
        log_db_write("physician_annual_summary", nrow(annual_summary))
      }
    }
  })
  invisible(TRUE)
}

#' Check if a file (by hash) was already uploaded
#' @param con       DBI connection
#' @param file_hash MD5 hash string
is_duplicate_upload <- function(con, file_hash) {
  result <- db_query(con,
    "SELECT COUNT(*) AS n FROM upload_log WHERE file_hash = ? AND status = 'success'",
    list(file_hash)
  )
  result$n > 0
}
