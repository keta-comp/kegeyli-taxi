-- JAYHUN TAXI audit log: every order creation, assignment and status transition.
create table if not exists public.order_events (
 id uuid primary key default gen_random_uuid(),
 order_id uuid not null references public.orders(id) on delete cascade,
 actor_id uuid,
 event_type text not null check(event_type in ('CREATED','DRIVER_ASSIGNED','STATUS_CHANGED')),
 old_status text,
 new_status text,
 old_driver_id uuid,
 new_driver_id uuid,
 created_at timestamptz not null default now()
);
create index if not exists idx_order_events_order_time on public.order_events(order_id,created_at desc);
alter table public.order_events enable row level security;
revoke all on public.order_events from anon,public;
grant select on public.order_events to authenticated;
create policy audit_dispatcher_read on public.order_events
  for select to authenticated using(public.has_role('operator') or public.has_role('admin'));
create or replace function public.audit_order_transition() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if tg_op='INSERT' then
   insert into public.order_events(order_id,actor_id,event_type,new_status,new_driver_id)
   values(new.id,auth.uid(),'CREATED',new.status,new.driver_id);
 else
   if new.driver_id is distinct from old.driver_id then
     insert into public.order_events(order_id,actor_id,event_type,old_status,new_status,old_driver_id,new_driver_id)
     values(new.id,auth.uid(),'DRIVER_ASSIGNED',old.status,new.status,old.driver_id,new.driver_id);
   end if;
   if new.status is distinct from old.status then
     insert into public.order_events(order_id,actor_id,event_type,old_status,new_status,old_driver_id,new_driver_id)
     values(new.id,auth.uid(),'STATUS_CHANGED',old.status,new.status,old.driver_id,new.driver_id);
   end if;
 end if;
 return new;
end $$;
revoke all on function public.audit_order_transition() from public,anon,authenticated;
drop trigger if exists order_audit on public.orders;
create trigger order_audit after insert or update of status,driver_id on public.orders
for each row execute function public.audit_order_transition();
