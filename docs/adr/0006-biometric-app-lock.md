# ADR-0006: Biometric app lock over an encrypted session

**Status:** Accepted · 2026-10-21

## Context
The plan called for bank-style quick access: fingerprint or face instead of signing in again. The first idea was to keep the refresh token in storage that only opens after biometrics (`biometric_storage`). Supabase rotates the session about every hour and must persist the new token each time, so a biometric-bound store would prompt the user hourly, or force us to stop persisting sessions.

## Decision
- The Supabase session is persisted with `flutter_secure_storage` (Android Keystore / iOS Keychain encryption) instead of the default plain SharedPreferences.
- `local_auth` gates the UI: on cold start and after 5 minutes in the background, the app shows nothing until the owner's biometrics pass (`biometricOnly: true`). The check runs before any network call, so it also works offline.
- Offered once after the first real sign-in on a phone; demo sessions never lock. Signing out clears the preference, so the next account on the phone decides for itself.

## Threat model
- Covers: an unlocked phone left on the counter, a coworker picking it up, someone reading app storage on a non-rooted device.
- Does not cover: a rooted/jailbroken device with instrumentation that skips the UI gate. Mitigations: tokens encrypted at rest, short-lived JWTs, server-side session revocation, and RLS limiting any session to its own business.

## Upgrade path
Passkeys (WebAuthn): a hardware-bound key signs a server challenge after biometrics, which is what banking apps do. Supabase Auth has passkeys in beta and `supabase_flutter` 2.18 exposes them; revisit when they leave beta.
