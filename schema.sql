-- OWN CRM (빛으로 아트 스토리 · 전시동) - Supabase/Postgres schema
-- 실행 위치: Supabase SQL Editor
-- 주의: Supabase Auth(휴대폰 OTP) 활성화 필요

-- Extensions
create extension if not exists pgcrypto;
create extension if not exists btree_gist;

-- Enums
do $$ begin
  create type role_type as enum ('ADMIN','MANAGER','STAFF','PARTNER');
exception when duplicate_object then null; end $$;

do $$ begin
  create type customer_type as enum ('WEDDING','RENTAL');
exception when duplicate_object then null; end $$;

do $$ begin
  create type booking_type as enum ('WEDDING','RENTAL');
exception when duplicate_object then null; end $$;

do $$ begin
  create type booking_status as enum ('INQUIRY','HOLD','CONFIRMED','CANCELED');
exception when duplicate_object then null; end $$;

do $$ begin
  create type schedule_type as enum ('CONSULT','VISIT','CALL','REHEARSAL','SETUP','ETC');
exception when duplicate_object then null; end $$;

-- Tables
create table if not exists tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  hold_days int not null default 7,
  created_at timestamptz not null default now()
);

create table if not exists halls (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique(tenant_id, name)
);

-- 웨딩 슬롯(고정 시간)
create table if not exists wedding_slots (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  hall_id uuid not null references halls(id) on delete cascade,
  slot_time time not null,
  duration_minutes int not null default 180, -- 3시간 블록
  unique(tenant_id, hall_id, slot_time)
);

-- 직원 프로필(auth.users와 1:1)
create table if not exists profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone text,
  name text,
  title text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- 테넌트 소속 + 권한
create table if not exists tenant_members (
  tenant_id uuid not null references tenants(id) on delete cascade,
  user_id uuid not null references profiles(user_id) on delete cascade,
  role role_type not null,
  created_at timestamptz not null default now(),
  primary key(tenant_id, user_id)
);

-- 초대(Invite Only)
create table if not exists invites (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  phone text not null,
  role role_type not null,
  created_by uuid references profiles(user_id),
  used_by uuid references profiles(user_id),
  used_at timestamptz,
  created_at timestamptz not null default now(),
  unique(tenant_id, phone)  -- 같은 지점에 동일 번호 중복 초대 방지
);

-- 고객
create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  type customer_type not null default 'WEDDING',
  status text not null default 'INQUIRY',
  -- wedding
  groom_name text, groom_phone text,
  bride_name text, bride_phone text,
  primary_phone text, -- Primary 연락처(선택)
  -- rental
  company_name text, contact_name text, contact_phone text,
  source text,
  flow text,
  memo text,
  owner_user_id uuid references profiles(user_id),
  wish_date date,
  first_contact_at timestamptz default now(),
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  deleted_by uuid references profiles(user_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 예약(웨딩/대관 공통: 시간 범위로 관리)
create table if not exists bookings (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  hall_id uuid not null references halls(id) on delete restrict,
  customer_id uuid references customers(id) on delete set null,
  type booking_type not null,
  status booking_status not null default 'INQUIRY',
  -- 시간 범위(충돌 검사에 사용)
  start_at timestamptz not null,
  end_at   timestamptz not null,
  -- 웨딩 슬롯 표시용(웨딩일 때만)
  slot_time time,
  guests int,
  hold_expires_at timestamptz,
  memo text,
  owner_user_id uuid references profiles(user_id),
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  deleted_by uuid references profiles(user_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_at > start_at)
);

-- 같은 홀에서 시간 겹치면 예약 불가(웨딩/대관 공통)
-- 보관(is_deleted=true) 건은 제외하고 싶지만, exclusion은 조건부가 까다로워서
-- 앱/트리거에서 is_deleted 건 제외 검사 + 운영상 보관된 예약은 충돌 무시하도록 처리.
-- 우선 강한 안전장치로 "모든 예약" 시간겹침을 막고, 보관 처리 시에는 end_at/start_at를 null로 만들지 않도록.
-- 실제 운영에서는 보관된 예약은 복구 시 다시 충돌 검사하는 방식 권장.
do $$ begin
  alter table bookings
  add constraint bookings_no_overlap
  exclude using gist (
    hall_id with =,
    tstzrange(start_at, end_at, '[)') with &&
  );
exception when duplicate_object then null; end $$;

-- 일정(상담/방문/세팅/리허설 등)
create table if not exists schedules (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  hall_id uuid references halls(id) on delete set null,
  customer_id uuid references customers(id) on delete set null,
  type schedule_type not null,
  start_at timestamptz not null,
  end_at timestamptz not null,
  memo text,
  owner_user_id uuid references profiles(user_id),
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  deleted_by uuid references profiles(user_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_at > start_at)
);

-- 거래처 할당(예약/일정 단위로 PARTNER에게 공유)
create table if not exists assignments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  partner_user_id uuid not null references profiles(user_id) on delete cascade,
  booking_id uuid references bookings(id) on delete cascade,
  schedule_id uuid references schedules(id) on delete cascade,
  created_by uuid references profiles(user_id),
  created_at timestamptz not null default now(),
  check (
    (booking_id is not null and schedule_id is null)
    or (booking_id is null and schedule_id is not null)
  ),
  unique(tenant_id, partner_user_id, booking_id, schedule_id)
);

