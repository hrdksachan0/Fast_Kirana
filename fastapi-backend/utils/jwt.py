"""
JWT validation utilities for FastAPI.
Validates NextAuth.js JWT tokens using the same AUTH_SECRET.
"""

import os
import jwt
from typing import Optional, Dict, Any
from datetime import datetime, timezone, timedelta


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


import base64
import json
import os
import jwt
from typing import Optional, Dict, Any
from datetime import datetime, timezone, timedelta
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes


def base64url_decode(input_str: str) -> bytes:
    rem = len(input_str) % 4
    if rem > 0:
        input_str += '=' * (4 - rem)
    return base64.urlsafe_b64decode(input_str.encode('utf-8'))


def decrypt_jwe(token: str, secret_str: str) -> Optional[Dict[str, Any]]:
    try:
        parts = token.split('.')
        if len(parts) != 5:
            return None
        
        header_b64, _, iv_b64, ciphertext_b64, tag_b64 = parts
        
        iv = base64url_decode(iv_b64)
        ciphertext = base64url_decode(ciphertext_b64)
        tag = base64url_decode(tag_b64)
        data = ciphertext + tag
        aad = header_b64.encode('utf-8')
        
        info_candidates = [
            b"NextAuth.js Generated Encryption Key",
            b"Auth.js Generated Encryption Key",
            b"NextAuth.js Generated Encryption Key (dir)",
            b"",
        ]
        
        for info in info_candidates:
            try:
                hkdf = HKDF(algorithm=hashes.SHA256(), length=32, salt=b"", info=info)
                derived_key = hkdf.derive(secret_str.encode('utf-8'))
                aesgcm = AESGCM(derived_key)
                decrypted = aesgcm.decrypt(iv, data, aad)
                return json.loads(decrypted.decode('utf-8'))
            except Exception:
                continue
        return None
    except Exception:
        return None


def decode_nextauth_jwt(token: str) -> Optional[Dict[str, Any]]:
    """
    Decode NextAuth.js JWT or JWE encrypted token.
    Supports both standard HS256 JWTs and encrypted JWE tokens.
    """
    if not token:
        return None
        
    # 1. Try plain HS256 JWT decode
    try:
        payload = jwt.decode(
            token,
            AUTH_SECRET,
            algorithms=["HS256"],
            options={
                "verify_signature": True,
                "verify_exp": False,
            }
        )
        return payload
    except Exception:
        pass

    # 2. Try NextAuth JWE decryption
    jwe_payload = decrypt_jwe(token, AUTH_SECRET)
    if jwe_payload:
        return jwe_payload

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
        return False
    try:
        return datetime.now(timezone.utc).timestamp() > (float(exp) - 30)
    except Exception:
        return False


def create_access_token(data: dict, expires_delta: Optional[Any] = None) -> str:
    """Create a signed JWT token matching NextAuth and FastAPI auth requirements."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(days=30)
    to_encode.update({"exp": int(expire.timestamp())})
    if "id" in to_encode and "sub" not in to_encode:
        to_encode["sub"] = to_encode["id"]
    return jwt.encode(to_encode, AUTH_SECRET, algorithm="HS256")