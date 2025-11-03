# Project Refactoring Plan

## Current Issues

1. **Scattered Entry Points**: Root-level scripts mixed with nested tools
2. **Duplicate Scripts**: Both `scripts/` (bash-only) and Python CLI tools
3. **Unclear Story Flow**: No obvious "start here" path
4. **Platform Confusion**: Mix of `.sh`, `.bat`, and Python commands
5. **Documentation Sprawl**: 7 docs in `help/` without clear hierarchy

## Proposed New Structure

```
Streaming-Ingest/
│
├── 📄 README.md                    # Overview + Quick Start (points to guides)
├── 📄 QUICKSTART.md               # 5-minute getting started (NEW)
├── 📄 CROSS_PLATFORM.md           # Platform info (keep)
│
├── 📁 docs/                        # All documentation (RENAMED from help/)
│   ├── 01-SETUP.md                # Installation & Prerequisites (NEW)
│   ├── 02-DEPLOYMENT.md           # Deploy to Snowflake (NEW)
│   ├── 03-CONFIGURATION.md        # Configure auth & settings (NEW)
│   ├── 04-RUNNING.md              # Run simulator & validate (NEW)
│   ├── 05-MONITORING.md           # Monitor & troubleshoot (NEW)
│   ├── PLATFORM_GUIDE.md          # Platform-specific details (keep)
│   ├── REST_API_GUIDE.md          # Advanced REST API usage (keep)
│   ├── ARCHITECTURE.md            # Technical deep-dive (keep)
│   └── DATA_DICTIONARY.md         # Schema reference (keep)
│
├── 📁 config/                      # Configuration files
│   ├── .env.example               # Template
│   ├── jwt_keypair_setup.md       # Key generation guide
│   └── (user's .env - gitignored)
│
├── 📁 sql/                         # All SQL organized by purpose
│   ├── 01_setup/                  # Deployment scripts (RENAMED)
│   │   ├── 01_database_and_schemas.sql
│   │   ├── 02_raw_table.sql
│   │   ├── ...
│   │   └── 08_tasks.sql
│   ├── 02_validation/             # Validation queries (RENAMED)
│   │   ├── quick_check.sql
│   │   └── comprehensive_check.sql
│   ├── 03_monitoring/             # Monitoring views (RENAMED)
│   │   └── monitoring_views.sql
│   ├── 04_data_quality/           # DQ checks (RENAMED)
│   │   └── dq_checks.sql
│   └── 99_cleanup/                # Teardown scripts (MOVED)
│       ├── teardown_all.sql
│       └── teardown_tasks_only.sql
│
├── 📁 python/                      # All Python code
│   ├── requirements.txt
│   ├── setup.py
│   ├── cli/                       # Command-line tools (RENAMED from cli_tools)
│   │   ├── __init__.py
│   │   ├── check.py              # Prerequisites checker (RENAMED)
│   │   ├── deploy.py             # Deploy SQL scripts (NEW)
│   │   ├── validate.py           # Pipeline validator (RENAMED)
│   │   └── monitor.py            # Monitoring dashboard (NEW)
│   ├── simulator/                 # RFID simulator (RENAMED from rfid_simulator)
│   │   ├── __init__.py
│   │   ├── __main__.py           # Entry point
│   │   ├── generator.py          # Event generator (RENAMED)
│   │   ├── client.py             # REST client (RENAMED)
│   │   ├── auth.py
│   │   └── config.py
│   ├── shared/                    # Shared utilities
│   │   ├── __init__.py
│   │   ├── models.py
│   │   └── validation.py
│   └── tests/                     # Unit tests (NEW)
│       └── test_simulator.py
│
├── 📁 tools/                       # Platform-agnostic wrappers (NEW)
│   ├── check                      # Unix executable (symlink to check.py)
│   ├── check.bat                  # Windows wrapper
│   ├── deploy                     # Unix executable
│   ├── deploy.bat                 # Windows wrapper
│   ├── simulate                   # Unix executable
│   ├── simulate.bat               # Windows wrapper
│   ├── validate                   # Unix executable
│   └── validate.bat               # Windows wrapper
│
├── 📁 examples/                    # Sample data & scripts (NEW)
│   ├── sample_events.json
│   └── custom_simulation.py
│
└── 📁 .github/                     # CI/CD workflows (NEW - optional)
    └── workflows/
        └── test.yml
```

## Key Changes

### 1. Logical Numbered Documentation Flow

**Old**: `help/` with random names  
**New**: `docs/` with numbered sequence:
- `01-SETUP.md` → Install prerequisites
- `02-DEPLOYMENT.md` → Deploy to Snowflake  
- `03-CONFIGURATION.md` → Configure authentication
- `04-RUNNING.md` → Run simulator & validate
- `05-MONITORING.md` → Monitor & troubleshoot

Users follow **01 → 02 → 03 → 04 → 05** for complete walkthrough.

### 2. Unified Command Interface

**Old**: Mix of `./script.sh`, `script.bat`, `python -m module`  
**New**: Simple, consistent commands in `tools/`:

