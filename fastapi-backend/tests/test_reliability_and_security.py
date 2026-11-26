import hashlib
import hmac
import os
import sys
import unittest

# Ensure fastapi-backend root is on sys.path
BACKEND_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_ROOT not in sys.path:
    sys.path.insert(0, BACKEND_ROOT)


class TestReliabilityAndSecurity(unittest.TestCase):
    def test_tiered_rate_limit_buckets(self):
        from main import resolve_rate_limit_bucket

        self.assertEqual(resolve_rate_limit_bucket("/api/auth/send-otp", "POST"), ("auth_strict", 10))
        self.assertEqual(resolve_rate_limit_bucket("/api/auth/login", "POST"), ("auth_strict", 10))
        self.assertEqual(resolve_rate_limit_bucket("/api/orders", "POST"), ("order_create", 20))
        self.assertEqual(resolve_rate_limit_bucket("/api/orders", "GET"), ("general", 200))
        self.assertEqual(resolve_rate_limit_bucket("/api/products", "GET"), ("general", 200))

    def test_public_settings_sensitive_key_filter(self):
        from routers.settings import _is_sensitive_setting_key

        self.assertTrue(_is_sensitive_setting_key("razorpay_key_secret"))
        self.assertTrue(_is_sensitive_setting_key("cashfree_client_secret"))
        self.assertTrue(_is_sensitive_setting_key("supabase_service_role_key"))
        self.assertTrue(_is_sensitive_setting_key("whatsapp_webhook_secret"))
        self.assertFalse(_is_sensitive_setting_key("razorpay_key_id"))
        self.assertFalse(_is_sensitive_setting_key("active_payment_gateway"))
        self.assertFalse(_is_sensitive_setting_key("store_lat"))

    def test_razorpay_captured_payment_extraction(self):
        from routers.cron import _extract_captured_razorpay_payment

        captured_payload = {
            "items": [
                {"id": "pay_failed_1", "status": "failed", "captured": False},
                {"id": "pay_live_999", "status": "captured", "captured": True},
            ]
        }
        self.assertEqual(_extract_captured_razorpay_payment(captured_payload), "pay_live_999")

        unpaid_payload = {
            "items": [
                {"id": "pay_pending_1", "status": "created", "captured": False},
            ]
        }
        self.assertIsNone(_extract_captured_razorpay_payment(unpaid_payload))
        self.assertIsNone(_extract_captured_razorpay_payment(None))

    def test_razorpay_hmac_signature_verification(self):
        from config import settings
        from routers.razorpay_router import verify_razorpay_signature

        original_secret = settings.RAZORPAY_KEY_SECRET
        try:
            settings.RAZORPAY_KEY_SECRET = "test_secret_12345"
            order_id = "order_ABC123"
            payment_id = "pay_XYZ789"
            valid_sig = hmac.new(
                b"test_secret_12345",
                f"{order_id}|{payment_id}".encode("utf-8"),
                hashlib.sha256,
            ).hexdigest()

            self.assertTrue(verify_razorpay_signature(order_id, payment_id, valid_sig))
            self.assertFalse(verify_razorpay_signature(order_id, payment_id, "tampered_sig"))
        finally:
            settings.RAZORPAY_KEY_SECRET = original_secret


if __name__ == "__main__":
    unittest.main()
