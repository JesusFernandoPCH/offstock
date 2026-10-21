# ADR-0002: Inventory as an append-only ledger + temporary holds

**Status:** Accepted · 2026-10-21

## Context
Several sellers sell the same stock at once, sometimes offline. We need an audit trail and conflict-free merges.

## Decision
- Stock is never edited in place. Every change is a row in `inventory_moves` (`+` purchase/return, `−` sale/adjust). On-hand = sum of moves (cached by trigger).
- Available = on-hand − active `stock_holds`.
- `add_to_cart` RPC: lock variant row → check available ≥ qty → insert hold with `expires_at = now() + 15 min`.
- The open cart sends a heartbeat that extends its holds; `pg_cron` deletes expired holds every minute; Realtime broadcasts availability.
- `confirm_sale` RPC, one transaction: holds → `sale` moves + sale + payments. Idempotent on client-generated `sale_id`.

## Consequences
Moves from different devices commute, so offline merges never conflict. Stock can go negative after an offline sale; that is flagged for owner review, never rejected.
