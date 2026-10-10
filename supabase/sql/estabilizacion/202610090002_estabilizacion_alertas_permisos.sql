-- H07/H08. Forward migration; apply after 202610090001.
begin;
-- Source: supabase_alertas_automaticas.sql
-- H07. Requiere migración 202610090001. No programa tareas ni envía correos.
create table if not exists public.alertas_inventario (
  id uuid primary key default gen_random_uuid(),
  existencia_id uuid not null references public.existencias(id) on delete cascade,
  producto_id uuid not null references public.productos(id),
  ubicacion_id uuid not null references public.ubicaciones(id),
  estado varchar not null check (estado in ('SIN_STOCK','STOCK_BAJO')),
  stock_disponible numeric not null, stock_minimo numeric not null default 0,
  stock_maximo numeric, activa boolean not null default true, enviada_en timestamptz,
  resuelta_en timestamptz, fecha_creacion timestamptz not null default now(),
  fecha_actualizacion timestamptz not null default now()
);
alter table public.alertas_inventario
  add column if not exists envio_lote uuid,
  add column if not exists envio_reclamado_en timestamptz,
  add column if not exists envio_usuario_id uuid,
  add column if not exists envio_payload jsonb,
  add column if not exists primer_intento_en timestamptz,
  add column if not exists intentos integer not null default 0,
  add column if not exists ultimo_error text,
  add column if not exists proveedor_email_id text;
-- Conserva la historia y prefiere una alerta ya enviada al reparar duplicados.
with repetidas as (
  select id,row_number() over (partition by existencia_id
    order by (enviada_en is not null) desc,fecha_creacion,id) posicion
  from public.alertas_inventario where activa
)
update public.alertas_inventario a
set activa=false,resuelta_en=now(),fecha_actualizacion=now()
from repetidas r where r.id=a.id and r.posicion>1;
create unique index if not exists alertas_inventario_una_activa_idx
  on public.alertas_inventario(existencia_id) where activa;
create index if not exists alertas_inventario_pendientes_idx
  on public.alertas_inventario(fecha_creacion,id) where activa and enviada_en is null;
