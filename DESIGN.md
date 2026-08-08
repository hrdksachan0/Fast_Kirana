# Design System: FastKirana (Google Stitch Specification)

## 1. Visual Theme & Atmosphere
FastKirana is an ultra-fast quick-commerce grocery and food delivery platform combining the urgency of 10-minute delivery with high visual polish. The atmosphere is crisp, vibrant, and clinical yet warm. It features an asymmetric dual-personality interface — **Grocery Mode** (energetic red & savings green) and **Cafe Mode** (warm culinary orange).

- **Density:** 7 (Daily App Balanced — high scannability, compact product cards, tabular numerals)
- **Variance:** 6 (Asymmetric Hero area, curved floating navigation shell, bento category grid)
- **Motion:** 6 (Fluid spring physics, active tab pill glow transitions, interactive quantity counter)

---

## 2. Color Palette & Roles
- **HyperMart Brand Red** (`#E20A22`) — Primary brand identity, primary CTA buttons, active grocery mode tabs, flash deal ribbons.
- **Savings Green** (`#00B140`) — Accent green for savings chips, success status, stock availability, and quantity modifier pills (`[-] 1 [+]`).
- **Cafe Warm Orange** (`#F97316`) — Secondary accent for cafe mode switcher, warm food categories, and meal deals.
- **Canvas Gray** (`#FAFAFA`) — Primary background surface for entire app viewports.
- **Pure Surface** (`#FFFFFF`) — Elevating cards, modals, and navigation containers.
- **Charcoal Ink** (`#1A1A2E`) — Primary text headers and product titles (Zinc-950 equivalent).
- **Muted Slate** (`#6B7280`) — Secondary text, metadata, delivery specs, MRP strikethroughs.
- **Whisper Border** (`#F3F4F6` / `rgba(229, 231, 235, 0.6)`) — Subtle 1px structural container borders.

---

## 3. Typography Rules
- **Display / Headers:** `Outfit` / `Poppins` (Weights: 700 Bold, 800 ExtraBold) — Track-tight, bold hierarchy.
- **Body & Controls:** `Inter` (Weights: 400 Regular, 500 Medium, 600 SemiBold, 700 Bold) — High legibility.
- **Tabular Numerals / Price Tags:** `JetBrains Mono` / `Inter` (`font-variant-numeric: tabular-nums`) — Price numbers (`₹49`), 10-Min timers (`02:45:30`), and order IDs.
- **Banned:** Generic serif fonts (`Times New Roman`, `Georgia`), pure black text (`#000000`).

---

## 4. Component Stylings
- **Header & Delivery Badge:** Top bar features live location ("Deliver to Home • Ghatampur Market") with an animated ⚡ `10 MINS` express badge pill in translucent green (`rgba(0,177,64,0.1)`).
- **Grocery vs Food Mode Switcher:** Segmented curved pill toggle slider (`height: 50px`). Grocery active uses Red Gradient (`#E20A22` -> `#FF4D62`). Food active uses Cafe Orange Gradient (`#EA580C` -> `#F97316`).
- **Product Cards:** Pure white card (`#FFFFFF`) with 16px corner radius, 1px whisper border, top-left discount ribbon (`-15% OFF`), unit badge (`1 kg`, `500g`), bold price, and pill-shaped ADD button / active green quantity counter (`[-] 1 [+]`).
- **Floating Bottom Shell:** Glassmorphism curved floating container (`margin: 16px`) with active tab pill background glow (`rgba(226,10,34,0.08)`), crisp icons, and live cart item count badge.

---

## 5. Layout Principles
- **Grid Architecture:** 2-column responsive bento product grid for mobile; multi-column responsive grid for desktop web.
- **Whitespace & Containment:** 16px edge padding across all viewports.
- **Single-Column Collapse:** Mobile viewports (<768px) collapse all complex multi-column grids gracefully.
- **No Stacking Overlaps:** Text and interactive elements occupy distinct spatial zones.

---

## 6. Motion & Interaction
- **Spring Physics:** `stiffness: 100, damping: 20` for smooth card scaling (`scale: 0.96` on tap down).
- **Micro-Animations:** Pulsing 10-Min delivery badge, sliding banner carousel, and cart badge bounce.
- **Haptic Feedback:** Light tactile impact on button taps and quantity increments.

---

## 7. Anti-Patterns (Explicitly Banned)
- ❌ No pure black (`#000000`) backgrounds or text.
- ❌ No oversaturated neon glows or purple AI gradients.
- ❌ No emojis as primary icon substitutes in key UI actions.
- ❌ No overlapping text over product images.
- ❌ No 3-column equal generic feature rows on mobile.
