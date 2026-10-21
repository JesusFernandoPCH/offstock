# ADR-0005: Zero-billing policy

**Status:** Accepted · 2026-10-21

## Context
Forgotten cloud automations on metered accounts have produced bills of thousands of dollars. This is a portfolio project that may sit idle for months.

## Decision
No payment method on any metered service. Every scheduled job is inventoried in [COSTS.md](../COSTS.md). Services that require a card (R2, AWS, Firebase Blaze) are excluded.

## Consequences
Hitting a free limit degrades the demo instead of generating charges. Backups go to a private GitHub repo instead of object storage.