alter table public.alertas_inventario enable row level security;
revoke all on public.alertas_inventario from anon,authenticated;
grant select on public.alertas_inventario to authenticated;
grant all on public.alertas_inventario to service_role;
drop policy if exists alertas_inventario_select on public.alertas_inventario;
create policy alertas_inventario_select on public.alertas_inventario
for select to authenticated using (
  public.erp_usuario_activo() and coalesce(public.tiene_permiso('existencias.ver'),false)
  and coalesce(public.tiene_acceso_ubicacion(ubicacion_id),false)
);
-- Interno: el trigger hereda la autorización de la operación de stock.
create or replace function erp_private.actualizar_alerta_existencia(p_existencia_id uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare e public.existencias%rowtype; v_estado text; v_creadas integer:=0; v_resueltas integer:=0;
begin
  select * into e from public.existencias where id=p_existencia_id for update;
  if not found then return jsonb_build_object('creadas',0,'resueltas',0); end if;
  v_estado:=case when e.activo is distinct from true then null
    when coalesce(e.stock_disponible,0)<=0 then 'SIN_STOCK'
    when coalesce(e.stock_disponible,0)<=coalesce(e.stock_minimo,0)
      or (coalesce(e.stock_maximo,0)>0 and e.stock_disponible<=e.stock_maximo*.40) then 'STOCK_BAJO'
    else null end;
  update public.alertas_inventario set activa=false,resuelta_en=now(),fecha_actualizacion=now()
  where existencia_id=e.id and activa and (v_estado is null or estado<>v_estado);
  get diagnostics v_resueltas=row_count;
  if v_estado is not null then
    insert into public.alertas_inventario(existencia_id,producto_id,ubicacion_id,estado,
      stock_disponible,stock_minimo,stock_maximo)
    values(e.id,e.producto_id,e.ubicacion_id,v_estado,coalesce(e.stock_disponible,0),
      coalesce(e.stock_minimo,0),e.stock_maximo)
    on conflict (existencia_id) where activa do nothing;
    get diagnostics v_creadas=row_count;
    -- Una entrega iniciada conserva su cuerpo para reintentos idempotentes.
    update public.alertas_inventario set producto_id=e.producto_id,ubicacion_id=e.ubicacion_id,
      stock_disponible=coalesce(e.stock_disponible,0),stock_minimo=coalesce(e.stock_minimo,0),
      stock_maximo=e.stock_maximo,fecha_actualizacion=now()
    where existencia_id=e.id and activa;
  end if;
  return jsonb_build_object('creadas',v_creadas,'resueltas',v_resueltas);
end $$;
revoke all on function erp_private.actualizar_alerta_existencia(uuid) from public,anon,authenticated;
create or replace function public.generar_alertas_inventario()
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare e record; r jsonb; v_creadas integer:=0; v_resueltas integer:=0;
begin
  perform erp_private.require_staff('existencias.ver');
  for e in select id,ubicacion_id from public.existencias
    where auth.role()='service_role' or coalesce(public.tiene_acceso_ubicacion(ubicacion_id),false)
    order by id
  loop
    r:=erp_private.actualizar_alerta_existencia(e.id);
    v_creadas:=v_creadas+(r->>'creadas')::integer;
    v_resueltas:=v_resueltas+(r->>'resueltas')::integer;
  end loop;
  return jsonb_build_object('creadas',v_creadas,'resueltas',v_resueltas);
end $$;
revoke all on function public.generar_alertas_inventario() from public,anon;
grant execute on function public.generar_alertas_inventario() to authenticated,service_role;
create or replace function public.actualizar_alertas_despues_de_stock()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if tg_op='UPDATE' and
    (new.stock_disponible,new.stock_minimo,new.stock_maximo,new.activo,new.producto_id,new.ubicacion_id)
    is not distinct from
    (old.stock_disponible,old.stock_minimo,old.stock_maximo,old.activo,old.producto_id,old.ubicacion_id) then
    return new;
  end if;
  perform erp_private.actualizar_alerta_existencia(new.id);
  return new;
end $$;
revoke all on function public.actualizar_alertas_despues_de_stock() from public,anon,authenticated;
drop trigger if exists existencias_generar_alertas on public.existencias;
-- La base existente tenía un segundo trigger con la misma tarea de inventario.
-- Conserva los triggers downstream de notificaciones_operativas_ecommerce.
drop trigger if exists existencias_alertas_ecommerce on public.existencias;
create trigger existencias_generar_alertas
-- AFTER UPDATE also sees stock_disponible updated by a BEFORE trigger/generated column.
after insert or update on public.existencias
for each row execute function public.actualizar_alertas_despues_de_stock();
-- El cliente de usuario conserva auth.uid() y la semántica de acceso existente.
create or replace function public.erp_reclamar_alertas(p_lote uuid,p_limite integer default 20)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_ids jsonb; v_bloqueadas integer;
begin
  perform erp_private.require_staff('existencias.ver');
  if p_lote is null or p_limite is null or p_limite<1 or p_limite>100 then
    raise exception 'Lote y límite de alertas inválidos.';
  end if;
  select count(*) into v_bloqueadas from public.alertas_inventario
  where activa and enviada_en is null and primer_intento_en<=now()-interval '23 hours'
    and (auth.role()='service_role' or coalesce(public.tiene_acceso_ubicacion(ubicacion_id),false));
  with elegidas as (
    select id from public.alertas_inventario
    where activa and enviada_en is null
      and (primer_intento_en is null or primer_intento_en>now()-interval '23 hours')
      and (envio_lote is null or envio_reclamado_en<now()-interval '10 minutes')
      and (auth.role()='service_role' or coalesce(public.tiene_acceso_ubicacion(ubicacion_id),false))
    order by fecha_creacion,id for update skip locked limit p_limite
  ), reclamadas as (
    update public.alertas_inventario a set envio_lote=p_lote,envio_reclamado_en=now(),
      envio_usuario_id=auth.uid(),fecha_actualizacion=now()
    from elegidas e where a.id=e.id returning a.id
  ) select coalesce(jsonb_agg(id),'[]'::jsonb) into v_ids from reclamadas;
  return jsonb_build_object('ids',v_ids,'blocked',v_bloqueadas);
end $$;
revoke all on function public.erp_reclamar_alertas(uuid,integer) from public,anon;
grant execute on function public.erp_reclamar_alertas(uuid,integer) to authenticated,service_role;
-- Sólo el servidor configura destinatarios y cuerpo; el usuario no puede alterarlos.
create or replace function public.erp_preparar_envio_alerta(
  p_alerta_id uuid,p_lote uuid,p_remitente text,p_destinatarios text[])
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare a public.alertas_inventario%rowtype; v_producto text; v_sku text; v_ubicacion text; v_payload jsonb;
begin
  if auth.role() is distinct from 'service_role' then raise exception 'Operación exclusiva del servidor.' using errcode='42501'; end if;
  if nullif(trim(p_remitente),'') is null or coalesce(cardinality(p_destinatarios),0)=0 then raise exception 'Configuración de correo incompleta.'; end if;
  select * into a from public.alertas_inventario where id=p_alerta_id for update;
  if not found or a.envio_lote is distinct from p_lote or p_lote is null then raise exception 'La reserva de envío ya no pertenece a este proceso.'; end if;
  if not a.activa or a.enviada_en is not null then
    update public.alertas_inventario set envio_lote=null,envio_reclamado_en=null,envio_usuario_id=null where id=a.id;
    return null;
  end if;
  if a.primer_intento_en<=now()-interval '23 hours' then raise exception 'Envío antiguo requiere conciliación manual con el proveedor.'; end if;
  v_payload:=a.envio_payload;
  if v_payload is null then
    select nombre,sku into v_producto,v_sku from public.productos where id=a.producto_id;
    select nombre into v_ubicacion from public.ubicaciones where id=a.ubicacion_id;
    v_payload:=jsonb_build_object('from',p_remitente,'to',to_jsonb(p_destinatarios),
      'subject','Alerta de inventario: '||replace(a.estado,'_',' '),
      'text',format(E'Estado: %s\nProducto: %s (%s)\nUbicación: %s\nDisponible: %s\nMínimo: %s\nMáximo: %s\nReferencia: %s',
        replace(a.estado,'_',' '),coalesce(v_producto,'—'),coalesce(v_sku,''),coalesce(v_ubicacion,'—'),
        a.stock_disponible,a.stock_minimo,coalesce(a.stock_maximo::text,'Sin definir'),a.id));
  end if;
  update public.alertas_inventario set envio_payload=v_payload,primer_intento_en=coalesce(primer_intento_en,now()),
    intentos=intentos+1,ultimo_error=null,fecha_actualizacion=now() where id=a.id;
  return v_payload;
end $$;
revoke all on function public.erp_preparar_envio_alerta(uuid,uuid,text,text[]) from public,anon,authenticated;
grant execute on function public.erp_preparar_envio_alerta(uuid,uuid,text,text[]) to service_role;
create or replace function public.erp_finalizar_envio_alerta(
  p_alerta_id uuid,p_lote uuid,p_email_id text default null,p_error text default null)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_actualizadas integer;
begin
  if auth.role() is distinct from 'service_role' then raise exception 'Operación exclusiva del servidor.' using errcode='42501'; end if;
  if nullif(trim(p_email_id),'') is null and nullif(trim(p_error),'') is null then raise exception 'Falta resultado de envío.'; end if;
  update public.alertas_inventario set
    enviada_en=case when p_error is null then now() else enviada_en end,
    proveedor_email_id=case when p_error is null then p_email_id else proveedor_email_id end,
    ultimo_error=case when p_error is null then null else left(p_error,1000) end,
    envio_lote=null,envio_reclamado_en=null,envio_usuario_id=null,fecha_actualizacion=now()
  where id=p_alerta_id and envio_lote=p_lote and enviada_en is null;
  get diagnostics v_actualizadas=row_count;
  return v_actualizadas=1;
end $$;
revoke all on function public.erp_finalizar_envio_alerta(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.erp_finalizar_envio_alerta(uuid,uuid,text,text) to service_role;
notify pgrst,'reload schema';

-- Source: supabase_permisos_atomicos.sql
-- H08. Requiere migración 202610090001. Conserva permisos efectivos existentes.
create or replace function public.erp_guardar_permisos_rol(p_rol_id uuid,p_permiso_ids uuid[])
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_ids uuid[]; v_validos integer;
begin
  if auth.uid() is null or not public.erp_usuario_activo() then
    raise exception 'Se requiere un usuario activo.' using errcode='42501';
  end if;
  perform erp_private.require_staff('permisos.asignar');
  if p_rol_id is null or p_permiso_ids is null or array_position(p_permiso_ids,null) is not null then
    raise exception 'Rol y lista de permisos son obligatorios; usa [] para quitar todos.';
  end if;
  perform id from public.roles where id=p_rol_id for update;
  if not found then raise exception 'Rol no encontrado.'; end if;
  select coalesce(array_agg(distinct id),'{}'::uuid[]) into v_ids from unnest(p_permiso_ids) id;
  perform id from public.permisos where id=any(v_ids) and activo order by id for share;
  select count(*) into v_validos from public.permisos where id=any(v_ids) and activo;
  if v_validos<>cardinality(v_ids) then raise exception 'Hay permisos inexistentes o inactivos; no se guardó ningún cambio.'; end if;
  delete from public.rol_permisos where rol_id=p_rol_id and not(permiso_id=any(v_ids));
  insert into public.rol_permisos(rol_id,permiso_id)
  select p_rol_id,id from unnest(v_ids) id on conflict (rol_id,permiso_id) do nothing;
  return jsonb_build_object('rol_id',p_rol_id,'permisos',cardinality(v_ids));
end $$;
revoke all on function public.erp_guardar_permisos_rol(uuid,uuid[]) from public,anon;
grant execute on function public.erp_guardar_permisos_rol(uuid,uuid[]) to authenticated;
notify pgrst,'reload schema';

commit;
