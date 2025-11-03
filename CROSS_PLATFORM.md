# Cross-Platform Design

This project is designed to work seamlessly on **Windows**, **macOS**, and **Linux**.

## Architecture

### Core Logic: Python
All business logic is written in Python for maximum portability:
- ✅ Event simulator
- ✅ REST API client
- ✅ Prerequisites checker
- ✅ Pipeline validator
- ✅ Data models and validation

### Platform Wrappers
Convenience scripts are provided for each platform:

| Platform | Wrapper Type | Example |
|----------|--------------|---------|
| Windows | `.bat` files | `check_prerequisites.bat` |
| macOS/Linux | `.sh` files | `check_prerequisites.sh` |
| All | Python modules | `python -m python.cli_tools.check_prerequisites` |

### Universal Commands

**All platforms** can use Python commands directly:

```bash
# Prerequisites check
python -m python.cli_tools.check_prerequisites --auto-update

# Pipeline validation
python -m python.cli_tools.validate_pipeline quick

# Run simulator
python -m python.rfid_simulator.simulator
```

## Quick Start by Platform

### Windows
```powershell
check_prerequisites.bat --auto-update
python -m python.rfid_simulator.simulator
validate_pipeline.bat quick
```

### macOS/Linux
```bash
./check_prerequisites.sh --auto-update
python -m python.rfid_simulator.simulator
./validate_pipeline.sh quick
```

## File Structure

```
Streaming-Ingest/
├── check_prerequisites.bat    # Windows wrapper
├── check_prerequisites.sh     # Unix wrapper  
├── validate_pipeline.bat      # Windows wrapper
├── validate_pipeline.sh       # Unix wrapper
├── python/
│   ├── cli_tools/            # Cross-platform CLI tools
│   │   ├── check_prerequisites.py
│   │   └── validate_pipeline.py
│   ├── rfid_simulator/       # Simulator (cross-platform)
│   └── shared/               # Shared models
├── scripts/                  # Legacy bash scripts
└── help/
    └── PLATFORM_GUIDE.md     # Detailed platform instructions
```

## Design Principles

1. **Python First**: Core logic in Python for portability
2. **Platform Wrappers**: Shell scripts for convenience
3. **Fail Gracefully**: Clear error messages for platform-specific issues
4. **Path Handling**: Use `pathlib.Path` for cross-platform paths
5. **ANSI Colors**: Work on Windows 10+, macOS, and Linux terminals

## Testing

The project has been tested on:
- ✅ Windows 10/11 (PowerShell, Command Prompt)
- ✅ macOS 12+ (zsh, bash)
- ✅ Linux (Ubuntu, RHEL, Arch)

## Contributing

When adding new features:
1. Write core logic in Python
2. Create `.bat` and `.sh` wrappers
3. Test on multiple platforms if possible
4. Update `PLATFORM_GUIDE.md` with any platform-specific notes

## Support

For platform-specific issues, see [`help/PLATFORM_GUIDE.md`](help/PLATFORM_GUIDE.md).

