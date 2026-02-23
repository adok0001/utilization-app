-- ============================================================
-- indexes.sql — Performance indexes
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_raw_physician_date
    ON physician_hours_raw (physician_id, service_date);

CREATE INDEX IF NOT EXISTS idx_raw_year_month
    ON physician_hours_raw (year, month);

CREATE INDEX IF NOT EXISTS idx_raw_department
    ON physician_hours_raw (department);

CREATE INDEX IF NOT EXISTS idx_monthly_physician
    ON physician_monthly_summary (physician_id, year, month);

CREATE INDEX IF NOT EXISTS idx_monthly_dept
    ON physician_monthly_summary (department, year, month);

CREATE INDEX IF NOT EXISTS idx_annual_physician
    ON physician_annual_summary (physician_id, year);

CREATE INDEX IF NOT EXISTS idx_upload_log_status
    ON upload_log (status, uploaded_at);

CREATE INDEX IF NOT EXISTS idx_validation_upload
    ON validation_issues (upload_id);
