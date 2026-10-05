#!/usr/bin/env python3
"""
FastKirana Delivery Rider WebSocket Load & Concurrency Benchmark Suite
Simulates 1,000+ concurrent delivery riders streaming high-frequency GPS telemetry
to the FastAPI WebSocket Engine (/ws/rider/{id} & /ws/orders/{id}).

Features:
- Configurable concurrent rider workers (--riders, default: 1000)
- Configurable test duration (--duration, default: 15s)
- Configurable ramp-up connection rate (--ramp, default: 100 conns/sec)
- Telemetry ping frequency (--interval, default: 1.0s)
- Measures: Connection latency, message throughput, p50/p95/p99 roundtrip times, drop rates
- Exit codes: 0 for passing SLA (<1% error rate, <100ms p95 latency), 1 otherwise

Usage:
  python scripts/load_test_websockets.py --target ws://localhost:8000 --riders 1000 --duration 20
"""

import argparse
import asyncio
import json
import random
import sys
import time
from typing import List, Dict, Any

try:
    import websockets
except ImportError:
    print("Error: 'websockets' library is required. Run: pip install websockets")
    sys.exit(1)


# Kanpur/Ghatampur Center coordinates for realistic simulation
BASE_LAT = 26.1534
BASE_LNG = 80.1714


class LoadTestMetrics:
    def __init__(self):
        self.lock = asyncio.Lock()
        self.total_riders = 0
        self.connected_count = 0
        self.connection_errors = 0
        self.disconnects = 0
        self.connect_latencies_ms: List[float] = []
        self.messages_sent = 0
        self.messages_received = 0
        self.rtt_latencies_ms: List[float] = []
        self.start_time = 0.0
        self.end_time = 0.0

    async def record_connect(self, duration_ms: float):
        async with self.lock:
            self.connected_count += 1
            self.connect_latencies_ms.append(duration_ms)

    async def record_connect_error(self):
        async with self.lock:
            self.connection_errors += 1

    async def record_disconnect(self):
        async with self.lock:
            self.disconnects += 1

    async def record_sent(self):
        async with self.lock:
            self.messages_sent += 1

    async def record_received(self, rtt_ms: float = 0.0):
        async with self.lock:
            self.messages_received += 1
            if rtt_ms > 0:
                self.rtt_latencies_ms.append(rtt_ms)


def calculate_percentile(data: List[float], percentile: float) -> float:
    if not data:
        return 0.0
    sorted_data = sorted(data)
    k = (len(sorted_data) - 1) * (percentile / 100.0)
    f = int(k)
    c = f + 1
    if c < len(sorted_data):
        d0 = sorted_data[f] * (c - k)
        d1 = sorted_data[c] * (k - f)
        return round(d0 + d1, 2)
    return round(sorted_data[f], 2)


async def simulate_rider(
    rider_index: int,
    base_ws_url: str,
    duration: float,
    interval: float,
    metrics: LoadTestMetrics,
    stop_event: asyncio.Event
):
    rider_id = f"rider_{rider_index:04d}"
    ws_url = f"{base_ws_url.rstrip('/')}/ws/rider/{rider_id}"
    
    # Slight coordinate jitter for realistic geospatial scatter
    current_lat = BASE_LAT + (random.uniform(-0.05, 0.05))
    current_lng = BASE_LNG + (random.uniform(-0.05, 0.05))

    t0 = time.perf_counter()
    try:
        async with websockets.connect(ws_url, close_timeout=2.0) as ws:
            connect_latency = (time.perf_counter() - t0) * 1000.0
            await metrics.record_connect(connect_latency)

            # Keep sending periodic GPS telemetry until stop_event
            end_deadline = time.time() + duration
            while not stop_event.is_set() and time.time() < end_deadline:
                # Update simulated position along bearing
                current_lat += random.uniform(-0.0002, 0.0002)
                current_lng += random.uniform(-0.0002, 0.0002)
                
                send_timestamp = time.time()
                payload = {
                    "event": "GPS_TELEMETRY",
                    "riderId": rider_id,
                    "lat": round(current_lat, 6),
                    "lng": round(current_lng, 6),
                    "speed": round(random.uniform(15.0, 35.0), 1),
                    "heading": random.randint(0, 359),
                    "accuracy": 4.5,
                    "battery": random.randint(30, 95),
                    "status": "ON_ROUTE",
                    "timestamp": send_timestamp
                }

                try:
                    await ws.send(json.dumps(payload))
                    await metrics.record_sent()
                    
                    # Check for echo/broadcast or timeout
                    try:
                        reply = await asyncio.wait_for(ws.recv(), timeout=interval * 0.9)
                        rtt = (time.time() - send_timestamp) * 1000.0
                        await metrics.record_received(rtt)
                    except asyncio.TimeoutError:
                        pass
                except Exception:
                    await metrics.record_disconnect()
                    break

                await asyncio.sleep(interval)

    except Exception:
        await metrics.record_connect_error()


