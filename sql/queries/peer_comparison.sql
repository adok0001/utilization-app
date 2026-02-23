-- ============================================================
-- peer_comparison.sql — Peer benchmarking query
-- ============================================================
-- Compares each physician to peers in the same department/year/month

WITH dept_averages AS (
    SELECT
        department,
        year,
        month,
        AVG(total_hours)       AS peer_avg_hours,
        AVG(total_compensation) AS peer_avg_compensation,
        AVG(avg_hourly_rate)   AS peer_avg_rate,
        COUNT(DISTINCT physician_id) AS peer_count
    FROM physician_monthly_summary
    GROUP BY department, year, month
)

SELECT
    m.*,
    d.peer_avg_hours,
    d.peer_avg_compensation,
    d.peer_avg_rate,
    d.peer_count,
    ROUND((m.total_hours       - d.peer_avg_hours)        / NULLIF(d.peer_avg_hours, 0),        4) AS vs_peer_hours_pct,
    ROUND((m.total_compensation - d.peer_avg_compensation) / NULLIF(d.peer_avg_compensation, 0), 4) AS vs_peer_comp_pct,
    ROUND((m.avg_hourly_rate   - d.peer_avg_rate)         / NULLIF(d.peer_avg_rate, 0),         4) AS vs_peer_rate_pct

FROM physician_monthly_summary m
LEFT JOIN dept_averages d
    ON m.department = d.department
   AND m.year       = d.year
   AND m.month      = d.month

ORDER BY m.year DESC, m.month DESC, m.physician_name;
