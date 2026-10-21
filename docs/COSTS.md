# Cost Guardrails

Goal: this project can be forgotten for a year and still cost **$0**. No surprise bills.

## Rule 1 — No credit card on any metered service

A service without a payment method cannot charge. When the free quota runs out, it stops or pauses; it does not bill.

| Service | Plan | Card on file? | What happens at the limit |
|---|---|---|---|
| Supabase | Free | **No** | Requests restricted / project paused. Never billed. |
| Firebase (FCM only) | Spark | **No** | FCM is free. We do **not** use Cloud Functions (requires Blaze = card). |
| Google Cloud (OAuth client for Google Sign-In) | No billing account | **No** | OAuth consent/client needs no billing. |
| Vercel | Hobby | **No** | Deployments/functions throttled. |
| GitHub (public repo) | Free | **No** | Actions minutes are free for public repos. |
| Codemagic | Free (500 macOS min/mo) | **No** | Builds stop until next month. |
| Sentry | Developer (free) | **No** | Events dropped over quota. |
| Facturapi | Test mode | **No** | Test mode does not bill. |
| Google Play Console | One-time USD 25 | Paid once | No recurring or metered charges. |
| Apple Developer | USD 99/yr | Deferred | Only if/when we publish on iOS. |

**Rejected because they require a card:** Cloudflare R2, AWS, Firebase Blaze, Supabase Pro.
If a card ever becomes unavoidable: set a hard spend cap *and* a budget alert at USD 1 **before** using the service, and add it to this table.

## Rule 2 — Every scheduled job is listed here

If it is not in this table, it must not exist.

| Job | Where | Schedule | Cost | How to stop it |
|---|---|---|---|---|
| Expired stock-hold cleanup | Supabase `pg_cron` (inside the DB) | every minute | $0 (runs in the free DB) | `select cron.unschedule('cleanup-holds');` |
| Encrypted nightly backup | GitHub Actions | daily | $0 (public repo) | Disable the workflow in GitHub → Actions |
| Keep-alive ping | GitHub Actions | weekly | $0 | Disable the workflow |
| Demo data reset | Supabase `pg_cron` | daily | $0 | `select cron.unschedule('reset-demo');` |

## Rule 3 — Forgetting the project is safe by design

- GitHub **automatically disables scheduled workflows after 60 days without repo activity**. Abandoned = jobs stop by themselves.
- Supabase Free pauses a project after ~7 days without traffic. Pausing costs nothing; resume from the dashboard.
- With no card anywhere, the worst case is "the demo is offline", never "the bill arrived".

## Quarterly check (5 minutes)

- [ ] No payment method added on any service in the table above
- [ ] The scheduled jobs table matches reality
- [ ] Free-tier usage below 70% on the Supabase and Vercel dashboards
