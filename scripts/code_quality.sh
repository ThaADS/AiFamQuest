#!/bin/bash
# FamQuest Code Quality Audit Script
# Runs linters, formatters, and type checkers

set -e

echo "╔════════════════════════════════════════════╗"
echo "║   FamQuest Code Quality Audit v1.0         ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

QUALITY_REPORT="code_quality_report_$(date +%Y%m%d_%H%M%S).txt"

log_result() {
    echo "$1" | tee -a "$QUALITY_REPORT"
}

log_result "=== Code Quality Report ==="
log_result "Date: $(date)"
log_result ""

# Backend Python Code Quality
echo -e "${YELLOW}[1/5] Backend Python Code Quality...${NC}"
log_result "## Backend (Python)"
log_result ""

cd backend || exit 1

# Install tools if needed
if ! command -v black &> /dev/null; then
    echo "Installing Python code quality tools..."
    pip install black isort mypy pylint flake8
fi

# Black: Code formatter (check mode)
echo "Running black (code formatter)..."
black --check . > ../black_report.txt 2>&1 || true
if [ $? -eq 0 ]; then
    log_result "${GREEN}✅ Black: Code is formatted correctly${NC}"
else
    FILES_TO_FORMAT=$(grep "would reformat" ../black_report.txt | wc -l || echo "0")
    log_result "${YELLOW}⚠️  Black: $FILES_TO_FORMAT files need formatting${NC}"
    log_result "    Run: black backend/"
fi
log_result ""

# isort: Import sorting
echo "Running isort (import sorting)..."
isort --check-only . > ../isort_report.txt 2>&1 || true
if [ $? -eq 0 ]; then
    log_result "${GREEN}✅ isort: Imports are sorted correctly${NC}"
else
    log_result "${YELLOW}⚠️  isort: Some imports need sorting${NC}"
    log_result "    Run: isort backend/"
fi
log_result ""

# mypy: Type checking
echo "Running mypy (type checking)..."
mypy . --ignore-missing-imports --no-strict-optional > ../mypy_report.txt 2>&1 || true
MYPY_ERRORS=$(grep -c "error:" ../mypy_report.txt || echo "0")
log_result "mypy Type Errors: $MYPY_ERRORS"
if [ "$MYPY_ERRORS" -gt 0 ]; then
    log_result "${YELLOW}⚠️  Type hints need improvement (see mypy_report.txt)${NC}"
else
    log_result "${GREEN}✅ mypy: No type errors${NC}"
fi
log_result ""

# flake8: Linting
echo "Running flake8 (linter)..."
flake8 . --max-line-length=120 --exclude=.venv,migrations --count > ../flake8_report.txt 2>&1 || true
FLAKE8_ISSUES=$(tail -1 ../flake8_report.txt || echo "0")
log_result "flake8 Issues: $FLAKE8_ISSUES"
if [ "$FLAKE8_ISSUES" != "0" ]; then
    log_result "${YELLOW}⚠️  Code style issues found (see flake8_report.txt)${NC}"
else
    log_result "${GREEN}✅ flake8: No issues${NC}"
fi
log_result ""

# Code metrics
echo "Calculating code metrics..."
LOC=$(find . -name "*.py" -not -path "./.venv/*" -exec wc -l {} + | tail -1 | awk '{print $1}')
FILES=$(find . -name "*.py" -not -path "./.venv/*" | wc -l)
AVG_LOC=$((LOC / FILES))

log_result "Code Metrics:"
log_result "  Total Lines: $LOC"
log_result "  Python Files: $FILES"
log_result "  Avg Lines/File: $AVG_LOC"
log_result ""

cd ..

# Frontend Flutter Code Quality
echo -e "${YELLOW}[2/5] Flutter Code Quality...${NC}"
log_result "## Frontend (Flutter)"
log_result ""

cd flutter_app || exit 1

# Flutter analyze
echo "Running flutter analyze..."
flutter analyze --no-fatal-infos > ../flutter_analyze_report.txt 2>&1
FLUTTER_ISSUES=$(grep -c "issue found" ../flutter_analyze_report.txt || echo "0")
log_result "Flutter Analyzer Issues: $FLUTTER_ISSUES"

if [ "$FLUTTER_ISSUES" -eq 0 ]; then
    log_result "${GREEN}✅ Flutter Analyze: No issues${NC}"
else
    log_result "${YELLOW}⚠️  Flutter issues found (see flutter_analyze_report.txt)${NC}"
    log_result "    Run: flutter analyze"
fi
log_result ""

# Dart format check
echo "Running dart format..."
dart format --set-exit-if-changed lib/ > ../dart_format_report.txt 2>&1 || true
if [ $? -eq 0 ]; then
    log_result "${GREEN}✅ Dart Format: Code is formatted correctly${NC}"
else
    log_result "${YELLOW}⚠️  Dart Format: Some files need formatting${NC}"
    log_result "    Run: dart format lib/"
fi
log_result ""