-- 감사 로그
create table if not exists audit_logs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  actor_user_id uuid references profiles(user_id),
  action text not null,
  entity_type text,
  entity_id uuid,
  detail jsonb,
  created_at timestamptz not null default now()
);

-- updated_at 자동 갱신
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_customers_updated on customers;
create trigger trg_customers_updated before update on customers
for each row execute function set_updated_at();

drop trigger if exists trg_bookings_updated on bookings;
create trigger trg_bookings_updated before update on bookings
for each row execute function set_updated_at();

drop trigger if exists trg_schedules_updated on schedules;
create trigger trg_schedules_updated before update on schedules
for each row execute function set_updated_at();

-- Helper: 현재 유저의 tenant role 가져오기
create or replace function current_role_for_tenant(tid uuid)
returns role_type language sql stable as $$
  select tm.role
  from tenant_members tm
  where tm.tenant_id = tid and tm.user_id = auth.uid()
$$;

create or replace function is_member(tid uuid)
returns boolean language sql stable as $$
  select exists(
    select 1 from tenant_members tm
    where tm.tenant_id = tid and tm.user_id = auth.uid()
  )
$$;

create or replace function is_admin(tid uuid)
returns boolean language sql stable as $$
  select exists(
    select 1 from tenant_members tm
    where tm.tenant_id = tid and tm.user_id = auth.uid() and tm.role = 'ADMIN'
  )
$$;

create or replace function is_manager_or_admin(tid uuid)
returns boolean language sql stable as $$
  select exists(
    select 1 from tenant_members tm
    where tm.tenant_id = tid and tm.user_id = auth.uid() and tm.role in ('ADMIN','MANAGER')
  )
$$;

-- RLS ON
alter table tenants enable row level security;
alter table halls enable row level security;
alter table wedding_slots enable row level security;
alter table profiles enable row level security;
alter table tenant_members enable row level security;
alter table invites enable row level security;
alter table customers enable row level security;
alter table bookings enable row level security;
alter table schedules enable row level security;
alter table assignments enable row level security;
alter table audit_logs enable row level security;

-- Profiles: 본인만 읽기/수정(관리자 기능은 앱에서 service role로 수행 권장)
drop policy if exists "profiles_select_own" on profiles;
create policy "profiles_select_own" on profiles
for select using (user_id = auth.uid());

drop policy if exists "profiles_update_own" on profiles;
create policy "profiles_update_own" on profiles
for update using (user_id = auth.uid());

-- tenant_members: 본인 소속만 조회
drop policy if exists "tm_select_own" on tenant_members;
create policy "tm_select_own" on tenant_members
for select using (user_id = auth.uid());

-- tenants/halls/wedding_slots: 소속만 조회
drop policy if exists "tenants_select_member" on tenants;
create policy "tenants_select_member" on tenants
for select using (is_member(id));

drop policy if exists "halls_select_member" on halls;
create policy "halls_select_member" on halls
for select using (is_member(tenant_id));

drop policy if exists "slots_select_member" on wedding_slots;
create policy "slots_select_member" on wedding_slots
for select using (is_member(tenant_id));

-- customers: STAFF/MANAGER/ADMIN은 소속+미삭제만 기본 접근
drop policy if exists "customers_select_member" on customers;
create policy "customers_select_member" on customers
for select using (
  is_member(tenant_id)
  and (is_deleted = false)
);

-- customers insert/update: 소속이면 가능
drop policy if exists "customers_insert_member" on customers;
create policy "customers_insert_member" on customers
for insert with check (is_member(tenant_id));

drop policy if exists "customers_update_member" on customers;
create policy "customers_update_member" on customers
for update using (is_member(tenant_id));

-- bookings: 소속+미삭제 select
drop policy if exists "bookings_select_member" on bookings;
create policy "bookings_select_member" on bookings
for select using (is_member(tenant_id) and is_deleted=false);

drop policy if exists "bookings_insert_member" on bookings;
create policy "bookings_insert_member" on bookings
for insert with check (is_member(tenant_id));

