# Pipeline Validation Guide

After inserting 3000 rows, use these commands to validate the data flow through the pipeline.

## Quick Validation (Recommended First)

### Option 1: Using the validation script (Cross-Platform)
```bash
# Windows
validate_pipeline.bat quick

# macOS/Linux
./validate_pipeline.sh quick

# Or Python directly (all platforms)
python -m python.cli_tools.validate_pipeline quick
```

### Option 2: Direct SQL command
```bash
snow sql -f sql/validation/quick_check.sql
```

### Option 3: Inline SQL query
```bash
snow sql -q "
USE DATABASE SNOWFLAKE_EXAMPLE;
SELECT 'RAW' AS layer, COUNT(*) FROM STAGE_BADGE_TRACKING.RAW_BADGE_EVENTS
UNION ALL
SELECT 'STAGING', COUNT(*) FROM TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS
UNION ALL
SELECT 'ANALYTICS', COUNT(*) FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS;
"
```

## Expected Results for 3000 Rows

```
Layer      | Row Count
-----------|----------
RAW        | 3000
STAGING    | 3000
ANALYTICS  | 3000
```

**Stream Status**: Should be `False` (empty) after tasks process all data

## Full Validation Suite

For comprehensive analysis:
```bash
./scripts/validate_pipeline.sh full
```

Or run directly:
```bash
snow sql -f sql/validation/check_pipeline.sql
```

This provides:
- ✅ Row counts across all layers
- ✅ Stream status
- ✅ Dimension table statistics
- ✅ Event distribution by date
- ✅ Signal quality analysis
- ✅ After-hours/weekend event counts
- ✅ Top active zones and badges
- ✅ Task execution history
- ✅ Data completeness checks
- ✅ Processing latency metrics

## Individual Check Commands

### 1. Check Raw Table
```bash
snow sql -q "SELECT COUNT(*) AS raw_count FROM SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.RAW_BADGE_EVENTS;"
```

### 2. Check Stream Status
```bash
snow sql -q "SELECT SYSTEM\$STREAM_HAS_DATA('SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.raw_badge_events_stream') AS has_data;"
```

### 3. Check Staging Table
```bash
snow sql -q "SELECT COUNT(*) AS staging_count FROM SNOWFLAKE_EXAMPLE.TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS;"
```

### 4. Check Fact Table
```bash
snow sql -q "SELECT COUNT(*) AS fact_count FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS;"
```

### 5. Check Task Status
```bash
snow sql -q "SHOW TASKS IN DATABASE SNOWFLAKE_EXAMPLE;"
```

### 6. Check Recent Task Runs
```bash
snow sql -q "
SELECT 
    name,
    state,
    scheduled_time,
    completed_time,
    error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
WHERE database_name = 'SNOWFLAKE_EXAMPLE'
ORDER BY scheduled_time DESC
LIMIT 10;
"
```

### 7. Check User Dimension Growth
```bash
snow sql -q "
SELECT 
    COUNT(*) AS total_users,
    COUNT(CASE WHEN user_name = 'UNKNOWN' THEN 1 END) AS auto_created_users
FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.DIM_USERS
WHERE is_current = TRUE;
"
```

### 8. View Event Date Distribution
```bash
snow sql -q "
SELECT 
    event_date,
    COUNT(*) AS event_count
FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS
GROUP BY event_date
ORDER BY event_date DESC;
"
```

### 9. Check Processing Latency
```bash
snow sql -q "
SELECT 
    MIN(DATEDIFF('second', ingestion_time, fact_load_time)) AS min_latency_sec,
    AVG(DATEDIFF('second', ingestion_time, fact_load_time)) AS avg_latency_sec,
    MAX(DATEDIFF('second', ingestion_time, fact_load_time)) AS max_latency_sec
FROM SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS;
"
```

## Troubleshooting

### Problem: Row counts don't match

**Cause**: Tasks are still processing data

**Solution**:
1. Wait 1-2 minutes (tasks run every 1 minute)
2. Re-run the quick validation
3. Check task execution:
```bash
snow sql -q "
SELECT name, state, scheduled_time, completed_time, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE database_name = 'SNOWFLAKE_EXAMPLE'
ORDER BY scheduled_time DESC
LIMIT 5;
"
```

### Problem: Stream still has data

**Cause**: Tasks haven't consumed the stream yet

**Check**: 
```bash
snow sql -q "SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.STAGE_BADGE_TRACKING.raw_badge_events_stream;"
```

**Wait**: 1-2 minutes and recheck

### Problem: Fact table count < Staging count

**Cause**: Missing dimension keys (users/zones not in dimension tables)

**Check**:
```bash
snow sql -q "
SELECT 
    s.user_id,
    COUNT(*) AS event_count
FROM SNOWFLAKE_EXAMPLE.TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS s
LEFT JOIN SNOWFLAKE_EXAMPLE.ANALYTICS_BADGE_TRACKING.DIM_USERS u 
    ON s.user_id = u.user_id AND u.is_current = TRUE
WHERE u.user_key IS NULL
GROUP BY s.user_id;
"
```

### Problem: Tasks show errors

**View error details**:
```bash
snow sql -q "
SELECT 
    name,
    scheduled_time,
    state,
    error_code,
    error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE database_name = 'SNOWFLAKE_EXAMPLE'
  AND state = 'FAILED'
ORDER BY scheduled_time DESC;
"
```

## Monitoring During Processing

Watch the pipeline in real-time:
```bash
watch -n 5 "snow sql -q \"
USE DATABASE SNOWFLAKE_EXAMPLE;
SELECT 'RAW' AS layer, COUNT(*) AS count FROM STAGE_BADGE_TRACKING.RAW_BADGE_EVENTS
UNION ALL
SELECT 'STAGING', COUNT(*) FROM TRANSFORM_BADGE_TRACKING.STG_BADGE_EVENTS
UNION ALL
SELECT 'ANALYTICS', COUNT(*) FROM ANALYTICS_BADGE_TRACKING.FCT_ACCESS_EVENTS;
\""
```

## Performance Metrics

Check warehouse credit consumption:
```bash
snow sql -q "
SELECT 
    warehouse_name,
    SUM(credits_used) AS total_credits,
    COUNT(*) AS execution_count
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name = 'ETL_WH'
  AND start_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
GROUP BY warehouse_name;
"
```

## Success Criteria

✅ **Pipeline is working correctly if:**
- RAW count = 3000
- STAGING count = 3000
- ANALYTICS count = 3000
- Stream status = False (empty)
- No failed tasks in task history
- Processing latency < 120 seconds
- All dimension foreign keys resolved

## Next Steps

After validation:
1. Review the analytics queries in `sql/validation/check_pipeline.sql`
2. Test the REST API with live streaming (see `REST_API_GUIDE.md`)
3. Monitor ongoing task executions
4. Query the dimensional model for insights