# Flutter code metrics
echo "Calculating Flutter metrics..."
DART_LOC=$(find lib -name "*.dart" -exec wc -l {} + | tail -1 | awk '{print $1}')
DART_FILES=$(find lib -name "*.dart" | wc -l)
DART_AVG=$((DART_LOC / DART_FILES))

log_result "Flutter Metrics:"
log_result "  Total Dart Lines: $DART_LOC"
log_result "  Dart Files: $DART_FILES"
log_result "  Avg Lines/File: $DART_AVG"
log_result ""

cd ..

# Test Coverage
echo -e "${YELLOW}[3/5] Test Coverage Analysis...${NC}"
log_result "## Test Coverage"
log_result ""

# Backend coverage
cd backend || exit 1
if [ -f "pytest.ini" ] || [ -f "pyproject.toml" ]; then
    echo "Running backend tests with coverage..."
    pytest --cov=. --cov-report=term --cov-report=html > ../backend_coverage.txt 2>&1 || true
    BACKEND_COV=$(grep "TOTAL" ../backend_coverage.txt | awk '{print $NF}' || echo "0%")
    log_result "Backend Coverage: $BACKEND_COV"
else
    log_result "Backend Coverage: Not configured"
fi
cd ..

# Flutter coverage
cd flutter_app || exit 1
echo "Running Flutter tests..."
flutter test --coverage > ../flutter_test_output.txt 2>&1 || true
if [ -f "coverage/lcov.info" ]; then
    # Calculate coverage percentage (requires lcov tool)
    if command -v lcov &> /dev/null; then
        FLUTTER_COV=$(lcov --summary coverage/lcov.info 2>&1 | grep "lines" | awk '{print $2}')
        log_result "Flutter Coverage: $FLUTTER_COV"
    else
        log_result "Flutter Coverage: coverage/lcov.info generated (install lcov for percentage)"
    fi
else
    log_result "Flutter Coverage: No coverage data"
fi
cd ..
log_result ""

# Documentation Quality
echo -e "${YELLOW}[4/5] Documentation Quality...${NC}"
log_result "## Documentation"
log_result ""

# Check for README
if [ -f "README.md" ]; then
    README_LINES=$(wc -l README.md | awk '{print $1}')
    log_result "${GREEN}✅ README.md exists ($README_LINES lines)${NC}"
else
    log_result "${RED}⚠️  No README.md found${NC}"
fi

# Check for API documentation
if [ -f "backend/README.md" ] || [ -d "docs/" ]; then
    log_result "${GREEN}✅ Additional documentation found${NC}"
fi

# Check inline documentation
cd backend || exit 1
DOCSTRINGS=$(grep -r "\"\"\"" --include="*.py" . | wc -l || echo "0")
log_result "Python Docstrings: $DOCSTRINGS"
cd ..

cd flutter_app || exit 1
DART_DOCS=$(grep -r "///" --include="*.dart" lib/ | wc -l || echo "0")
log_result "Dart Doc Comments: $DART_DOCS"
cd ..
log_result ""

# Complexity Analysis
echo -e "${YELLOW}[5/5] Code Complexity Analysis...${NC}"
log_result "## Code Complexity"
log_result ""

cd backend || exit 1

# Find large files (potential refactoring candidates)
echo "Finding large files..."
LARGE_FILES=$(find . -name "*.py" -not -path "./.venv/*" -exec wc -l {} + | awk '$1 > 500 {print $2}' | wc -l || echo "0")
log_result "Large Files (>500 lines): $LARGE_FILES"

if [ "$LARGE_FILES" -gt 0 ]; then
    log_result "${YELLOW}⚠️  Consider refactoring large files${NC}"
    find . -name "*.py" -not -path "./.venv/*" -exec wc -l {} + | awk '$1 > 500 {print "    " $2 " (" $1 " lines)"}' >> "$QUALITY_REPORT"
fi

cd ..

cd flutter_app || exit 1
LARGE_DART=$(find lib -name "*.dart" -exec wc -l {} + | awk '$1 > 500 {print $2}' | wc -l || echo "0")
log_result "Large Dart Files (>500 lines): $LARGE_DART"

if [ "$LARGE_DART" -gt 0 ]; then
    log_result "${YELLOW}⚠️  Consider refactoring large Dart files${NC}"
fi

cd ..
log_result ""

# Summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Code Quality Audit Complete              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Report saved to: $QUALITY_REPORT"
echo ""
echo "Generated Reports:"
echo "  - $QUALITY_REPORT (main report)"
echo "  - black_report.txt"
echo "  - isort_report.txt"
echo "  - mypy_report.txt"
echo "  - flake8_report.txt"
echo "  - flutter_analyze_report.txt"
echo "  - dart_format_report.txt"
echo ""
echo "Quick Fixes:"
echo "  Backend:"
echo "    black backend/"
echo "    isort backend/"
echo "    flake8 backend/ --max-line-length=120"
echo ""
echo "  Frontend:"
echo "    dart format lib/"
echo "    dart fix --apply"
echo "    flutter analyze"
echo ""
