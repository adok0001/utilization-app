# ============================================================
# seed_db.R — Load sample data into the SQLite database
# Run from the project root:  Rscript scripts/seed_db.R
# ============================================================

# Ensure working directory is the project root
setwd("/Users/tamaraadokeme/Projects/utilization-app")

# Source all required helpers in dependency order
source("R/utils/constants.R")
source("R/utils/formatting.R")
source("R/utils/logging.R")
source("R/utils/validation_rules.R")
source("R/data/import.R")
source("R/data/validate.R")
source("R/data/transform.R")
source("R/data/calculate_metrics.R")
source("R/database/init_db.R")
source("R/database/queries.R")
source("R/database/persistence.R")

# Initialise logger and database
init_logger()
con <- init_db("data/physician_utilization.sqlite")
on.exit(DBI::dbDisconnect(con), add = TRUE)

# ── Helper: seed one file ─────────────────────────────────────
seed_file <- function(path) {
  cat("Seeding:", path, "\n")
  raw   <- read_upload(file_path = path, file_name = basename(path))
  val   <- validate_upload(raw)
  if (val$n_errors > 0) {
    cat("  Validation issues:", val$n_errors, "errors – skipping hard failures but continuing\n")
  }
  clean <- clean_and_standardise(val$dt)

  log_id <- tryCatch({
    insert_upload_log(
      con,
      file_name   = basename(path),
      file_hash   = file_hash(path),
      n_rows      = nrow(clean),
      n_errors    = val$n_errors,
      n_warnings  = 0L,
      status      = if (val$pass) "success" else "warning"
    )
    DBI::dbGetQuery(con, "SELECT last_insert_rowid() AS id")$id
  }, error = function(e) NULL)

  persist_upload(con, clean, upload_log_id = log_id)
  cat("  Loaded", nrow(clean), "rows\n")
}

# ── Seed all sample files ─────────────────────────────────────
seed_file("sample_data/sample_upload_1.csv")
seed_file("sample_data/sample_upload_2.csv")

# ── Summary ───────────────────────────────────────────────────
n_raw  <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM physician_hours_raw")$n
n_mon  <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM physician_monthly_summary")$n
n_doc  <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM physician_master")$n

cat("\nDatabase seeded successfully:\n")
cat("  Raw rows:         ", n_raw,  "\n")
cat("  Monthly summaries:", n_mon,  "\n")
cat("  Physicians:       ", n_doc,  "\n")