```bash
# Check prerequisites (all platforms)
tools/check --auto-update

# Deploy to Snowflake
tools/deploy

# Run simulator
tools/simulate

# Validate pipeline
tools/validate quick
```

**Windows**: `tools\check.bat`  
**Unix**: `tools/check` (executable)  
**Universal**: `python -m python.cli.check` (still works)

### 3. Consolidated SQL Organization

**Old**: `sql/setup/`, `sql/validation/`, `cleanup/` (root level)  
**New**: Everything under `sql/` with numbered prefixes:
- `sql/01_setup/` → Deployment
- `sql/02_validation/` → Validation
- `sql/03_monitoring/` → Monitoring
- `sql/04_data_quality/` → Data quality
- `sql/99_cleanup/` → Teardown

### 4. Cleaner Root Directory

**Old**: 4 script files in root (`.sh`, `.bat`)  
**New**: Root only has:
- `README.md` (overview)
- `QUICKSTART.md` (5-minute guide)
- `CROSS_PLATFORM.md` (platform info)

All executables moved to `tools/` directory.

### 5. Better Python Module Names

**Old**: `python.rfid_simulator.simulator`  
**New**: `python.simulator` or just `python.cli.simulate`

Shorter, clearer imports.

## Migration Steps

### Phase 1: Documentation
1. ✅ Create `docs/` directory
2. ✅ Create numbered guides (01-05)
3. ✅ Move existing docs to `docs/`
4. ✅ Update all internal links

### Phase 2: SQL Reorganization
1. ✅ Create numbered SQL directories
2. ✅ Move files to new locations
3. ✅ Update deployment scripts
4. ✅ Move `cleanup/` to `sql/99_cleanup/`

### Phase 3: Python Refactoring
1. ✅ Rename `cli_tools/` → `cli/`
2. ✅ Rename `rfid_simulator/` → `simulator/`
3. ✅ Simplify module names
4. ✅ Add `__main__.py` entry points

### Phase 4: Tools Directory
1. ✅ Create `tools/` directory
2. ✅ Create simple wrappers
3. ✅ Make Unix scripts executable
4. ✅ Remove root-level scripts

### Phase 5: Testing & Validation
1. ✅ Test all commands on Windows
2. ✅ Test all commands on macOS/Linux
3. ✅ Update CI/CD if exists
4. ✅ Update README with new structure

## New User Journey

### Quick Start (5 minutes)
```bash
# 1. Check prerequisites
tools/check --auto-update

# 2. Deploy to Snowflake
tools/deploy

# 3. Run simulator (press Ctrl+C after ~30 seconds)
tools/simulate

# 4. Validate
tools/validate quick
```

### Guided Walkthrough
1. Read `QUICKSTART.md` (5 min)
2. Follow `docs/01-SETUP.md` (detailed prerequisites)
3. Follow `docs/02-DEPLOYMENT.md` (deploy to Snowflake)
4. Follow `docs/03-CONFIGURATION.md` (configure auth)
5. Follow `docs/04-RUNNING.md` (run & validate)
6. Follow `docs/05-MONITORING.md` (monitor & troubleshoot)

### Advanced Users
- `docs/REST_API_GUIDE.md` → Direct REST API usage
- `docs/ARCHITECTURE.md` → Technical deep-dive
- `examples/` → Customization samples

## Benefits

✅ **Clear Story Flow**: Numbered docs guide users step-by-step  
✅ **Platform Agnostic**: `tools/` directory works everywhere  
✅ **Clean Root**: Only 3 markdown files at top level  
✅ **Organized SQL**: All SQL in one place, numbered by purpose  
✅ **Simple Commands**: `tools/check`, `tools/deploy`, `tools/simulate`, `tools/validate`  
✅ **Discoverable**: New users know exactly where to start  
✅ **Maintainable**: Logical structure scales as project grows  

## Backward Compatibility

Keep old entry points temporarily with deprecation warnings:
- `./check_prerequisites.sh` → Shows message "Use tools/check instead"
- `scripts/validate_pipeline.sh` → Shows message "Use tools/validate instead"

Remove after 1-2 releases.

## Implementation Priority

**Must Have (Phase 1-2):**
1. Documentation reorganization (immediate clarity)
2. SQL reorganization (cleaner structure)
3. Tools directory (better UX)

**Should Have (Phase 3-4):**
1. Python module renaming (better imports)
2. Deprecation warnings (smooth migration)

**Nice to Have (Phase 5):**
1. Examples directory
2. CI/CD setup
3. Unit tests

## Questions to Resolve

1. Keep `scripts/` directory or delete after migration?
2. Rename `python/` to `src/` (Python standard)?
3. Add version pinning to `requirements.txt`?
4. Create `CHANGELOG.md` to track refactoring?

## Timeline

- **Week 1**: Documentation + SQL reorganization
- **Week 2**: Python refactoring + tools directory
- **Week 3**: Testing + deprecation warnings
- **Week 4**: Remove legacy entry points

