-- ============================================================================
-- RFID Badge Tracking: Data Quality Checks
-- ============================================================================
-- Purpose: Comprehensive data quality validation queries for the badge
--          tracking pipeline. These checks should be run regularly to
--          ensure data integrity.
--
-- Check Categories:
--   1. Null Value Checks
--   2. Duplicate Detection
--   3. Referential Integrity
--   4. Business Logic Validation
--   5. Anomaly Detection
-- ============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA STAGE_BADGE_TRACKING;

-- ============================================================================
-- 1. Null Value Checks
-- ============================================================================

-- Check for null values in required fields
SELECT 
    'RAW_BADGE_EVENTS' AS table_name,
    'Null required fields' AS check_type,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) > 0 THEN 'FAIL' ELSE 'PASS' END AS status
FROM RAW_BADGE_EVENTS
WHERE badge_id IS NULL
   OR user_id IS NULL
   OR zone_id IS NULL
   OR event_timestamp IS NULL
   OR ingestion_time IS NULL;

-- ============================================================================
-- 2. Duplicate Detection
-- ============================================================================

-- Check for duplicate events (same badge, timestamp)
WITH duplicates AS (
    SELECT 
        badge_id,
        event_timestamp,
        COUNT(*) AS occurrence_count
    FROM RAW_BADGE_EVENTS
    GROUP BY badge_id, event_timestamp
    HAVING COUNT(*) > 1
)
SELECT 
    'RAW_BADGE_EVENTS' AS table_name,
    'Duplicate events' AS check_type,
    COUNT(*) AS violation_count,
    SUM(occurrence_count) AS total_duplicate_rows,
    CASE WHEN COUNT(*) > 0 THEN 'WARN' ELSE 'PASS' END AS status
FROM duplicates;

-- Check staging table for duplicates (should be zero after QUALIFY)
WITH stg_duplicates AS (
    SELECT 
        badge_id,
        event_timestamp,
        COUNT(*) AS occurrence_count
    FROM SNOWFLAKE_EXAMPLE.TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS
    GROUP BY badge_id, event_timestamp
    HAVING COUNT(*) > 1
)
SELECT 
    'STG_BADGE_EVENTS' AS table_name,
    'Duplicate events' AS check_type,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) > 0 THEN 'FAIL' ELSE 'PASS' END AS status
FROM stg_duplicates;

-- ============================================================================
-- 3. Referential Integrity
-- ============================================================================

-- Check for orphaned records in fact table (missing user dimension)
SELECT 
    'FCT_ACCESS_EVENTS' AS table_name,
    'Orphaned records - missing user' AS check_type,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) > 0 THEN 'FAIL' ELSE 'PASS' END AS status
FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS f
WHERE NOT EXISTS (
    SELECT 1 FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.DIM_USERS u
    WHERE f.user_key = u.user_key
);

-- Check for orphaned records in fact table (missing zone dimension)
SELECT 
    'FCT_ACCESS_EVENTS' AS table_name,
    'Orphaned records - missing zone' AS check_type,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) > 0 THEN 'FAIL' ELSE 'PASS' END AS status
FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS f
WHERE NOT EXISTS (
    SELECT 1 FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.DIM_ZONES z
    WHERE f.zone_key = z.zone_key
);

-- ============================================================================
-- 4. Business Logic Validation
-- ============================================================================

-- Check for invalid signal strength (should be between -100 and 0 dBm)
SELECT 
    'RAW_BADGE_EVENTS' AS table_name,
    'Invalid signal strength' AS check_type,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) > 0 THEN 'WARN' ELSE 'PASS' END AS status
FROM RAW_BADGE_EVENTS
WHERE signal_strength NOT BETWEEN -100 AND 0
  AND signal_strength <> -999;  -- -999 is allowed as "unknown"

-- Check for events with future timestamps
SELECT 
    'RAW_BADGE_EVENTS' AS table_name,
    'Future timestamps' AS check_type,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) > 0 THEN 'FAIL' ELSE 'PASS' END AS status
FROM RAW_BADGE_EVENTS
WHERE event_timestamp > CURRENT_TIMESTAMP();

-- Check for events older than 30 days (possible data quality issue)
SELECT 
    'RAW_BADGE_EVENTS' AS table_name,
    'Very old events' AS check_type,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) > 0 THEN 'WARN' ELSE 'PASS' END AS status
FROM RAW_BADGE_EVENTS
WHERE event_timestamp < DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND ingestion_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP());  -- Recently ingested

