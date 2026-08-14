# FastKirana Frontend Specification Document

**Target Frameworks:** Next.js 15 (TailwindCSS + Framer Motion) & Flutter 3.x (Dart + Riverpod)  
**Design aesthetic:** Zepto / Blinkit Glassmorphism, Premium Dark/Light Modes  
**Performance Goal:** 60 FPS (Web) / 120 FPS (Flutter Mobile)

---

## 1. Design System Tokens

### 1.1 Color Palette
- **Primary Gradient**: `from-[#E8153A] to-[#FF2D55]` (Rose Crimson)
- **Secondary Accent**: `emerald-500` / `teal-600` (Success & Savings)
- **Packaging Highlight**: `amber-500` (Premium Thermal Packaging)
- **Backgrounds**: Light (`#F4F4F5` / `#FFFFFF`), Dark (`#09090B` / `#18181B`)

### 1.2 Typography & Radius
- **Fonts**: Inter & Outward (Weights: 600 SemiBold, 800 Bold, 900 Black)
- **Border Radius**: Cards `20px` (`rounded-2xl`), Modals `28px` (`rounded-3xl`), Pills `9999px` (`rounded-full`)

---

## 2. Core Frontend Components

### 2.1 Mode Switcher (Grocery vs Food/Cafe)
- **Behavior**: Smooth sliding pill header with Framer Motion (`layoutId="activeModePill"`) on Web and `AnimatedContainer` with haptic feedback on Flutter.

### 2.2 Product Card & Quantity Stepper
- Glassmorphic translucent surface.
- Image with shimmer loading placeholder.
- MRP strike-through (`₹60`) vs current price (`₹49`).
- `+ ADD` button transforms into quantity stepper (`- 1 +`).

### 2.3 Single Unified Order Progress Card
- Single consolidated card for combined orders.
- 4-step progress timeline: `Confirmed ➔ Packing/Cooking ➔ Out for Delivery ➔ Delivered`.
- Single combined total amount, order ID, and ETA timer (`⏱️ 8 Mins`).

### 2.4 Bottom Cart Drawer Sheet
- Slide-up sheet displaying items, packaging options (`Normal ₹0` vs `✨ Premium Packaging +₹15`), bill breakdown, and slide-to-pay button.
