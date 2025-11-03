-- ============================================================================
-- RFID Badge Tracking: Modern Data Quality with Data Metric Functions (DMFs)
-- ============================================================================
-- Purpose: Leverage Snowflake's native Data Quality features using Data
--          Metric Functions for automated, continuous monitoring.
--
-- Architecture:
--   - System DMFs: Built-in Snowflake functions for common metrics
--   - Custom DMFs: User-defined functions for business-specific checks
--   - Associations: DMFs attached to tables with ON SCHEDULE execution
--   - Expectations: Thresholds that define pass/fail criteria
--
-- Benefits over manual queries:
--   - Automated execution on schedule or table changes
--   - Native monitoring and alerting integration
--   - Historical tracking of metrics over time
--   - Lower maintenance overhead
-- ============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA STAGE_BADGE_TRACKING;

-- ============================================================================
-- PREREQUISITE: Grant necessary privileges for DMF usage
-- ============================================================================
-- Must be run by ACCOUNTADMIN or a role with appropriate privileges

-- Grant the DATA_METRIC_USER database role to your current role
-- This provides USAGE privilege on all system DMFs
GRANT DATABASE ROLE SNOWFLAKE.DATA_METRIC_USER TO ROLE SYSADMIN;

-- Grant the ability to execute DMFs (uses serverless compute)
GRANT EXECUTE DATA METRIC FUNCTION ON ACCOUNT TO ROLE SYSADMIN;

-- If using a different role, replace SYSADMIN above with your role name

-- ============================================================================
-- 1. System DMF Associations: RAW_BADGE_EVENTS
-- ============================================================================

-- Set table-level schedule for all DMFs (runs every 5 minutes)
ALTER TABLE RAW_BADGE_EVENTS SET DATA_METRIC_SCHEDULE = '5 MINUTE';

-- NULL value monitoring on critical columns
ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
        ON (badge_id)
        EXPECTATION no_nulls (VALUE = 0);

ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
        ON (user_id)
        EXPECTATION no_nulls (VALUE = 0);

ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT 
        ON (event_timestamp)
        EXPECTATION no_nulls (VALUE = 0);

-- Duplicate detection on badge_id only (system DMF accepts single column)
ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT 
        ON (badge_id)
        EXPECTATION low_badge_duplicates (VALUE < 100);

-- Row count monitoring for volume anomalies
ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT 
        ON ()
        EXPECTATION min_volume (VALUE > 1000);

-- Freshness monitoring based on last DML operation
-- Note: FRESHNESS requires TIMESTAMP_LTZ or TIMESTAMP_TZ for column-based checks
-- Using table-level FRESHNESS instead (tracks last DML operation)
ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS 
        ON ()
        EXPECTATION recent_data (VALUE < 300);

-- Signal strength validation
ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.MIN 
        ON (signal_strength)
        EXPECTATION valid_min (VALUE >= -100);

ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.MAX 
        ON (signal_strength)
        EXPECTATION valid_max (VALUE <= 0);

-- ============================================================================
-- 2. System DMF Associations: STG_BADGE_EVENTS (Post-transformation)
-- ============================================================================

USE SCHEMA TRANSFORM_BADGE_TRACKING;

-- Set schedule for staging table DMFs
ALTER TABLE STG_BADGE_EVENTS SET DATA_METRIC_SCHEDULE = '5 MINUTE';

-- Verify deduplication worked (check badge_id duplicates only, system DMF limitation)
ALTER TABLE STG_BADGE_EVENTS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT 
        ON (badge_id)
        EXPECTATION no_duplicates (VALUE = 0);

-- Freshness check based on last DML operation
ALTER TABLE STG_BADGE_EVENTS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS 
        ON ()
        EXPECTATION fresh_staging (VALUE < 600);

-- Volume consistency (staging should have similar count to raw)
ALTER TABLE STG_BADGE_EVENTS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT 
        ON ()
        EXPECTATION reasonable_volume (VALUE > 0);

-- ============================================================================
-- 3. System DMF Associations: Analytics Layer
-- ============================================================================

USE SCHEMA ANALYTICS_BADGE_TRACKING;

