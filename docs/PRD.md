# PRD — Offstock

*Funciona Aunque Te Salgas* — sell even when the connection drops.

## Problem
Small retail businesses in Mexico (clothing, electronics, food counters) sell from a single cash register. Customers queue, staff walk back and forth, stock counts drift, and invoicing (CFDI) is a separate chore.

## Solution
A mobile-first POS: each employee sells **from their own phone while assisting the customer**. They scan barcodes, build a cart that reserves stock in real time, close the sale, share the ticket and, when asked, issue the CFDI. The owner sees everything in a web dashboard with PDF/Excel reports. Sales keep working without internet.

## Users
| Role | Device | Can |
|---|---|---|
| Owner | Own phone + web | Everything: setup, catalog, costs, reports, employees, invoicing |
| Employee | **Own phone only** (see ADR-0004) | Sell, scan, check stock, open/close own cash session |
| Recruiter / visitor | Any | Demo mode, no sign-up, seeded data |

## Scope — v1 (in)
1. Terms & privacy notice on first launch; account deletion (in-app + web).
2. Sign-in with Google; biometric quick unlock; demo mode.
3. Onboarding: business name, type (clothing / food counter / tech / other), logo, currency (MXN in v1). The type selects a template (clothing → sizes & colors; food → units & menu categories).
4. Catalog: products with variants, photo, price, cost, stock, barcode, SAT keys; scan to create; printable barcode labels for items without one.
5. Sales: camera scanning, manual search, cart with **real-time stock holds**, promotions (% / amount / NxM / wholesale), payment methods with change, returns & cancellations.
6. Cash sessions: open, close, cash count.
7. PDF tickets shared via WhatsApp / email.
8. Income & expenses.
9. Web dashboard with charts; PDF & Excel reports.
10. CFDI 4.0 in sandbox: invoice a sale, global invoice, cancellation.
11. Push (low stock, cash session closed) and local notifications.
12. Offline-first with sync.
13. Encrypted backups and a tested restore.
14. Audit log of sensitive actions.

## Out (architecture must not block them)
Multi-branch, customers & credit, suppliers, loyalty, AI, restaurant tables/kitchen tickets/modifiers, multi-currency, thermal printers.

## Success criteria
- A sale started online survives airplane mode mid-checkout with no duplicates and no lost data.
- Two employees cannot sell the last unit twice while online.
- A user from business A can never read business B's data (proven by automated tests).
- A recruiter reaches a working demo in under 30 seconds.
- Running cost: $0 (see [COSTS.md](COSTS.md)).
