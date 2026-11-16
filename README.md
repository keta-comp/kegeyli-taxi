# JAYHUN TAXI — Kegeyli Taxi Dispatch

TypeScript + React + Vite + PWA project with **white interface, yellow/gold buttons and black text**.

This is **not** Uber/Yandex: customers call an operator. The operator enters a booking, announces it in a shared voice room, drivers respond by voice or press **OLAMAN**, and the operator chooses the driver.

## Features implemented in repository

- Demo mode for **Driver**, **Operator**, **Admin** (demo state is in memory, not a real dispatch).
- Login/password via Supabase Auth when configured.
- Role-separated user interfaces.
- Driver online/offline presence, operator driver list.
- Shared LiveKit WebRTC audio room, press-and-hold microphone, audio playback, reconnect status.
- Operator order creation, order claim, manual assignment, status updates.
- Admin user creation through protected Supabase Edge Function, active/block UI, basic statistics.
- Installable PWA manifest, responsive phone/desktop UI.

**Important:** This is an integration scaffold / first implementation and has **not** passed build, device, or security testing. Do not deploy to an operating taxi fleet before those tests and fixes.

## Run locally

Install Node.js 20.19+ or 22.12+, then:

```bash
npm install
cp .env.example .env.local
npm run dev
```

Windows PowerShell: `Copy-Item .env.example .env.local`.

In the browser, select one of the demo roles if you haven't configured Supabase. No live audio is sent in demo mode.

## Configure Supabase

1. Create a Supabase project.
2. Execute the SQL migrations in order in Supabase SQL editor:\n   - `supabase/migrations/202611170001_initial.sql`\n   - `supabase/migrations/202611170002_security.sql`\n   - `supabase/migrations/202611170003_announcements.sql`
3. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in `.env.local` or hosting environment. This key is **publishable**; do not use the `service_role` key in the browser.
4. Create your first admin manually in Supabase Authentication -> Users (email/password).
5. Copy the generated Auth user's UUID and run the bootstrap command in the migration, replacing the placeholder UUID. First admin creation is privileged and intentionally NOT exposed via anonymous signup.
6. Deploy Supabase Edge Functions `livekit-token`, `create-user`, and `set-user-active`. Keep JWT verification enabled for all functions.

## Configure LiveKit

Create a LiveKit Cloud project or host LiveKit, then add **server-side Edge Function secrets** (Supabase project settings or CLI):

```text
LIVEKIT_URL=wss://YOUR-LIVEKIT-SERVER
LIVEKIT_API_KEY=YOUR_LIVEKIT_API_KEY
LIVEKIT_API_SECRET=YOUR_LIVEKIT_API_SECRET
```

The LiveKit secret must never be prefixed `VITE_`, committed to Git, or sent to the frontend. The `livekit-token` function validates Supabase Auth and role, then creates a token restricted to `JAYHUN_TAXI_MAIN_ROOM`.

## Build / publish

```bash
npm run build
npm run preview
```

Deploy the generated `dist/` directory to Cloudflare Pages or Vercel, with HTTPS and the two public `VITE_` environment variables configured. To install on Android Chrome, open the HTTPS site, select **Install app / Add to Home Screen**.

## Critical production limitations / release checklist

- **Background/locked-screen audio is not guaranteed for a browser PWA.** Test on several Android phones, with screen off, cellular/Wi-Fi transitions, Bluetooth, notification interruptions and battery optimization. If background audio is mandatory, ship a native Android wrapper with an appropriately implemented foreground service / audio integration, or a native app.
- A restricted `driver_orders` view excludes customer phone numbers and notes. Validate the migration, row-level policies and caller permissions against an actual Supabase project before going live; they are not yet live-tested.\n- Online drivers receive sanitized order announcements via a dedicated realtime table.
- Order assignment and driver progress now use server-side RPCs, but add an audit history, error-recovery integration tests, and defensive rate limiting.
- Admin can save a `Shahar ichi` tariff in Supabase. Additional tariff management, operator-default selection and end-to-end testing are still needed.
- Complete user/admin acceptance testing, microphone-device testing, error states, accessibility and loading states, credentials recovery, HTTPS and deployment. GitHub Actions validates TypeScript + Vite compilation, not production behavior.
- Use a migration/rollback process, enforce safe PWA updates so live voice sessions are not interrupted, and review service worker lifecycle. Blocking an account calls LiveKit's removal API, but must be end-to-end tested.
- No maps, GPS, customer app, automated dispatch, online payments, or price prediction are part of MVP.

## Current development status

Initial source code is committed. Backend resources and credentials are **not** provisioned by this repository. No claim of production readiness or tested live audio should be inferred.
