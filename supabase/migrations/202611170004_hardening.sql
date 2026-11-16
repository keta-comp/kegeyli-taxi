-- Harden function privileges: explicit anon EXECUTE grants are present by default.
revoke execute on function public.has_role(text) from anon, public;
revoke execute on function public.is_active() from anon, public;
revoke execute on function public.is_claimable_order(uuid) from anon, public;
revoke execute on function public.assign_order(uuid,uuid) from anon, public;
revoke execute on function public.advance_my_order(uuid,text) from anon, public;
revoke execute on function public.protect_driver_update() from anon, authenticated, public;
revoke execute on function public.protect_order_update() from anon, authenticated, public;
revoke execute on function public.update_order_announcement() from anon, authenticated, public;
grant execute on function public.has_role(text), public.is_active(), public.is_claimable_order(uuid), public.assign_order(uuid,uuid), public.advance_my_order(uuid,text) to authenticated;

create index if not exists idx_orders_driver_id on public.orders(driver_id);
create index if not exists idx_orders_operator_id on public.orders(operator_id);
create index if not exists idx_claims_driver_id on public.order_claims(driver_id);
create index if not exists idx_orders_created_at on public.orders(created_at desc);

-- Avoid overlapping permissive SELECT policies for tariffs.
drop policy if exists tariffs_admin on public.tariffs;
create policy tariffs_admin_insert on public.tariffs for insert to authenticated with check(public.has_role('admin'));
create policy tariffs_admin_update on public.tariffs for update to authenticated using(public.has_role('admin')) with check(public.has_role('admin'));
create policy tariffs_admin_delete on public.tariffs for delete to authenticated using(public.has_role('admin'));