-- Set schedules for analytics tables
ALTER TABLE FCT_ACCESS_EVENTS SET DATA_METRIC_SCHEDULE = '15 MINUTE';
ALTER TABLE DIM_USERS SET DATA_METRIC_SCHEDULE = '1 HOUR';
ALTER TABLE DIM_ZONES SET DATA_METRIC_SCHEDULE = '1 HOUR';

-- Fact table volume monitoring
ALTER TABLE FCT_ACCESS_EVENTS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT 
        ON ()
        EXPECTATION growing_fact (VALUE > 0);

-- Dimension table monitoring
ALTER TABLE DIM_USERS
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT 
        ON ()
        EXPECTATION active_users (VALUE > 0);

ALTER TABLE DIM_ZONES
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT 
        ON ()
        EXPECTATION active_zones (VALUE > 0);

-- ============================================================================
-- 4. Custom Data Metric Functions for Business Logic
-- ============================================================================

USE SCHEMA STAGE_BADGE_TRACKING;

-- Custom DMF: Check for composite duplicates (badge_id + event_timestamp)
CREATE OR REPLACE DATA METRIC FUNCTION dmf_composite_duplicates(
    arg_t TABLE(badge_id VARCHAR, event_timestamp TIMESTAMP_NTZ)
)
RETURNS NUMBER
AS
$$
    WITH duplicates AS (
        SELECT 
            badge_id,
            event_timestamp,
            COUNT(*) AS occurrence_count
        FROM arg_t
        GROUP BY badge_id, event_timestamp
        HAVING COUNT(*) > 1
    )
    SELECT COALESCE(COUNT(*), 0)
    FROM duplicates
$$;

-- Custom DMF: Check for invalid direction values
CREATE OR REPLACE DATA METRIC FUNCTION dmf_invalid_direction(
    arg_t TABLE(direction VARCHAR)
)
RETURNS NUMBER
AS
$$
    SELECT COALESCE(COUNT(*), 0)
    FROM arg_t
    WHERE direction NOT IN ('ENTRY', 'EXIT')
      AND direction IS NOT NULL
$$;

-- Associate custom DMFs (schedule already set at table level)
ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION dmf_composite_duplicates
        ON (badge_id, event_timestamp)
        EXPECTATION low_composite_duplicates (VALUE < 10);

ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION dmf_invalid_direction
        ON (direction)
        EXPECTATION no_invalid_directions (VALUE = 0);

-- Custom DMF: Check for future timestamps
CREATE OR REPLACE DATA METRIC FUNCTION dmf_future_timestamps(
    arg_t TABLE(event_timestamp TIMESTAMP_NTZ)
)
RETURNS NUMBER
AS
$$
    SELECT COALESCE(COUNT(*), 0)
    FROM arg_t
    WHERE event_timestamp > SNOWFLAKE.CORE.DATA_METRIC_SCHEDULED_TIME()
$$;

ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION dmf_future_timestamps
        ON (event_timestamp)
        EXPECTATION no_future_events (VALUE = 0);

-- Custom DMF: Check for abnormally high user activity
CREATE OR REPLACE DATA METRIC FUNCTION dmf_high_activity_users(
    arg_t TABLE(user_id VARCHAR, event_timestamp TIMESTAMP_NTZ)
)
RETURNS NUMBER
AS
$$
    WITH user_activity AS (
        SELECT 
            user_id,
            COUNT(*) AS event_count
        FROM arg_t
        WHERE event_timestamp >= DATEADD('hour', -1, SNOWFLAKE.CORE.DATA_METRIC_SCHEDULED_TIME())
        GROUP BY user_id
    )
    SELECT COALESCE(COUNT(*), 0)
    FROM user_activity
    WHERE event_count > 100
$$;

ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION dmf_high_activity_users
        ON (user_id, event_timestamp)
        EXPECTATION few_high_activity (VALUE < 5);

