-- Remove the SECURITY DEFINER driver_orders view and read from a sanitized, RLS-protected table instead.
revoke all on public.driver_orders from authenticated, anon, public;
drop view if exists public.driver_orders;

drop policy if exists announcements_read on public.order_announcements;
create policy announcements_read on public.order_announcements
for select to authenticated using(
  public.has_role('operator') or public.has_role('admin') or (
    public.has_role('driver') and (
      (status='NEW' and exists(
         select 1 from public.drivers d where d.user_id=auth.uid()
           and d.is_online=true and d.last_seen_at>now()-interval '90 seconds'
      )) or driver_id in (
        select d.id from public.drivers d where d.user_id=auth.uid()
      )
    )
  )
);
