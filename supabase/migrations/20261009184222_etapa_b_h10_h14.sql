-- Etapa B: H10-H14, catálogos/ofertas, invitaciones y recepción de compras.
-- Migración atómica sobre el estado de Etapa A.
begin;

-- H11 · configuración y comprobantes
-- Etapa B / H11. Borrador para integrar en una migración de Etapa B.
-- Los precios y pedidos actuales están denominados en GTQ; configurar USD sin
-- precios/tipos de cambio por transacción produciría comprobantes falsos.

-- El módulo de Configuración usa sus propios permisos canónicos. La lectura
-- también se concede al editor porque UPDATE/UPSERT requiere poder ver la fila.
revoke all on public.configuracion_erp from anon, authenticated;
grant select, insert, update on public.configuracion_erp to authenticated;
alter table public.configuracion_erp enable row level security;
drop policy if exists configuracion_erp_select on public.configuracion_erp;
drop policy if exists configuracion_erp_insert on public.configuracion_erp;
drop policy if exists configuracion_erp_update on public.configuracion_erp;
create policy configuracion_erp_select on public.configuracion_erp
  for select to authenticated
  using (public.tiene_permiso('configuracion.ver') or public.tiene_permiso('configuracion.editar'));
create policy configuracion_erp_insert on public.configuracion_erp
  for insert to authenticated
  with check (public.tiene_permiso('configuracion.editar'));
create policy configuracion_erp_update on public.configuracion_erp
  for update to authenticated
  using (public.tiene_permiso('configuracion.editar'))
  with check (public.tiene_permiso('configuracion.editar'));

do $$
begin
  if exists (
    select 1 from public.configuracion_erp
    where clave = 'moneda' and coalesce(valor->>'valor', '') <> 'GTQ'
  ) then
    raise exception 'La configuración de moneda debe ser GTQ antes de instalar H11.';
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.configuracion_erp'::regclass
      and conname = 'erp_configuracion_moneda_gtq'
  ) then
    alter table public.configuracion_erp
      add constraint erp_configuracion_moneda_gtq
      check (clave <> 'moneda' or coalesce(valor->>'valor', '') = 'GTQ');
  end if;
end;
$$;

create or replace function public.erp_emitir_comprobante_interno(p_pedido_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_pedido public.pedidos_ecommerce%rowtype;
  v_id uuid;
  v_config jsonb;
  v_empresa jsonb;
  v_zona_horaria text;
  v_cliente jsonb;
  v_lineas jsonb;
begin
  select * into v_pedido
  from public.pedidos_ecommerce
  where id = p_pedido_id
  for update;
  if not found or v_pedido.estado <> 'PAGADO' then
    raise exception 'Solo se emiten comprobantes para pedidos con pago confirmado.';
  end if;

  select id into v_id
  from public.facturas_ecommerce
  where pedido_id = p_pedido_id;
  if v_id is not null then
    return v_id;
  end if;

  select coalesce(jsonb_object_agg(clave, valor->>'valor'), '{}'::jsonb)
    into v_config
  from public.configuracion_erp
  where clave in (
    'empresa_nombre', 'empresa_nit', 'empresa_correo', 'empresa_telefono',
    'empresa_direccion', 'zona_horaria'
  );
  v_empresa := jsonb_build_object(
    'empresa_nombre', coalesce(nullif(btrim(v_config->>'empresa_nombre'), ''), 'San Martín'),
    'empresa_nit', coalesce(nullif(btrim(v_config->>'empresa_nit'), ''), '42299039'),
    'empresa_correo', coalesce(nullif(btrim(v_config->>'empresa_correo'), ''), 'sanmartinlibreriapapeleria@gmail.com'),
    'empresa_telefono', coalesce(nullif(btrim(v_config->>'empresa_telefono'), ''), '+502 4902-7035'),
    'empresa_direccion', coalesce(nullif(btrim(v_config->>'empresa_direccion'), ''),
      '5ta c. 7-01 col. Belén apto. A av. La Brigada z. 7, Mixco, Guatemala')
  );
  -- La pantalla de configuración sólo ofrece esta zona. Se guarda en la
  -- instantánea para que un cambio futuro no altere la hora de emisión.
  v_zona_horaria := case
    when v_config->>'zona_horaria' = 'America/Guatemala' then 'America/Guatemala'
    else 'America/Guatemala'
  end;

  select jsonb_build_object(
    'nombre', concat_ws(' ', nombre, segundo_nombre, apellido, segundo_apellido),
    'correo', correo, 'telefono', telefono,
    'direccion_completa', direccion_completa,
    'municipio', municipio, 'departamento', departamento,
    'referencia_direccion', referencia_direccion
  ) into v_cliente
  from public.perfiles
  where id = v_pedido.cliente_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'sku', p.sku, 'nombre', p.nombre, 'medida', u.abreviatura,
    'cantidad', d.cantidad, 'precio_unitario', d.precio_unitario,
    'total_linea', d.total_linea
  ) order by d.id), '[]'::jsonb)
  into v_lineas
  from public.pedidos_ecommerce_detalle d
  join public.productos p on p.id = d.producto_id
  left join public.unidades_medida u on u.id = p.unidad_medida_id
  where d.pedido_id = p_pedido_id;

  insert into public.facturas_ecommerce
    (pedido_id, ubicacion_id, fecha_emision, datos)
  values (
    p_pedido_id,
    v_pedido.ubicacion_id,
    coalesce(v_pedido.fecha_pago, now()),
    jsonb_build_object(
      'empresa', v_empresa,
      'moneda', 'GTQ',
      'zona_horaria', v_zona_horaria,
      'cliente', coalesce(v_cliente, '{}'::jsonb),
      'pedido', to_jsonb(v_pedido),
      'lineas', v_lineas
    )
  ) returning id into v_id;
  return v_id;
