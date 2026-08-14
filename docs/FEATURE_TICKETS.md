# FastKirana Feature Ticket List (Jira / Linear Backlog)

**Project:** FastKirana Quick Commerce & Food Delivery  
**Status Key:** `DONE` | `IN_PROGRESS` | `BACKLOG`

---

## Epic 1: Core Storefront & Category Curation

| Ticket ID | Feature Title | Priority | Status | Target Component |
| :--- | :--- | :--- | :--- | :--- |
| **FK-101** | Replace loose `/dew/` beverage regex with exact word boundary `/\bdew\b|mountain.?dew/` | HIGH | `DONE` | Category Page & Curation Hub |
| **FK-102** | Exclude personal care / skincare items from Beverages category tab | HIGH | `DONE` | Category Page & Curation Hub |
| **FK-103** | Fix Cold Coffee matchTags to prevent appearing in Hot Brews Specials | HIGH | `DONE` | DB & Store Settings |
| **FK-104** | Framer Motion sliding pill tab bar for Account Dashboard | MEDIUM | `DONE` | Account Dashboard |
| **FK-105** | Instant thumbnail visual search predictions in Header Search | MEDIUM | `BACKLOG` | Search Header |

---

## Epic 2: Cart, Checkout & Packaging Engine

| Ticket ID | Feature Title | Priority | Status | Target Component |
| :--- | :--- | :--- | :--- | :--- |
| **FK-201** | Food Packaging Selection (`Normal ₹0` vs `✨ Premium Packaging +₹15`) | HIGH | `DONE` | Checkout Page & Orders API |
| **FK-202** | Waive standard ₹5 handling fee when Premium Packaging (+₹15) is selected | HIGH | `DONE` | Checkout Page & Orders API |
| **FK-203** | Highlight `✨ Premium Thermal Packaging (+₹15)` gold badge on Kitchen Card | HIGH | `DONE` | Kitchen Console |
| **FK-204** | 60-Second Grace Period Order Edit/Cancellation Window | MEDIUM | `BACKLOG` | Order Confirmation Page |

---

## Epic 3: Unified Single Order Experience

| Ticket ID | Feature Title | Priority | Status | Target Component |
| :--- | :--- | :--- | :--- | :--- |
| **FK-301** | Merge combined Grocery + Restaurant orders into 1 single unified card for customer | HIGH | `DONE` | Orders API & Order Tracker |
| **FK-302** | Remove split order banners ("Your order has been split") from customer screens | HIGH | `DONE` | Order Placed Page |
| **FK-303** | Combine total price, items list, and status timeline for customer tracking | HIGH | `DONE` | Live Tracking Client |
| **FK-304** | 1-Tap WhatsApp Live Tracking Link Sharing | LOW | `BACKLOG` | Order Tracker |

---

## Epic 4: Kitchen & Logistics Operational Consoles

| Ticket ID | Feature Title | Priority | Status | Target Component |
| :--- | :--- | :--- | :--- | :--- |
| **FK-401** | Display Customer Phone Number for Self-Pickup Orders | HIGH | `DONE` | Admin & Kitchen Console |
| **FK-402** | Multi-pickup rider navigation cards (`Pickup 1: Dark Store` + `Pickup 2: Restaurant`) | HIGH | `DONE` | Delivery Rider Console |
| **FK-403** | Thermal Receipt KOT Printing integration | HIGH | `DONE` | KOT Print Module |
| **FK-404** | Exclude Packaging Fee (₹15) from Restaurant Net Sales calculation | HIGH | `DONE` | Admin Sales Report |

---

## Epic 5: FastAPI Backend & Flutter Mobile Alignment

| Ticket ID | Feature Title | Priority | Status | Target Component |
| :--- | :--- | :--- | :--- | :--- |
| **FK-501** | Implement Dual Auth in FastAPI (`Bearer JWT` + `NextAuth Session Cookie`) | HIGH | `DONE` | FastAPI Auth Router |
| **FK-502** | Group combined orders in FastAPI `list_user_orders` | HIGH | `DONE` | FastAPI Orders Router |
| **FK-503** | Build Flutter Mobile App design system mirroring Web App mobile UI 1-to-1 | HIGH | `IN_PROGRESS` | Flutter App (`lib/`) |
| **FK-504** | Fix String type cast error in Flutter `admin_banners.dart` | HIGH | `DONE` | Flutter Admin Banners |
| **FK-505** | Clean up unused imports in Flutter `app_router.dart` | HIGH | `DONE` | Flutter Router |
