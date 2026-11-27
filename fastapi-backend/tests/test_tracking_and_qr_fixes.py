import os
import sys
import asyncio
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from routers import orders_notifications


class TestTrackingAndQrFixes(unittest.TestCase):
    def test_clear_order_cache_purges_all_aliases(self):
        orders_notifications._order_details_cache.clear()
        orders_notifications._order_details_cache_time.clear()

        sample_payload = {
            "id": "ord_test_12345",
            "readableId": "4639-R",
            "combinedId": "combined_abc_999",
            "status": "ADMIN_PENDING",
        }
        other_payload = {
            "id": "ord_other_999",
            "readableId": "4640-G",
            "combinedId": None,
            "status": "CONFIRMED",
        }

        keys_for_target = [
            "ord_test_12345:usr_1:CUSTOMER",
            "4639-R:usr_1:CUSTOMER",
            "4639:usr_1:CUSTOMER",
            "combined_abc_999:usr_1:CUSTOMER",
        ]
        for k in keys_for_target:
            orders_notifications._order_details_cache[k] = sample_payload
            orders_notifications._order_details_cache_time[k] = 9999999999.0

        orders_notifications._order_details_cache["4640-G:usr_2:CUSTOMER"] = other_payload
        orders_notifications._order_details_cache_time["4640-G:usr_2:CUSTOMER"] = 9999999999.0

        # Clearing by order.id MUST purge id, readableId, base readableId, and combinedId cache keys!
        orders_notifications.clear_order_cache("ord_test_12345")

        for k in keys_for_target:
            self.assertNotIn(k, orders_notifications._order_details_cache, f"Stale cache key survived: {k}")
        self.assertIn("4640-G:usr_2:CUSTOMER", orders_notifications._order_details_cache)

    def test_clear_order_cache_by_readable_id_purges_base_key(self):
        orders_notifications._order_details_cache.clear()
        orders_notifications._order_details_cache_time.clear()

        orders_notifications._order_details_cache["4639:usr_1:CUSTOMER"] = {"id": "ord_1", "readableId": "4639-G"}
        orders_notifications._order_details_cache["4639-G:usr_1:CUSTOMER"] = {"id": "ord_1", "readableId": "4639-G"}

        orders_notifications.clear_order_cache("4639-G")
        self.assertEqual(len(orders_notifications._order_details_cache), 0)

    def test_supabase_realtime_location_broadcast_live(self):
        """Verify live Supabase Realtime broadcast REST endpoint accepts location_update payload."""
        from dotenv import load_dotenv
        load_dotenv(os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".env")))
        from utils.supabase_broadcast import broadcast_supabase_realtime

        async def _run():
            # Harmless isolated test topic (no real customer is subscribed to this)
            await broadcast_supabase_realtime(
                topics=["order-live-tracking-self-test-ping"],
                event="location_update",
                payload={"lat": 26.1534, "lng": 80.1714, "heading": 90.0, "speed": 5.0},
            )
            return True

        ok = asyncio.run(_run())
        self.assertTrue(ok)


if __name__ == "__main__":
    unittest.main()