-- Custom DMF: Check weak signal zones
CREATE OR REPLACE DATA METRIC FUNCTION dmf_weak_signal_zones(
    arg_t TABLE(zone_id VARCHAR, signal_quality VARCHAR, ingestion_time TIMESTAMP_NTZ)
)
RETURNS NUMBER
AS
$$
    WITH zone_signals AS (
        SELECT 
            zone_id,
            COUNT(*) AS total_events,
            SUM(CASE WHEN signal_quality = 'WEAK' THEN 1 ELSE 0 END) AS weak_signals,
            100.0 * SUM(CASE WHEN signal_quality = 'WEAK' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS weak_pct
        FROM arg_t
        WHERE ingestion_time >= DATEADD('hour', -1, SNOWFLAKE.CORE.DATA_METRIC_SCHEDULED_TIME())
        GROUP BY zone_id
        HAVING COUNT(*) > 10
    )
    SELECT COALESCE(COUNT(*), 0)
    FROM zone_signals
    WHERE weak_pct > 50
$$;

ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION dmf_weak_signal_zones
        ON (zone_id, signal_quality, ingestion_time)
        EXPECTATION few_weak_zones (VALUE < 3);

-- Custom DMF: Referential integrity check (orphaned fact records)
-- This DMF accepts TWO table arguments to check referential integrity
CREATE OR REPLACE DATA METRIC FUNCTION dmf_orphaned_fact_users(
    fact_table TABLE(user_sk NUMBER),
    dim_table TABLE(user_sk NUMBER, is_active BOOLEAN)
)
RETURNS NUMBER
AS
$$
    SELECT COALESCE(COUNT(*), 0)
    FROM fact_table f
    WHERE NOT EXISTS (
        SELECT 1 
        FROM dim_table d
        WHERE f.user_sk = d.user_sk
          AND d.is_active = TRUE
    )
$$;

USE SCHEMA ANALYTICS_BADGE_TRACKING;

-- Associate the orphaned records check (schedule already set at table level)
-- Note: Multi-table DMF association syntax needs further investigation
-- For now, this DMF is created but not yet associated
-- TODO: Verify correct syntax for associating multi-table DMFs
-- Expected syntax: ALTER TABLE FCT_ACCESS_EVENTS ADD DATA METRIC FUNCTION ... ON (user_sk, '<second_table_fqn>');

-- Placeholder for future association
-- ALTER TABLE FCT_ACCESS_EVENTS
--     ADD DATA METRIC FUNCTION SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.dmf_orphaned_fact_users
--         ON (user_sk, 'SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.DIM_USERS')
--         EXPECTATION no_orphans (VALUE = 0);

-- ============================================================================
-- 5. Monitoring Views: Query DMF Results
-- ============================================================================

USE SCHEMA STAGE_BADGE_TRACKING;

-- View recent DMF measurements
CREATE OR REPLACE VIEW V_DMF_MEASUREMENTS AS
SELECT 
    table_catalog,
    table_schema,
    table_name,
    data_metric_name,
    measurement_time,
    value,
    expectation_pass
FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_QUALITY_MONITORING_RESULTS
WHERE table_catalog = 'SNOWFLAKE_EXAMPLE'
  AND measurement_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY measurement_time DESC;

-- View recent expectation violations
CREATE OR REPLACE VIEW V_DMF_VIOLATIONS AS
SELECT 
    table_catalog,
    table_schema,
    table_name,
    data_metric_name,
    expectation_name,
    measurement_time,
    value,
    expectation_pass
FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_QUALITY_MONITORING_RESULTS
WHERE table_catalog = 'SNOWFLAKE_EXAMPLE'
  AND expectation_pass = FALSE
  AND measurement_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY measurement_time DESC;

-- Dashboard: Current DQ Status
CREATE OR REPLACE VIEW V_DQ_DASHBOARD AS
WITH latest_measurements AS (
    SELECT 
        table_schema,
        table_name,
        data_metric_name,
        expectation_name,
        measurement_time,
        value,
        expectation_pass,
        ROW_NUMBER() OVER (PARTITION BY table_schema, table_name, data_metric_name ORDER BY measurement_time DESC) AS rn
    FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_QUALITY_MONITORING_RESULTS
    WHERE table_catalog = 'SNOWFLAKE_EXAMPLE'
      AND measurement_time >= DATEADD('day', -1, CURRENT_TIMESTAMP())
)
SELECT 
    table_schema,
    table_name,
    data_metric_name,
    expectation_name,
    measurement_time,
    value,
    CASE 
        WHEN expectation_pass = TRUE THEN 'PASS'
        WHEN expectation_pass = FALSE THEN 'FAIL'
        ELSE 'NO_EXPECTATION'
    END AS status,
    DATEDIFF('minute', measurement_time, CURRENT_TIMESTAMP()) AS minutes_since_check
FROM latest_measurements
WHERE rn = 1
ORDER BY expectation_pass NULLS LAST, measurement_time DESC;

-- ============================================================================
-- 6. Alerting Integration (Example using SYSTEM$SEND_EMAIL)
-- ============================================================================

-- Create a task to check for violations and send alerts
CREATE OR REPLACE TASK task_dq_alert_check
    WAREHOUSE = ETL_WH
    SCHEDULE = '15 MINUTE'
AS
DECLARE
    violation_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO :violation_count
    FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_QUALITY_MONITORING_RESULTS
    WHERE table_catalog = 'SNOWFLAKE_EXAMPLE'
      AND expectation_pass = FALSE
      AND measurement_time >= DATEADD('minute', -15, CURRENT_TIMESTAMP());
    
    IF (violation_count > 0) THEN
        CALL SYSTEM$SEND_EMAIL(
            'data_quality_notifications',
            'ops-team@company.com',
            'Data Quality Alert: Expectation Violations Detected',
            CONCAT(
                'Number of violations in last 15 minutes: ',
                violation_count::STRING,
                '\n\nPlease check V_DMF_VIOLATIONS view for details.'
            )
        );
    END IF;
END;

-- Note: Activate the task after email integration is configured
-- ALTER TASK task_dq_alert_check RESUME;

-- ============================================================================
-- 7. Management Commands
-- ============================================================================

-- View all DMF associations for a table
-- SHOW DATA METRIC FUNCTIONS IN TABLE RAW_BADGE_EVENTS;

-- Suspend a specific DMF association (during maintenance)
-- ALTER TABLE RAW_BADGE_EVENTS
--     MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS
--         ON (ingestion_time)
--         SUSPEND;

-- Resume a suspended DMF
-- ALTER TABLE RAW_BADGE_EVENTS
--     MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS
--         ON (ingestion_time)
--         RESUME;

-- Remove a DMF association
-- ALTER TABLE RAW_BADGE_EVENTS
--     DROP DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON (ingestion_time);

-- Modify an expectation
-- ALTER TABLE RAW_BADGE_EVENTS
--     MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS
--         ON (ingestion_time)
--         MODIFY EXPECTATION recent_data (VALUE < 600);

-- ============================================================================
-- 8. Query Historical DMF Results
-- ============================================================================

-- Trend analysis: Row count over time
-- SELECT 
--     measurement_time,
--     value AS row_count
-- FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_QUALITY_MONITORING_RESULTS
-- WHERE table_name = 'RAW_BADGE_EVENTS'
--   AND data_metric_name = 'ROW_COUNT'
--   AND measurement_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
-- ORDER BY measurement_time;

-- Expectation pass rate by metric
-- SELECT 
--     data_metric_name,
--     COUNT(*) AS total_checks,
--     SUM(CASE WHEN expectation_pass = TRUE THEN 1 ELSE 0 END) AS passed,
--     SUM(CASE WHEN expectation_pass = FALSE THEN 1 ELSE 0 END) AS failed,
--     ROUND(100.0 * passed / NULLIF(total_checks, 0), 2) AS pass_rate_pct
-- FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_QUALITY_MONITORING_RESULTS
-- WHERE table_name = 'RAW_BADGE_EVENTS'
--   AND measurement_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
-- GROUP BY data_metric_name
-- ORDER BY pass_rate_pct;

-- ============================================================================
-- DEPLOYMENT NOTES
-- ============================================================================
--
-- 1. Grant Privileges:
--    GRANT DATABASE ROLE SNOWFLAKE.DATA_METRIC_USER TO ROLE <your_etl_role>;
--
-- 2. Run this script to create all DMF associations
--
-- 3. Monitor via:
--    - V_DQ_DASHBOARD: Current status
--    - V_DMF_VIOLATIONS: Recent failures
--    - SNOWFLAKE.ACCOUNT_USAGE.DATA_QUALITY_MONITORING_RESULTS: Historical data
--
-- 4. Set up email integration for alerting (requires ACCOUNTADMIN)
--
-- 5. Adjust schedules and expectations based on your SLAs
--
-- ============================================================================

