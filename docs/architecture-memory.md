# 4. The One Authoritative Firebase + Supabase + Cloudinary Setup Guide

Do this **once**, in this order, before writing feature code in any repo. Every one of the four repositories connects to the exact same three projects created here — never create a second Firebase project, a second Supabase project, or a second Cloudinary account "for" a specific app.

## 4.1 Firebase — Full Real Setup

1. Create project `homigo-care-prod` (and a second, fully separate project `homigo-care-dev` for testing — never test against production).
2. **Authentication** → enable: Email/Password, Google, Apple (needed for the iOS app's "Sign in with Apple" requirement), Anonymous/Guest.
3. **Cloud Firestore** → create in Native mode, region closest to Pakistan. This holds **only** the real-time collections: `presence`, `bookings_live`, `chat_threads`, `notifications_feed`, `booking_status_events`, `verification_status` (one small doc per professional, so their app can subscribe to live approve/reject updates — this collection was implied but never explicitly named in the earlier documents; add it now).
4. **Cloud Messaging** → enable for Android, iOS (requires an APNs key uploaded to Firebase, generated from the Apple Developer account once it exists), and Web (requires a VAPID key).
5. **Storage** → enable the default Firebase Storage bucket as part of standard project setup. **Clarification on Cloudinary vs. Firebase Storage:** Cloudinary remains the **primary** store for all user-facing images and documents (CNIC, degrees, prescriptions, receipts, app illustrations/icons) exactly as the four earlier documents specify — that decision does not change. Enabling Firebase Storage here is simply standard Firebase project setup and gives the team a free, already-configured **secondary/fallback** bucket (useful for e.g. temporary server-side file processing) without taking over Cloudinary's role. Do not build a second parallel image pipeline against Firebase Storage unless a specific future need requires it.
6. Register three client apps inside this one project: Android (`pk.homigocare.android`), iOS (`pk.homigocare.ios`), Web. Download each config file (`google-services.json`, `GoogleService-Info.plist`, the Web config object) and place them exactly where each repo's own blueprint specifies.

## 4.2 Supabase — Full Real Setup

1. Create project `homigo-care` (plus a `homigo-care-dev` branch/project for testing).
2. Note the project URL and both the `anon` key (safe for client apps) and the `service_role` key (secret, Admin-Panel-only, per its blueprint's §1.4).
3. Enable the `pgcrypto` extension (`create extension if not exists pgcrypto;`) — needed for §4.8.

## 4.3 The Authoritative Database Schema (fixes Gap §1.3)

Run this as the first Supabase migration, before any app code is written. Column types are intentionally explicit so all four repos generate matching typed clients from the same source of truth.

```sql
create table users (
  id uuid primary key default gen_random_uuid(),
  auth_uid text unique not null,              -- Firebase Auth UID
  role text not null check (role in ('patient','professional','admin')),
  full_name text not null,
  email text unique,
  phone text,
  email_verified boolean default false,
  created_at timestamptz default now()
);

create table patients (
  user_id uuid primary key references users(id) on delete cascade,
  patient_type text check (patient_type in ('adult','minor','elderly')),
  cnic_encrypted bytea,                        -- pgcrypto-encrypted, see §4.8
  guardian_cnic_encrypted bytea,
  date_of_birth date,
  gender text,
  emergency_contact_name text,
  emergency_contact_phone text
);

create table role_requirements (
  role_id text primary key,
  role_label text not null,
  category text not null,
  requires_cnic boolean default true,
  required_documents jsonb not null default '[]',
  requires_affiliation boolean default true,
  requires_assessment boolean default true,
  min_age int default 21,
  active boolean default true
);

create table professionals (
  user_id uuid primary key references users(id) on delete cascade,
  role_id text references role_requirements(role_id),
  hospital_affiliation text,
  verification_status text default 'pending' check (verification_status in ('pending','approved','rejected')),
  badge_tier text check (badge_tier in ('none','certified','excellence','elite')),
  rating_avg numeric(3,2) default 0
);

create table addresses (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(user_id) on delete cascade,
  label text, latitude numeric, longitude numeric,
  house_number text, street text, is_default boolean default false
);

create table bookings (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(user_id),
  professional_id uuid references professionals(user_id),
  service_category text not null,
  booking_type text check (booking_type in ('instant','scheduled','recurring','online','emergency')),
  status text default 'pending_professional' check (status in
    ('pending_professional','accepted','rejected','payment_pending_verification','paid',
     'in_progress','completed','cancelled','disputed')),
  price numeric(10,2), currency text default 'PKR',
  scheduled_at timestamptz, notes text,
  created_at timestamptz default now()
);

create table payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references bookings(id) on delete cascade,
  method text check (method in ('jazzcash','easypaisa','card','bank_transfer','cod')),
  amount numeric(10,2), reference_no text, screenshot_url text,
  status text default 'pending_verification' check (status in ('pending_verification','paid','rejected','refunded')),
  confirmed_by uuid references users(id), confirmed_at timestamptz
);

create table payment_accounts (
  id uuid primary key default gen_random_uuid(),
  method text not null, account_title text, account_number text, active boolean default true
);

create table health_passport (
  patient_id uuid primary key references patients(user_id) on delete cascade,
  medical_history jsonb default '{}', allergies jsonb default '[]',
  medications jsonb default '[]', critical_alerts jsonb default '[]',
  pin_hash text, emergency_pin_hash text
);

create table vitals (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(user_id) on delete cascade,
  recorded_at timestamptz default now(),
  blood_pressure text, sugar_level numeric, weight_kg numeric, temperature_c numeric
);

create table documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references users(id) on delete cascade,
  doc_type text, cloudinary_public_id text, status text default 'pending',
  reviewed_by uuid references users(id), reviewed_at timestamptz, rejection_reason text
);

create table reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references bookings(id),
  reviewer_id uuid references users(id), reviewee_id uuid references users(id),
  punctuality int, professionalism int, medical_skills int, communication int, overall int,
  text_review text, anonymous boolean default false,
  moderation_status text default 'pending' check (moderation_status in ('pending','approved','rejected'))
);

create table wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(user_id) on delete cascade,
  type text check (type in ('topup','cashback','referral','booking_payment','withdrawal')),
  amount numeric(10,2), created_at timestamptz default now()
);

create table assessment_tests (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid references professionals(user_id) on delete cascade,
  phase int check (phase in (1,2,3)), score numeric(5,2), passed boolean, attempted_at timestamptz default now()
);

create table supply_requests (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references bookings(id) on delete cascade,
  item_name text, estimated_cost numeric(10,2), approved boolean default false
);

create table cms_content (
  key text primary key, content jsonb not null, version int default 1, updated_at timestamptz default now()
);

create table access_logs (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid references patients(user_id), accessed_by uuid references users(id),
  booking_id uuid references bookings(id), accessed_at timestamptz default now()
);

create table admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references users(id), action text, table_affected text, record_id uuid,
  before_data jsonb, after_data jsonb, created_at timestamptz default now()
);

create table otp_codes (
  id uuid primary key default gen_random_uuid(),
  email text not null, code text not null, purpose text default 'signup',
  expires_at timestamptz not null, used boolean default false, created_at timestamptz default now()
);
```

Enable Row Level Security on every table immediately after creation, then write the policies matching each repo blueprint's access rules (patient sees own rows; professional sees own rows; admin-only tables gated on the `role` JWT claim from §4.4).

## 4.4 The Firebase ⇄ Supabase Auth Bridge (fixes Gap §1.1 — the real method)

Use Supabase's **Third-Party Auth** integration (Supabase Auth's support for external JWT issuers), configured to trust Firebase Authentication as an external provider:
1. In the Supabase Dashboard → Authentication → Sign In / Providers → Third-Party Auth, add **Firebase Auth** as a trusted provider, supplying the `homigo-care-prod` Firebase project ID. This tells Supabase to accept and verify Firebase-issued ID tokens directly using Firebase's own public JWKS — no custom token-exchange server is needed.
2. On each client (Android, iOS, Web), after `FirebaseAuth` sign-in succeeds, initialize the Supabase client using that Firebase ID token as the Supabase session's access token (each Supabase SDK exposes a method for supplying an externally-issued JWT as the active session).
3. Write RLS policies referencing `auth.jwt() ->> 'sub'` (the Firebase UID inside the token) matched against the `users.auth_uid` column — this is what makes "a patient can only read their own rows" actually enforceable.
4. **This is the one piece of plumbing every other feature depends on — test it in complete isolation first** (sign in on a test client, confirm a simple `select * from users where auth_uid = auth.jwt()->>'sub'` returns exactly one's own row and nothing else) before building any feature screen on top of it.

## 4.5 Dual-Write Consistency Pattern (fixes Gap §1.4)

For any action touching both Firestore and Supabase (e.g. confirming a payment: Supabase `payments.status = 'paid'` **and** Firestore `booking_status_events` gets a new event):
1. **Write to Supabase first** (the permanent record) — if this fails, stop, nothing happened, safe to retry.
2. **Then write to Firestore** (the real-time notification of that fact) — if this second write fails, the permanent record is still correct; log the failure and add a lightweight retry (e.g. a Supabase database trigger/webhook that re-attempts the Firestore write, or a simple scheduled reconciliation job that compares recent Supabase status changes against Firestore events and backfills any that are missing).
3. Never write to Firestore first for anything that matters permanently — Firestore here is a **notification/live-state layer**, Supabase is the **source of truth**.

## 4.6 OTP Rate-Limiting (fixes Gap §1.5)

On `/api/otp/send`: allow at most **3 sends per email per 15 minutes** and **10 sends per IP per hour**, tracked via a simple counter in the `otp_codes` table (count recent rows for that email/IP) or Vercel Edge Middleware's rate-limiting helpers. Return a clear "please wait before requesting another code" response rather than silently dropping the extra request.

## 4.7 Guest Account Upgrade Path (fixes Gap §1.6)

When a Guest (Anonymous Firebase user) chooses to add a real email/Google/Apple identity later, use Firebase Auth's **account linking** (`linkWithCredential`) rather than creating a brand-new account — this keeps the same `auth_uid`, so their existing `users`/`patients`/`bookings`/`wallet_transactions` rows in Supabase remain correctly attached with zero data migration needed.

## 4.8 Concrete Encryption for CNIC Fields (fixes Gap §1.8)

```sql
-- Encrypt on write:
update patients set cnic_encrypted = pgp_sym_encrypt('<plain CNIC>', current_setting('app.encryption_key'));
-- Decrypt on read (server-side only, never in a client-exposed query):
select pgp_sym_decrypt(cnic_encrypted, current_setting('app.encryption_key')) from patients where user_id = ...;
```
Store `app.encryption_key` as a Supabase Vault secret (or a Postgres configuration parameter set from a securely-stored value), never inline in application code. Only Server Actions/Route Handlers running with elevated trust (never a client-side query) may call `pgp_sym_decrypt`.

## 4.9 Cloudinary — Full Real Setup Recap

Create the account once, the folders and two presets (`homigo_public_assets` unsigned, `homigo_user_documents` signed) once, exactly as specified in the Android Blueprint §1.4 — every other repo (iOS, Web, Admin) connects to this same account, never a second one.

\newpage


## Repository-local implementation notes
Follow the supplied blueprint PDF for this repository and keep this file updated after each completed feature.

## Current implementation decision (2026-09-28)

Firebase Storage is not used anywhere in HomigoCare. All user-facing images, videos, PDFs, CNICs, degrees, prescriptions, receipts, and other files must use Cloudinary. Firebase is limited to Authentication, Firestore realtime collections, and Cloud Messaging. This decision supersedes any earlier Firebase Storage mention in the supplied guide.
