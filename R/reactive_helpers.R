# ============================================================
# reactive_helpers.R — Shared reactive expressions and caching
# ============================================================

#' Build a reactive that returns the physician list (cached)
#' Invalidated only when r$upload_ts changes.
reactive_physician_list <- function(r) {
  reactive({
    r$upload_ts  # dependency — refresh after each upload
    get_physician_list(r$db_con)
  })
}

#' Build a reactive that returns the monthly summary table
#' with peer comparison columns added.
reactive_monthly_summary <- function(r) {
  reactive({
    r$upload_ts
    dt <- get_monthly_summary(r$db_con)
    if (nrow(dt) > 0) add_peer_comparison(dt) else dt
  })
}

#' Build a reactive that returns the department summary
reactive_dept_summary <- function(r) {
  reactive({
    r$upload_ts
    get_department_summary(r$db_con)
  })
}

#' Build a reactive that returns dashboard KPIs
reactive_kpis <- function(r) {
  reactive({
    r$upload_ts
    get_dashboard_kpis(r$db_con)
  })
}

#' Build a reactive that returns the upload log
reactive_upload_history <- function(r) {
  reactive({
    r$upload_ts
    get_upload_history(r$db_con)
  })
}

#' Utility: null-coalescing operator already in logging.R —
#' re-export so modules can use without sourcing logging.R directly
`%||%` <- function(a, b) if (!is.null(a) && !is.na(a)) a else b
