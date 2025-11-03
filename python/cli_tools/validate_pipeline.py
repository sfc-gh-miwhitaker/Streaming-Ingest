"""
Cross-platform pipeline validation tool.

Validates data flow through the RFID Badge Tracking pipeline.
"""

import sys
import subprocess
import argparse
from pathlib import Path
from typing import Optional


class Colors:
    """ANSI color codes for terminal output."""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'


class PipelineValidator:
    """Validate the data pipeline."""
    
    def __init__(self, mode: str = 'quick'):
        self.mode = mode
        self.project_root = Path(__file__).parent.parent.parent
        self.sql_dir = self.project_root / 'sql' / 'validation'
    
    def print_header(self):
        """Print header."""
        print(f"{Colors.BLUE}{'=' * 76}{Colors.NC}")
        print(f"{Colors.BLUE}RFID Badge Tracking: Pipeline Validation{Colors.NC}")
        print(f"{Colors.BLUE}{'=' * 76}{Colors.NC}")
        print()
    
    def run_sql_file(self, sql_file: Path, description: str) -> bool:
        """Run a SQL file using snow CLI."""
        print(f"{Colors.YELLOW}Running: {description}{Colors.NC}")
        print()
        
        if not sql_file.exists():
            print(f"{Colors.RED}Error: SQL file not found: {sql_file}{Colors.NC}")
            return False
        
        try:
            result = subprocess.run(
                ['snow', 'sql', '-f', str(sql_file)],
                capture_output=True,
                text=True,
                timeout=120
            )
            
            # Print output
            if result.stdout:
                print(result.stdout)
            
            if result.returncode != 0:
                if result.stderr:
                    print(f"{Colors.RED}Error:{Colors.NC}")
                    print(result.stderr)
                return False
            
            print()
            return True
            
        except subprocess.TimeoutExpired:
            print(f"{Colors.RED}Error: Query timeout{Colors.NC}")
            return False
        except Exception as e:
            print(f"{Colors.RED}Error: {e}{Colors.NC}")
            return False
    
    def print_interpretation_guide(self):
        """Print interpretation guide."""
        print(f"{Colors.BLUE}{'=' * 76}{Colors.NC}")
        print(f"{Colors.GREEN}Validation Complete!{Colors.NC}")
        print(f"{Colors.BLUE}{'=' * 76}{Colors.NC}")
        print()
        print(f"{Colors.YELLOW}Interpretation Guide:{Colors.NC}")
        print("  • RAW count = 3000+     : All events were ingested")
        print("  • STAGING count = RAW   : All events moved to staging")
        print("  • ANALYTICS count = STG : All events processed to fact table")
        print("  • Stream status = False : All data consumed by tasks")
        print()
        print(f"{Colors.YELLOW}If counts don't match:{Colors.NC}")
        print("  • Wait 1-2 minutes for tasks to process")
        print(f"  • Re-run: {Colors.BLUE}python -m python.cli_tools.validate_pipeline{Colors.NC}")
        print()
    
    def run(self) -> bool:
        """Run validation."""
        self.print_header()
        
        if self.mode == 'quick':
            print(f"{Colors.GREEN}Running Quick Validation Checks...{Colors.NC}")
            print()
            sql_file = self.sql_dir / 'quick_check.sql'
            success = self.run_sql_file(sql_file, "Quick Pipeline Check")
        elif self.mode == 'full':
            print(f"{Colors.GREEN}Running Full Validation Suite...{Colors.NC}")
            print()
            sql_file = self.sql_dir / 'check_pipeline.sql'
            success = self.run_sql_file(sql_file, "Comprehensive Pipeline Validation")
        else:
            print(f"{Colors.RED}Error: Invalid mode '{self.mode}'{Colors.NC}")
            return False
        
        if success:
            self.print_interpretation_guide()
        
        return success


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Validate RFID Badge Tracking pipeline"
    )
    
    parser.add_argument(
        'mode',
        nargs='?',
        default='quick',
        choices=['quick', 'full'],
        help='Validation mode (default: quick)'
    )
    
    args = parser.parse_args()
    
    validator = PipelineValidator(mode=args.mode)
    success = validator.run()
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

