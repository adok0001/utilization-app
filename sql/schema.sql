-- ============================================================
-- schema.sql — SQLite database schema
-- ============================================================

-- Raw uploaded physician hours data
CREATE TABLE IF NOT EXISTS physician_hours_raw (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    physician_id      TEXT    NOT NULL,
    physician_name    TEXT    NOT NULL,
    service_date      TEXT    NOT NULL,   -- ISO 8601: YYYY-MM-DD
    start_time        TEXT,               -- HH:MM:SS
    end_time          TEXT,               -- HH:MM:SS
    hours_worked      REAL    NOT NULL,
    payment_amount    REAL    NOT NULL,
    payment_type      TEXT,
    department        TEXT,
    specialty         TEXT,
    shift_type        TEXT,
    is_on_call        INTEGER DEFAULT 0,  -- boolean 0/1
    notes             TEXT,
    year              INTEGER,
    month             INTEGER,
    week              INTEGER,
    upload_id         INTEGER,            -- FK → upload_log.id
    loaded_at         TEXT,
    FOREIGN KEY (upload_id) REFERENCES upload_log(id)
);

-- Pre-aggregated monthly summaries (rebuilt on each upload)
CREATE TABLE IF NOT EXISTS physician_monthly_summary (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    physician_id          TEXT    NOT NULL,
    physician_name        TEXT    NOT NULL,
    department            TEXT,
    year                  INTEGER NOT NULL,
    month                 INTEGER NOT NULL,
    total_hours           REAL,
    days_worked           INTEGER,
    shift_count           INTEGER,
    total_compensation    REAL,
    hourly_pay_total      REAL,
    stipend_total         REAL,
    bonus_total           REAL,
    incentive_total       REAL,
    n_payment_records     INTEGER,
    fte_pct               REAL,
    avg_hourly_rate       REAL,
    hours_day             REAL DEFAULT 0,
    hours_evening         REAL DEFAULT 0,
    hours_night           REAL DEFAULT 0,
    hours_weekend         REAL DEFAULT 0,
    hours_holiday         REAL DEFAULT 0,
    hours_on_call         REAL DEFAULT 0,
    peer_avg_hours        REAL,
    peer_avg_rate         REAL,
    vs_peer_hours_pct     REAL,
    vs_peer_rate_pct      REAL,
    UNIQUE(physician_id, year, month)
);

-- Annual rollup
CREATE TABLE IF NOT EXISTS physician_annual_summary (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    physician_id          TEXT    NOT NULL,
    physician_name        TEXT    NOT NULL,
    department            TEXT,
    year                  INTEGER NOT NULL,
    total_hours           REAL,
    total_compensation    REAL,
    days_worked           INTEGER,
    shift_count           INTEGER,
    months_active         INTEGER,
    fte_pct               REAL,
    avg_hourly_rate       REAL,
    UNIQUE(physician_id, year)
);

-- Physician master / roster
CREATE TABLE IF NOT EXISTS physician_master (
    physician_id    TEXT PRIMARY KEY,
    physician_name  TEXT NOT NULL,
    department      TEXT,
    specialty       TEXT,
    first_seen      TEXT,
    is_active       INTEGER DEFAULT 1
);

-- Upload audit log
CREATE TABLE IF NOT EXISTS upload_log (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    file_name       TEXT    NOT NULL,
    file_hash       TEXT,
    uploaded_at     TEXT    NOT NULL,
    uploaded_by     TEXT    DEFAULT 'anonymous',
    n_rows          INTEGER,
    n_errors        INTEGER DEFAULT 0,
    n_warnings      INTEGER DEFAULT 0,
    status          TEXT    NOT NULL    -- 'success' | 'failed' | 'pending'
);

-- Validation issues (linked to upload_log)
CREATE TABLE IF NOT EXISTS validation_issues (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    upload_id       INTEGER,
    row_num         INTEGER,
    column_name     TEXT,
    issue           TEXT,
    severity        TEXT,               -- 'error' | 'warning'
    resolved        INTEGER DEFAULT 0,  -- 0 = open, 1 = resolved
    resolved_by     TEXT,
    resolved_at     TEXT,
    FOREIGN KEY (upload_id) REFERENCES upload_log(id)
);