end;
$function$;

revoke all on function public.erp_emitir_comprobante_interno(uuid)
from public, anon, authenticated;

-- H12 · imágenes y Storage
-- Etapa B, H12: coordinar metadatos y Storage sin publicar referencias incompletas.
-- Los RPC son las únicas escrituras de producto_imagenes desde el navegador.

alter table public.producto_imagenes
  add column if not exists estado_storage text not null default 'ACTIVA';
update public.producto_imagenes set estado_storage='BORRANDO'
where activo=false and estado_storage='ACTIVA';
do $$ begin
  if not exists(select 1 from pg_constraint where conrelid='public.producto_imagenes'::regclass and conname='producto_imagenes_estado_storage_chk') then
    alter table public.producto_imagenes add constraint producto_imagenes_estado_storage_chk
      check (estado_storage in ('CARGANDO','ACTIVA','BORRANDO') and activo=(estado_storage='ACTIVA'));
  end if;
end $$;

create unique index if not exists producto_imagenes_storage_path_uniq
  on public.producto_imagenes(storage_bucket,storage_path);
create unique index if not exists producto_imagenes_principal_activa_uniq
  on public.producto_imagenes(producto_id) where activo and es_principal;

create or replace function public.erp_reservar_imagen_producto(
  p_producto_id uuid,p_storage_path text,p_nombre_archivo text,
  p_mime_type text,p_tamano_bytes bigint,p_url_publica text
) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid;
begin
  perform erp_private.require_staff('productos.editar');
  if p_producto_id is null or p_storage_path is null or p_storage_path !~
       ('^'||p_producto_id::text||'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}-[A-Za-z0-9._-]{1,180}$')
     or p_nombre_archivo is null or btrim(p_nombre_archivo)='' or length(p_nombre_archivo)>255
     or p_mime_type is null or p_mime_type not in ('image/jpeg','image/png','image/webp','image/gif','image/avif')
     or p_tamano_bytes is null or p_tamano_bytes<=0
     or p_url_publica is distinct from
       ('https://beasfybalepkdlomzazf.supabase.co/storage/v1/object/public/productos/'||p_storage_path) then
    raise exception 'Datos de imagen inválidos.' using errcode='22023';
  end if;
  perform 1 from public.productos where id=p_producto_id and activo=true for update;
  if not found then raise exception 'Producto no encontrado o inactivo.' using errcode='22023'; end if;
  insert into public.producto_imagenes(
    producto_id,storage_bucket,storage_path,url_publica,nombre_archivo,
    tipo_imagen,orden,es_principal,"tamaño_bytes",mime_type,activo,estado_storage,creado_por
  ) values (
    p_producto_id,'productos',p_storage_path,p_url_publica,p_nombre_archivo,
    'producto',coalesce((select max(orden)+1 from public.producto_imagenes where producto_id=p_producto_id and activo),0),
    false,p_tamano_bytes,p_mime_type,false,'CARGANDO',auth.uid()
  ) returning id into v_id;
  return v_id;
end $$;

