-- HomigoCare authoritative schema, Phase 0
-- Source: supplied Firebase + Supabase + Cloudinary Setup Guide
create extension if not exists pgcrypto;

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

-- RLS is enabled immediately; policies are added in the next migration after auth bridge validation.
do $$ declare t record; begin for t in select tablename from pg_tables where schemaname='public' and tablename in (
  'users','patients','role_requirements','professionals','addresses','bookings','payments','payment_accounts','health_passport','vitals','documents','reviews','wallet_transactions','assessment_tests','supply_requests','cms_content','access_logs','admin_audit_log','otp_codes'
) loop execute format('alter table public.%I enable row level security', t.tablename); end loop; end $$;