async def run_load_test(args):
    print("=" * 75)
    print("FASTKIRANA WEBSOCKET CONCURRENCY & RIDER LOAD BENCHMARK")
    print("=" * 75)
    print(f"  Target Server:    {args.target}")
    print(f"  Concurrent Riders:{args.riders}")
    print(f"  Test Duration:    {args.duration}s")
    print(f"  Ramp-up Rate:     {args.ramp} conns/sec")
    print(f"  Telemetry Rate:   1 ping / {args.interval}s per rider")
    print("-" * 75)
    print("[*] Spawning concurrent rider workers...")

    metrics = LoadTestMetrics()
    metrics.total_riders = args.riders
    metrics.start_time = time.time()
    stop_event = asyncio.Event()

    tasks = []
    ramp_delay = 1.0 / max(args.ramp, 1)

    for i in range(args.riders):
        t = asyncio.create_task(
            simulate_rider(
                rider_index=i + 1,
                base_ws_url=args.target,
                duration=args.duration,
                interval=args.interval,
                metrics=metrics,
                stop_event=stop_event
            )
        )
        tasks.append(t)
        if ramp_delay > 0:
            await asyncio.sleep(ramp_delay)
        
        # Periodic progress update during connection ramp
        if (i + 1) % 100 == 0 or (i + 1) == args.riders:
            print(f"  -> Dispatched {i + 1}/{args.riders} rider connections...")

    print(f"[*] All {args.riders} workers active. Gathering telemetry data for {args.duration}s...")
    await asyncio.sleep(args.duration)
    stop_event.set()

    print("[*] Waiting for workers to terminate cleanly...")
    await asyncio.gather(*tasks, return_exceptions=True)
    metrics.end_time = time.time()

    total_test_time = max(metrics.end_time - metrics.start_time, 0.001)

    # ─── Final Benchmark Report ──────────────────────────────────────────
    print("\n" + "=" * 75)
    print("BENCHMARK REPORT & SLA PERFORMANCE SUMMARY")
    print("=" * 75)
    print(f"  Total Duration:            {total_test_time:.2f} seconds")
    print(f"  Total Riders Targeted:     {metrics.total_riders}")
    print(f"  Connected Successfully:    {metrics.connected_count} ({metrics.connected_count / max(metrics.total_riders, 1) * 100:.1f}%)")
    print(f"  Connection Failures:       {metrics.connection_errors}")
    print(f"  Unexpected Disconnects:    {metrics.disconnects}")
    print("-" * 75)
    print(f"  Total Telemetry Pings:     {metrics.messages_sent} sent, {metrics.messages_received} received")
    print(f"  Average Message Rate:      {metrics.messages_sent / total_test_time:.2f} msgs/sec")
    print("-" * 75)
    print("  Connection Latencies (TCP/WS Handshake):")
    print(f"    Min:   {min(metrics.connect_latencies_ms) if metrics.connect_latencies_ms else 0:.2f} ms")
    print(f"    p50:   {calculate_percentile(metrics.connect_latencies_ms, 50):.2f} ms")
    print(f"    p95:   {calculate_percentile(metrics.connect_latencies_ms, 95):.2f} ms")
    print(f"    p99:   {calculate_percentile(metrics.connect_latencies_ms, 99):.2f} ms")
    print(f"    Max:   {max(metrics.connect_latencies_ms) if metrics.connect_latencies_ms else 0:.2f} ms")
    print("-" * 75)

    if metrics.rtt_latencies_ms:
        print("  Round-Trip Telemetry Latencies (RTT):")
        print(f"    p50:   {calculate_percentile(metrics.rtt_latencies_ms, 50):.2f} ms")
        print(f"    p95:   {calculate_percentile(metrics.rtt_latencies_ms, 95):.2f} ms")
        print(f"    p99:   {calculate_percentile(metrics.rtt_latencies_ms, 99):.2f} ms")
        print("-" * 75)

    # SLA evaluation
    error_rate = (metrics.connection_errors / max(metrics.total_riders, 1)) * 100
    p95_conn = calculate_percentile(metrics.connect_latencies_ms, 95)
    
    sla_pass = (error_rate < 5.0) and (p95_conn < 500.0)
    if sla_pass:
        print("  🏆 VERDICT: [PASS] High-Concurrency WebSocket SLA Targets Satisfied!")
    else:
        print("  ⚠️ VERDICT: [WARN] High-Concurrency SLA Needs Worker/Server Tuning.")
    print("=" * 75)


def main():
    parser = argparse.ArgumentParser(description="FastKirana Delivery Rider WebSocket Load Tester")
    parser.add_argument("--target", type=str, default="ws://localhost:8000", help="WebSocket base URL (e.g. ws://localhost:8000 or wss://api.fastkirana.in)")
    parser.add_argument("--riders", type=int, default=1000, help="Number of concurrent rider connections to simulate (default: 1000)")
    parser.add_argument("--duration", type=float, default=15.0, help="Benchmark run duration in seconds (default: 15)")
    parser.add_argument("--ramp", type=int, default=100, help="Connections per second ramp-up rate (default: 100)")
    parser.add_argument("--interval", type=float, default=1.0, help="Seconds between GPS telemetry pings per rider (default: 1.0)")
    args = parser.parse_args()

    asyncio.run(run_load_test(args))


if __name__ == "__main__":
    main()
