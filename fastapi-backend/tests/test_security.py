"""
Security Smoke Tests for FastKirana FastAPI Backend.
Verifies that all critical security fixes remain intact across deployments.

Run: pytest tests/test_security.py -v
"""
import pytest
import os
import sys

# Ensure fastapi-backend is on the path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# ─── Test 1: Master OTP Bypass is Blocked ──────────────────────────

class TestMasterOTPBypass:
    """Verify master OTP 261300 is restricted to review test phone only."""

    def test_review_accounts_dict_exists(self):
        """_REVIEW_ACCOUNTS must exist and map only test phones."""
        from routers.auth import verify_otp
        # The function source should contain _REVIEW_ACCOUNTS with only 0000000000
        import inspect
        source = inspect.getsource(verify_otp)
        assert '"0000000000"' in source, "Review account test phone 0000000000 must be defined"
        assert 'MASTER_OTPS' not in source, "Legacy MASTER_OTPS list must be removed"

    def test_master_otp_not_in_global_scope(self):
        """261300 must NOT be accepted for any arbitrary phone."""
        import routers.auth as auth_module
        source_code = open(auth_module.__file__, 'r', encoding='utf-8').read()
        # The old pattern: MASTER_OTPS = ['261300'] followed by unconditional check
        assert "if entered_otp in MASTER_OTPS" not in source_code, \
            "Unconditional MASTER_OTPS check must be removed"


# ─── Test 2: Header Spoofing is Blocked ────────────────────────────

class TestHeaderSpoofing:
    """Verify x-user-* headers cannot grant admin without INTERNAL_API_SECRET."""

    def test_no_fabricated_admin_user(self):
        """The old 'admin-user' fabricated identity must be removed."""
        import routers.auth as auth_module
        source_code = open(auth_module.__file__, 'r', encoding='utf-8').read()
        assert '"id": x_user_id or "admin-user"' not in source_code, \
            "Fabricated admin-user identity must be removed from get_current_user"
        assert '"admin-user"' not in source_code, \
            "String 'admin-user' must not appear in auth.py"

    def test_internal_secret_check_exists(self):
        """INTERNAL_API_SECRET grace period / check must be present."""
        import routers.auth as auth_module
        source_code = open(auth_module.__file__, 'r', encoding='utf-8').read()
        assert 'INTERNAL_API_SECRET' in source_code, \
            "INTERNAL_API_SECRET check must exist in get_current_user"
        assert 'x-internal-secret' in source_code, \
            "x-internal-secret header must be read in get_current_user"

    def test_no_hardcoded_phone_in_header_fallback(self):
        """Hardcoded phone 8112849854 must NOT be in header trust logic."""
        import routers.auth as auth_module
        source_code = open(auth_module.__file__, 'r', encoding='utf-8').read()
        # Find the get_current_user function and check for hardcoded phone
        gcu_start = source_code.find("async def get_current_user")
        gcu_end = source_code.find("\nasync def require_auth")
        get_current_user_source = source_code[gcu_start:gcu_end]
        assert "8112849854" not in get_current_user_source, \
            "Hardcoded phone 8112849854 must not be in get_current_user"


# ─── Test 3: require_admin is DB-Role Only ─────────────────────────

class TestRequireAdmin:
    """Verify require_admin checks database role, not hardcoded values."""

    def test_no_hardcoded_phone_in_require_admin(self):
        """require_admin must not contain hardcoded phone numbers."""
        import routers.auth as auth_module
        source_code = open(auth_module.__file__, 'r', encoding='utf-8').read()
        ra_start = source_code.find("async def require_admin")
        ra_end = source_code.find("\n\nasync def require_delivery")
        if ra_end == -1:
            ra_end = source_code.find("\nasync def require_delivery")
        require_admin_source = source_code[ra_start:ra_end]
        assert "8112849854" not in require_admin_source, \
            "Hardcoded phone must not be in require_admin"
        assert "hrdk" not in require_admin_source, \
            "Hardcoded email pattern 'hrdk' must not be in require_admin"
        assert 'email.startswith("admin")' not in require_admin_source, \
            "Email prefix check must not be in require_admin"

    def test_require_admin_uses_role_check(self):
        """require_admin must check role in ['ADMIN', 'SUPER_ADMIN']."""
        import inspect
        from routers.auth import require_admin
        source = inspect.getsource(require_admin)
        assert "ADMIN" in source, "require_admin must check for ADMIN role"
        assert "SUPER_ADMIN" in source, "require_admin must check for SUPER_ADMIN role"


