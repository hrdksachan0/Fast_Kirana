"""
JWT authentication middleware for FastAPI.
Validates NextAuth.js JWT tokens and attaches user info to request state.
"""

from fastapi import Request, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Optional, Dict, Any
from utils.jwt import extract_user_from_token, is_token_expired


# HTTPBearer security scheme
security = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
) -> Optional[Dict[str, Any]]:
    """
    Extract and validate current user from JWT token.

    Returns:
        User dict with {id, email, role, phone, ...} or None if no token
    """
    if not credentials or not credentials.credentials:
        return None

    user = extract_user_from_token(credentials.credentials)
    if not user:
        return None

    if is_token_expired(user):
        return None

    return user


async def require_auth(
    user: Optional[Dict[str, Any]] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Require authenticated user.

    Raises:
        HTTPException 401 if not authenticated
    """
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized - valid JWT token required",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


async def require_admin(
    user: Dict[str, Any] = Depends(require_auth)
) -> Dict[str, Any]:
    """
    Require admin role.

    Raises:
        HTTPException 403 if not admin
    """
    if user.get("role") != "ADMIN":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forbidden - admin access required",
        )
    return user


async def require_staff(
    user: Dict[str, Any] = Depends(require_auth)
) -> Dict[str, Any]:
    """
    Require staff role (ADMIN, CHEF, PICKER, DELIVERY, RESTAURANT_OWNER).

    Raises:
        HTTPException 403 if not staff
    """
    staff_roles = ["ADMIN", "CHEF", "PICKER", "DELIVERY", "RESTAURANT_OWNER"]
    if user.get("role") not in staff_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forbidden - staff access required",
        )
    return user


async def require_role(allowed_roles: list):
    """
    Create a dependency that requires specific role(s).

    Usage:
        @router.get("/admin", dependencies=[Depends(require_role(["ADMIN"]))])
    """
    async def role_checker(user: Dict[str, Any] = Depends(require_auth)) -> Dict[str, Any]:
        if user.get("role") not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Forbidden - requires one of: {', '.join(allowed_roles)}",
            )
        return user
    return role_checker


async def require_order_access(order_user_id: str, extra_roles: list = None):
    """
    Require access to a specific order (owner or staff).

    Usage:
        await require_order_access(order.userId, request)
    """
    async def access_checker(user: Dict[str, Any] = Depends(require_auth)) -> Dict[str, Any]:
        if not user:
            raise HTTPException(status_code=401, detail="Unauthorized")

        staff_roles = ["ADMIN", "DELIVERY", "PICKER", "CHEF", "RESTAURANT_OWNER"]
        if extra_roles:
            staff_roles.extend(extra_roles)

        is_owner = order_user_id == user.get("id")
        is_staff = user.get("role") in staff_roles

        if not is_owner and not is_staff:
            raise HTTPException(status_code=403, detail="Forbidden")

        return user
    return access_checker