-- Check for invalid direction values
SELECT 
    'RAW_BADGE_EVENTS' AS table_name,
    'Invalid direction values' AS check_type,
    COUNT(*) AS violation_count,
    CASE WHEN COUNT(*) > 0 THEN 'WARN' ELSE 'PASS' END AS status
FROM RAW_BADGE_EVENTS
WHERE direction NOT IN ('ENTRY', 'EXIT') 
  AND direction IS NOT NULL;

-- ============================================================================
-- 5. Anomaly Detection
-- ============================================================================

-- Detect sudden drop in ingestion rate (< 50% of average)
WITH hourly_rates AS (
    SELECT 
        DATE_TRUNC('hour', ingestion_time) AS hour,
        COUNT(*) AS event_count
    FROM RAW_BADGE_EVENTS
    WHERE ingestion_time >= DATEADD('day', -1, CURRENT_TIMESTAMP())
    GROUP BY DATE_TRUNC('hour', ingestion_time)
),
avg_rate AS (
    SELECT AVG(event_count) AS avg_events_per_hour
    FROM hourly_rates
)
SELECT 
    'RAW_BADGE_EVENTS' AS table_name,
    'Ingestion rate drop' AS check_type,
    h.hour,
    h.event_count,
    a.avg_events_per_hour,
    ROUND(100.0 * h.event_count / NULLIF(a.avg_events_per_hour, 0), 2) AS pct_of_average,
    CASE WHEN h.event_count < 0.5 * a.avg_events_per_hour THEN 'WARN' ELSE 'PASS' END AS status
FROM hourly_rates h
CROSS JOIN avg_rate a
WHERE h.hour >= DATEADD('hour', -3, CURRENT_TIMESTAMP())
ORDER BY h.hour DESC;

-- Detect users with abnormally high activity (> 100 events/hour)
WITH user_activity AS (
    SELECT 
        user_id,
        DATE_TRUNC('hour', event_timestamp) AS hour,
        COUNT(*) AS event_count
    FROM RAW_BADGE_EVENTS
    WHERE event_timestamp >= DATEADD('day', -1, CURRENT_TIMESTAMP())
    GROUP BY user_id, DATE_TRUNC('hour', event_timestamp)
    HAVING COUNT(*) > 100
)
SELECT 
    'RAW_BADGE_EVENTS' AS table_name,
    'Abnormal user activity' AS check_type,
    user_id,
    hour,
    event_count,
    CASE WHEN event_count > 100 THEN 'WARN' ELSE 'PASS' END AS status
FROM user_activity
ORDER BY event_count DESC;

-- Detect zones with unusual weak signal rates (> 50%)
WITH zone_signals AS (
    SELECT 
        zone_id,
        COUNT(*) AS total_events,
        SUM(CASE WHEN signal_quality = 'WEAK' THEN 1 ELSE 0 END) AS weak_signals,
        ROUND(100.0 * SUM(CASE WHEN signal_quality = 'WEAK' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS weak_signal_pct
    FROM RAW_BADGE_EVENTS
    WHERE ingestion_time >= DATEADD('day', -1, CURRENT_TIMESTAMP())
    GROUP BY zone_id
    HAVING COUNT(*) > 10  -- Minimum threshold
)
SELECT 
    'RAW_BADGE_EVENTS' AS table_name,
    'High weak signal rate' AS check_type,
    zone_id,
    total_events,
    weak_signals,
    weak_signal_pct,
    CASE WHEN weak_signal_pct > 50 THEN 'WARN' ELSE 'PASS' END AS status
FROM zone_signals
WHERE weak_signal_pct > 50
ORDER BY weak_signal_pct DESC;

-- ============================================================================
-- Summary Dashboard
-- ============================================================================

-- Create a summary view of all checks
CREATE OR REPLACE VIEW V_DATA_QUALITY_SUMMARY AS
WITH all_checks AS (
    -- Combine all check results here
    -- This would aggregate the individual check queries above
    SELECT 
        CURRENT_TIMESTAMP() AS check_timestamp,
        'Placeholder for aggregated checks' AS note
)
SELECT * FROM all_checks;

-- ============================================================================
-- USAGE NOTES
-- ============================================================================
-- 
-- Schedule these checks to run regularly:
--   - Run null and duplicate checks every hour
--   - Run referential integrity checks after each task run
--   - Run business logic validation daily
--   - Run anomaly detection every 15 minutes
-- 
-- Alert on failures:
--   - FAIL status: Immediate alert and investigation
--   - WARN status: Monitor and investigate if persists
--   - PASS status: No action needed
-- 
-- Automated monitoring:
--   Create a task to run these checks and store results in a DQ log table
--   Send notifications to operations team for failures
-- ============================================================================

