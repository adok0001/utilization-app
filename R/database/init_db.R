# ============================================================
# init_db.R — SQLite schema creation
# ============================================================
library(DBI)
library(RSQLite)

#' Initialise the SQLite database and create tables if they don't exist
#'
#' @param db_path  File path to the SQLite database file
#' @return         DBI connection object
init_db <- function(db_path = "data/physician_utilization.sqlite") {
  dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)

  con <- dbConnect(RSQLite::SQLite(), db_path)

  # Enable WAL mode for better concurrent performance
  dbExecute(con, "PRAGMA journal_mode=WAL;")
  dbExecute(con, "PRAGMA foreign_keys=ON;")

  # Locate sql/ directory — works whether CWD is project root or tests/
  sql_dir <- if (file.exists("sql/schema.sql")) "sql" else "../sql"

  # Read and execute schema SQL
  schema_sql <- readSQLFile(file.path(sql_dir, "schema.sql"))
  statements <- split_sql(schema_sql)
  for (stmt in statements) {
    if (nzchar(trimws(stmt))) dbExecute(con, stmt)
  }

  # Read and apply indexes
  index_sql <- readSQLFile(file.path(sql_dir, "indexes.sql"))
  idx_stmts <- split_sql(index_sql)
  for (stmt in idx_stmts) {
    if (nzchar(trimws(stmt))) {
      tryCatch(dbExecute(con, stmt), error = function(e) NULL) # ignore if exists
    }
  }

  log_info("Database initialised at {db_path}")
  con
}

#' Read a SQL file as a string
readSQLFile <- function(path) {
  if (!file.exists(path)) {
    warning(glue::glue("SQL file not found: {path}"))
    return("")
  }
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

#' Split a SQL string into individual statements on semicolons
split_sql <- function(sql_text) {
  stmts <- strsplit(sql_text, ";")[[1]]
  trimws(stmts[nzchar(trimws(stmts))])
}
