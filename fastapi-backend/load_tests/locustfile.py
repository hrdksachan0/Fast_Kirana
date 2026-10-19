"""
FastKirana & FastMinute Locust Load & Capacity Testing Suite.
Simulates concurrent shoppers (browsing, cart sync, address quotes, checkout).
Tests connection pool exhaustion limits and durability under load.
"""

import os
import uuid
import random
from urllib.parse import urlparse
from typing import Dict, Any, List
from locust import HttpUser, task, between, events

# Allowed origins for load/stress tests (staging and local environments ONLY)
ALLOWED_LOAD_TEST_ORIGINS = {
    "localhost",
    "127.0.0.1",
    "0.0.0.0",
    "staging.fastkirana.in",
    "staging.fastminute.in",
    "staging-api.fastkirana.in",
    "fastkirana-staging.up.railway.app",
    "fastminute-staging.up.railway.app",
}

BLOCKED_PRODUCTION_PATTERNS = [
    "fastkirana.in",
    "fastminute.in",
    "fastminute.app",
    "fastkirana.com",
    "railway.app", # unless explicitly staging prefix
]


class FastKiranaCustomerUser(HttpUser):
    # Realistic shopper pacing between 3.0 to 8.0 seconds
    wait_time = between(3.0, 8.0)

    def on_start(self):
        """Initialize verified staging user session and enforce origin guard."""
        target_host = str(self.host or "").strip().lower()
        parsed = urlparse(target_host if "://" in target_host else f"http://{target_host}")
        hostname = (parsed.hostname or "").lower()

        # STRICT SAFETY BLOCK: Guarantee load runner never targets production
        is_allowed = hostname in ALLOWED_LOAD_TEST_ORIGINS or hostname.endswith(".local") or hostname.startswith("staging-")
        is_blocked = any(prod in hostname for prod in ["fastkirana.in", "fastminute.in", "fastminute.app"]) and "staging" not in hostname

        if not is_allowed or is_blocked:
            raise RuntimeError(
                f"[CRITICAL SAFETY BLOCK] Locust target ({hostname}) is not in the staging allowlist: {ALLOWED_LOAD_TEST_ORIGINS}. "
                "High-concurrency load testing against production or unverified hosts is strictly prohibited."
            )

        self.guest_id = f"guest_stress_{uuid.uuid4().hex[:16]}"
        self.phone = f"9876{random.randint(100000, 999999)}"
        self.user_id = f"usr_{self.guest_id}"
        self.headers = {
            "Content-Type": "application/json",
            "x-guest-id": self.guest_id,
            "x-user-phone": self.phone,
            "x-user-role": "USER",
        }
        self.known_product_ids: List[str] = []

    @task(11)  # ~55% of user actions
    def browse_products(self):
        """High frequency: Browse products catalog with pagination."""
        params = {"limit": 20, "page": random.randint(1, 3)}
        with self.client.get("/api/products", params=params, headers=self.headers, catch_response=True) as response:
            if response.status_code == 200:
                try:
                    data = response.json()
                    products = data.get("products") or data.get("items") or (data if isinstance(data, list) else [])
                    for p in products[:5]:
                        if isinstance(p, dict) and p.get("id"):
                            self.known_product_ids.append(p["id"])
                    response.success()
                except Exception as e:
                    response.failure(f"Catalog response parsing error: {e}")
            else:
                response.failure(f"Browse products failed with HTTP {response.status_code}: {response.text[:100]}")

    @task(4)  # ~20% of user actions
    def cart_operations(self):
        """Inspect and mutate cart using correct /api/cart endpoints."""
        # 1. Inspect cart
        with self.client.get("/api/cart", headers=self.headers, catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Cart view failed with HTTP {response.status_code}: {response.text[:100]}")
                return

        # 2. Add/sync item if product IDs are known
        product_id = random.choice(self.known_product_ids) if self.known_product_ids else "prod_1"
        sync_payload = {
            "guestId": self.guest_id,
            "items": [
                {
                    "productId": product_id,
                    "quantity": random.randint(1, 3),
                    "selectedVariant": None,
                    "notes": ""
                }
            ]
        }
        with self.client.post("/api/cart", json=sync_payload, headers=self.headers, catch_response=True) as response:
            if response.status_code in [200, 201]:
                response.success()
            else:
                response.failure(f"Cart sync failed with HTTP {response.status_code}: {response.text[:100]}")

    @task(2)  # ~10% of user actions
    def calculate_delivery_quote(self):
        """Simulate geofence, fee and surge calculation."""
        payload = {
            "lat": 26.1534 + (random.random() - 0.5) * 0.02,
            "lng": 80.1714 + (random.random() - 0.5) * 0.02,
            "subtotal": random.choice([149.0, 249.0, 399.0, 599.0])
        }
        with self.client.post("/api/delivery/calculate", json=payload, headers=self.headers, catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Delivery calculation failed with HTTP {response.status_code}: {response.text[:100]}")

    @task(1)  # ~5% of user actions
    def checkout_attempt(self):
        """Simulate checkout write with idempotency key."""
        idempotency_key = f"idemp_load_{uuid.uuid4().hex}"
        checkout_headers = {
            **self.headers,
            "X-Idempotency-Key": idempotency_key
        }
        product_id = random.choice(self.known_product_ids) if self.known_product_ids else "prod_1"
        checkout_payload = {
            "items": [
                {
                    "productId": product_id,
                    "quantity": 1,
                    "price": 100.0,
                    "name": "Standard Catalog Item"
                }
            ],
            "customerPhone": self.phone,
            "paymentMethod": "COD",
            "deliveryMethod": "DELIVERY",
            "address": {
                "street": "123 Staging Boulevard",
                "city": "Kanpur",
                "pincode": "208001",
                "lat": 26.1534,
                "lng": 80.1714
            }
        }
        with self.client.post("/api/orders", json=checkout_payload, headers=checkout_headers, catch_response=True) as response:
            # Only genuine business successes (200 OK / 201 Created) count as success
            if response.status_code in [200, 201]:
                response.success()
            else:
                response.failure(f"Checkout failed with HTTP {response.status_code}: {response.text[:120]}")

    @task(2)  # ~10% of user actions
    def order_tracking_read(self):
        """Simulate customer polling order tracking status."""
        with self.client.get("/api/orders/user", headers=self.headers, catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            elif response.status_code == 404:
                # No orders placed yet for this user session is a valid empty read
                response.success()
            else:
                response.failure(f"Order tracking read failed with HTTP {response.status_code}: {response.text[:100]}")
