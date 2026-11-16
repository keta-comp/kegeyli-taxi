-- Security hardening and order operations for JAYHUN TAXI.
-- Apply after 202611170001_initial.sql. Protect customer personal data from drivers.

drop policy if exists orders_read on public.orders;
create policy orders_dispatcher_read on public.orders for select to authenticated
using(public.has_role('operator') or public.has_role('admin'));

-- A projection deliberately contains NO customer contact number or operator-only notes.
-- View is security definer, so its WHERE clause is the privacy boundary.
create or replace view public.driver_orders
with (security_barrier=true)
as select o.id,o.order_number,''::text as customer_phone,o.pickup_address,
o.destination,o.passengers_count,o.price,null::text as notes,o.status,
o.driver_id,o.operator_id,o.created_at
from public.orders o
where public.has_role('driver') and
 ((o.status='NEW' and exists(select 1 from public.drivers online_d where online_d.user_id=auth.uid() and online_d.is_online=true and online_d.last_seen_at>now()-interval '90 seconds')) or o.driver_id in (
   select d.id from public.drivers d where d.user_id=auth.uid()
 ));
revoke all on public.driver_orders from public;
grant select on public.driver_orders to authenticated;

-- Drivers can claim an open order without SELECT privilege on private orders table.
create or replace function public.is_claimable_order(target_id uuid)
returns boolean language sql stable security definer
set search_path=public
as $$select public.has_role('driver') and exists(
  select 1 from public.orders where id=target_id and status='NEW'
)$$;
revoke all on function public.is_claimable_order(uuid) from public;
grant execute on function public.is_claimable_order(uuid) to authenticated;
drop policy if exists claims_create on public.order_claims;
create policy claims_create on public.order_claims
for insert to authenticated with check (
  public.has_role('driver')
  and driver_id in (
    select d.id from public.drivers d where d.user_id=auth.uid()
      and d.is_online=true
      and d.last_seen_at>now()-interval '90 seconds'
  )
  and public.is_claimable_order(order_id)
);

-- Drivers can only see claims for their own driver record; operators can see all.
drop policy if exists claims_read on public.order_claims;
create policy claims_read on public.order_claims for select to authenticated using(
  public.has_role('operator') or public.has_role('admin')
  or (public.has_role('driver') and driver_id in
    (select id from public.drivers where user_id=auth.uid()))
);

-- The frontend submits order IDs and driver IDs. Validation and atomic assignment live on the server.
create or replace function public.assign_order(target_order uuid, chosen_driver uuid)
returns boolean language plpgsql security definer set search_path=public
as $$
declare affected int;
begin
  if not(public.has_role('operator') or public.has_role('admin'))
  then raise exception 'Only dispatchers can assign orders'; end if;
  update public.orders set driver_id=chosen_driver,status='ACCEPTED',accepted_at=now()
  where id=target_order and status='NEW' and exists(
    select 1 from public.drivers d where d.id=chosen_driver and d.is_online=true
      and d.last_seen_at>now()-interval '90 seconds'
  );
  get diagnostics affected=row_count;
  return affected=1;
end;$$;
revoke all on function public.assign_order(uuid,uuid) from public;
grant execute on function public.assign_order(uuid,uuid) to authenticated;

-- Drivers update only their own assigned order's status using this narrow API.
create or replace function public.advance_my_order(target_order uuid,next_status text)
returns boolean language plpgsql security definer set search_path=public
as $$
declare affected int;
begin
 if not public.has_role('driver') then raise exception 'Driver only'; end if;
 update public.orders o set
 status=next_status,
 completed_at=case when next_status='COMPLETED' then now() else completed_at end
 where o.id=target_order
   and o.driver_id in(select id from public.drivers where user_id=auth.uid())
   and ((o.status='ACCEPTED' and next_status='ON_THE_WAY')
     or (o.status='ON_THE_WAY' and next_status='PASSENGER_PICKED_UP')
     or (o.status='PASSENGER_PICKED_UP' and next_status='COMPLETED'));
 get diagnostics affected=row_count;
 return affected=1;
end;$$;
revoke all on function public.advance_my_order(uuid,text) from public;
grant execute on function public.advance_my_order(uuid,text) to authenticated;

-- Restrict direct order updates to operator/admin; driver uses advance_my_order.
drop policy if exists orders_manage on public.orders;
create policy orders_manage on public.orders for update to authenticated
using(public.has_role('operator') or public.has_role('admin'))
with check(public.has_role('operator') or public.has_role('admin'));

-- Protect immutable order identity and passenger/contact fields from direct edits.
create or replace function public.protect_order_update() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if public.has_role('driver') and not(public.has_role('operator') or public.has_role('admin')) then
   if new.driver_id is distinct from old.driver_id or new.operator_id is distinct from old.operator_id
      or new.customer_phone is distinct from old.customer_phone
      or new.pickup_address is distinct from old.pickup_address
      or new.destination is distinct from old.destination or new.price is distinct from old.price
      or new.passengers_count is distinct from old.passengers_count
      or new.notes is distinct from old.notes then raise exception 'Driver may only update progress'; end if;
   if not ((old.status='ACCEPTED' and new.status='ON_THE_WAY')
     or (old.status='ON_THE_WAY' and new.status='PASSENGER_PICKED_UP')
     or (old.status='PASSENGER_PICKED_UP' and new.status='COMPLETED'))
   then raise exception 'Invalid order status transition'; end if;
 end if;
 if public.has_role('operator') and not public.has_role('admin') then
   if new.status is distinct from old.status and not (
     (old.status='NEW' and new.status in ('ACCEPTED','CANCELLED')) or
     (old.status='ACCEPTED' and new.status in ('ON_THE_WAY','CANCELLED')) or
     (old.status='ON_THE_WAY' and new.status in ('PASSENGER_PICKED_UP','CANCELLED')) or
     (old.status='PASSENGER_PICKED_UP' and new.status in ('COMPLETED','CANCELLED'))
   ) then raise exception 'Invalid order status transition'; end if;
   if old.status <> 'NEW' and new.driver_id is distinct from old.driver_id
     then raise exception 'Cannot reassign an active order'; end if;
 end if;
 if new.id is distinct from old.id or new.order_number is distinct from old.order_number
   or new.created_at is distinct from old.created_at
   then raise exception 'Order identity cannot be changed'; end if;
 return new;
end $$;

-- Operator and admin may read and maintain tariff records, admin only writes.
-- Restrict profile editing to non-role edits from the user-facing administration (roll changes require trusted backend).

-- Explicit anonymous denial by RLS; ALL user data requires authenticated session.
