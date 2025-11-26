#!/usr/bin/env python3
"""
Remove unused app_logger.dart imports from Flutter files.
Run from project root directory.

This script:
1. Runs flutter analyze to find unused imports
2. Parses the output for files with unused app_logger.dart imports
3. Removes the unused import lines from those files
4. Reports results
"""
import subprocess
import re
import sys
from pathlib import Path

def get_unused_imports():
    """Parse flutter analyze output for unused app_logger.dart imports."""
    print("[ANALYZE] Running flutter analyze...")

    result = subprocess.run(
        ['flutter.bat', 'analyze', '--no-pub'],
        cwd='flutter_app',
        capture_output=True,
        text=True,
        shell=True
    )

    unused = []
    for line in result.stdout.splitlines():
        if 'Unused import' in line and 'app_logger.dart' in line:
            # Extract file path
            match = re.search(r"lib[\\\/][^\s]+\.dart", line)
            if match:
                file_path = match.group(0).replace('\\', '/')
                unused.append(file_path)

    return list(set(unused))  # Remove duplicates

def remove_import_from_file(file_path):
    """Remove app_logger.dart import from a single file."""
    full_path = Path('flutter_app') / file_path

    if not full_path.exists():
        print(f"WARNING File not found: {file_path}")
        return False

    with open(full_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    filtered = []
    removed_count = 0

    for line in lines:
        # Skip the unused import line (both patterns)
        if "import '../core/app_logger.dart';" in line or \
           "import '../../core/app_logger.dart';" in line:
            removed_count += 1
            continue
        filtered.append(line)

    if removed_count > 0:
        with open(full_path, 'w', encoding='utf-8') as f:
            f.writelines(filtered)
        return True

    return False

# Main execution
if __name__ == '__main__':
    print("=" * 60)
    print("Flutter Unused Imports Cleanup Script")
    print("=" * 60)

    # Get list of files with unused imports
    unused_files = get_unused_imports()

    if not unused_files:
        print("\nSUCCESS No unused app_logger.dart imports found!")
        sys.exit(0)

    print(f"\n[LIST] Found {len(unused_files)} files with unused app_logger imports:")
    for f in sorted(unused_files):
        print(f"  - {f}")

    print(f"\n[FIX] Removing unused imports...")

    fixed = 0
    for file_path in unused_files:
        if remove_import_from_file(file_path):
            print(f"  OK {file_path}")
            fixed += 1
        else:
            print(f"  WARNING No changes: {file_path}")

    print("\n" + "=" * 60)
    print(f"SUCCESS Fixed {fixed} out of {len(unused_files)} files")
    print("=" * 60)
    print("\n[TEST] Verifying fixes...")

    # Re-run analyze to verify
    result = subprocess.run(
        ['flutter.bat', 'analyze', '--no-pub'],
        cwd='flutter_app',
        capture_output=True,
        text=True,
        shell=True
    )

    # Count remaining unused import warnings
    remaining = sum(1 for line in result.stdout.splitlines()
                    if 'Unused import' in line and 'app_logger.dart' in line)

    if remaining == 0:
        print("SUCCESS All unused app_logger.dart imports have been removed!")
    else:
        print(f"WARNING {remaining} unused imports remain (may need manual review)")

    print("\n[TIP] Next steps:")
    print("  1. Run: cd flutter_app && flutter analyze")
    print("  2. Run: cd flutter_app && flutter test")
    print("  3. Review git diff to verify changes")