create or replace function public.erp_confirmar_carga_imagen_producto(p_imagen_id uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_producto_id uuid; v_imagen public.producto_imagenes%rowtype; v_principal boolean;
begin
  perform erp_private.require_staff('productos.editar');
  select producto_id into v_producto_id from public.producto_imagenes where id=p_imagen_id;
  if v_producto_id is null then raise exception 'Imagen no encontrada.' using errcode='22023'; end if;
  perform 1 from public.productos where id=v_producto_id for update;
  select * into v_imagen from public.producto_imagenes where id=p_imagen_id for update;
  if v_imagen.estado_storage='ACTIVA' then return jsonb_build_object('id',v_imagen.id,'orden',v_imagen.orden,'es_principal',v_imagen.es_principal); end if;
  if v_imagen.estado_storage<>'CARGANDO' then raise exception 'La imagen está pendiente de borrar.' using errcode='22023'; end if;
  if not exists(select 1 from storage.objects where bucket_id='productos' and name=v_imagen.storage_path) then
    raise exception 'El archivo aún no existe en Storage.' using errcode='22023';
  end if;
  select not exists(select 1 from public.producto_imagenes where producto_id=v_producto_id and activo and es_principal) into v_principal;
  update public.producto_imagenes set
    activo=true,estado_storage='ACTIVA',
    orden=coalesce((select max(orden)+1 from public.producto_imagenes where producto_id=v_producto_id and activo),0),
    es_principal=v_principal,fecha_actualizacion=now()
  where id=p_imagen_id returning * into v_imagen;
  return jsonb_build_object('id',v_imagen.id,'orden',v_imagen.orden,'es_principal',v_imagen.es_principal);
end $$;

create or replace function public.erp_organizar_imagenes_producto(
  p_producto_id uuid,p_imagen_ids uuid[],p_principal_id uuid default null
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_count integer; v_primary uuid;
begin
  perform erp_private.require_staff('productos.editar');
  if p_producto_id is null or p_imagen_ids is null then raise exception 'Producto y orden requeridos.' using errcode='22023'; end if;
  perform 1 from public.productos where id=p_producto_id for update;
  if not found then raise exception 'Producto no encontrado.' using errcode='22023'; end if;
  select count(*) into v_count from public.producto_imagenes where producto_id=p_producto_id and activo;
  if cardinality(p_imagen_ids)<>v_count or
     (select count(distinct id) from unnest(p_imagen_ids) id)<>v_count or
     exists(select 1 from unnest(p_imagen_ids) id where id is null or not exists(
       select 1 from public.producto_imagenes i where i.id=id and i.producto_id=p_producto_id and i.activo)) then
    raise exception 'El orden debe incluir exactamente todas las imágenes activas del producto.' using errcode='22023';
  end if;
  if p_principal_id is not null and not p_principal_id=any(p_imagen_ids) then
    raise exception 'La principal debe estar en el orden.' using errcode='22023';
  end if;
  select coalesce(p_principal_id,
    (select id from public.producto_imagenes where producto_id=p_producto_id and activo and es_principal limit 1),
    p_imagen_ids[1]) into v_primary;
  update public.producto_imagenes set es_principal=false
  where producto_id=p_producto_id and activo and es_principal;
  update public.producto_imagenes i set orden=x.ordinality-1,
    es_principal=(i.id=v_primary),fecha_actualizacion=now()
  from unnest(p_imagen_ids) with ordinality as x(id,ordinality)
  where i.id=x.id and i.producto_id=p_producto_id and i.activo;
  return jsonb_build_object('producto_id',p_producto_id,'imagenes',v_count,'principal_id',v_primary);
end $$;

create or replace function public.erp_preparar_borrado_imagen_producto(p_imagen_id uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_producto_id uuid; v_imagen public.producto_imagenes%rowtype; v_next uuid;
begin
  perform erp_private.require_staff('productos.editar');
  select producto_id into v_producto_id from public.producto_imagenes where id=p_imagen_id;
  if v_producto_id is null then raise exception 'Imagen no encontrada.' using errcode='22023'; end if;
  perform 1 from public.productos where id=v_producto_id for update;
  select * into v_imagen from public.producto_imagenes where id=p_imagen_id for update;
  if v_imagen.estado_storage<>'BORRANDO' then
    update public.producto_imagenes set activo=false,es_principal=false,
      estado_storage='BORRANDO',fecha_actualizacion=now() where id=p_imagen_id;
    if v_imagen.es_principal then
      select id into v_next from public.producto_imagenes
      where producto_id=v_producto_id and activo order by orden,id limit 1;
      if v_next is not null then
        update public.producto_imagenes set es_principal=true,fecha_actualizacion=now() where id=v_next;
      end if;
    end if;
  end if;
  return jsonb_build_object('id',v_imagen.id,'producto_id',v_producto_id,
    'storage_bucket',v_imagen.storage_bucket,'storage_path',v_imagen.storage_path);
end $$;

create or replace function public.erp_confirmar_borrado_imagen_producto(p_imagen_id uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_producto_id uuid; v_imagen public.producto_imagenes%rowtype;
begin
  perform erp_private.require_staff('productos.editar');
  select producto_id into v_producto_id from public.producto_imagenes where id=p_imagen_id;
  if v_producto_id is null then return jsonb_build_object('id',p_imagen_id,'borrada',true); end if;
  perform 1 from public.productos where id=v_producto_id for update;
  select * into v_imagen from public.producto_imagenes where id=p_imagen_id for update;
  if v_imagen.estado_storage<>'BORRANDO' then raise exception 'La imagen aún no se preparó para borrar.' using errcode='22023'; end if;
  if exists(select 1 from storage.objects where bucket_id=v_imagen.storage_bucket and name=v_imagen.storage_path) then
    raise exception 'El archivo aún existe en Storage; reintente el borrado.' using errcode='22023';
  end if;
  delete from public.producto_imagenes where id=p_imagen_id;
  return jsonb_build_object('id',p_imagen_id,'borrada',true);
end $$;

revoke all on function public.erp_reservar_imagen_producto(uuid,text,text,text,bigint,text) from public,anon;
revoke all on function public.erp_confirmar_carga_imagen_producto(uuid) from public,anon;
revoke all on function public.erp_organizar_imagenes_producto(uuid,uuid[],uuid) from public,anon;
revoke all on function public.erp_preparar_borrado_imagen_producto(uuid) from public,anon;
revoke all on function public.erp_confirmar_borrado_imagen_producto(uuid) from public,anon;
grant execute on function public.erp_reservar_imagen_producto(uuid,text,text,text,bigint,text) to authenticated,service_role;
grant execute on function public.erp_confirmar_carga_imagen_producto(uuid) to authenticated,service_role;
grant execute on function public.erp_organizar_imagenes_producto(uuid,uuid[],uuid) to authenticated,service_role;
grant execute on function public.erp_preparar_borrado_imagen_producto(uuid) to authenticated,service_role;
grant execute on function public.erp_confirmar_borrado_imagen_producto(uuid) to authenticated,service_role;

-- El usuario autorizado puede leer también sus operaciones inconclusas para reintentarlas.
create policy producto_imagenes_pending_select on public.producto_imagenes
  for select to authenticated using (
    estado_storage<>'ACTIVA' and public.erp_usuario_activo()
    and public.tiene_permiso('productos.editar')
  );
revoke insert,update,delete,truncate,trigger on public.producto_imagenes from anon,authenticated;

drop policy if exists productos_storage_insert on storage.objects;
drop policy if exists productos_storage_update on storage.objects;
drop policy if exists productos_storage_delete on storage.objects;
create policy productos_storage_insert on storage.objects for insert to authenticated with check (
  bucket_id='productos' and public.erp_usuario_activo() and public.tiene_permiso('productos.editar')
  and exists(select 1 from public.producto_imagenes i where i.storage_bucket=bucket_id
    and i.storage_path=name and i.estado_storage='CARGANDO' and i.creado_por=auth.uid())
);
create policy productos_storage_select_editor on storage.objects for select to authenticated using (
  bucket_id='productos' and public.erp_usuario_activo() and public.tiene_permiso('productos.editar')
);
create policy productos_storage_delete on storage.objects for delete to authenticated using (
  bucket_id='productos' and public.erp_usuario_activo() and public.tiene_permiso('productos.editar')
  and exists(select 1 from public.producto_imagenes i where i.storage_bucket=bucket_id
    and i.storage_path=name and i.estado_storage='BORRANDO')
);


-- H13 · acceso y permisos de tabla
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

-- Recepción de compras
-- Etapa B: ciclo completo de orden y recepción parcial de compras.
-- Borrador para integrar en una migración de Etapa B, después de Etapa A.

alter table public.ordenes_compra_detalle
  add constraint erp_orden_cantidad_recibida_limite
  check (cantidad_recibida <= cantidad_solicitada);

revoke all on public.ordenes_compra, public.ordenes_compra_detalle from anon, authenticated;
grant select on public.ordenes_compra, public.ordenes_compra_detalle to authenticated;
alter table public.ordenes_compra enable row level security;
alter table public.ordenes_compra_detalle enable row level security;
drop policy if exists ordenes_compra_select on public.ordenes_compra;
drop policy if exists ordenes_compra_insert on public.ordenes_compra;
drop policy if exists ordenes_compra_update on public.ordenes_compra;
drop policy if exists ordenes_compra_detalle_select on public.ordenes_compra_detalle;
drop policy if exists ordenes_compra_detalle_insert on public.ordenes_compra_detalle;
create policy ordenes_compra_select on public.ordenes_compra
  for select to authenticated using (public.tiene_permiso('compras.ver'));
create policy ordenes_compra_detalle_select on public.ordenes_compra_detalle
  for select to authenticated using (public.tiene_permiso('compras.ver'));

-- El núcleo de inventario de Etapa A exige existencias.ajustar. La recepción
-- necesita un permiso más preciso: compras.recibir. Esta marca privada sólo
-- vive durante la transacción y la crea la RPC de recepción después de validar
-- orden, ubicación y cantidades; ningún usuario puede escribirla directamente.
create table erp_private.compra_movement_context (
  backend integer not null,
  transaction_id bigint not null,
  usuario_id uuid,
  producto_id uuid not null,
  ubicacion_id uuid not null,
  cantidad numeric not null,
  referencia_numero text not null,
  primary key (backend,transaction_id,producto_id,ubicacion_id)
);
revoke all on erp_private.compra_movement_context from public,anon,authenticated,service_role;

create function erp_private.purchase_movement_allowed(
  p_producto_id uuid,p_ubicacion_id uuid,p_cantidad numeric,
  p_tipo text,p_origen text,p_referencia_tipo text,p_referencia_numero text
)
returns boolean
language sql
security definer
set search_path = public, pg_temp
as $function$
  select auth.uid() is not null
    and public.tiene_permiso('compras.recibir')
    and public.tiene_acceso_ubicacion(p_ubicacion_id)
    and p_tipo='ENTRADA'
    and p_origen='COMPRA'
    and p_referencia_tipo='orden_compra'
    and exists (
      select 1 from erp_private.compra_movement_context c
      where c.backend=pg_backend_pid() and c.transaction_id=txid_current()
        and c.usuario_id=auth.uid() and c.producto_id=p_producto_id
        and c.ubicacion_id=p_ubicacion_id and c.cantidad=p_cantidad
        and c.referencia_numero=p_referencia_numero
    );
$function$;
revoke all on function erp_private.purchase_movement_allowed(uuid,uuid,numeric,text,text,text,text)
  from public,anon,authenticated,service_role;

-- Modifica únicamente la comprobación de permiso de la copia privada del
-- núcleo. El punto de entrada público conserva existencias.ajustar y la
-- copia privada sólo acepta compras.recibir cuando coincide la marca privada.
do $function$
declare
  v_definition text;
  v_needle constant text := 'or not public.tiene_permiso(''existencias.ajustar''::text)';
  v_replacement constant text := 'or not (public.tiene_permiso(''existencias.ajustar''::text) or erp_private.purchase_movement_allowed(p_producto_id,p_ubicacion_id,p_cantidad,p_tipo_movimiento,p_origen,p_referencia_tipo,p_referencia_numero))';
begin
  select pg_get_functiondef(p.oid) into v_definition
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='erp_private' and p.proname='registrar_movimiento_inventario';
  if v_definition is null
     or length(v_definition)-length(replace(v_definition,v_needle,''))<>length(v_needle) then
    raise exception 'La firma de permisos del núcleo estabilizado cambió; revisar antes de habilitar compras.';
  end if;
  execute replace(v_definition,v_needle,v_replacement);
end;
$function$;

create table public.recepciones_compra (
  id uuid primary key,
  orden_compra_id uuid not null references public.ordenes_compra(id),
  ubicacion_id uuid not null references public.ubicaciones(id),
  documento varchar(120) not null check (length(btrim(documento)) > 0),
  observaciones text,
  creado_por uuid default auth.uid(),
  fecha_recepcion timestamptz not null default now(),
  solicitud jsonb not null,
  resultado jsonb,
  unique (orden_compra_id, documento)
);
create table public.recepciones_compra_detalle (
  id uuid primary key default gen_random_uuid(),
  recepcion_id uuid not null references public.recepciones_compra(id),
  orden_detalle_id uuid not null references public.ordenes_compra_detalle(id),
  producto_id uuid not null references public.productos(id),
  cantidad numeric not null check (cantidad > 0 and cantidad::text not in ('NaN','Infinity','-Infinity')),
  costo_unitario numeric not null check (costo_unitario >= 0 and costo_unitario::text not in ('NaN','Infinity','-Infinity')),
  movimiento_id uuid not null references public.movimientos(id),
  unique (recepcion_id, orden_detalle_id),
  unique (movimiento_id)
);
create index recepciones_compra_orden_fecha_idx
  on public.recepciones_compra(orden_compra_id, fecha_recepcion desc);
create unique index recepciones_compra_documento_ci_idx
  on public.recepciones_compra(orden_compra_id, lower(documento));
create index recepciones_compra_detalle_orden_idx
  on public.recepciones_compra_detalle(orden_detalle_id);

alter table public.recepciones_compra enable row level security;
alter table public.recepciones_compra_detalle enable row level security;
revoke all on public.recepciones_compra, public.recepciones_compra_detalle from public, anon, authenticated;
grant select on public.recepciones_compra, public.recepciones_compra_detalle to authenticated;
create policy recepciones_compra_select on public.recepciones_compra
  for select to authenticated
  using (public.tiene_permiso('compras.ver') and public.tiene_acceso_ubicacion(ubicacion_id));
create policy recepciones_compra_detalle_select on public.recepciones_compra_detalle
  for select to authenticated
  using (exists (
    select 1 from public.recepciones_compra r
    where r.id = recepcion_id
      and public.tiene_permiso('compras.ver')
      and public.tiene_acceso_ubicacion(r.ubicacion_id)
  ));

create or replace function public.crear_orden_compra(
  p_proveedor_id uuid,
  p_fecha_esperada date,
  p_observaciones text,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_orden_id uuid;
  v_numero varchar := 'OC-' || to_char(now(),'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));
  v_item record;
  v_vistos uuid[] := '{}'::uuid[];
begin
  perform erp_private.require_staff('compras.crear', null);
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'La orden requiere una lista de productos.';
  end if;
  if jsonb_array_length(p_items) = 0 then
    raise exception 'La orden debe incluir al menos un producto.';
  end if;
  if not exists(select 1 from public.proveedores where id=p_proveedor_id and activo) then
    raise exception 'Proveedor inactivo o inexistente.';
  end if;
  if length(coalesce(p_observaciones,'')) > 2000 then
    raise exception 'Las observaciones de la orden son demasiado largas.';
  end if;

  insert into public.ordenes_compra(numero,proveedor_id,fecha_esperada,observaciones,creado_por)
  values(v_numero,p_proveedor_id,p_fecha_esperada,p_observaciones,auth.uid())
  returning id into v_orden_id;

  for v_item in
    select * from jsonb_to_recordset(p_items)
      as x(producto_id uuid,cantidad numeric,precio_estimado numeric)
  loop
    if v_item.producto_id is null or v_item.producto_id=any(v_vistos) then
      raise exception 'Cada producto debe aparecer una sola vez en la orden.';
    end if;
    if not exists(select 1 from public.productos
                  where id=v_item.producto_id and activo and es_comprable and controla_inventario) then
      raise exception 'Producto inactivo o no disponible para compras/inventario.';
    end if;
    if v_item.cantidad is null or v_item.cantidad<=0
       or v_item.cantidad::text in ('NaN','Infinity','-Infinity')
       or (v_item.precio_estimado is not null and (
         v_item.precio_estimado<0 or v_item.precio_estimado::text in ('NaN','Infinity','-Infinity'))) then
      raise exception 'Cantidad o precio estimado inválido.';
    end if;
    insert into public.ordenes_compra_detalle
      (orden_compra_id,producto_id,cantidad_solicitada,precio_estimado)
    values(v_orden_id,v_item.producto_id,v_item.cantidad,v_item.precio_estimado);
    v_vistos:=array_append(v_vistos,v_item.producto_id);
  end loop;
  return jsonb_build_object('id',v_orden_id,'numero',v_numero,'estado','BORRADOR');
end;
$function$;
revoke all on function public.crear_orden_compra(uuid,date,text,jsonb)
  from public,anon,authenticated;
grant execute on function public.crear_orden_compra(uuid,date,text,jsonb) to authenticated;

create function public.erp_confirmar_orden_compra(p_orden_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare v_orden public.ordenes_compra%rowtype;
begin
  perform erp_private.require_staff('compras.confirmar',null);
  select * into v_orden from public.ordenes_compra where id=p_orden_id for update;
  if not found then raise exception 'Orden de compra no encontrada.'; end if;
  if v_orden.estado not in ('BORRADOR','ENVIADA') then
    raise exception 'Esta orden ya no puede confirmarse.';
  end if;
  if v_orden.estado='BORRADOR' then
    update public.ordenes_compra set estado='ENVIADA' where id=p_orden_id;
  end if;
  return jsonb_build_object('id',v_orden.id,'numero',v_orden.numero,'estado','ENVIADA');
end;
$function$;
revoke all on function public.erp_confirmar_orden_compra(uuid) from public,anon,authenticated;
grant execute on function public.erp_confirmar_orden_compra(uuid) to authenticated;

create function public.erp_recibir_orden_compra(
  p_recepcion_id uuid,
  p_orden_id uuid,
  p_ubicacion_id uuid,
  p_documento varchar,
  p_observaciones text,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_orden public.ordenes_compra%rowtype;
  v_linea public.ordenes_compra_detalle%rowtype;
  v_recepcion public.recepciones_compra%rowtype;
  v_item record;
  v_existencia public.existencias%rowtype;
  v_movimiento_id uuid;
  v_stock_nuevo numeric;
  v_costo_promedio numeric;
  v_resultado jsonb;
  v_estado text;
  v_vistos uuid[] := '{}'::uuid[];
  v_solicitud jsonb;
  v_documento varchar := nullif(btrim(p_documento),'');
begin
  perform erp_private.require_staff('compras.recibir',p_ubicacion_id);
  if p_recepcion_id is null or p_orden_id is null or p_ubicacion_id is null
     or v_documento is null or length(v_documento)>120 then
    raise exception 'Orden, ubicación, identificador y documento de recepción son obligatorios.';
  end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' then
    raise exception 'La recepción requiere una lista de artículos.';
  end if;
  if jsonb_array_length(p_items)=0 then
    raise exception 'Selecciona al menos una cantidad para recibir.';
  end if;
  if length(coalesce(p_observaciones,''))>2000 then
    raise exception 'Las observaciones de la recepción son demasiado largas.';
  end if;
  if not exists(select 1 from public.ubicaciones
                where id=p_ubicacion_id and activo and permite_recepcion and permite_inventario) then
    raise exception 'Ubicación no habilitada para recepción de inventario.';
  end if;

  v_solicitud:=jsonb_build_object('orden_id',p_orden_id,'ubicacion_id',p_ubicacion_id,
    'documento',v_documento,'observaciones',p_observaciones,'items',p_items);
  select * into v_orden from public.ordenes_compra where id=p_orden_id for update;
  if not found then raise exception 'Orden de compra no encontrada.'; end if;
  select * into v_recepcion from public.recepciones_compra where id=p_recepcion_id;
  if found then
    if v_recepcion.solicitud is distinct from v_solicitud then
      raise exception 'El identificador de recepción ya se usó con otros datos.';
    end if;
    return v_recepcion.resultado;
  end if;
  if v_orden.estado not in ('ENVIADA','PARCIAL') then
    raise exception 'Solo se pueden recibir órdenes confirmadas pendientes.';
  end if;
  if exists(select 1 from public.recepciones_compra
            where orden_compra_id=p_orden_id and lower(documento)=lower(v_documento)) then
    raise exception 'Este documento ya se registró para la orden.';
  end if;

  insert into public.recepciones_compra
    (id,orden_compra_id,ubicacion_id,documento,observaciones,creado_por,solicitud)
  values(p_recepcion_id,p_orden_id,p_ubicacion_id,v_documento,p_observaciones,auth.uid(),v_solicitud);

  for v_item in
    select * from jsonb_to_recordset(p_items)
      as x(detalle_id uuid,cantidad numeric,costo_unitario numeric)
  loop
    if v_item.detalle_id is null or v_item.detalle_id=any(v_vistos)
       or v_item.cantidad is null or v_item.cantidad<=0
       or v_item.cantidad::text in ('NaN','Infinity','-Infinity')
       or v_item.costo_unitario is null or v_item.costo_unitario<0
       or v_item.costo_unitario::text in ('NaN','Infinity','-Infinity') then
      raise exception 'Detalle, cantidad o costo de recepción inválido.';
    end if;
    select * into v_linea from public.ordenes_compra_detalle
    where id=v_item.detalle_id and orden_compra_id=p_orden_id for update;
    if not found then raise exception 'El artículo no pertenece a la orden.'; end if;
    if v_linea.cantidad_recibida+v_item.cantidad>v_linea.cantidad_solicitada then
      raise exception 'La recepción excede la cantidad pendiente del producto %.',v_linea.producto_id;
    end if;
    if not exists(select 1 from public.productos
                  where id=v_linea.producto_id and activo and controla_inventario) then
      raise exception 'El producto no admite recepción de inventario.';
    end if;

    -- El mismo bloqueo por producto/ubicación serializa esta ruta con las
    -- entradas y transferencias estabilizadas en la Etapa A.
    perform pg_advisory_xact_lock(hashtextextended(
      v_linea.producto_id::text||':'||p_ubicacion_id::text,0));
    if exists(select 1 from public.existencias
              where producto_id=v_linea.producto_id and ubicacion_id=p_ubicacion_id and not activo) then
      raise exception 'La existencia de este producto está inactiva.';
    end if;
    select * into v_existencia from public.existencias
    where producto_id=v_linea.producto_id and ubicacion_id=p_ubicacion_id and activo
    for update;
    v_stock_nuevo:=coalesce(v_existencia.stock_fisico,0)+v_item.cantidad;
    v_costo_promedio:=case
      when coalesce(v_existencia.stock_fisico,0)>0 and coalesce(v_existencia.costo_promedio,0)=0
        then v_item.costo_unitario
      else (coalesce(v_existencia.stock_fisico,0)*coalesce(v_existencia.costo_promedio,0)
        +v_item.cantidad*v_item.costo_unitario)/v_stock_nuevo
    end;
    insert into erp_private.compra_movement_context
      (backend,transaction_id,usuario_id,producto_id,ubicacion_id,cantidad,referencia_numero)
    values(pg_backend_pid(),txid_current(),auth.uid(),v_linea.producto_id,
      p_ubicacion_id,v_item.cantidad,v_orden.numero||'/'||v_documento);
    v_movimiento_id:=erp_private.move(
      v_linea.producto_id,p_ubicacion_id,v_item.cantidad,
      'ENTRADA','COMPRA','orden_compra',v_orden.numero||'/'||v_documento,
      concat_ws(' · ', 'Recepción '||p_recepcion_id::text,p_observaciones),
      v_item.costo_unitario);
    delete from erp_private.compra_movement_context
    where backend=pg_backend_pid() and transaction_id=txid_current()
      and producto_id=v_linea.producto_id and ubicacion_id=p_ubicacion_id;
    update public.movimientos
      set referencia_id=p_orden_id, grupo_movimiento_id=p_recepcion_id
      where id=v_movimiento_id;
    update public.existencias set costo_promedio=v_costo_promedio
      where producto_id=v_linea.producto_id and ubicacion_id=p_ubicacion_id and activo;
    update public.productos set costo_ultimo=v_item.costo_unitario
      where id=v_linea.producto_id;
    update public.ordenes_compra_detalle
      set cantidad_recibida=cantidad_recibida+v_item.cantidad
      where id=v_linea.id;
    insert into public.recepciones_compra_detalle
      (recepcion_id,orden_detalle_id,producto_id,cantidad,costo_unitario,movimiento_id)
    values(p_recepcion_id,v_linea.id,v_linea.producto_id,v_item.cantidad,
      v_item.costo_unitario,v_movimiento_id);
    v_vistos:=array_append(v_vistos,v_item.detalle_id);
  end loop;

  v_estado:=case when exists(
    select 1 from public.ordenes_compra_detalle
    where orden_compra_id=p_orden_id and cantidad_recibida<cantidad_solicitada
  ) then 'PARCIAL' else 'RECIBIDA' end;
  update public.ordenes_compra set estado=v_estado where id=p_orden_id;
  v_resultado:=jsonb_build_object('id',p_recepcion_id,'orden_id',p_orden_id,
    'numero',v_orden.numero,'estado',v_estado,'lineas',cardinality(v_vistos));
  update public.recepciones_compra set resultado=v_resultado where id=p_recepcion_id;
  return v_resultado;
end;
$function$;
revoke all on function public.erp_recibir_orden_compra(uuid,uuid,uuid,varchar,text,jsonb)
  from public,anon,authenticated;
grant execute on function public.erp_recibir_orden_compra(uuid,uuid,uuid,varchar,text,jsonb)
  to authenticated;

commit;
