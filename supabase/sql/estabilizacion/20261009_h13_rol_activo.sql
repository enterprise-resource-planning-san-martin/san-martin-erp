-- H13: un perfil con rol desactivado tampoco puede seguir usando una sesión.
create or replace function public.erp_usuario_activo()
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select auth.uid() is not null and exists (
    select 1
    from public.perfiles p
    join public.roles r on r.id = p.rol_id
    where p.id = auth.uid()
      and p.activo = true
      and p.estado = 'ACTIVO'
      and r.activo = true
  );
$function$;

revoke all on function public.erp_usuario_activo() from public, anon;
grant execute on function public.erp_usuario_activo() to authenticated, service_role;
