# ============================================================
# import.R — File reading (CSV and Excel)
# ============================================================
library(data.table)
library(readxl)
library(janitor)

#' Read an uploaded file into a cleaned data.table
#'
#' @param file_path  Path to the uploaded file (temp path from fileInput)
#' @param file_name  Original file name (used to infer format)
#' @return           data.table with cleaned column names, or stops with message
read_upload <- function(file_path, file_name) {
  ext <- tolower(tools::file_ext(file_name))

  dt <- switch(ext,
    "csv"  = read_csv_upload(file_path),
    "xlsx" = read_excel_upload(file_path),
    "xls"  = read_excel_upload(file_path),
    stop(glue::glue("Unsupported file format: .{ext}. Please upload CSV or XLSX."))
  )

  # Standardise column names (snake_case, no spaces)
  setnames(dt, janitor::make_clean_names(names(dt)))

  # Normalise known column name aliases
  dt <- normalise_column_names(dt)

  log_info("Imported {nrow(dt)} rows from {file_name}")
  dt
}

#' Read CSV using data.table::fread for speed
read_csv_upload <- function(file_path) {
  dt <- data.table::fread(file_path, stringsAsFactors = FALSE, na.strings = c("", "NA", "N/A"))
  setDT(dt)
  dt
}

#' Read Excel using readxl
read_excel_upload <- function(file_path) {
  df <- readxl::read_excel(file_path, na = c("", "NA", "N/A"), guess_max = 5000)
  as.data.table(df)
}

#' Map common column name variations to standard names
#' @param dt data.table
normalise_column_names <- function(dt) {
  aliases <- list(
    physician_id     = c("phys_id", "doctor_id", "provider_id", "npi"),
    physician_name   = c("phys_name", "doctor_name", "provider_name", "name", "full_name"),
    service_date     = c("date", "work_date", "shift_date", "dos"),
    start_time       = c("time_in", "shift_start", "clock_in"),
    end_time         = c("time_out", "shift_end", "clock_out"),
    hours_worked     = c("hours", "total_hours", "hrs_worked", "shift_hours"),
    payment_amount   = c("pay", "payment", "compensation", "amount", "pay_amount"),
    payment_type     = c("pay_type", "comp_type", "payment_category")
  )

  for (std_name in names(aliases)) {
    for (alias in aliases[[std_name]]) {
      if (alias %in% names(dt) && !std_name %in% names(dt)) {
        setnames(dt, alias, std_name)
        break
      }
    }
  }
  dt
}

#' Preview first n rows for UI display before committing
#' @param dt data.table
#' @param n  Number of rows to return
preview_upload <- function(dt, n = 10) {
  head(dt, n)
}

#' Compute a simple file hash for duplicate detection
#' @param file_path Path to file
file_hash <- function(file_path) {
  digest::digest(file_path, algo = "md5", file = TRUE)
}
