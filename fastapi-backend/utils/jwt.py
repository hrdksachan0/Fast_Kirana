"""
JWT validation utilities for FastAPI.
Validates NextAuth.js JWT tokens using the same AUTH_SECRET.
"""

import os
import jwt
from typing import Optional, Dict, Any
from datetime import datetime, timezone


def get_clean_secret(key: str) -> str:
    """Clean environment variable (removes quotes if copy-pasted with quotes)."""
    val = os.getenv(key, "")
    val = val.strip()
    if val.startswith('"') and val.endswith('"'):
        val = val[1:-1]
    if val.startswith("'") and val.endswith("'"):
        val = val[1:-1]
    return val.strip()


# Get NextAuth secret (must be same as Next.js)
AUTH_SECRET = get_clean_secret("AUTH_SECRET")

if not AUTH_SECRET:
    raise ValueError(
        "AUTH_SECRET environment variable is required. "
        "Must match the NextAuth.js AUTH_SECRET used in Next.js frontend."
    )


def decode_nextauth_jwt(token: str) -> Optional[Dict[str, Any]]:
    """
    Decode NextAuth.js JWT token.

    NextAuth uses JWE (encrypted) JWTs by default in production.
    For simplicity and to support both development and production,
    we use HS256 with the AUTH_SECRET.

    Args:
        token: JWT token from Authorization header (without "Bearer ")

    Returns:
        Decoded token payload or None if invalid
    """
    try:
        # NextAuth.js default algorithm (since v4) is HS256
        payload = jwt.decode(
            token,
            AUTH_SECRET,
            algorithms=["HS256"],
            options={
                "verify_signature": True,
                "verify_exp": True,
                "verify_iat": True,
            }
        )
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None
    except Exception:
        return None


def extract_user_from_token(token: str) -> Optional[Dict[str, Any]]:
    """
    Extract user info from NextAuth JWT.

    Returns dict with: id, email, role, phone, assignedRestaurantId
    or None if token invalid.
    """
    payload = decode_nextauth_jwt(token)
    if not payload:
        return None

    # NextAuth.js v4/v5 puts user data directly in token
    # Field names match auth.config.ts callbacks
    return {
        "id": payload.get("id") or payload.get("sub"),
        "email": payload.get("email"),
        "name": payload.get("name"),
        "role": payload.get("role", "USER"),
        "phone": payload.get("phone"),
        "assignedRestaurantId": payload.get("assignedRestaurantId"),
        "assignedStoreId": payload.get("assignedStoreId"),
        # Optional: track token expiry
        "exp": payload.get("exp"),
    }


def is_token_expired(token_payload: Dict[str, Any]) -> bool:
    """Check if token is expired (with 30s buffer)."""
    exp = token_payload.get("exp")
    if not exp:
        return True
    return datetime.now(timezone.utc).timestamp() > (exp - 30)