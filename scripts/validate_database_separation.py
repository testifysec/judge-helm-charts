#!/usr/bin/env python3
"""
Validate that each service has its own database.
This prevents Atlas migration conflicts.
"""

import sys
import re
import glob

def check_database_separation():
    """Check that each service uses a separate database."""
    issues = []
    databases_found = set()

    for file in glob.glob('charts/**/values*.yaml', recursive=True):
        try:
            with open(file, 'r') as f:
                content = f.read()

            # Skip files without database configuration
            if 'postgresql://' not in content and 'database:' not in content:
                continue

            print(f"Checking {file}...")

            # Find PostgreSQL DSN patterns
            dsn_pattern = r'postgresql://[^@]+@[^/]+/([a-zA-Z0-9_]+)'
            dsns = re.findall(dsn_pattern, content)

            for db in dsns:
                databases_found.add(db)
                if db == 'postgres':
                    issues.append(f"❌ Default 'postgres' database used in {file}")
                    issues.append("   Each service must have its own database")

            # Also look for database name patterns in YAML
            db_name_pattern = r'database(?:Name)?:\s*([a-zA-Z0-9_]+)'
            db_names = re.findall(db_name_pattern, content)

            for db in db_names:
                if db == 'postgres':
                    issues.append(f"⚠️  Database name 'postgres' found in {file}")

        except Exception as e:
            print(f"Warning: Could not process {file}: {e}")

    # Check for required databases
    required_dbs = {'judge_api', 'archivista', 'kratos'}

    # Also accept variants with hyphens
    found_dbs = databases_found | {db.replace('-', '_') for db in databases_found}

    print(f"\nDatabases found: {databases_found}")

    missing_dbs = required_dbs - found_dbs
    if missing_dbs and len(databases_found) > 0:  # Only warn if we found any DBs
        for db in missing_dbs:
            issues.append(f"⚠️  Missing separate database for: {db}")

    # Report results
    if issues:
        print("\n=== Database Separation Issues Found ===")
        for issue in issues:
            print(issue)
        print("\nEach service requires a separate database:")
        print("  - judge_api: For Judge API")
        print("  - archivista: For Archivista")
        print("  - kratos: For Kratos identity service")
        return 1
    else:
        print("✅ Database separation validated - no issues found")
        return 0

if __name__ == '__main__':
    sys.exit(check_database_separation())