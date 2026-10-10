-- H13: permisos efectivos del usuario actual para mostrar las acciones disponibles.
-- Las políticas y RPC de operación siguen siendo la autoridad final.
create or replace function public.erp_mis_permisos()
returns table(codigo text)
language sql
stable
security definer
set search_path = ''
as $function$
  select pe.codigo::text
  from public.permisos pe
  where auth.uid() is not null
    and pe.activo = true
    and public.usuario_tiene_permiso(auth.uid(), pe.codigo::text)
  order by pe.codigo;
$function$;

revoke all on function public.erp_mis_permisos() from public, anon;
grant execute on function public.erp_mis_permisos() to authenticated;

-- Ambas entradas de Auth ejecutaban crear_perfil_cliente() al mismo INSERT.
-- La función ya usa ON CONFLICT DO NOTHING; una sola ejecución basta.
drop trigger if exists on_auth_cliente_created on auth.users;

-- TRUNCATE elude RLS: los clientes de navegador no deben poder vaciar tablas.
revoke truncate on all tables in schema public from anon, authenticated;
