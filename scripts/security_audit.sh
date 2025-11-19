#!/bin/bash
# FamQuest Security Audit Script
# Performs comprehensive security checks on backend and frontend

set -e

echo "╔════════════════════════════════════════════╗"
echo "║   FamQuest Security Audit v1.0             ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

AUDIT_REPORT="security_audit_report_$(date +%Y%m%d_%H%M%S).txt"

# Function to log results
log_result() {
    echo "$1" | tee -a "$AUDIT_REPORT"
}

log_result "=== Security Audit Report ==="
log_result "Date: $(date)"
log_result "Project: FamQuest"
log_result ""

# 1. Backend Security Audit
echo -e "${YELLOW}[1/6] Running Backend Security Audit...${NC}"
log_result "## Backend Security (Python)"
log_result ""

cd backend || exit 1

# Install security tools if not present
if ! command -v bandit &> /dev/null; then
    echo "Installing bandit..."
    pip install bandit safety
fi

# Bandit: Python security scanner
echo "Running bandit (Python security issues)..."
bandit -r . -ll -f txt -o ../bandit_report.txt 2>&1 || true
BANDIT_ISSUES=$(grep -c "Issue:" ../bandit_report.txt || echo "0")
log_result "Bandit High/Medium Issues: $BANDIT_ISSUES"
if [ "$BANDIT_ISSUES" -gt 0 ]; then
    log_result "${RED}⚠️  Security issues found! Check bandit_report.txt${NC}"
else
    log_result "${GREEN}✅ No high/medium security issues${NC}"
fi
log_result ""

# Safety: Dependency vulnerability check
echo "Running safety (dependency vulnerabilities)..."
pip freeze > requirements_freeze.txt
safety check --file requirements_freeze.txt --output text > ../safety_report.txt 2>&1 || true
SAFETY_ISSUES=$(grep -c "vulnerability" ../safety_report.txt || echo "0")
log_result "Safety Vulnerabilities: $SAFETY_ISSUES"
if [ "$SAFETY_ISSUES" -gt 0 ]; then
    log_result "${RED}⚠️  Vulnerable dependencies found! Check safety_report.txt${NC}"
else
    log_result "${GREEN}✅ No known vulnerabilities${NC}"
fi
rm requirements_freeze.txt
log_result ""

cd ..

# 2. Frontend Security Audit
echo -e "${YELLOW}[2/6] Running Flutter Security Audit...${NC}"
log_result "## Frontend Security (Flutter)"
log_result ""

cd flutter_app || exit 1

# Check for sensitive data in code
echo "Scanning for hardcoded secrets..."
SECRETS_FOUND=0

# API keys pattern
if grep -r "api_key.*=.*['\"][A-Za-z0-9_-]\{20,\}" lib/ > /dev/null 2>&1; then
    SECRETS_FOUND=$((SECRETS_FOUND + 1))
    log_result "${RED}⚠️  Potential API keys found in code${NC}"
fi

# Passwords pattern
if grep -r "password.*=.*['\"]" lib/ | grep -v "passwordController" > /dev/null 2>&1; then
    SECRETS_FOUND=$((SECRETS_FOUND + 1))
    log_result "${RED}⚠️  Potential hardcoded passwords found${NC}"
fi

# Tokens pattern
if grep -r "token.*=.*['\"][A-Za-z0-9_-]\{20,\}" lib/ > /dev/null 2>&1; then
    SECRETS_FOUND=$((SECRETS_FOUND + 1))
    log_result "${RED}⚠️  Potential hardcoded tokens found${NC}"
fi

if [ $SECRETS_FOUND -eq 0 ]; then
    log_result "${GREEN}✅ No hardcoded secrets detected${NC}"
fi
log_result ""

# Check for insecure storage
echo "Checking for insecure storage patterns..."
INSECURE_STORAGE=0

if grep -r "SharedPreferences" lib/ | grep -v "flutter_secure_storage" > /dev/null 2>&1; then
    INSECURE_STORAGE=$((INSECURE_STORAGE + 1))
    log_result "${YELLOW}⚠️  Consider using flutter_secure_storage instead of SharedPreferences for sensitive data${NC}"
