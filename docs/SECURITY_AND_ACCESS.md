# FastKirana Security & Access Control Document

**Security Standard:** OWASP Top 10 Compliant  
**Auth Model:** Role-Based Access Control (RBAC)  
**Encryption:** Passwords (bcrypt salt 10+), Tokens (HS256 JWT / AES-256)

---

## 1. Role-Based Access Control (RBAC) Matrix

| User Role | Permitted Access Scope | Endpoint Protection Guard |
| :--- | :--- | :--- |
| `USER` | Read products/categories, manage own cart/addresses, place orders, view own order history | `require_auth` / `auth()` |
| `PICKER` | Access Dark Store Picker Console (`/picker`), update item picking status (`PACKED`) | `require_picker` |
| `CHEF` | Access Kitchen Console (`/restaurant-console`), update cooking status (`CONFIRMED` -> `PREPARED`) | `require_chef` |
| `RESTAURANT_OWNER` | Manage own outlet menu items, view outlet payout reports & kitchen stats | `require_restaurant_owner` |
| `DELIVERY` | Access Rider App (`/delivery`), accept multi-pickup deliveries, record COD cash collections | `require_delivery` |
| `ADMIN` | Full platform control: users, block/unblock, coupons, financial reports, system settings | `require_admin` |

---

## 2. Authentication Architecture & Token Inspection

FastAPI and Next.js enforce **Dual Authentication Resolution**:

```python
async def get_current_user(request: Request, credentials: Optional[HTTPAuthorizationCredentials]):
    # 1. Inspect Authorization: Bearer <jwt> (Mobile Flutter App)
    if credentials and credentials.credentials:
        return verify_jwt(credentials.credentials)

    # 2. Inspect Session Cookie (Web App)
    cookie = request.cookies.get("next-auth.session-token")
    if cookie:
        return verify_session_token(cookie)

    # 3. Fallback to X-User-Id header in secure internal RPC
    x_user_id = request.headers.get("x-user-id")
    if x_user_id:
        return fetch_user(x_user_id)
```

---

## 3. Financial & Anti-Fraud Controls

1. **Rider COD Cash Ledger**:
   - Cash collected by riders is locked in `RiderWallet.cashInHand`.
   - Rider cannot accept new orders if `cashInHand` exceeds `maxCashLimit` until admin approves cash deposit transaction (`CashDepositTransaction`).
2. **Order Tampering Protection**:
   - Order totals, discounts, taxes, and packaging fees are recalculated on the backend server; client-submitted totals are ignored.
3. **Packaging Fee Integrity**:
   - Premium Packaging (₹15) waives standard ₹5 handling fee on food orders to prevent double charging.
