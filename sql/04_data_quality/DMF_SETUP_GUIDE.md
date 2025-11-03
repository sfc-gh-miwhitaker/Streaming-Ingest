# Snowflake Data Metric Functions (DMF) Setup Guide

## Key Learnings from Testing

### 1. Custom DMF Syntax Requirements

**✅ Correct:** Custom DMFs MUST accept `TABLE()` arguments
```sql
CREATE OR REPLACE DATA METRIC FUNCTION my_check(
    arg_t TABLE(col1 VARCHAR, col2 NUMBER)
)
RETURNS NUMBER
AS
$$
    SELECT COUNT(*) FROM arg_t WHERE col1 IS NULL
$$;
```

**❌ Incorrect:** Cannot directly reference tables
```sql
CREATE OR REPLACE DATA METRIC FUNCTION my_check()
RETURNS NUMBER
AS
$$
    SELECT COUNT(*) FROM my_schema.my_table WHERE col1 IS NULL  -- WRONG!
$$;
```

### 2. System DMF Parameter Rules

| DMF | Parameters | Example |
|-----|------------|---------|
| `NULL_COUNT` | Single column | `ON (badge_id)` |
| `DUPLICATE_COUNT` | Single column | `ON (badge_id)` |
| `ROW_COUNT` | **Empty parentheses** | `ON ()` |
| `FRESHNESS` | Empty parentheses OR timestamp column | `ON ()` or `ON (timestamp_col)` |
| `MIN` / `MAX` | Single numeric column | `ON (signal_strength)` |

### 3. FRESHNESS DMF Compatibility

**FRESHNESS requires `TIMESTAMP_LTZ` or `TIMESTAMP_TZ` for column-based checks.**

- ✅ Use `ON ()` for table-level freshness (tracks last DML operation)
- ❌ Cannot use `ON (timestamp_col)` if column is `TIMESTAMP_NTZ`

### 4. Non-Deterministic Functions

**Custom DMFs cannot use non-deterministic functions like `CURRENT_TIMESTAMP()`.**

**✅ Solution:** Use `SNOWFLAKE.CORE.DATA_METRIC_SCHEDULED_TIME()` instead

```sql
-- ✅ CORRECT
WHERE event_timestamp >= DATEADD('hour', -1, SNOWFLAKE.CORE.DATA_METRIC_SCHEDULED_TIME())

-- ❌ WRONG
WHERE event_timestamp >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
```

### 5. Multi-Table DMFs

For referential integrity checks across tables, use **two TABLE arguments**:

```sql
CREATE OR REPLACE DATA METRIC FUNCTION dmf_orphaned_records(
    fact_table TABLE(foreign_key NUMBER),
    dim_table TABLE(primary_key NUMBER)
)
RETURNS NUMBER
AS
$$
    SELECT COALESCE(COUNT(*), 0)
    FROM fact_table f
    WHERE NOT EXISTS (
        SELECT 1 FROM dim_table d WHERE f.foreign_key = d.primary_key
    )
$$;

-- Associate with multiple SELECT statements
ALTER TABLE fact_table
    ADD DATA METRIC FUNCTION dmf_orphaned_records
        ON (
            (SELECT foreign_key FROM fact_table),
            (SELECT primary_key FROM dim_table)
        )
        EXPECTATION no_orphans (VALUE = 0);
```

### 6. Required Privileges

Before creating DMFs, grant these privileges:

```sql
-- Grant access to system DMFs
GRANT DATABASE ROLE SNOWFLAKE.DATA_METRIC_USER TO ROLE <your_role>;

-- Grant ability to execute DMFs (uses serverless compute)
GRANT EXECUTE DATA METRIC FUNCTION ON ACCOUNT TO ROLE <your_role>;
```

### 7. Scheduling

Set `DATA_METRIC_SCHEDULE` at the **table level**, not on individual DMFs:

```sql
-- ✅ CORRECT
ALTER TABLE my_table SET DATA_METRIC_SCHEDULE = '5 MINUTE';

ALTER TABLE my_table
    ADD DATA METRIC FUNCTION my_dmf ON (col1) EXPECTATION check1 (VALUE = 0);

-- ❌ WRONG
ALTER TABLE my_table
    ADD DATA METRIC FUNCTION my_dmf ON (col1) ON SCHEDULE '5 MINUTE' ...  -- Invalid syntax
```

## Testing Strategy

To test incrementally and avoid "already exists" errors:

1. **Create Functions First** (use `CREATE OR REPLACE` - safe to re-run)
2. **Associate Functions Second** (will fail if already associated - that's OK)
3. **Use separate test scripts** to isolate issues

Example test script:
```sql
-- Create (safe to re-run)
CREATE OR REPLACE DATA METRIC FUNCTION my_dmf(...) ...;

-- Associate (will error if exists, but that's fine)
ALTER TABLE my_table ADD DATA METRIC FUNCTION my_dmf ON (...) ...;
```

## Common Errors & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `Invalid number of arguments. Data metric function accepts only one or two table arguments` | Custom DMF doesn't have TABLE() parameter | Add `arg_t TABLE(...)` parameter |
| `Data metric function body cannot refer to the non-deterministic function 'CURRENT_TIMESTAMP'` | Using non-deterministic function | Use `SNOWFLAKE.CORE.DATA_METRIC_SCHEDULED_TIME()` |
| `Function 'FRESHNESS$V1' does not exist or not authorized` | Missing privileges | Grant `DATA_METRIC_USER` role and `EXECUTE DATA METRIC FUNCTION` |
| `Table already has the data metric function ... on the same column(s)` | DMF already associated | Use `MODIFY DATA METRIC FUNCTION` or drop and recreate |
| `syntax error ... unexpected 'TABLE'` | Incorrect `ON (TABLE)` syntax | Use `ON ()` for parameterless DMFs or `ON (col1, col2)` for custom DMFs |
| `syntax error ... unexpected 'ON'` | Schedule in wrong place | Move `DATA_METRIC_SCHEDULE` to table level |

## Next Steps

Run the main DMF setup file:
```bash
snow sql -f sql/data_quality/dq_checks_dmf.sql
```

Note: You may see "already exists" errors for DMFs that are already set up - this is expected and safe to ignore.

