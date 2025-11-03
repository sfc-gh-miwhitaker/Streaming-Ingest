#!/bin/bash
# ============================================================================
# Pipeline Validation Script
# ============================================================================
# Purpose: Run validation checks on the RFID badge tracking pipeline
#          after data ingestion.
#
# Usage: ./scripts/validate_pipeline.sh [quick|full]
#
# Options:
#   quick - Run basic row count checks (default)
#   full  - Run comprehensive validation suite
# ============================================================================

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VALIDATION_DIR="${PROJECT_ROOT}/sql/validation"

# Check mode (default: quick)
MODE="${1:-quick}"

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE}RFID Badge Tracking: Pipeline Validation${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""

# Function to run SQL file
run_validation() {
    local sql_file=$1
    local description=$2
    
    echo -e "${YELLOW}Running: ${description}${NC}"
    echo ""
    
    if [[ ! -f "${sql_file}" ]]; then
        echo -e "${RED}Error: SQL file not found: ${sql_file}${NC}"
        exit 1
    fi
    
    snow sql -f "${sql_file}"
    
    echo ""
}

# Run validation based on mode
case "$MODE" in
    quick)
        echo -e "${GREEN}Running Quick Validation Checks...${NC}"
        echo ""
        run_validation "${VALIDATION_DIR}/quick_check.sql" "Quick Pipeline Check"
        ;;
    
    full)
        echo -e "${GREEN}Running Full Validation Suite...${NC}"
        echo ""
        run_validation "${VALIDATION_DIR}/check_pipeline.sql" "Comprehensive Pipeline Validation"
        ;;
    
    *)
        echo -e "${RED}Error: Invalid mode '${MODE}'${NC}"
        echo "Usage: $0 [quick|full]"
        exit 1
        ;;
esac

echo -e "${BLUE}============================================================================${NC}"
echo -e "${GREEN}Validation Complete!${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""
echo -e "${YELLOW}Interpretation Guide:${NC}"
echo "  • RAW count = 3000+     : All events were ingested"
echo "  • STAGING count = RAW   : All events moved to staging"
echo "  • ANALYTICS count = STG : All events processed to fact table"
echo "  • Stream status = False : All data consumed by tasks"
echo ""
echo -e "${YELLOW}If counts don't match:${NC}"
echo "  • Wait 1-2 minutes for tasks to process"
echo "  • Re-run: ./scripts/validate_pipeline.sh quick"
echo "  • Check task history: snow sql -q 'SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY()) LIMIT 5;'"
echo ""

