-- ============================================================================
-- Final Custom DMF Setup
-- Purpose: Create and associate all custom DMFs (safe to re-run)
-- Note: System DMFs are already configured
-- ============================================================================

USE DATABASE SNOWFLAKE_EXAMPLE;
USE SCHEMA STAGE_BADGE_TRACKING;

SELECT '=== Creating Custom DMFs ===' AS status;

-- Custom DMF 1: Composite duplicates (badge_id + event_timestamp)
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

-- Custom DMF 2: Invalid direction values
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

-- Custom DMF 3: Future timestamps
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

-- Custom DMF 4: High activity users (last hour)
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

-- Custom DMF 5: Weak signal zones
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

-- Custom DMF 6: Orphaned fact records (cross-table referential integrity)
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

SELECT '✅ All custom DMF functions created' AS status;

SELECT '=== Associating Custom DMFs (errors for "already exists" are normal) ===' AS status;

-- Note: These will error if already associated - that's expected and OK
-- To update an existing association, use: ALTER TABLE ... MODIFY DATA METRIC FUNCTION ...

-- Associate with RAW_BADGE_EVENTS
ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION dmf_composite_duplicates
        ON (badge_id, event_timestamp)
        EXPECTATION low_composite_duplicates (VALUE < 10);

ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION dmf_invalid_direction
        ON (direction)
        EXPECTATION no_invalid_directions (VALUE = 0);

ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION dmf_future_timestamps
        ON (event_timestamp)
        EXPECTATION no_future_events (VALUE = 0);

ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION dmf_high_activity_users
        ON (user_id, event_timestamp)
        EXPECTATION few_high_activity (VALUE < 5);

ALTER TABLE RAW_BADGE_EVENTS
    ADD DATA METRIC FUNCTION dmf_weak_signal_zones
        ON (zone_id, signal_quality, ingestion_time)
        EXPECTATION few_weak_zones (VALUE < 3);

-- Associate with FCT_ACCESS_EVENTS (cross-schema)
USE SCHEMA ANALYTICS_BADGE_TRACKING;

ALTER TABLE FCT_ACCESS_EVENTS
    ADD DATA METRIC FUNCTION SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.dmf_orphaned_fact_users
        ON (
            (SELECT user_sk FROM FCT_ACCESS_EVENTS),
            (SELECT user_sk, is_active FROM DIM_USERS)
        )
        EXPECTATION no_orphans (VALUE = 0);

SELECT '🎯 Custom DMF setup complete! (Ignore "already exists" errors above)' AS final_status;

-- To view DMF results, query the monitoring views in the main dq_checks_dmf.sql file