fi

if [ $INSECURE_STORAGE -eq 0 ]; then
    log_result "${GREEN}✅ Secure storage patterns used${NC}"
fi
log_result ""

cd ..

# 3. Environment Variables Check
echo -e "${YELLOW}[3/6] Checking Environment Variables...${NC}"
log_result "## Environment Variables"
log_result ""

# Backend .env check
if [ -f "backend/.env" ]; then
    log_result "${RED}⚠️  backend/.env exists (should not be committed)${NC}"
    if git ls-files --error-unmatch backend/.env > /dev/null 2>&1; then
        log_result "${RED}🚨 CRITICAL: backend/.env is tracked by git!${NC}"
    fi
else
    log_result "${GREEN}✅ backend/.env not present (good)${NC}"
fi

# Frontend .env check
if [ -f "flutter_app/.env" ]; then
    log_result "${RED}⚠️  flutter_app/.env exists (should not be committed)${NC}"
    if git ls-files --error-unmatch flutter_app/.env > /dev/null 2>&1; then
        log_result "${RED}🚨 CRITICAL: flutter_app/.env is tracked by git!${NC}"
    fi
else
    log_result "${GREEN}✅ flutter_app/.env not present (good)${NC}"
fi
log_result ""

# 4. CORS Configuration Check
echo -e "${YELLOW}[4/6] Checking CORS Configuration...${NC}"
log_result "## CORS Configuration"
log_result ""

if grep -r "allow_origins=\[\"*\"\]" backend/ > /dev/null 2>&1; then
    log_result "${RED}⚠️  CORS allows all origins (*) - restrict in production!${NC}"
else
    log_result "${GREEN}✅ CORS properly configured${NC}"
fi
log_result ""

# 5. Authentication Security
echo -e "${YELLOW}[5/6] Checking Authentication Security...${NC}"
log_result "## Authentication Security"
log_result ""

cd backend || exit 1

# Check for weak JWT settings
if grep -r "algorithm.*=.*\"HS256\"" . > /dev/null 2>&1; then
    log_result "${GREEN}✅ JWT using HS256 algorithm${NC}"
fi

# Check for password hashing
if grep -r "passlib" requirements.txt > /dev/null 2>&1; then
    log_result "${GREEN}✅ Password hashing library present (passlib)${NC}"
fi

# Check for 2FA implementation
if grep -r "pyotp" requirements.txt > /dev/null 2>&1; then
    log_result "${GREEN}✅ 2FA library present (pyotp)${NC}"
fi

cd ..
log_result ""

# 6. Dependency Audit
echo -e "${YELLOW}[6/6] Running Dependency Audit...${NC}"
log_result "## Dependency Audit"
log_result ""

# Backend dependencies
cd backend || exit 1
TOTAL_DEPS=$(pip list | wc -l)
log_result "Backend Dependencies: $TOTAL_DEPS"

# Check for outdated packages
pip list --outdated > ../outdated_packages.txt 2>&1
OUTDATED=$(grep -c "." ../outdated_packages.txt || echo "0")
log_result "Outdated Packages: $OUTDATED"

cd ..

# Flutter dependencies
cd flutter_app || exit 1
flutter pub outdated > ../flutter_outdated.txt 2>&1 || true
log_result ""
log_result "Flutter package status saved to flutter_outdated.txt"

cd ..
log_result ""

# Summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Security Audit Complete                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Report saved to: $AUDIT_REPORT"
echo ""
echo "Generated Reports:"
echo "  - $AUDIT_REPORT (main report)"
echo "  - bandit_report.txt (Python security)"
echo "  - safety_report.txt (dependency vulnerabilities)"
echo "  - outdated_packages.txt (backend)"
echo "  - flutter_outdated.txt (frontend)"
echo ""
echo "Recommended Actions:"
echo "1. Review all reports for critical issues"
echo "2. Update vulnerable dependencies"
echo "3. Fix hardcoded secrets (use environment variables)"
echo "4. Restrict CORS in production"
echo "5. Ensure .env files are in .gitignore"
echo ""
