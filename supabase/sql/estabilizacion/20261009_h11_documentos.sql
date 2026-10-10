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
