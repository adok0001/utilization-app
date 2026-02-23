# ============================================================
# constants.R — App-wide constants
# ============================================================

# ── Standard full-time hours ────────────────────────────────
FTE_ANNUAL_HOURS <- 2080   # 52 weeks × 40 hours
FTE_MONTHLY_HOURS <- FTE_ANNUAL_HOURS / 12

# ── Required columns in uploaded files ──────────────────────
REQUIRED_COLS <- c(
  "physician_id",
  "physician_name",
  "service_date",
  "start_time",
  "end_time",
  "hours_worked",
  "payment_amount",
  "payment_type"
)

OPTIONAL_COLS <- c(
  "department",
  "specialty",
  "shift_type",
  "is_on_call",
  "notes"
)

# ── Accepted payment types ───────────────────────────────────
PAYMENT_TYPES <- c(
  "hourly",
  "stipend",
  "bonus",
  "incentive",
  "salary",
  "call_pay",
  "other"
)

# ── Shift types ──────────────────────────────────────────────
SHIFT_TYPES <- c("day", "evening", "night", "weekend", "holiday", "on_call")

# ── Thresholds (overridable via config/validation_rules.yaml) ─
MAX_SHIFT_HOURS      <- 24    # flag shifts longer than this
MIN_HOURLY_RATE      <- 50    # USD — below this is suspicious
MAX_HOURLY_RATE      <- 2000  # USD — above this is suspicious
MIN_PAYMENT_AMOUNT   <- 0     # negative amounts are invalid

# ── Date / time formats ──────────────────────────────────────
DATE_FORMAT   <- "%Y-%m-%d"
TIME_FORMAT   <- "%H:%M:%S"

# ── Colours (matches custom.css) ────────────────────────────
COL_PRIMARY   <- "#1e6091"
COL_SUCCESS   <- "#2ecc71"
COL_WARNING   <- "#f39c12"
COL_DANGER    <- "#e74c3c"
COL_INFO      <- "#3498db"
COL_MUTED     <- "#95a5a6"