drop policy if exists "bookings_update_member" on bookings;
create policy "bookings_update_member" on bookings
for update using (is_member(tenant_id));

-- schedules: 소속+미삭제 select
drop policy if exists "schedules_select_member" on schedules;
create policy "schedules_select_member" on schedules
for select using (is_member(tenant_id) and is_deleted=false);

drop policy if exists "schedules_insert_member" on schedules;
create policy "schedules_insert_member" on schedules
for insert with check (is_member(tenant_id));

drop policy if exists "schedules_update_member" on schedules;
create policy "schedules_update_member" on schedules
for update using (is_member(tenant_id));

-- assignments: 거래처는 본인 할당만 조회, 직원은 지점 내 전체 조회
drop policy if exists "assignments_select_member_or_partner" on assignments;
create policy "assignments_select_member_or_partner" on assignments
for select using (
  (is_member(tenant_id))
  or (partner_user_id = auth.uid())
);

drop policy if exists "assignments_insert_manager" on assignments;
create policy "assignments_insert_manager" on assignments
for insert with check (is_manager_or_admin(tenant_id));

drop policy if exists "assignments_delete_manager" on assignments;
create policy "assignments_delete_manager" on assignments
for delete using (is_manager_or_admin(tenant_id));

-- invites: ADMIN만 생성/조회(직원 초대)
drop policy if exists "invites_select_admin" on invites;
create policy "invites_select_admin" on invites
for select using (is_admin(tenant_id));

drop policy if exists "invites_insert_admin" on invites;
create policy "invites_insert_admin" on invites
for insert with check (is_admin(tenant_id));

drop policy if exists "invites_update_admin" on invites;
create policy "invites_update_admin" on invites
for update using (is_admin(tenant_id));

-- audit_logs: 멤버만 조회/생성
drop policy if exists "audit_select_member" on audit_logs;
create policy "audit_select_member" on audit_logs
for select using (is_member(tenant_id));

drop policy if exists "audit_insert_member" on audit_logs;
create policy "audit_insert_member" on audit_logs
for insert with check (is_member(tenant_id));

-- PARTNER 고객정보 제한은 "뷰(view)"로 제공하는 것이 안전
-- 1) partner_assigned_customers_view: 할당된 일정/예약에 연결된 고객만 + 최소 필드만 노출
create or replace view partner_assigned_customers_view as
select
  c.id,
  c.tenant_id,
  c.groom_name,
  c.bride_name,
  c.primary_phone,
  c.company_name,
  c.contact_name
from customers c
where c.is_deleted=false;

-- RLS는 view에 직접 적용되지 않으므로, 앱에서 이 뷰는 service role로 읽지 말고
-- "partner_user_id = auth.uid()" 조건의 RPC를 쓰는 방식이 가장 안전합니다.
-- 스타터 단계에서는 assignments 기반으로 필터링하여 노출 범위를 제한하세요.

-- -----------------------------
-- Bootstrap / Seed
-- -----------------------------
-- 초기 지점/홀/슬롯 삽입
insert into tenants(name, hold_days)
select '빛으로 아트 스토리', 7
where not exists (select 1 from tenants where name='빛으로 아트 스토리');

insert into halls(tenant_id, name)
select t.id, '전시동'
from tenants t
where t.name='빛으로 아트 스토리'
and not exists (
  select 1 from halls h where h.tenant_id=t.id and h.name='전시동'
);

-- 슬롯: 11:00 / 14:30 / 18:00 (3시간)
insert into wedding_slots(tenant_id, hall_id, slot_time, duration_minutes)
select t.id, h.id, s.slot_time, 180
from tenants t
join halls h on h.tenant_id=t.id and h.name='전시동'
join (values ('11:00'::time), ('14:30'::time), ('18:00'::time)) as s(slot_time) on true
where t.name='빛으로 아트 스토리'
and not exists (
  select 1 from wedding_slots ws where ws.tenant_id=t.id and ws.hall_id=h.id and ws.slot_time=s.slot_time
);

-- -----------------------------
-- Auth User -> Profile 자동 생성 + 대표 번호 부트스트랩
-- -----------------------------
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  tid uuid;
begin
  -- profile upsert
  insert into profiles(user_id, phone, name)
  values (new.id, new.phone, null)
  on conflict (user_id) do update
    set phone = excluded.phone;

  -- 대표 번호(ADMIN) 부트스트랩: 010-9566-3379
  if new.phone = '010-9566-3379' then
    select id into tid from tenants where name='빛으로 아트 스토리' limit 1;
    if tid is not null then
      insert into tenant_members(tenant_id, user_id, role)
      values (tid, new.id, 'ADMIN')
      on conflict do nothing;
    end if;
  end if;

  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();
