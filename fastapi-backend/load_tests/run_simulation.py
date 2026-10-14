"""
FastKirana In-Process Concurrency & Database Pool Stress Simulator.
Simulates concurrent database connection acquisition and transactional pressure
to benchmark pool behavior under simulated festive peak loads.
"""

import asyncio
import time
import statistics
import os
import sys

# Ensure backend root is on PYTHONPATH
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import AsyncSessionLocal, engine
from sqlalchemy import text


async def simulate_worker_query(worker_id: int) -> float:
    start = time.perf_counter()
    async with AsyncSessionLocal() as session:
        # Simulate rapid transactional check
        await session.execute(text("SELECT 1"))
    return (time.perf_counter() - start) * 1000.0


async def run_stress_simulation(concurrency: int = 100, total_requests: int = 500):
    print(f"\n=======================================================")
    print(f"[BENCHMARK] FastKirana Peak Surge Stress Benchmark")
    print(f"Target Concurrency: {concurrency} simultaneous workers")
    print(f"Total Database Transactions: {total_requests}")
    print(f"Engine Pool: size={engine.pool.size()} max_overflow={getattr(engine.pool, '_max_overflow', 'N/A')}")
    print(f"=======================================================\n")

    latencies = []
    errors = 0
    start_total = time.perf_counter()

    semaphore = asyncio.Semaphore(concurrency)

    async def worker(req_id: int):
        nonlocal errors
        async with semaphore:
            try:
                lat = await simulate_worker_query(req_id)
                latencies.append(lat)
            except Exception as e:
                errors += 1
                if errors <= 3:
                    print(f"[WARN] [Worker {req_id}] Pool contention error: {e}")

    tasks = [worker(i) for i in range(total_requests)]
    await asyncio.gather(*tasks)

    duration = time.perf_counter() - start_total
    rps = total_requests / duration if duration > 0 else 0

    print(f"\n[REPORT] Benchmark Results:")
    print(f"-------------------------------------------------------")
    print(f"Total Requests:      {total_requests}")
    print(f"Successful:          {len(latencies)}")
    print(f"Failed / Dropped:    {errors} ({(errors/total_requests)*100:.2f}%)")
    print(f"Total Duration:      {duration:.2f}s")
    print(f"Throughput:          {rps:.1f} queries/second")

    if latencies:
        latencies.sort()
        p50 = statistics.median(latencies)
        p95 = latencies[int(len(latencies) * 0.95)]
        p99 = latencies[int(len(latencies) * 0.99)]
        print(f"Latency (p50):       {p50:.2f}ms")
        print(f"Latency (p95):       {p95:.2f}ms")
        print(f"Latency (p99):       {p99:.2f}ms")
        print(f"Max Latency:         {max(latencies):.2f}ms")

    print(f"-------------------------------------------------------")
    if errors == 0:
        print(f"[SUCCESS] POOL VERIFICATION PASSED: Zero connection timeouts under peak concurrency.")
    else:
        print(f"[ALERT] POOL SATURATION DETECTED: Consider increasing DB_POOL_SIZE / PgBouncer.")
    print(f"=======================================================\n")


if __name__ == "__main__":
    asyncio.run(run_stress_simulation(concurrency=50, total_requests=300))
