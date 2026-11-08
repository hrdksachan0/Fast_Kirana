<!-- BEGIN:nextjs-agent-rules -->
# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` before writing any code. Heed deprecation notices.
<!-- END:nextjs-agent-rules -->

# FastMinute Production Database & Execution Rules

## 1. Supabase & Prisma Connection Pool Safeguards (STRICT)
- **Lean Pool Restriction:** In `src/lib/prisma.ts`, Prisma connection pool is strictly capped:
  - Serverless / API routes: `max: 2` connections per instance.
  - Server / local tasks: `max: 4` connections.
  - `idleTimeoutMillis: 3000` (reclaims idle connections in 3 seconds).
- **No Unthrottled / Parallel Scripts:** NEVER execute unthrottled, multi-threaded, or high-concurrency scripts (`p-limit(25)`, `Promise.all` floods) against the live pooled Supabase database (port 6543 / 200 client max).
- **Incident Recovery Protocol:** If Supabase PgBouncer ever exhausts connections (`EMAXCONN` or `CONNECT_TIMEOUT 5001ms`), no data is corrupt. It is purely a TCP connection deadlock. Instruct Sooraj to click "Restart Project" in the Supabase Dashboard, which resets PgBouncer slots in 30-40 seconds.

## 2. Multi-Hub Operational Stock Rules
- **Operational Warehouse:** Ghatampur Central Hub (`hub-209206`) is the only active live warehouse.
- **Non-Operational Hubs:** Akbarpur (`hub-224122`) and Barharwa (`hub-816101`) are staged/non-operational. Their inventory MUST remain stock = 0 (`isAvailable: false`, Stock Out). Do NOT inflate or replicate stock to these hubs.

## 3. Deployment & Git Rules
- **NO UNAPPROVED GIT PUSH:** NEVER run `git push origin main` unless Sooraj explicitly instructs to push. Local changes remain local until vetted.

