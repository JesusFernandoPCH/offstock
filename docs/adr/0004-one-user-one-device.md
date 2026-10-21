# ADR-0004: Each employee uses their own phone and Google account

**Status:** Accepted · 2026-10-21

## Context
Shared devices with PINs let one employee act as another (sabotage, blame-shifting). Mixing shared and personal devices doubles the auth surface.

## Decision
- One person = one Google account = their own phone. No shared-device mode, no PINs.
- The owner invites employees by email; accepting creates a `membership`.
- Quick access is biometric unlock of a session stored in hardware-backed storage on that phone only.
- Every sale, discount and adjustment is attributed to the authenticated user.

## Consequences
Clean audit trail and simpler auth. Businesses with a single shared tablet are not supported in v1.