# ─── Test 4: Hardcoded Checks Removed from Other Routers ──────────

class TestHardcodedChecksRemoved:
    """Verify hardcoded phone/email admin checks are removed from all routers."""

    @pytest.mark.parametrize("router_file", [
        "routers/products.py",
        "routers/restaurants.py",
        "routers/picker.py",
    ])
    def test_no_hardcoded_phone_in_router(self, router_file):
        """No router should contain hardcoded phone-based admin checks."""
        filepath = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), router_file)
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        # Check for hardcoded phone patterns in is_admin assignments
        import re
        # Find all is_admin = (...) blocks
        is_admin_blocks = re.findall(r'is_admin\s*=\s*\([\s\S]*?\)', content)
        for block in is_admin_blocks:
            assert "8112849854" not in block, \
                f"Hardcoded phone 8112849854 found in is_admin check in {router_file}"
            assert "hrdk" not in block, \
                f"Hardcoded 'hrdk' email pattern found in is_admin check in {router_file}"

    def test_admin_extended_uses_super_admins_table(self):
        """admin_extended.py root admin safeguard must query super_admins table."""
        filepath = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                "routers/admin_extended.py")
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        assert "SuperAdmin" in content, \
            "admin_extended.py must import and query SuperAdmin model for root admin check"


# ─── Test 5: CORS is Locked ────────────────────────────────────────

class TestCORSConfig:
    """Verify CORS is not wildcard in production."""

    def test_cors_not_wildcard(self):
        """main.py must not have allow_origins=['*'] without env override."""
        filepath = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "main.py")
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        # The old pattern: allow_origins=["*"] as the direct value
        assert 'allow_origins=["*"],' not in content, \
            "Hardcoded CORS wildcard must be removed — use _cors_origins list"
        assert "fastkirana.in" in content, \
            "CORS origins must include fastkirana.in"


# ─── Test 6: Sensitive Data Not Logged ─────────────────────────────

class TestNoSensitiveLogging:
    """Verify OTP codes and tokens are not printed in logs."""

    def test_no_otp_in_logs(self):
        """OTP values must not be printed to stdout."""
        filepath = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                "routers/auth.py")
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        # Check for patterns that leak OTP codes
        assert "stored_code={code}" not in content, \
            "OTP code must not be logged (stored_code pattern)"
        assert "entered_otp={entered_otp}" not in content, \
            "Entered OTP must not be logged"


# ─── Test 7: Rate Limiter Configured ──────────────────────────────

class TestRateLimiter:
    """Verify slowapi rate limiter is configured."""

    def test_slowapi_in_main(self):
        """main.py must configure slowapi limiter."""
        filepath = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "main.py")
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        assert "slowapi" in content or "Limiter" in content, \
            "SlowAPI rate limiter must be configured in main.py"

    def test_slowapi_in_requirements(self):
        """slowapi must be in requirements.txt."""
        filepath = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                "requirements.txt")
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        assert "slowapi" in content, "slowapi must be in requirements.txt"


# ─── Test 8: DB Pool Config ──────────────────────────────────────

class TestDBPoolConfig:
    """Verify connection pool is properly configured."""

    def test_pool_size_reasonable(self):
        """pool_size should be <= 15 per worker for Supabase safety."""
        from database import engine
        assert engine.pool.size() <= 15, \
            f"pool_size={engine.pool.size()} is too high for Supabase — should be <= 15"

    def test_pool_pre_ping_enabled(self):
        """pool_pre_ping must be True to catch dead connections."""
        from database import engine
        assert engine.pool._pre_ping is True, "pool_pre_ping must be enabled"
