-- ============================================================
-- variance_analysis.sql — Budget vs. Actual variance breakdown
-- ============================================================
-- Requires a contracted_hours table (physician_id, year, month, contracted_hours, contracted_rate)
-- If no contract table exists, variance columns will be NULL.

SELECT
    m.physician_id,
    m.physician_name,
    m.department,
    m.year,
    m.month,
    m.total_hours                                                        AS actual_hours,
    c.contracted_hours,
    (m.total_hours - c.contracted_hours)                                 AS hours_variance,
    ROUND((m.total_hours - c.contracted_hours) / NULLIF(c.contracted_hours, 0), 4) AS hours_variance_pct,

    m.total_compensation                                                 AS actual_compensation,
    (c.contracted_hours * c.contracted_rate)                             AS budgeted_compensation,
    (m.total_compensation - (c.contracted_hours * c.contracted_rate))   AS comp_variance,
    ROUND(
        (m.total_compensation - (c.contracted_hours * c.contracted_rate))
        / NULLIF(c.contracted_hours * c.contracted_rate, 0), 4
    )                                                                    AS comp_variance_pct,

    -- Volume variance: how much of the comp variance is due to hours change
    ROUND((m.total_hours - c.contracted_hours) * c.contracted_rate, 2)  AS volume_variance,
    -- Rate variance: how much is due to rate change
    ROUND((m.avg_hourly_rate - c.contracted_rate) * m.total_hours, 2)   AS rate_variance

FROM physician_monthly_summary m
LEFT JOIN contracted_hours c
    ON m.physician_id = c.physician_id
   AND m.year         = c.year
   AND m.month        = c.month

ORDER BY m.year DESC, m.month DESC, ABS(comp_variance) DESC NULLS LAST;
