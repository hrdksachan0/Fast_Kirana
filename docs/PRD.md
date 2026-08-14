# FastKirana Product Requirements Document (PRD)

**Version:** 2.5.0  
**Status:** Approved & Production-Active  
**Target Platform:** Web (Next.js), Mobile (Flutter iOS & Android), Backend (FastAPI + PostgreSQL)

---

## 1. Executive Summary & Product Vision
FastKirana is an enterprise-grade **Quick-Commerce & Hyperlocal Food Delivery Platform** that combines **10-Minute Dark Store Grocery Delivery** with **Hot Restaurant/Cafe Food Delivery** into a single unified customer experience.

### Key Differentiators:
- **Dual Experience Switcher**: Seamless 1-tap toggling between `🛒 Grocery Mode` and `☕ Food/Cafe Mode`.
- **Unified Single Order Presentation**: Even when an order contains both Dark Store Grocery items and Restaurant prepared dishes, the customer sees **1 Single Unified Order Card & Tracker**.
- **Multi-Pickup Logistics Engine**: Delivery riders are routed to pick up items from both the Dark Store and Restaurant Kitchen before fulfilling a combined order.
- **Dynamic Thermal Packaging**: Optional ₹15 insulated thermal packaging that waives standard handling fees and alerts kitchen staff for hot food integrity.

---

## 2. User Personas & Core Journeys

| Persona | Primary Goal | Core Interfaces Used |
| :--- | :--- | :--- |
| **End Customer** | Order groceries & hot food in under 10 mins with zero friction | Web App, Flutter iOS/Android |
| **Dark Store Picker** | Fulfill grocery item picking lists within 120 seconds | Picker Web/Mobile Console |
| **Restaurant Kitchen Chef** | Receive KOT food orders, track prep timer, print receipt | Kitchen Console & KOT Printer |
| **Delivery Rider** | Complete multi-pickup orders and collect Cash-on-Delivery (COD) | Delivery Rider Console & Wallet |
| **Super Admin** | Manage inventory, pricing, coupons, payouts & real-time ops | Super Admin Dashboard |

---

## 3. Product Feature Requirements

### 3.1 Dual-Mode Storefront & Curation
- **Grocery Storefront**: Category grid, lightning search with image previews, discount tags, MRP strike-throughs, 1-tap quantity steppers.
- **Cafe & Hot Brews Specials**: Category exclusions ensuring personal care items never appear in food sections; strict regex filtering for beverage terms (`/\bdew\b|mountain.?dew/i`).

### 3.2 Cart, Checkout & Packaging Logic
- **Single Unified Checkout**: Combines Grocery + Restaurant items into 1 checkout flow.
- **Packaging Option Rules**:
  - `Normal Packaging (₹0)`: Standard eco-friendly bag.
  - `✨ Premium Thermal Packaging (+₹15)`: Insulated thermal pouch. When selected, standard ₹5 handling fee is waived so net packaging charge is flat ₹15.

### 3.3 Unified Order Experience for Customers
- Customers see **1 single order** on Account Dashboard, Order History, Order Confirmation, and Live Tracking screens.
- Split notices ("Your order has been split") are hidden from customer view to eliminate confusion.

### 3.4 Operational Consoles (Kitchen, Picker, Rider)
- **Kitchen KOT Console**: Audio chime on new orders, prep time SLA countdown, thermal receipt printing, `✨ Premium Packaging` gold badges.
- **Delivery Rider Multi-Pickup**: Visual pickup cards (`Pickup 1: Grocery Store` + `Pickup 2: A.S. Restaurant`), COD cash collection ledger, delivery photo upload.

---

## 4. Success Metrics & Key Performance Indicators (KPIs)
- **Average Delivery Time**: Target < 12 Minutes end-to-end.
- **Order Picking Accuracy**: Target > 99.5% accuracy in Dark Stores.
- **Cart Abandonment Rate**: Target < 25% via 1-tap checkout.
- **Repeat Order Rate**: Target > 45% month-over-month.
