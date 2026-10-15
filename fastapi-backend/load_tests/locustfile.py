"""
FastKirana Locust Load & Stress Testing Suite.
Simulates high-concurrency peak festive sale surges (browsing, cart operations, checkout).
Tests connection pool exhaustion limits and durability under load.
"""

import uuid
import random
from locust import HttpUser, task, between, events
from typing import Dict, Any

class FastKiranaCustomerUser(HttpUser):
    # Wait between 0.5 to 2.5 seconds between simulated customer actions
    wait_time = between(0.5, 2.5)

    def on_start(self):
        """Initialize simulated user credentials and headers."""
        # SAFETY GUARD: Prevent accidental load tests against production domain to avoid Railway abuse triggers
        target_host = str(self.host or "").lower()
        if "fastkirana.in" in target_host and not os.environ.get("FORCE_PROD_LOAD_TEST"):
            raise RuntimeError(
                f"[CRITICAL SAFETY BLOCK] Locust is configured to target live production ({self.host}). "
                "Direct high-concurrency load testing against production is disabled to protect against provider bans. "
                "Target localhost:8000 or a dedicated staging environment instead."
            )

        self.user_id = f"stress_user_{uuid.uuid4().hex[:12]}"
        self.auth_token = None
        self.headers = {
            "Content-Type": "application/json",
            "x-user-id": self.user_id,
            "x-user-role": "USER",
        }
        self.cart_items = []

    @task(5)
    def browse_products(self):
        """High frequency: Browse products catalog with category filters."""
        params = {"limit": 20, "page": random.randint(1, 5)}
        with self.client.get("/api/products", params=params, headers=self.headers, catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Browse products failed with {response.status_code}")

    @task(3)
    def view_cart(self):
        """Inspect current cart items."""
        with self.client.get("/api/cart", headers=self.headers, catch_response=True) as response:
            if response.status_code in [200, 404]:
                response.success()
            else:
                response.failure(f"Cart view failed with {response.status_code}")

    @task(4)
    def update_cart_item(self):
        """Simulate concurrent cart mutation."""
        product_id = f"prod_sample_{random.randint(1, 100)}"
        qty = random.randint(1, 5)
        payload = {
            "productId": product_id,
            "quantity": qty
        }
        with self.client.post("/api/cart/items", json=payload, headers=self.headers, catch_response=True) as response:
            if response.status_code in [200, 201]:
                response.success()
            elif response.status_code in [400, 404]:
                # Handled business rejection (e.g., sample product doesn't exist)
                response.success()
            else:
                response.failure(f"Cart update failed with {response.status_code}")

    @task(2)
    def calculate_delivery_surge(self):
        """Simulate geofence and surge fee calculations during rush hour."""
        payload = {
            "lat": 26.1534 + (random.random() - 0.5) * 0.05,
            "lng": 80.1714 + (random.random() - 0.5) * 0.05,
            "subtotal": random.choice([99.0, 149.0, 299.0, 499.0])
        }
        with self.client.post("/api/delivery/calculate", json=payload, headers=self.headers, catch_response=True) as response:
            if response.status_code in [200, 400]:
                response.success()
            else:
                response.failure(f"Delivery calculation failed with {response.status_code}")

    @task(1)
    def checkout_attempt(self):
        """Simulate concurrent flash sale checkout with idempotency key."""
        idempotency_key = f"idemp_surge_{uuid.uuid4().hex}"
        checkout_headers = {
            **self.headers,
            "X-Idempotency-Key": idempotency_key
        }
        checkout_payload = {
            "items": [
                {
                    "productId": f"prod_flash_{random.randint(1, 20)}",
                    "quantity": random.randint(1, 2),
                    "price": 100.0,
                    "name": "Festive Special Item"
                }
            ],
            "addressId": f"addr_stress_{random.randint(1, 50)}",
            "paymentMethod": "COD",
            "deliveryMethod": "DELIVERY"
        }
        with self.client.post("/api/orders", json=checkout_payload, headers=checkout_headers, catch_response=True) as response:
            # Under load, expect 201 Created, 200 Replayed, or 400 validation error (e.g. stock/address)
            # 500 or 503 indicates pool exhaustion or unhandled database deadlock
            if response.status_code in [200, 201, 400, 404, 409]:
                response.success()
            else:
                response.failure(f"Checkout crashed or timed out with {response.status_code}: {response.text[:100]}")
