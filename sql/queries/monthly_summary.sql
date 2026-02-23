-- ============================================================
-- monthly_summary.sql — Pre-aggregated monthly metric query
-- ============================================================
-- Parameters: :year, :month (optional)

SELECT
    r.physician_id,
    r.physician_name,
    r.department,
    r.year,
    r.month,
    SUM(r.hours_worked)                                              AS total_hours,
    COUNT(DISTINCT r.service_date)                                   AS days_worked,
    COUNT(*)                                                          AS shift_count,
    SUM(r.payment_amount)                                            AS total_compensation,
    SUM(CASE WHEN r.payment_type = 'hourly'    THEN r.payment_amount ELSE 0 END) AS hourly_pay_total,
    SUM(CASE WHEN r.payment_type = 'stipend'   THEN r.payment_amount ELSE 0 END) AS stipend_total,
    SUM(CASE WHEN r.payment_type = 'bonus'     THEN r.payment_amount ELSE 0 END) AS bonus_total,
    SUM(CASE WHEN r.payment_type = 'incentive' THEN r.payment_amount ELSE 0 END) AS incentive_total,
    ROUND(SUM(r.hours_worked) / 173.33, 4)                          AS fte_pct,
    ROUND(SUM(r.payment_amount) / NULLIF(SUM(r.hours_worked), 0), 2) AS avg_hourly_rate,
    SUM(CASE WHEN r.shift_type = 'day'     THEN r.hours_worked ELSE 0 END) AS hours_day,
    SUM(CASE WHEN r.shift_type = 'evening' THEN r.hours_worked ELSE 0 END) AS hours_evening,
    SUM(CASE WHEN r.shift_type = 'night'   THEN r.hours_worked ELSE 0 END) AS hours_night,
    SUM(CASE WHEN r.shift_type = 'weekend' THEN r.hours_worked ELSE 0 END) AS hours_weekend

FROM physician_hours_raw r

WHERE (:year  IS NULL OR r.year  = :year)
  AND (:month IS NULL OR r.month = :month)

GROUP BY
    r.physician_id,
    r.physician_name,
    r.department,
    r.year,
    r.month

ORDER BY r.year, r.month, r.physician_name;
