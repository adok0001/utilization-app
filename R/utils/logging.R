# ============================================================
# logging.R — Structured audit and debug logging
# ============================================================
library(logger)

#' Initialize the logger for the application
#' Call once in server(), before module servers are invoked.
init_logger <- function(log_level = "INFO", log_file = "logs/app.log") {

  dir.create(dirname(log_file), recursive = TRUE, showWarnings = FALSE)

  log_formatter(formatter_glue)
  log_threshold(log_level)

  # Console appender (dev) + file appender
  log_appender(appender_tee(log_file))
}

#' Log a user action for the audit trail
#' @param action  Short label, e.g. "file_upload"
#' @param detail  Details string
#' @param session Shiny session object (optional)
log_action <- function(action, detail = "", session = NULL) {
  user <- if (!is.null(session)) session$user %||% "anonymous" else "system"
  log_info("[AUDIT] user={user} action={action} detail={detail}")
}

#' Log a validation event
#' @param file_name   Name of the uploaded file
#' @param n_rows      Total rows
#' @param n_issues    Number of flagged issues
#' @param session     Shiny session
log_validation <- function(file_name, n_rows, n_issues, session = NULL) {
  user <- if (!is.null(session)) session$user %||% "anonymous" else "system"
  log_info(
    "[VALIDATION] user={user} file={file_name} rows={n_rows} issues={n_issues}"
  )
}

#' Log a database write event
#' @param table   Target table name
#' @param n_rows  Rows written
log_db_write <- function(table, n_rows) {
  log_info("[DB_WRITE] table={table} rows={n_rows}")
}

# Null coalescing operator (also needed in early utils)
`%||%` <- function(a, b) if (!is.null(a)) a else b
