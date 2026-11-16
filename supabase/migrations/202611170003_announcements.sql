-- Public-to-drivers order announcements: no phone number or private notes.
-- Used as safe realtime notification source instead of exposing orders table.
create table if not exists public.order_announcements (
  order_id uuid primary key references public.orders(id) on delete cascade,
  order_number bigint not null,
  pickup_address text not null,
  destination text not null,
  passengers_count integer not null,
  price integer not null,
  status text not null,
  driver_id uuid,
  changed_at timestamptz not null default now()
);
alter table public.order_announcements enable row level security;
create policy announcements_read on public.order_announcements for select to authenticated
using(public.has_role('driver') or public.has_role('operator') or public.has_role('admin'));
revoke all on public.order_announcements from anon;
grant select on public.order_announcements to authenticated;

create or replace function public.update_order_announcement() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 insert into public.order_announcements
   (order_id,order_number,pickup_address,destination,passengers_count,price,status,driver_id,changed_at)
 values
   (new.id,new.order_number,new.pickup_address,new.destination,new.passengers_count,new.price,new.status,new.driver_id,now())
 on conflict(order_id) do update set
   pickup_address=excluded.pickup_address,destination=excluded.destination,
   passengers_count=excluded.passengers_count,price=excluded.price,
   status=excluded.status,driver_id=excluded.driver_id,changed_at=now();
 return new;
end $$;
drop trigger if exists order_announcement_sync on public.orders;
create trigger order_announcement_sync after insert or update on public.orders
for each row execute function public.update_order_announcement();

insert into public.order_announcements(order_id,order_number,pickup_address,destination,passengers_count,price,status,driver_id)
select id,order_number,pickup_address,destination,passengers_count,price,status,driver_id
from public.orders on conflict(order_id) do nothing;

do $$ begin alter publication supabase_realtime add table public.order_announcements;
exception when duplicate_object then null; end $$;
