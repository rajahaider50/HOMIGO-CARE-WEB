# HomigoCare

This repository is part of the four-repository HomigoCare system:

- `HOMIGO-CARE-ANDROID` — Kotlin + Jetpack Compose native Android client
- `HOMIGO-CARE-IOS` — SwiftUI native iOS client
- `HOMIGO-CARE-WEB` — responsive public and logged-in web client
- `HOMIGO-CARE-ADMIN` — secure admin panel and backend-for-frontend API

## Shared architecture

Supabase is the relational source of truth. Firebase Auth provides identity; Firebase Firestore is limited to realtime/live collections (`presence`, `bookings_live`, `chat_threads`, `notifications_feed`, `booking_status_events`, `verification_status`). Cloudinary is the primary user-facing image/document store. The admin repository alone may hold server-only secrets.

## Brand tokens

Primary teal `#1B6B63`, dark teal `#0D4A44`, header emerald `#0B5545`, orange `#F5823A`, light gray `#F5F5F5`, error `#E53935`, success `#43A047`. Light mode is the v1 default.

## Security rules

Never commit real secrets. Copy `.env.example`/`Secrets.xcconfig.example`/`secrets.properties.example`, fill locally, and keep the real file ignored. CNIC is encrypted server-side with a Supabase Vault-backed key; service-role and Cloudinary API secrets stay server-side in the admin deployment.

## Phase 0 status

This commit establishes the source-of-truth schema, assets, design tokens, navigation shells, environment contracts, and CI placeholders. Feature screens are added in subsequent focused commits and must be verified in the target runtime before being called complete.

## Repository role
`web`
