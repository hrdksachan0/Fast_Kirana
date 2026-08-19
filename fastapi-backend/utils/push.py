import os
import logging
import httpx
from typing import Optional, Dict, Any, List

logger = logging.getLogger("push_notifications")

async def send_push_notification(
    user_id: Optional[str] = None,
    roles: Optional[List[str]] = None,
    title: str = "",
    body: str = "",
    data: Optional[Dict[str, Any]] = None
) -> bool:
    """
    Sends a push notification by bridging to the Next.js API endpoint.
    Uses AUTH_SECRET for secret header authorization.
    """
    app_url = os.getenv("NEXT_PUBLIC_APP_URL", "http://localhost:3000")
    if app_url.endswith("/"):
        app_url = app_url[:-1]
        
    api_url = f"{app_url}/api/push/notify"
    secret = os.getenv("AUTH_SECRET")

    if not secret:
        logger.error("AUTH_SECRET not configured in environment, cannot send push notification.")
        return False

    payload = {
        "title": title,
        "body": body,
        "data": data or {}
    }
    
    if user_id:
        payload["userId"] = user_id
    elif roles:
        payload["roles"] = roles
    else:
        logger.error("Either user_id or roles must be specified to send push notification.")
        return False

    headers = {
        "x-api-secret": secret,
        "Content-Type": "application/json"
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(api_url, json=payload, headers=headers)
            if response.status_code == 200:
                logger.info(f"Push notification successfully bridged for user/roles: {user_id or roles}")
                return True
            else:
                logger.error(f"Failed to bridge push notification. Next.js status {response.status_code}: {response.text}")
                return False
    except Exception as e:
        logger.error(f"Exception occurred while sending push notification to Next.js API: {str(e)}")
        return False
