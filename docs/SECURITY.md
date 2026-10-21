# Security

Baseline: OWASP MASVS (mobile) and ASVS L1 (web/API).

## Secrets — public repo rules
1. **Nothing secret is committed.** Config comes from git-ignored files (`env.json` via `--dart-define-from-file`, `.env.local` for Next.js); committed templates end in `.example`.
2. Three gates:
   - `pre-commit`: blocks secret-bearing file types and runs `gitleaks` on staged changes.
   - `pre-push`: runs `gitleaks` on the full history.
   - CI `secret-scan` workflow: same scan on GitHub, since local hooks can be bypassed.
   - Also enable on GitHub: *Settings → Code security → Secret scanning + Push protection*.
3. Server-only secrets (Supabase `service_role`, Facturapi key, FCM credentials) live **only** in Supabase Edge Function secrets. The app ships only the public `anon` key, which is safe because RLS enforces access.
4. **If a secret leaks: rotate it first**, then clean history. Deleting the commit is not enough; bots scrape GitHub within minutes.

Hook setup (once per clone): `git config core.hooksPath .githooks`

## Data access
- RLS on every table, scoped by `business_id` through `public.has_role(business_id, roles)`, which reads `memberships`. Not a JWT claim: a user can belong to several businesses and role changes apply immediately.
- Nothing that grants a role is writable directly; `create_business` and (later) invitation RPCs are the only paths.
- pgTAP tests attempt cross-business reads/writes and must fail.
- The UI hiding a button is never the control; the database is.

## Device
- Session refresh token in `biometric_storage` (Keystore/Keychain key bound to biometrics); invalidated when new biometrics are enrolled.
- Local DB encrypted (SQLCipher).

## Platform
- Input validated at boundaries (Zod on web, checks inside RPCs).
- Rate limits on Edge Functions.
- Audit log for discounts, stock adjustments, cancellations, role changes.
- Dependabot + CodeQL + gitleaks in CI.

## Privacy & compliance
- Privacy notice (LFPDPPP) and terms accepted on first launch; acceptance version stored.
- Account + data deletion from the app and from a public web page (Google Play requirement).

## Backups
Nightly `pg_dump` → encrypted with `age` → pushed to a **private** GitHub repo. Restore drill documented in `RUNBOOK.md` and performed at least once.
