# ============================================================
# validate.R — High-level validation orchestration
# ============================================================

#' Validate an uploaded data.table against all rules
#'
#' @param dt        data.table (output of read_upload)
#' @param file_name Original file name
#' @return          List with:
#'                    $pass        — logical, TRUE if no errors
#'                    $dt          — original data with row_flag column added
#'                    $issues      — data.table of all issues
#'                    $n_errors    — count of error-severity issues
#'                    $n_warnings  — count of warning-severity issues
#'                    $summary     — human-readable summary string
validate_upload <- function(dt, file_name = "upload") {

  # 1. Schema check
  schema_check <- check_required_columns(names(dt))
  if (!schema_check$pass) {
    missing_str <- paste(schema_check$missing, collapse = ", ")
    return(list(
      pass      = FALSE,
      dt        = dt,
      issues    = data.table(row = NA_integer_, column = missing_str,
                             issue = glue::glue("Missing required columns: {missing_str}"),
                             severity = "error"),
      n_errors  = 1L,
      n_warnings = 0L,
      summary   = glue::glue("FAILED: Missing columns — {missing_str}")
    ))
  }

  # 2. All other rule-based validations
  issues <- run_all_validations(dt)

  n_errors   <- if (nrow(issues)) nrow(issues[severity == "error"])   else 0L
  n_warnings <- if (nrow(issues)) nrow(issues[severity == "warning"]) else 0L

  # 3. Tag each row
  dt_flagged <- copy(dt)[, row_flag := "ok"]
  if (nrow(issues) > 0) {
    error_rows   <- issues[severity == "error",   unique(row)]
    warning_rows <- issues[severity == "warning", unique(row)]
    dt_flagged[error_rows,   row_flag := "error"]
    dt_flagged[warning_rows & row_flag == "ok", row_flag := "warning"]
  }

  pass <- n_errors == 0

  summary_str <- glue::glue(
    "{nrow(dt)} rows checked \u2022 {n_errors} errors \u2022 {n_warnings} warnings"
  )

  log_validation(file_name, nrow(dt), nrow(issues))

  list(
    pass       = pass,
    dt         = dt_flagged,
    issues     = issues,
    n_errors   = n_errors,
    n_warnings = n_warnings,
    summary    = summary_str
  )
}

#' Generate a formatted validation report as a data.frame for DT display
#' @param validation_result  Output of validate_upload()
format_validation_report <- function(validation_result) {
  issues <- validation_result$issues
  if (nrow(issues) == 0) {
    return(data.table(Row = integer(), Column = character(),
                      Issue = character(), Severity = character()))
  }
  data.table(
    Row      = issues$row,
    Column   = issues$column,
    Issue    = issues$issue,
    Severity = toupper(issues$severity)
  )
}
