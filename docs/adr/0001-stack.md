# ADR-0001: Flutter + Supabase + Next.js

**Status:** Accepted · 2026-10-21

## Context
Solo developer, $0 budget, Android + iOS + web, fully custom UI (no native-looking widgets), relational data with transactions (inventory), SQL reporting.

## Decision
- **Flutter** for mobile: renders every pixel itself, so the custom design system is the default, not a fight.
- **Supabase** (Postgres) for backend: row locks for stock holds, RLS for multi-tenant security, SQL for reports, Auth with Google, free tier without a card.
- **Next.js** for the dashboard: industry-standard React stack.

## Alternatives rejected
- Firebase/Firestore: easy offline, but weak transactions across documents and painful aggregations for reports.
- React Native: fights native components for a fully custom UI.
- Flutter Web for the dashboard: less valuable on a CV and weaker SEO/accessibility.

## Consequences
Two languages (Dart, TypeScript). Offline sync is ours to build (ADR-0003).
