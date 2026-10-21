# Offstock

> *Funciona Aunque Te Salgas.*

Mobile-first POS for small businesses: sell from your phone while assisting the customer, with real-time stock holds, offline sales, a web dashboard and CFDI 4.0 invoicing (sandbox).

**Stack:** Flutter · Supabase (Postgres) · Next.js

- [Product requirements](docs/PRD.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Security](docs/SECURITY.md)
- [Cost guardrails](docs/COSTS.md)
- [Decisions (ADRs)](docs/adr/)
- [Design tokens](design/tokens.json)

## Repo
```
apps/mobile   Flutter app (Android, iOS)
apps/web      Next.js dashboard
supabase/     migrations, edge functions, DB tests
design/       tokens shared by both apps
docs/         PRD, architecture, ADRs
```

## Setup
```sh
git config core.hooksPath .githooks     # secret scanning before commit and push (requires gitleaks)

cd apps/mobile && flutter pub get && flutter run
cd apps/web && npm install && npm run dev
npx supabase start                      # local Supabase (requires Docker)
```

## Checks
```sh
cd apps/mobile && flutter analyze && flutter test
cd apps/web && npm run lint && npm test && npm run build
```
