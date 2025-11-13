#!/usr/bin/env python3
"""
Basic security functionality test script
Tests core security utilities without requiring full database setup
"""

import sys
sys.path.insert(0, 'c:\\Ai Projecten\\AiFamQuest\\backend')

from core.security import (
    hash_password, verify_password,
    new_totp_secret, verify_totp, generate_totp_uri, generate_qr_code,
    generate_backup_codes, hash_backup_code, verify_backup_code,
    check_rate_limit, reset_rate_limit
)
import pyotp
import time

def test_password_hashing():
    """Test password hashing and verification"""
    print("Testing password hashing...")
    password = "TestPass123!"
    hashed = hash_password(password)
    assert verify_password(password, hashed), "Password verification failed"
    assert not verify_password("WrongPass", hashed), "Wrong password should not verify"
    print("✓ Password hashing works")

def test_totp():
    """Test TOTP generation and verification"""
    print("Testing TOTP...")
    secret = new_totp_secret()
    assert len(secret) > 0, "TOTP secret generation failed"

    # Generate code
    code = pyotp.TOTP(secret).now()
    assert verify_totp(secret, code), "TOTP verification failed"
    assert not verify_totp(secret, "000000"), "Invalid code should not verify"
    print(f"✓ TOTP works (secret: {secret[:10]}..., code: {code})")

def test_totp_uri():
    """Test TOTP URI generation"""
    print("Testing TOTP URI...")
    secret = new_totp_secret()
    uri = generate_totp_uri(secret, "test@example.com")
    assert uri.startswith("otpauth://totp/"), "Invalid TOTP URI"
    assert "test@example.com" in uri, "Email not in URI"
    assert secret in uri, "Secret not in URI"
    print(f"✓ TOTP URI works: {uri[:50]}...")

def test_qr_code():
    """Test QR code generation"""
    print("Testing QR code generation...")
    secret = new_totp_secret()
    uri = generate_totp_uri(secret, "test@example.com")
    qr_bytes = generate_qr_code(uri)
    assert len(qr_bytes) > 0, "QR code generation failed"
    assert qr_bytes.startswith(b'\x89PNG'), "Not a valid PNG image"
    print(f"✓ QR code generated ({len(qr_bytes)} bytes)")

def test_backup_codes():
    """Test backup code generation and verification"""
    print("Testing backup codes...")
    codes = generate_backup_codes(10)
    assert len(codes) == 10, "Should generate 10 codes"
    assert len(codes) == len(set(codes)), "Codes should be unique"

    # Test hashing and verification
    code = codes[0]
    hashed = hash_backup_code(code)
    assert verify_backup_code(code, hashed), "Backup code verification failed"
    assert not verify_backup_code("WRONG123", hashed), "Wrong code should not verify"
    print(f"✓ Backup codes work (example: {code})")

def test_rate_limiting():
    """Test rate limiting functionality"""
    print("Testing rate limiting...")
    key = f"test_{int(time.time())}"

    # Should allow 5 attempts
    for i in range(5):
        assert check_rate_limit(key, max_attempts=5), f"Attempt {i+1} should be allowed"

    # 6th attempt should be blocked
    assert not check_rate_limit(key, max_attempts=5), "6th attempt should be rate limited"

    # Reset and try again
    reset_rate_limit(key)
    assert check_rate_limit(key, max_attempts=5), "Should work after reset"
    print("✓ Rate limiting works")

def main():
    """Run all tests"""
    print("=" * 60)
    print("FamQuest Security Utilities Test")
    print("=" * 60)
    print()

    tests = [
        test_password_hashing,
        test_totp,
        test_totp_uri,
        test_qr_code,
        test_backup_codes,
        test_rate_limiting,
    ]

    passed = 0
    failed = 0

    for test in tests:
        try:
            test()
            passed += 1
            print()
        except Exception as e:
            print(f"✗ Test failed: {e}")
            failed += 1
            print()

    print("=" * 60)
    print(f"Results: {passed} passed, {failed} failed")
    print("=" * 60)

    return 0 if failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
