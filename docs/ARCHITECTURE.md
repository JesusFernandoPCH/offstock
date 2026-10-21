# Architecture

```
 Flutter app (Android/iOS)            Next.js dashboard (Vercel)
  Riverpod · go_router · Drift(SQLCipher)    TS · Tailwind · Motion · Radix
        │  outbox sync / RPC / realtime              │
        └──────────────┬─────────────────────────────┘
                       ▼
                Supabase (Free)
   Postgres + RLS · Auth (Google, anonymous demo) · Storage
   Realtime (stock) · Edge Functions (cfdi, notify) · pg_cron
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
   Facturapi (test mode)       FCM (push)
```

## Repo layout
```
apps/mobile/lib/{core, features/<feature>/{data,domain,presentation}}
apps/web/
supabase/{migrations, functions, tests, seed.sql}
design/tokens.json
docs/{PRD, ARCHITECTURE, SECURITY, COSTS, adr/}
```

## Core data model
```
businesses       (id, name, type, currency, logo_url, rfc, tax_regime, zip)
memberships      (user_id, business_id, role: owner|employee)
products         (id, business_id, name, category, sat_product_key, sat_unit_key, photo_url)
variants         (id, product_id, sku, barcode, attrs jsonb, price_cents, cost_cents, min_stock)
inventory_moves  (id, variant_id, qty ±, reason, ref_id, device_id, created_at)   -- append-only
stock_holds      (id, variant_id, cart_id, qty, seller_id, expires_at)
sales, sale_items, payments, promotions, cash_sessions, expenses, incomes
invoices         (sale_id, sat_uuid, status, xml_path, pdf_path)
audit_log        (actor, action, entity, before, after, at)
```
Access: every policy goes through `has_role(business_id, roles)`; role-granting writes only happen inside RPCs.
Money is integer cents. Prices include VAT (Mexican retail norm); tax is derived per line.

## Key flows
- **Stock holds** — [ADR-0002](adr/0002-inventory-ledger-and-holds.md)
- **Offline & sync** — [ADR-0003](adr/0003-offline-first-sync.md)
- **Auth & devices** — [ADR-0004](adr/0004-one-user-one-device.md)
- **CFDI**: app → Edge Function `create-invoice` → Facturapi (test key, server-side only) → XML/PDF to Storage. Supports per-sale invoice, global invoice ("público en general") and cancellation (reasons 01–04).

## Testing
| Layer | Tool |
|---|---|
| DB (RLS, stock RPCs, concurrency) | pgTAP |
| Dart domain (totals, promos, VAT rounding, sync queue) | package:test |
| Widgets / design system | flutter_test + goldens |
| Mobile E2E (incl. airplane mode) | Patrol |
| Web | Vitest + Playwright |

## Workflow
Scrumban, 1-week sprints, GitHub Projects. Issues carry a user story + Given/When/Then criteria. Short-lived branches, Conventional Commits, SemVer.
**Definition of Done:** tests green · a11y checked · offline behavior defined · docs/ADR updated.
