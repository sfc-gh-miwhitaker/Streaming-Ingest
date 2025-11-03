"""
Cross-platform prerequisites checker.

Verifies that all required tools and configurations are in place before
running the RFID Badge Tracking demo.
"""

import os
import sys
import subprocess
import re
from pathlib import Path
from typing import Tuple, List, Optional
import argparse


class Colors:
    """ANSI color codes for terminal output (works on Windows 10+, macOS, Linux)."""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color
    
    @classmethod
    def disable(cls):
        """Disable colors for Windows systems that don't support ANSI."""
        cls.RED = cls.GREEN = cls.YELLOW = cls.BLUE = cls.NC = ''


# Enable ANSI colors on Windows 10+
if sys.platform == 'win32':
    import platform
    if int(platform.version().split('.')[0]) >= 10:
        os.system('')  # Enable ANSI escape sequences
    else:
        Colors.disable()


class PrerequisitesChecker:
    """Check and validate all prerequisites for the project."""
    
    def __init__(self, auto_update: bool = False):
        self.auto_update = auto_update
        self.issues_found = 0
        self.project_root = Path(__file__).parent.parent.parent
        
    def print_header(self):
        """Print header."""
        print(f"{Colors.BLUE}{'=' * 76}{Colors.NC}")
        print(f"{Colors.BLUE}RFID Badge Tracking: Prerequisites Check{Colors.NC}")
        print(f"{Colors.BLUE}{'=' * 76}{Colors.NC}")
        print()
    
    def check_command_exists(self, command: str) -> bool:
        """Check if a command exists in PATH."""
        try:
            result = subprocess.run(
                [command, '--version'],
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.returncode == 0
        except (FileNotFoundError, subprocess.TimeoutExpired):
            return False
    
    def get_version(self, command: str, pattern: str = r'(\d+\.\d+\.\d+)') -> Optional[str]:
        """Get version of a command."""
        try:
            result = subprocess.run(
                [command, '--version'],
                capture_output=True,
                text=True,
                timeout=5
            )
            match = re.search(pattern, result.stdout + result.stderr)
            return match.group(1) if match else None
        except Exception:
            return None
    
    def version_compare(self, ver1: str, ver2: str) -> int:
        """
        Compare two semantic versions.
        Returns: 1 if ver1 > ver2, -1 if ver1 < ver2, 0 if equal
        """
        v1_parts = [int(x) for x in ver1.split('.')]
        v2_parts = [int(x) for x in ver2.split('.')]
        
        for i in range(max(len(v1_parts), len(v2_parts))):
            v1 = v1_parts[i] if i < len(v1_parts) else 0
            v2 = v2_parts[i] if i < len(v2_parts) else 0
            
            if v1 > v2:
                return 1
            elif v1 < v2:
                return -1
        
        return 0
    
    def check_snowflake_cli(self) -> bool:
        """Check Snowflake CLI installation and version."""
        print(f"{Colors.YELLOW}Checking Snowflake CLI...{Colors.NC}")
        
        if not self.check_command_exists('snow'):
            print(f"  {Colors.RED}✗{Colors.NC} Snowflake CLI not found")
            print(f"    Install from: {Colors.BLUE}https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/installation/installation{Colors.NC}")
            self.issues_found += 1
            return False
        
        version = self.get_version('snow')
        print(f"  {Colors.GREEN}✓{Colors.NC} Snowflake CLI installed: v{version}")
        
        # Check for updates
        print("  Checking for updates...")
        
        if self.auto_update:
            try:
                print("  Running: snow update")
                result = subprocess.run(
                    ['snow', 'update'],
                    capture_output=True,
                    text=True,
                    timeout=60
                )
                
                new_version = self.get_version('snow')
                if new_version and new_version != version:
                    print(f"  {Colors.GREEN}✓{Colors.NC} Updated to v{new_version}")
                else:
                    print(f"  {Colors.GREEN}✓{Colors.NC} Already on latest version")
            except Exception as e:
                print(f"  {Colors.YELLOW}⚠{Colors.NC} Update command failed: {e}")
        else:
            print(f"  {Colors.YELLOW}ℹ{Colors.NC} To update, run: {Colors.BLUE}snow update{Colors.NC}")
            print(f"  {Colors.YELLOW}ℹ{Colors.NC} Or re-run with: {Colors.BLUE}python -m python.cli_tools.check_prerequisites --auto-update{Colors.NC}")
        
        print()
        return True
    
    def check_python(self) -> bool:
        """Check Python version."""
        print(f"{Colors.YELLOW}Checking Python...{Colors.NC}")
        
        version = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
        print(f"  {Colors.GREEN}✓{Colors.NC} Python installed: v{version}")
        
        # Check minimum version (3.8+)
        if self.version_compare(version, "3.8.0") < 0:
            print(f"  {Colors.RED}✗{Colors.NC} Python version too old (requires 3.8+)")
            self.issues_found += 1
            print()
            return False
        
        print()
        return True
    
    def check_python_packages(self) -> bool:
        """Check required Python packages."""
        print(f"{Colors.YELLOW}Checking Python dependencies...{Colors.NC}")
        
        required_packages = [
            'pydantic',
            'python-dotenv',
            'cryptography',
            'requests'
        ]
        
        missing_packages = []
        
        for package in required_packages:
            package_import = package.replace('-', '_')
            try:
                __import__(package_import)
                print(f"  {Colors.GREEN}✓{Colors.NC} {package} installed")
            except ImportError:
                print(f"  {Colors.RED}✗{Colors.NC} {package} not found")
                missing_packages.append(package)
        
        if missing_packages:
            print()
            print(f"  {Colors.YELLOW}ℹ{Colors.NC} To install missing packages, run:")
            print(f"    {Colors.BLUE}pip install -r python/requirements.txt{Colors.NC}")
            self.issues_found += 1
        
        print()
        return len(missing_packages) == 0
    
    def check_configuration(self) -> bool:
        """Check configuration file."""
        print(f"{Colors.YELLOW}Checking configuration...{Colors.NC}")
        
        config_file = self.project_root / 'config' / '.env'
        
        if not config_file.exists():
            print(f"  {Colors.RED}✗{Colors.NC} Configuration file not found: config/.env")
            print(f"    Copy template: {Colors.BLUE}cp config/.env.example config/.env{Colors.NC}")
            print(f"    Then edit config/.env with your Snowflake credentials")
            self.issues_found += 1
            print()
            return False
        
        print(f"  {Colors.GREEN}✓{Colors.NC} Configuration file exists: config/.env")
        
        # Check for required keys
        required_vars = [
            'SNOWFLAKE_ACCOUNT',
            'SNOWFLAKE_USER',
            'SNOWFLAKE_PRIVATE_KEY_PATH'
        ]
        
        missing_vars = []
        
        with open(config_file, 'r') as f:
            content = f.read()
            
        for var in required_vars:
            # Check if variable is set and not empty
            pattern = rf'^{var}=(.+)$'
            match = re.search(pattern, content, re.MULTILINE)
            
            if match and match.group(1).strip():
                print(f"  {Colors.GREEN}✓{Colors.NC} {var} configured")
            else:
                print(f"  {Colors.YELLOW}⚠{Colors.NC} {var} not set or empty")
                missing_vars.append(var)
        
        if missing_vars:
            print()
            print(f"  {Colors.YELLOW}ℹ{Colors.NC} Please configure missing variables in: {Colors.BLUE}config/.env{Colors.NC}")
            self.issues_found += 1
        
        print()
        return len(missing_vars) == 0
    
    def check_private_key(self) -> bool:
        """Check JWT private key."""
        print(f"{Colors.YELLOW}Checking JWT private key...{Colors.NC}")
        
        config_file = self.project_root / 'config' / '.env'
        
        if not config_file.exists():
            print(f"  {Colors.YELLOW}⚠{Colors.NC} Skipping (config file not found)")
            print()
            return False
        
        # Read key path from config
        with open(config_file, 'r') as f:
            for line in f:
                if line.startswith('SNOWFLAKE_PRIVATE_KEY_PATH='):
                    key_path_str = line.split('=', 1)[1].strip()
                    
                    if not key_path_str:
                        print(f"  {Colors.YELLOW}⚠{Colors.NC} Private key path not configured")
                        print(f"    Generate key pair with: {Colors.BLUE}python -m python.cli_tools.setup_auth{Colors.NC}")
                        self.issues_found += 1
                        print()
                        return False
                    
                    # Resolve path relative to project root if needed
                    key_path = Path(key_path_str)
                    if not key_path.is_absolute():
                        key_path = self.project_root / key_path
                    
                    if key_path.exists():
                        print(f"  {Colors.GREEN}✓{Colors.NC} Private key file exists: {key_path}")
                        print()
                        return True
                    else:
                        print(f"  {Colors.RED}✗{Colors.NC} Private key file not found: {key_path}")
                        print(f"    Generate key pair with: {Colors.BLUE}python -m python.cli_tools.setup_auth{Colors.NC}")
                        self.issues_found += 1
                        print()
                        return False
        
        print(f"  {Colors.YELLOW}⚠{Colors.NC} Private key path not configured")
        print()
        return False
    
    def print_summary(self):
        """Print summary."""
        print(f"{Colors.BLUE}{'=' * 76}{Colors.NC}")
        
        if self.issues_found == 0:
            print(f"{Colors.GREEN}✓ All prerequisites satisfied!{Colors.NC}")
            print()
            print("Next steps:")
            print(f"  1. Run setup: {Colors.BLUE}python -m python.cli_tools.run_setup{Colors.NC}")
            print(f"  2. Start simulator: {Colors.BLUE}python -m python.rfid_simulator.simulator{Colors.NC}")
            print(f"  3. Validate pipeline: {Colors.BLUE}python -m python.cli_tools.validate_pipeline{Colors.NC}")
        else:
            print(f"{Colors.YELLOW}⚠ Found {self.issues_found} issue(s) that need attention{Colors.NC}")
            print()
            print("Please resolve the issues above before proceeding.")
        
        print(f"{Colors.BLUE}{'=' * 76}{Colors.NC}")
        print()
        
        return self.issues_found == 0
    
    def run(self) -> bool:
        """Run all checks."""
        self.print_header()
        
        self.check_snowflake_cli()
        self.check_python()
        self.check_python_packages()
        self.check_configuration()
        self.check_private_key()
        
        return self.print_summary()


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Check prerequisites for RFID Badge Tracking demo"
    )
    
    parser.add_argument(
        '--auto-update',
        action='store_true',
        help='Automatically update Snowflake CLI if outdated'
    )
    
    args = parser.parse_args()
    
    checker = PrerequisitesChecker(auto_update=args.auto_update)
    success = checker.run()
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

