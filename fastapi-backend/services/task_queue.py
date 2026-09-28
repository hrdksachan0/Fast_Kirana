"""
Distributed & In-Process Task Queue Dispatcher
Dispatches background jobs gracefully using Redis if REDIS_URL is configured,
or seamlessly falls back to FastAPI's in-process BackgroundTasks.
"""
import os
import json
import logging
from typing import Callable, Any, Optional
from fastapi import BackgroundTasks
from config import settings

logger = logging.getLogger("task_queue")


def enqueue_background_task(
    background_tasks: Optional[BackgroundTasks],
    task_func: Callable,
    *args: Any,
    **kwargs: Any
) -> bool:
    """
    Safely enqueue a task.
    If background_tasks is supplied, adds it to the current request's background queue.
    Guarantees exceptions during enqueue are caught and logged without breaking response cycle.
    """
    if background_tasks is not None:
        try:
            background_tasks.add_task(task_func, *args, **kwargs)
            return True
        except Exception as e:
            logger.error(f"[TaskQueue] Failed to add background task {task_func.__name__}: {e}")
            return False

    # Standalone execution if background_tasks was not passed
    import asyncio
    try:
        loop = asyncio.get_running_loop()
        loop.create_task(task_func(*args, **kwargs))
        return True
    except RuntimeError:
        # No running loop in thread, run synchronously as safe fallback
        try:
            import inspect
            if inspect.iscoroutinefunction(task_func):
                asyncio.run(task_func(*args, **kwargs))
            else:
                task_func(*args, **kwargs)
            return True
        except Exception as sync_err:
            logger.error(f"[TaskQueue] Fallback execution failed for {task_func.__name__}: {sync_err}")
            return False


async def publish_event_to_redis(channel: str, event_data: dict) -> bool:
    """
    Publish an event to a Redis pub/sub channel if Redis is configured.
    """
    if not settings.REDIS_URL:
        return False

    try:
        from redis import asyncio as aioredis
        redis = aioredis.from_url(settings.REDIS_URL)
        payload = json.dumps(event_data)
        await redis.publish(channel, payload)
        await redis.close()
        return True
    except Exception as e:
        logger.warning(f"[TaskQueue] Failed to publish event to Redis channel '{channel}': {e}")
        return False
