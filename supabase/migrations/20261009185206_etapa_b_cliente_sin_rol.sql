-- H13: los clientes de la tienda no tienen rol ERP; conservar su acceso.
-- Un rol ERP asignado pero desactivado sí bloquea la sesión.
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
    where p.id = auth.uid()
      and p.activo = true
      and p.estado = 'ACTIVO'
      and (
        p.rol_id is null
        or exists (
          select 1 from public.roles r
          where r.id = p.rol_id and r.activo = true
        )
      )
  );
$function$;

revoke all on function public.erp_usuario_activo() from public, anon;
grant execute on function public.erp_usuario_activo() to authenticated, service_role;
