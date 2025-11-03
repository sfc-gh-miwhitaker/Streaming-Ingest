# DMF Testing Summary

## ✅ Successfully Configured

### System DMFs (RAW_BADGE_EVENTS)
- ✅ `NULL_COUNT` on: badge_id, user_id, zone_id, reader_id, event_timestamp
- ✅ `DUPLICATE_COUNT` on: badge_id
- ✅ `ROW_COUNT` (table-level)
- ✅ `FRESHNESS` (table-level, tracks last DML operation)
- ✅ `MIN` / `MAX` on: signal_strength

### Custom DMFs (RAW_BADGE_EVENTS)  
- ✅ `dmf_composite_duplicates` - Checks for duplicate (badge_id + event_timestamp) combinations
- ✅ `dmf_invalid_direction` - Detects invalid direction values (not ENTRY/EXIT)
- ✅ `dmf_future_timestamps` - Flags events with timestamps in the future
- ✅ `dmf_high_activity_users` - Identifies users with >100 events in last hour
- ✅ `dmf_weak_signal_zones` - Zones with >50% weak signal readings

### System DMFs (STG_BADGE_EVENTS)
- ✅ `DUPLICATE_COUNT`, `FRESHNESS`, `ROW_COUNT`

### System DMFs (Analytics Layer)
- ✅ `ROW_COUNT` on: FCT_ACCESS_EVENTS, DIM_USERS, DIM_ZONES

### DMF Scheduling
- ✅ RAW_BADGE_EVENTS: Every 5 minutes
- ✅ STG_BADGE_EVENTS: Every 5 minutes
- ✅ FCT_ACCESS_EVENTS: Every 15 minutes
- ✅ DIM_USERS: Every 1 hour
- ✅ DIM_ZONES: Every 1 hour

## ⚠️ Known Limitations

### Multi-Table DMF Association
**Status:** Function created, but association syntax needs verification

The `dmf_orphaned_fact_users` function was successfully created to check referential integrity between FCT_ACCESS_EVENTS and DIM_USERS. However, the correct syntax for **associating** a multi-table DMF is not fully documented.

**Created Function:**
```sql
CREATE OR REPLACE DATA METRIC FUNCTION dmf_orphaned_fact_users(
    fact_table TABLE(user_sk NUMBER),
    dim_table TABLE(user_sk NUMBER, is_active BOOLEAN)
)
...
```

**Attempted Association (failed):**
```sql
ALTER TABLE FCT_ACCESS_EVENTS
    ADD DATA METRIC FUNCTION dmf_orphaned_fact_users
        ON (
            (SELECT user_sk FROM FCT_ACCESS_EVENTS),
            (SELECT user_sk, is_active FROM DIM_USERS)
        ) ...
```

**Error:** `syntax error line 4 at position 12 unexpected '('`

**Next Steps:**
1. Contact Snowflake support for clarification on multi-table DMF association syntax
2. Investigate if the second table must be specified differently (e.g., as a string literal or fully qualified name)
3. Consider alternative approaches (e.g., separate single-table DMF or scheduled stored procedure)

## 📊 How to View DMF Results

### Option 1: Query Monitoring Views (recommended)

The `dq_checks_dmf.sql` file includes pre-built monitoring views:

```sql
-- View all DMF results for RAW_BADGE_EVENTS
SELECT * FROM v_dmf_raw_badge_events_latest ORDER BY measurement_time DESC;

-- View all expectation failures
SELECT * FROM v_dmf_expectation_failures ORDER BY measurement_time DESC;

-- View DMF execution history
SELECT * FROM v_dmf_execution_history ORDER BY measurement_time DESC;
```

### Option 2: Direct Query (for troubleshooting)

```sql
-- Check if DMFs are running
SELECT 
    table_name,
    data_metric_name,
    measurement_time,
    value,
    expectation_pass
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE database_name = 'SNOWFLAKE_EXAMPLE'
  AND schema_name = 'STAGE_BADGE_TRACKING'
  AND table_name = 'RAW_BADGE_EVENTS'
ORDER BY measurement_time DESC
LIMIT 50;
```

### Option 3: Manual DMF Execution (for testing)

```sql
-- Test a system DMF manually
SELECT SNOWFLAKE.CORE.NULL_COUNT(SELECT badge_id FROM RAW_BADGE_EVENTS);

-- Test a custom DMF manually
SELECT dmf_composite_duplicates(
    SELECT badge_id, event_timestamp FROM RAW_BADGE_EVENTS
);
```

## 🐛 Errors Encountered and Fixed

| Error | Root Cause | Solution |
|-------|------------|----------|
| `Invalid number of arguments. Data metric function accepts only one or two table arguments` | Custom DMF defined without TABLE() parameter | Added `arg_t TABLE(col1 TYPE, ...)` parameter |
| `Data metric function body cannot refer to the non-deterministic function 'CURRENT_TIMESTAMP'` | Used `CURRENT_TIMESTAMP()` in DMF body | Replaced with `SNOWFLAKE.CORE.DATA_METRIC_SCHEDULED_TIME()` |
| `Function 'DUPLICATE_COUNT$V1' does not exist or not authorized` | Missing DMF privileges | Granted `DATA_METRIC_USER` role and `EXECUTE DATA METRIC FUNCTION` |
| `syntax error ... unexpected 'TABLE'` | Used `ON (TABLE)` instead of `ON ()` | Changed to `ON ()` for parameterless DMFs |
| `Function 'FRESHNESS$V1' does not exist` | FRESHNESS requires `TIMESTAMP_LTZ/TZ` for column-based | Used `ON ()` for table-level freshness instead |
| `syntax error ... unexpected 'ON'` | Put `ON SCHEDULE` in wrong place | Moved to table level: `ALTER TABLE ... SET DATA_METRIC_SCHEDULE = ...` |

## 📁 Generated Files

| File | Purpose |
|------|---------|
| `dq_checks_dmf.sql` | Main DMF setup file (complete, corrected) |
| `DMF_SETUP_GUIDE.md` | Comprehensive guide with syntax rules and best practices |
| `DMF_TESTING_SUMMARY.md` | This file - summary of what was configured and issues |
| `setup_custom_dmfs_final.sql` | Standalone script to create/associate custom DMFs (successfully tested) |

## 🎯 Next Actions

1. **Wait for DMFs to Run:** DMFs will execute according to their schedules (5 min, 15 min, 1 hour)
2. **Monitor Results:** Query the monitoring views after ~10 minutes to see initial results
3. **Adjust Expectations:** If DMFs are failing expectations, adjust thresholds:
   ```sql
   ALTER TABLE RAW_BADGE_EVENTS
       MODIFY DATA METRIC FUNCTION dmf_composite_duplicates
           ON (badge_id, event_timestamp)
           EXPECTATION low_composite_duplicates (VALUE < 50);  -- Adjusted from 10
   ```
4. **Investigate Multi-Table DMF:** Research correct association syntax for `dmf_orphaned_fact_users`

## ✅ Validation Complete

All DMFs (except the multi-table DMF association) have been successfully created, associated, and scheduled. The data quality monitoring framework is now operational!

