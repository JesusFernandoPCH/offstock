# ADR-0003: Offline-first sales with an outbox

**Status:** Accepted · 2026-10-21

## Context
Connectivity in stores is unreliable. A sale must never be lost or duplicated.

## Decision
- Every write is first stored in local SQLite (Drift) and appended to an `outbox` table in the same local transaction.
- A sync worker drains the outbox with exponential backoff. Each operation carries a client-generated UUID; server RPCs are idempotent on it.
- Offline: no stock holds (they need the server). The UI shows "Offline: stock is approximate". Tickets are generated on-device and marked "pending sync".
- Reads come from the local DB; the server pushes changes back via Realtime / incremental pulls by `updated_at`.

## Consequences
More client code, but it is the most interview-worthy part of the project. Chaos tests: airplane mode mid-checkout, app killed mid-sync, duplicate delivery.
