-- JAYHUN TAXI schema. Run in Supabase SQL editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  phone text,
  role text not null check (role in ('driver','operator','admin')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.drivers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  car_model text not null,
  car_number text not null,
  is_online boolean not null default false,
  last_seen_at timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number bigint generated always as identity unique,
  customer_phone text not null,
  pickup_address text not null,
  destination text not null,
  passengers_count integer not null default 1 check(passengers_count between 1 and 20),
  price integer not null default 0 check(price >= 0),
  notes text,
  driver_id uuid references public.drivers(id) on delete set null,
  operator_id uuid not null references public.profiles(id),
  status text not null default 'NEW' check(status in ('NEW','ACCEPTED','ON_THE_WAY','PASSENGER_PICKED_UP','COMPLETED','CANCELLED')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  completed_at timestamptz
);
create table if not exists public.order_claims (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  driver_id uuid not null references public.drivers(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(order_id,driver_id)
);
create table if not exists public.tariffs (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  price integer not null check(price >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
insert into public.tariffs(name,price) values('Shahar ichi',8000) on conflict (name) do nothing;

create or replace function public.has_role(wanted text)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and role=wanted and active=true); $$;
create or replace function public.is_active()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and active=true); $$;
revoke all on function public.has_role(text) from public;
revoke all on function public.is_active() from public;
grant execute on function public.has_role(text),public.is_active() to authenticated;

alter table public.profiles enable row level security;
alter table public.drivers enable row level security;
alter table public.orders enable row level security;
alter table public.order_claims enable row level security;
alter table public.tariffs enable row level security;

create policy profiles_read on public.profiles for select to authenticated using (
  public.is_active() and (id=auth.uid() or public.has_role('admin') or public.has_role('operator'))
);
create policy profiles_admin_update on public.profiles for update to authenticated using(public.has_role('admin')) with check(public.has_role('admin'));
create policy drivers_read on public.drivers for select to authenticated using(public.is_active());
create policy drivers_admin_create on public.drivers for insert to authenticated with check(public.has_role('admin'));
create policy drivers_update on public.drivers for update to authenticated using(
  public.has_role('admin') or (public.has_role('driver') and user_id=auth.uid())
) with check(
  public.has_role('admin') or (public.has_role('driver') and user_id=auth.uid())
);
create policy orders_read on public.orders for select to authenticated using(public.is_active());
create policy orders_create on public.orders for insert to authenticated with check(
  (public.has_role('operator') or public.has_role('admin')) and operator_id=auth.uid() and status='NEW' and driver_id is null
);
create policy orders_manage on public.orders for update to authenticated using(
  public.has_role('admin') or public.has_role('operator') or
  (public.has_role('driver') and driver_id in (select id from public.drivers where user_id=auth.uid()))
) with check(public.is_active());
create policy claims_read on public.order_claims for select to authenticated using(public.is_active());
create policy claims_create on public.order_claims for insert to authenticated with check(
  public.has_role('driver') and driver_id in (
    select id from public.drivers where user_id=auth.uid() and is_online=true
  ) and exists(select 1 from public.orders where id=order_id and status='NEW')
);
create policy tariffs_read on public.tariffs for select to authenticated using(public.is_active());
create policy tariffs_admin on public.tariffs for all to authenticated using(public.has_role('admin')) with check(public.has_role('admin'));

-- Enforce sensitive updates server-side: drivers cannot change car or status unrelated to their own online flag.
create or replace function public.protect_driver_update() returns trigger
language plpgsql security definer set search_path=public as $$
begin
  if public.has_role('driver') and not public.has_role('admin') then
    if new.user_id is distinct from old.user_id or new.car_model is distinct from old.car_model
       or new.car_number is distinct from old.car_number then
       raise exception 'Driver may only update presence';
    end if;
  end if;
  return new;
end $$;
create trigger protect_driver_update before update on public.drivers
for each row execute function public.protect_driver_update();

-- Driver can only transition their assigned order forward (or keep same state).
create or replace function public.protect_order_update() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if public.has_role('driver') and not (public.has_role('operator') or public.has_role('admin')) then
   if new.driver_id is distinct from old.driver_id
      or new.operator_id is distinct from old.operator_id
      or new.customer_phone is distinct from old.customer_phone
      or new.pickup_address is distinct from old.pickup_address
      or new.destination is distinct from old.destination
      or new.price is distinct from old.price
      or new.passengers_count is distinct from old.passengers_count
      or new.notes is distinct from old.notes then
     raise exception 'Driver may only update order progress';
   end if;
   if not (
      new.status = old.status
      or (old.status='ACCEPTED' and new.status='ON_THE_WAY')
      or (old.status='ON_THE_WAY' and new.status='PASSENGER_PICKED_UP')
      or (old.status='PASSENGER_PICKED_UP' and new.status='COMPLETED')
   ) then raise exception 'Invalid driver order transition'; end if;
 end if;
 return new;
end $$;
create trigger protect_order_update before update on public.orders
for each row execute function public.protect_order_update();

-- Realtime subscriptions in authenticated clients. Run once.
do $$ begin
 alter publication supabase_realtime add table public.drivers;
 exception when duplicate_object then null; end $$;
do $$ begin
 alter publication supabase_realtime add table public.orders;
 exception when duplicate_object then null; end $$;
do $$ begin
 alter publication supabase_realtime add table public.order_claims;
 exception when duplicate_object then null; end $$;

-- Bootstrap: create the first admin via Auth dashboard, then manually:
-- insert into public.profiles(id,name,role) values ('AUTH_USER_UUID','Administrator','admin');
-- Never put service_role keys in VITE_* environment variables.
