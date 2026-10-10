-- H01/H05/H06/H09. Aplicar una vez, en una copia validada, antes de 002/003.
-- NO instala ni inventa el núcleo: conserva su definición en un esquema privado.
-- Checkout externo: reserva/pago requieren personal autorizado o service_role.
-- Un backend de tienda debe mantener su vinculación explícita de cliente existente.
begin;
set local lock_timeout = '10s';

do $preflight$
declare f record; c record; n integer; accepted boolean; t text; col text;
begin
  if to_regnamespace('erp_private') is not null then
    raise exception 'erp_private ya existe. No reejecutar 001: revisar versión y restauración antes de continuar.';
  end if;
  if to_regprocedure('public.tiene_permiso(text)') is null or to_regprocedure('public.tiene_acceso_ubicacion(uuid)') is null then
    raise exception 'Faltan tiene_permiso(text) / tiene_acceso_ubicacion(uuid). No se modificó el sistema.';
  end if;
  for t,col in select * from (values
    ('perfiles','id'),('perfiles','activo'),('perfiles','estado'),
    ('productos','id'),('productos','precio_base'),('productos','costo_ultimo'),('productos','controla_inventario'),
    ('existencias','id'),('existencias','producto_id'),('existencias','ubicacion_id'),('existencias','stock_fisico'),
    ('existencias','stock_reservado'),('existencias','stock_disponible'),('existencias','costo_promedio'),
    ('movimientos','id'),('movimientos','cantidad'),('movimientos','costo_unitario'),('movimientos','valor_total'),
    ('pedidos_ecommerce','id'),('pedidos_ecommerce','cliente_id'),('pedidos_ecommerce','ubicacion_id'),
    ('pedidos_ecommerce_detalle','pedido_id'),('reservas','referencia_id'),('reservas','fecha_expiracion'),
    ('ventas_pos','numero'),('ventas_pos','estado'),('devoluciones_venta','cantidad'),('ajustes_inventario','solicitado_por'),
    ('conteos_inventario','stock_contado'),('ubicaciones','permite_transferencia'),('ubicaciones','permite_recepcion'),
    ('ofertas_producto','oferta_porcentaje')) as required(table_name,column_name)
  loop
    if not exists(select 1 from information_schema.columns where table_schema='public' and table_name=t and column_name=col) then
      raise exception 'Falta public.%.%; se requiere exportar/aplicar el esquema base instalado.',t,col;
    end if;
  end loop;
  if exists(select 1 from information_schema.columns where table_schema='public' and table_name='existencias' and column_name='stock_disponible' and is_generated <> 'NEVER') then
    raise exception 'stock_disponible es generado. Adaptar las RPC al esquema instalado antes de aplicar.';
  end if;
  if not exists(select 1 from pg_index i where i.indrelid='public.existencias'::regclass and i.indisunique and i.indisvalid and i.indpred is null
    and (select array_agg(a.attname::text order by a.attname) from unnest(i.indkey::smallint[]) k join pg_attribute a on a.attrelid=i.indrelid and a.attnum=k) = array['producto_id','ubicacion_id']) then
    raise exception 'Falta índice UNIQUE válido (producto_id,ubicacion_id) en existencias.';
  end if;
  if exists(select 1 from public.existencias where stock_fisico < 0 or stock_reservado < 0 or stock_disponible < 0 or stock_disponible is distinct from stock_fisico-stock_reservado) then
    raise exception 'Existencias inconsistentes: conciliar físico-reservado-disponible antes de migrar.';
  end if;
  select count(*) into n from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where ns.nspname='public' and p.proname='registrar_movimiento_inventario';
  if n <> 1 then raise exception 'El núcleo registrar_movimiento_inventario falta o tiene sobrecargas ambiguas.'; end if;
  select p.* into f from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where ns.nspname='public' and p.proname='registrar_movimiento_inventario';
  if f.proretset or f.proargmodes is not null or f.prorettype <> 'jsonb'::regtype or f.proargnames is null then
    raise exception 'Núcleo incompatible: se requiere resultado jsonb escalar y parámetros IN con nombre.';
  end if;
  if not f.proargnames @> array['p_producto_id','p_ubicacion_id','p_cantidad','p_tipo_movimiento','p_origen','p_referencia_tipo','p_referencia_numero','p_observaciones'] then
    raise exception 'Firma del núcleo distinta a las llamadas revisadas; no se reemplazó.';
  end if;
  for n in 1..f.pronargs-f.pronargdefaults loop
    if not f.proargnames[n]=any(array['p_producto_id','p_ubicacion_id','p_cantidad','p_tipo_movimiento','p_origen','p_referencia_tipo','p_referencia_numero','p_observaciones']) then
      raise exception 'El núcleo requiere un argumento adicional: %',f.proargnames[n];
    end if;
  end loop;
  if f.prosrc ~* '\mregistrar_movimiento_inventario\s*\(' then raise exception 'Núcleo recursivo: revisar su delegación antes de migrar.'; end if;
  select * into c from pg_constraint where conrelid='public.movimientos'::regclass and conname='movimientos_cantidad_chk' and contype='c' and convalidated;
  if not found then raise exception 'Falta CHECK validado movimientos_cantidad_chk; revisar convención de cantidad.'; end if;
  execute format('select coalesce((%s),true) from (select (jsonb_populate_record(null::public.movimientos,$1)).*) probe',pg_get_expr(c.conbin,c.conrelid)) into accepted
    using '{"cantidad":1,"tipo_movimiento":"SALIDA","origen":"ECOMMERCE"}'::jsonb;
  if not accepted then raise exception 'La restricción instalada rechaza SALIDA positiva. Revisar el parche de pago existente.'; end if;
  if to_regprocedure('public.registrar_venta_pos(uuid,jsonb,character varying,text)') is not null then
    select prosrc into t from pg_proc where oid='public.registrar_venta_pos(uuid,jsonb,character varying,text)'::regprocedure;
    if t !~* 'perform\s+(public\.)?registrar_movimiento_inventario\s*\(' or t !~* '\mbegin\M' then
      raise exception 'POS instalado cambió: revisar su llamada al núcleo antes de migrar.';
    end if;
  end if;
  if exists(select 1 from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where ns.nspname='public' and p.proname='transferir_inventario'
    and p.oid not in(coalesce(to_regprocedure('public.transferir_inventario(uuid,uuid,uuid,numeric,character varying,text)'),0),coalesce(to_regprocedure('public.transferir_inventario(uuid,uuid,uuid,numeric,numeric,character varying,uuid,character varying,text)'),0))) then
    raise exception 'Transferencia tiene una firma adicional no revisada';
  end if;
end $preflight$;

create schema erp_private;
revoke all on schema erp_private from public,anon,authenticated;
create table erp_private.installation(version text primary key, installed_at timestamptz not null default now());
insert into erp_private.installation values('202610090001',now());
create table erp_private.movement_context(
  id uuid primary key default gen_random_uuid(), backend integer not null, transaction_id bigint not null,
  producto_id uuid not null, ubicacion_id uuid not null, costo numeric,
  movimiento_id uuid, inserted integer not null default 0,
  unique(backend,transaction_id,producto_id,ubicacion_id)
);

create or replace function public.erp_usuario_activo()
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
  select auth.uid() is not null and exists(select 1 from public.perfiles where id=auth.uid() and activo=true and estado='ACTIVO');
$$;
revoke all on function public.erp_usuario_activo() from public,anon;
grant execute on function public.erp_usuario_activo() to authenticated,service_role;

create function erp_private.require_staff(p_permission text,p_location uuid default null)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if auth.role()='service_role' then return; end if;
  if not public.erp_usuario_activo() or not coalesce(public.tiene_permiso(p_permission),false)
    or (p_location is not null and not coalesce(public.tiene_acceso_ubicacion(p_location),false)) then
    raise exception 'Sesión activa, permiso % y acceso a ubicación requeridos.',p_permission using errcode='42501';
  end if;
end $$;

-- Copia exacta del núcleo, con firma/defaults/retorno originales. El cuerpo no se inventa.
do $clone$
declare f record; definition text; arguments text;
begin
  select p.* into f from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='registrar_movimiento_inventario';
  definition:=replace(pg_get_functiondef(f.oid),'FUNCTION public.registrar_movimiento_inventario(','FUNCTION erp_private.registrar_movimiento_inventario(');
  if definition=pg_get_functiondef(f.oid) then raise exception 'No se reconoció la definición del núcleo.'; end if;
  execute definition;
  execute format('revoke all on function erp_private.registrar_movimiento_inventario(%s) from public,anon,authenticated,service_role',pg_get_function_identity_arguments(f.oid));
  select string_agg(format('%I=>%I',a,a),',') into arguments from unnest(f.proargnames) a;
  execute format($wrapper$
    create or replace function public.registrar_movimiento_inventario(%s) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $body$
    begin
      perform erp_private.require_staff('existencias.ajustar',p_ubicacion_id);
      if p_origen is distinct from 'COMPRA' or p_tipo_movimiento is distinct from 'ENTRADA' or p_cantidad is null or p_cantidad<=0 or p_cantidad::text in('NaN','Infinity','-Infinity') then
        raise exception 'Usa la RPC específica de ajustes, conteos, devolución, POS o transferencia; solo COMPRA/ENTRADA directa.' using errcode='42501';
      end if;
      if not exists(select 1 from public.ubicaciones where id=p_ubicacion_id and activo and permite_recepcion) then raise exception 'Ubicación no habilitada para recepción'; end if;
      return erp_private.registrar_movimiento_inventario(%s);
    end $body$;
  $wrapper$,pg_get_function_arguments(f.oid),arguments);
  execute format('revoke all on function public.registrar_movimiento_inventario(%s) from public,anon',pg_get_function_identity_arguments(f.oid));
  execute format('grant execute on function public.registrar_movimiento_inventario(%s) to authenticated,service_role',pg_get_function_identity_arguments(f.oid));
end $clone$;

-- Contexto privado, imposible de fijar mediante un GUC/JSON del llamante.
-- Captura un ID exacto y completa el costo ANTES de insertar, sin UPDATE histórico.
create function erp_private.capture_movement()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare ctx erp_private.movement_context%rowtype;
begin
  -- El argumento del núcleo es delta firmado; el almacenamiento instalado exige magnitud positiva.
  new.cantidad:=abs(new.cantidad);
  if new.tipo_movimiento='AJUSTE' then
    new.tipo_movimiento:=case when new.stock_posterior>=new.stock_anterior then 'AJUSTE_POSITIVO' else 'AJUSTE_NEGATIVO' end;
  end if;
  if new.origen in('AJUSTE_AUTORIZADO','CONTEO_FISICO','DEVOLUCION_POS','DEVOLUCION_ECOMMERCE') then
    new.observaciones:='Origen operativo: '||new.origen||coalesce(' | '||new.observaciones,'');
    new.origen:=case new.origen when 'AJUSTE_AUTORIZADO' then 'AJUSTE' when 'CONTEO_FISICO' then 'CONTEO' else 'DEVOLUCION' end;
  end if;
  select * into ctx from erp_private.movement_context where backend=pg_backend_pid() and transaction_id=txid_current()
    and producto_id=new.producto_id and ubicacion_id=new.ubicacion_id for update;
  if found then
    if ctx.costo is not null then new.costo_unitario:=ctx.costo;new.valor_total:=abs(new.cantidad)*ctx.costo; end if;
    update erp_private.movement_context set movimiento_id=new.id,inserted=inserted+1 where id=ctx.id;
  end if;
  return new;
end $$;
create trigger erp_00_capture_movement before insert on public.movimientos for each row execute function erp_private.capture_movement();

create function erp_private.move(p_producto uuid,p_ubicacion uuid,p_cantidad numeric,p_tipo varchar,p_origen varchar,p_referencia_tipo varchar,p_referencia varchar,p_observaciones text,p_costo numeric default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare ctx uuid; result erp_private.movement_context%rowtype;
begin
  insert into erp_private.movement_context(backend,transaction_id,producto_id,ubicacion_id,costo)
    values(pg_backend_pid(),txid_current(),p_producto,p_ubicacion,p_costo) returning id into ctx;
  perform erp_private.registrar_movimiento_inventario(p_producto_id=>p_producto,p_ubicacion_id=>p_ubicacion,p_cantidad=>p_cantidad,
    p_tipo_movimiento=>p_tipo,p_origen=>p_origen,p_referencia_tipo=>p_referencia_tipo,p_referencia_numero=>p_referencia,p_observaciones=>p_observaciones);
  select * into result from erp_private.movement_context where id=ctx;
  if result.inserted <> 1 or result.movimiento_id is null then raise exception 'El núcleo no produjo exactamente un movimiento; operación revertida.'; end if;
  if p_costo is not null and not exists(select 1 from public.movimientos where id=result.movimiento_id and costo_unitario=p_costo and valor_total=abs(cantidad)*p_costo) then
    raise exception 'Otro trigger alteró el costo esperado; operación revertida.';
  end if;
  delete from erp_private.movement_context where id=ctx;
  return result.movimiento_id;
end $$;

create or replace function public.registrar_entrada_con_costo(p_producto_id uuid,p_ubicacion_id uuid,p_cantidad numeric,p_costo_unitario numeric,p_origen varchar,p_referencia_numero varchar default null,p_observaciones text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare e public.existencias%rowtype; nuevo numeric; promedio numeric; m uuid; referencia varchar:=coalesce(p_referencia_numero,'COSTO-'||gen_random_uuid());
begin
  perform erp_private.require_staff('existencias.ajustar',p_ubicacion_id);
  if p_origen is distinct from 'COMPRA' then raise exception 'La entrada con costo recibe COMPRA; usa la RPC específica para devoluciones/ajustes.'; end if;
  if p_cantidad is null or p_cantidad<=0 or p_cantidad::text in('NaN','Infinity','-Infinity') or p_costo_unitario is null or p_costo_unitario<0 or p_costo_unitario::text in('NaN','Infinity','-Infinity') then raise exception 'Cantidad/costo inválidos'; end if;
  if not exists(select 1 from public.ubicaciones where id=p_ubicacion_id and activo and permite_recepcion) then raise exception 'Ubicación no habilitada para recepción'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_producto_id::text||':'||p_ubicacion_id::text,0));
  select * into e from public.existencias where producto_id=p_producto_id and ubicacion_id=p_ubicacion_id and activo for update;
  nuevo:=coalesce(e.stock_fisico,0)+p_cantidad;
  -- Conserva el tratamiento histórico existente del inventario sin costo inicial.
  promedio:=case when coalesce(e.stock_fisico,0)>0 and coalesce(e.costo_promedio,0)=0 then p_costo_unitario
    else (coalesce(e.stock_fisico,0)*coalesce(e.costo_promedio,0)+p_cantidad*p_costo_unitario)/nuevo end;
  m:=erp_private.move(p_producto_id,p_ubicacion_id,p_cantidad,'ENTRADA','COMPRA','entrada_compra',referencia,p_observaciones,p_costo_unitario);
  update public.existencias set costo_promedio=promedio where producto_id=p_producto_id and ubicacion_id=p_ubicacion_id and activo;
  update public.productos set costo_ultimo=p_costo_unitario where id=p_producto_id;
  return jsonb_build_object('stock_anterior',coalesce(e.stock_fisico,0),'stock_nuevo',nuevo,'costo_promedio',promedio,'referencia_numero',referencia,'movimiento_id',m);
end $$;

create or replace function public.transferir_inventario(p_producto_id uuid,p_ubicacion_origen_id uuid,p_ubicacion_destino_id uuid,p_cantidad numeric,p_referencia_numero varchar default null,p_observaciones text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare origen public.existencias%rowtype; destino public.existencias%rowtype; promedio numeric; referencia varchar:=coalesce(p_referencia_numero,'TRF-'||gen_random_uuid()); loc uuid; salida uuid; entrada uuid;
begin
  perform erp_private.require_staff('existencias.ajustar',p_ubicacion_origen_id);
  perform erp_private.require_staff('existencias.ajustar',p_ubicacion_destino_id);
  if p_ubicacion_origen_id is null or p_ubicacion_destino_id is null or p_ubicacion_origen_id=p_ubicacion_destino_id or p_cantidad is null or p_cantidad<=0 or p_cantidad::text in('NaN','Infinity','-Infinity') then raise exception 'Transferencia inválida'; end if;
  if (select count(*) from public.ubicaciones where id in(p_ubicacion_origen_id,p_ubicacion_destino_id) and activo and permite_transferencia)<>2 then raise exception 'Ubicaciones no habilitadas para transferencia'; end if;
  for loc in select unnest(array[p_ubicacion_origen_id,p_ubicacion_destino_id]) order by 1 loop
    perform pg_advisory_xact_lock(hashtextextended(p_producto_id::text||':'||loc::text,0));
    perform id from public.existencias where producto_id=p_producto_id and ubicacion_id=loc for update;
  end loop;
  select * into origen from public.existencias where producto_id=p_producto_id and ubicacion_id=p_ubicacion_origen_id and activo;
  if not found or origen.stock_disponible<p_cantidad then raise exception 'Stock disponible insuficiente en origen'; end if;
  select * into destino from public.existencias where producto_id=p_producto_id and ubicacion_id=p_ubicacion_destino_id and activo;
  promedio:=(coalesce(destino.stock_fisico,0)*coalesce(destino.costo_promedio,0)+p_cantidad*origen.costo_promedio)/(coalesce(destino.stock_fisico,0)+p_cantidad);
  salida:=erp_private.move(p_producto_id,p_ubicacion_origen_id,-p_cantidad,'SALIDA','TRANSFERENCIA','transferencia',referencia,p_observaciones,origen.costo_promedio);
  entrada:=erp_private.move(p_producto_id,p_ubicacion_destino_id,p_cantidad,'ENTRADA','TRANSFERENCIA','transferencia',referencia,p_observaciones,origen.costo_promedio);
  update public.existencias set costo_promedio=promedio where producto_id=p_producto_id and ubicacion_id=p_ubicacion_destino_id and activo;
  return jsonb_build_object('referencia_numero',referencia,'estado','COMPLETADA','salida_id',salida,'entrada_id',entrada);
end $$;

-- Contrato legado: conserva UUID/grupo y parámetros, determina costo desde origen.
-- Requiere los permisos existentes de ambos contratos; no usa columnas obsoletas.
create or replace function public.transferir_inventario(p_producto_id uuid,p_ubicacion_origen_id uuid,p_ubicacion_destino_id uuid,p_cantidad numeric,p_costo_unitario numeric default null,p_referencia_tipo varchar default 'TRANSFERENCIA',p_referencia_id uuid default null,p_referencia_numero varchar default null,p_observaciones text default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare grupo uuid:=gen_random_uuid(); resultado jsonb;
begin
  if auth.uid() is null then raise exception 'El contrato legado requiere identidad de personal'; end if;
  perform erp_private.require_staff('transferencias.crear',p_ubicacion_origen_id);
  perform erp_private.require_staff('transferencias.crear',p_ubicacion_destino_id);
  if p_costo_unitario is not null and (p_costo_unitario<0 or p_costo_unitario::text in('NaN','Infinity','-Infinity')) then raise exception 'Costo inválido'; end if;
  resultado:=public.transferir_inventario(p_producto_id,p_ubicacion_origen_id,p_ubicacion_destino_id,p_cantidad,coalesce(p_referencia_numero,('TRF-'||grupo)::varchar),p_observaciones);
  update public.movimientos set grupo_movimiento_id=grupo,referencia_id=p_referencia_id,referencia_tipo=p_referencia_tipo
    where id in((resultado->>'salida_id')::uuid,(resultado->>'entrada_id')::uuid);
  return grupo;
end $$;

-- Nombre sin sobrecargas para PostgREST y el ERP actual. Ambos contratos antiguos permanecen.
create function public.erp_transferir_inventario(p_producto_id uuid,p_ubicacion_origen_id uuid,p_ubicacion_destino_id uuid,p_cantidad numeric,p_referencia_numero varchar default null,p_observaciones text default null)
returns jsonb language sql security definer set search_path=public,pg_temp as $$
  select public.transferir_inventario(p_producto_id,p_ubicacion_origen_id,p_ubicacion_destino_id,p_cantidad,p_referencia_numero,p_observaciones);
$$;

create or replace function public.registrar_devolucion_venta(p_canal varchar,p_referencia_venta varchar,p_producto_id uuid,p_ubicacion_id uuid,p_cantidad numeric,p_motivo varchar,p_observaciones text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare vendido numeric; devuelto numeric; referencia varchar:='DEV-'||gen_random_uuid(); costo numeric; e public.existencias%rowtype; m uuid;
begin
  perform erp_private.require_staff('existencias.ajustar',p_ubicacion_id);
  if p_canal is null or p_canal not in('POS','ECOMMERCE') or p_cantidad is null or p_cantidad<=0 or p_cantidad::text in('NaN','Infinity','-Infinity') or nullif(trim(p_motivo),'') is null then raise exception 'Devolución inválida'; end if;
  -- El bloqueo precede al SUM: cada devolución de una venta se serializa.
  if p_canal='POS' then
    perform id from public.ventas_pos where numero=p_referencia_venta and ubicacion_id=p_ubicacion_id and estado='COMPLETADA' for update;
  else
    perform id from public.pedidos_ecommerce where numero=p_referencia_venta and ubicacion_id=p_ubicacion_id and estado='PAGADO' for update;
  end if;
  if not found then raise exception 'Venta original válida no encontrada'; end if;
  select coalesce(sum(abs(cantidad)),0),coalesce(sum(abs(cantidad)*coalesce(costo_unitario,0))/nullif(sum(abs(cantidad)),0),0)
    into vendido,costo from public.movimientos where origen=p_canal and tipo_movimiento='SALIDA' and referencia_numero=p_referencia_venta and producto_id=p_producto_id and ubicacion_id=p_ubicacion_id;
  select coalesce(sum(cantidad),0) into devuelto from public.devoluciones_venta where canal=p_canal and referencia_venta=p_referencia_venta and producto_id=p_producto_id and ubicacion_id=p_ubicacion_id;
  if vendido<=0 or devuelto+p_cantidad>vendido then raise exception 'La devolución supera la cantidad pendiente (%).',vendido-devuelto; end if;
  select * into e from public.existencias where producto_id=p_producto_id and ubicacion_id=p_ubicacion_id and activo for update;
  if not found then raise exception 'Existencia activa no encontrada'; end if;
  m:=erp_private.move(p_producto_id,p_ubicacion_id,p_cantidad,'ENTRADA',case when p_canal='POS' then 'DEVOLUCION_POS' else 'DEVOLUCION_ECOMMERCE' end,'devolucion_venta',referencia,'Venta original: '||p_referencia_venta||' | '||p_motivo||coalesce(' | '||p_observaciones,''),costo);
  update public.existencias set costo_promedio=(e.stock_fisico*e.costo_promedio+p_cantidad*costo)/(e.stock_fisico+p_cantidad) where id=e.id;
  insert into public.devoluciones_venta(canal,referencia_venta,producto_id,ubicacion_id,cantidad,motivo,observaciones,usuario_id)
    values(p_canal,p_referencia_venta,p_producto_id,p_ubicacion_id,p_cantidad,p_motivo,p_observaciones,auth.uid());
  return jsonb_build_object('referencia_devolucion',referencia,'cantidad_devuelta',p_cantidad,'pendiente_por_devolver',vendido-devuelto-p_cantidad,'movimiento_id',m);
end $$;

create or replace function public.solicitar_ajuste_inventario(p_producto_id uuid,p_ubicacion_id uuid,p_tipo varchar,p_cantidad numeric,p_motivo varchar,p_observaciones text default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare result uuid;
begin
  perform erp_private.require_staff('existencias.ajustar',p_ubicacion_id);
  if auth.uid() is null then raise exception 'La solicitud requiere identidad de usuario'; end if;
  if p_tipo is null or p_tipo not in('ENTRADA','SALIDA') or p_cantidad is null or p_cantidad<=0 or p_cantidad::text in('NaN','Infinity','-Infinity') or nullif(trim(p_motivo),'') is null then raise exception 'Solicitud inválida'; end if;
  insert into public.ajustes_inventario(producto_id,ubicacion_id,tipo,cantidad,motivo,observaciones,solicitado_por,estado)
    values(p_producto_id,p_ubicacion_id,p_tipo,p_cantidad,p_motivo,p_observaciones,auth.uid(),'PENDIENTE') returning id into result;
  return result;
end $$;
create or replace function public.autorizar_ajuste_inventario(p_ajuste_id uuid,p_aprobar boolean,p_comentario text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare a public.ajustes_inventario%rowtype; referencia varchar;
begin
  select * into a from public.ajustes_inventario where id=p_ajuste_id for update;
  if not found then raise exception 'Solicitud no encontrada'; end if;
  perform erp_private.require_staff('existencias.ajustar',a.ubicacion_id);
  if auth.uid() is null or auth.uid()=a.solicitado_por then raise exception 'Debe autorizar otro usuario identificado'; end if;
  if a.estado<>'PENDIENTE' or p_aprobar is null then raise exception 'Estado o decisión inválidos'; end if;
  referencia:='AJU-'||replace(a.id::text,'-','');
  if p_aprobar then perform erp_private.move(a.producto_id,a.ubicacion_id,case when a.tipo='SALIDA' then -a.cantidad else a.cantidad end,'AJUSTE','AJUSTE_AUTORIZADO','ajuste_inventario',referencia,coalesce(a.observaciones,'')||coalesce(' | Autorización: '||p_comentario,'')); end if;
  update public.ajustes_inventario set estado=case when p_aprobar then 'APROBADO' else 'RECHAZADO' end,autorizado_por=auth.uid(),fecha_autorizacion=now(),comentario_autorizacion=p_comentario where id=a.id;
  return jsonb_build_object('estado',case when p_aprobar then 'APROBADO' else 'RECHAZADO' end,'referencia_numero',referencia);
end $$;
drop policy if exists ajustes_inventario_insert on public.ajustes_inventario;
drop policy if exists ajustes_inventario_update on public.ajustes_inventario;
revoke insert,update,delete on public.ajustes_inventario,public.devoluciones_venta,public.conteos_inventario,public.existencias,public.movimientos from anon,authenticated;

create or replace function public.registrar_conteo_inventario(p_producto_id uuid,p_ubicacion_id uuid,p_stock_contado numeric,p_observaciones text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare e public.existencias%rowtype; diferencia numeric; referencia varchar:='CONTEO-'||gen_random_uuid();
begin
  perform erp_private.require_staff('existencias.ajustar',p_ubicacion_id);
  if p_stock_contado is null or p_stock_contado<0 or p_stock_contado::text in('NaN','Infinity','-Infinity') then raise exception 'Conteo inválido'; end if;
  select * into e from public.existencias where producto_id=p_producto_id and ubicacion_id=p_ubicacion_id and activo for update;
  if not found then raise exception 'Existencia activa no encontrada'; end if;
  diferencia:=p_stock_contado-e.stock_fisico;
  if diferencia<>0 then perform erp_private.move(p_producto_id,p_ubicacion_id,diferencia,'AJUSTE','CONTEO_FISICO','conteo_inventario',referencia,p_observaciones); end if;
  update public.existencias set fecha_ultimo_conteo=now() where id=e.id;
  insert into public.conteos_inventario(producto_id,ubicacion_id,stock_sistema,stock_contado,diferencia,observaciones,usuario_id) values(p_producto_id,p_ubicacion_id,e.stock_fisico,p_stock_contado,diferencia,p_observaciones,auth.uid());
  return jsonb_build_object('referencia_numero',referencia,'stock_sistema',e.stock_fisico,'stock_contado',p_stock_contado,'diferencia',diferencia);
end $$;

-- POS conserva su cuerpo/precios originales; solo añade control y delegación privada.
do $pos$
declare f oid; source text; definition text;
begin
  f:=to_regprocedure('public.registrar_venta_pos(uuid,jsonb,character varying,text)');
  if f is not null then
    select prosrc into source from pg_proc where oid=f;
    source:=regexp_replace(source,'\mbegin\M','begin'||E'\n  perform erp_private.require_staff(''pos.vender'',p_ubicacion_id);','i');
    source:=regexp_replace(source,'perform\s+(public\.)?registrar_movimiento_inventario\s*\(','perform erp_private.registrar_movimiento_inventario(','gi');
    definition:=replace(pg_get_functiondef(f),(select prosrc from pg_proc where oid=f),source);
    execute definition;
  end if;
end $pos$;

create or replace function public.reservar_stock_ecommerce(p_ubicacion_id uuid,p_items jsonb,p_numero varchar default null,p_observaciones text default null,p_minutos_expiracion integer default 30)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare pedido uuid; numero varchar:=coalesce(p_numero,'WEB-'||gen_random_uuid()); item record; p public.productos%rowtype; e public.existencias%rowtype; precio numeric; v_total numeric:=0; porcentaje numeric;
begin
  perform erp_private.require_staff('productos.editar',p_ubicacion_id);
  if not exists(select 1 from public.ubicaciones where id=p_ubicacion_id and activo and permite_venta) then raise exception 'Ubicación no habilitada para venta'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Pedido sin artículos'; end if;
  if p_minutos_expiracion is null or p_minutos_expiracion<1 then raise exception 'Expiración inválida'; end if;
  insert into public.pedidos_ecommerce(numero,ubicacion_id,observaciones) values(numero,p_ubicacion_id,p_observaciones) returning id into pedido;
  -- Consolidar productos evita bloqueos en órdenes distintos y reservas duplicadas.
  for item in select producto_id,sum(cantidad) cantidad from jsonb_to_recordset(p_items) x(producto_id uuid,cantidad numeric) group by producto_id order by producto_id loop
    if item.producto_id is null or item.cantidad is null or item.cantidad<=0 or item.cantidad::text in('NaN','Infinity','-Infinity')
      or exists(select 1 from jsonb_to_recordset(p_items) x(producto_id uuid,cantidad numeric) where x.producto_id=item.producto_id and (cantidad is null or cantidad<=0 or cantidad::text in('NaN','Infinity','-Infinity'))) then raise exception 'Cantidad inválida'; end if;
    select * into p from public.productos where id=item.producto_id and activo and publicado_ecommerce and visible_ecommerce and es_vendible and not descontinuado for update;
    if not found or p.precio_base is null or p.precio_base<0 or p.precio_base::text in('NaN','Infinity','-Infinity') then raise exception 'Producto/precio no disponible'; end if;
    if not p.controla_inventario then raise exception 'Esta RPC requiere producto inventariable; revisar checkout para servicios'; end if;
    select * into e from public.existencias where producto_id=item.producto_id and ubicacion_id=p_ubicacion_id and activo for update;
    if not found or e.stock_disponible<item.cantidad then raise exception 'Stock insuficiente'; end if;
    -- Misma política que crear_pedido_ecommerce instalado: mayor descuento vigente, precio a 2 decimales.
    select max(oferta_porcentaje) into porcentaje from public.ofertas_producto where producto_id=p.id and activo and aplica_ecommerce and fecha_inicio<=now() and (fecha_fin is null or fecha_fin>=now());
    if porcentaje is not null and (porcentaje<0 or porcentaje>100 or porcentaje::text in('NaN','Infinity','-Infinity')) then raise exception 'Oferta inválida'; end if;
    precio:=round(p.precio_base*(1-coalesce(porcentaje,0)/100),2);
    update public.existencias set stock_reservado=stock_reservado+item.cantidad,stock_disponible=stock_disponible-item.cantidad where id=e.id;
    insert into public.reservas(producto_id,ubicacion_id,cantidad,estado,origen,referencia_tipo,referencia_id,referencia_numero,fecha_reserva,fecha_expiracion)
      values(p.id,p_ubicacion_id,item.cantidad,'ACTIVA','ECOMMERCE','pedido_ecommerce',pedido,numero,now(),now()+make_interval(mins=>p_minutos_expiracion));
    insert into public.pedidos_ecommerce_detalle(pedido_id,producto_id,cantidad,precio_unitario,total_linea) values(pedido,p.id,item.cantidad,precio,round(item.cantidad*precio,2));
    v_total:=v_total+round(item.cantidad*precio,2);
  end loop;
  update public.pedidos_ecommerce set total=v_total where id=pedido;
  return jsonb_build_object('id',pedido,'numero',numero,'estado','RESERVADO','total',v_total);
end $$;

create or replace function public.confirmar_pago_ecommerce(p_pedido_id uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare pedido public.pedidos_ecommerce%rowtype; reserva public.reservas%rowtype; e public.existencias%rowtype;
begin
  select * into pedido from public.pedidos_ecommerce where id=p_pedido_id for update;
  if not found then raise exception 'Pedido no encontrado'; end if;
  perform erp_private.require_staff('productos.editar',pedido.ubicacion_id);
  if pedido.estado='PAGADO' then return jsonb_build_object('id',pedido.id,'numero',pedido.numero,'estado','PAGADO'); end if;
  if pedido.estado<>'RESERVADO' then raise exception 'Pedido no reservado'; end if;
  perform id from public.reservas where referencia_id=p_pedido_id order by producto_id,id for update;
  if not exists(select 1 from public.pedidos_ecommerce_detalle where pedido_id=p_pedido_id) or not exists(select 1 from public.reservas where referencia_id=p_pedido_id) then raise exception 'Pedido sin detalle/reservas'; end if;
  if exists(select 1 from public.reservas where referencia_id=p_pedido_id and (estado<>'ACTIVA' or origen<>'ECOMMERCE' or lower(referencia_tipo) is distinct from 'pedido_ecommerce' or ubicacion_id<>pedido.ubicacion_id or (fecha_expiracion is not null and fecha_expiracion<=now()))) then raise exception 'Reserva vencida o incompatible'; end if;
  if exists(with d as(select producto_id,sum(cantidad) cantidad from public.pedidos_ecommerce_detalle where pedido_id=p_pedido_id group by producto_id),r as(select producto_id,sum(cantidad) cantidad from public.reservas where referencia_id=p_pedido_id and estado='ACTIVA' group by producto_id) select 1 from d full join r using(producto_id) where d.cantidad is distinct from r.cantidad) then raise exception 'Detalle y reservas no coinciden'; end if;
  for reserva in select * from public.reservas where referencia_id=p_pedido_id and estado='ACTIVA' order by producto_id,id loop
    select * into e from public.existencias where producto_id=reserva.producto_id and ubicacion_id=reserva.ubicacion_id and activo for update;
    if not found or e.stock_fisico<reserva.cantidad or e.stock_reservado<reserva.cantidad then raise exception 'Stock físico/reservado insuficiente'; end if;
    update public.existencias set stock_fisico=stock_fisico-reserva.cantidad,stock_reservado=stock_reservado-reserva.cantidad,fecha_ultimo_movimiento=now() where id=e.id;
    -- Convención positiva existente: no revertir corregir_pago_ecommerce_cantidad.sql.
    insert into public.movimientos(producto_id,ubicacion_id,tipo_movimiento,cantidad,stock_anterior,stock_posterior,costo_unitario,valor_total,origen,referencia_tipo,referencia_id,referencia_numero,grupo_movimiento_id,observaciones,usuario_id,fecha_movimiento)
      values(reserva.producto_id,reserva.ubicacion_id,'SALIDA',reserva.cantidad,e.stock_fisico,e.stock_fisico-reserva.cantidad,e.costo_promedio,reserva.cantidad*e.costo_promedio,'ECOMMERCE','pedido_ecommerce',pedido.id,pedido.numero,pedido.id,'Pago confirmado',auth.uid(),now());
    update public.reservas set estado='CONSUMIDA',fecha_consumo=now() where id=reserva.id;
  end loop;
  update public.pedidos_ecommerce set estado='PAGADO',fecha_pago=now() where id=pedido.id;
  return jsonb_build_object('id',pedido.id,'numero',pedido.numero,'estado','PAGADO');
end $$;

create or replace function public.cancelar_pedido_ecommerce(p_pedido_id uuid,p_motivo text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare pedido public.pedidos_ecommerce%rowtype; reserva public.reservas%rowtype;
begin
  select * into pedido from public.pedidos_ecommerce where id=p_pedido_id for update;
  if not found then raise exception 'Pedido no encontrado'; end if;
  if coalesce(auth.role(),'')<>'service_role' and not coalesce(public.erp_usuario_activo() and pedido.cliente_id=auth.uid(),false) then perform erp_private.require_staff('productos.editar',pedido.ubicacion_id); end if;
  if pedido.estado='CANCELADO' then return jsonb_build_object('id',pedido.id,'numero',pedido.numero,'estado','CANCELADO'); end if;
  if pedido.estado<>'RESERVADO' then raise exception 'Un pedido pagado requiere devolución/reembolso'; end if;
  for reserva in select * from public.reservas where referencia_id=pedido.id and estado='ACTIVA' order by producto_id,id for update loop
    update public.existencias set stock_reservado=stock_reservado-reserva.cantidad,stock_disponible=stock_disponible+reserva.cantidad where producto_id=reserva.producto_id and ubicacion_id=reserva.ubicacion_id;
    if not found then raise exception 'Existencia vinculada no encontrada'; end if;
    update public.reservas set estado='LIBERADA',fecha_liberacion=now() where id=reserva.id;
  end loop;
  update public.pedidos_ecommerce set estado='CANCELADO',fecha_cancelacion=now(),observaciones=coalesce(observaciones,'')||coalesce(' | Cancelación: '||p_motivo,'') where id=pedido.id;
  return jsonb_build_object('id',pedido.id,'numero',pedido.numero,'estado','CANCELADO');
end $$;

create or replace function public.liberar_reservas_expiradas()
returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare pedido public.pedidos_ecommerce%rowtype; reserva public.reservas%rowtype; total integer:=0;
begin
  perform erp_private.require_staff('productos.editar');
  -- Mismo orden de bloqueos que pago: pedido -> reservas -> existencias.
  for pedido in select p.* from public.pedidos_ecommerce p where p.estado='RESERVADO' and exists(select 1 from public.reservas r where r.referencia_id=p.id and r.estado='ACTIVA' and r.fecha_expiracion<=now())
    and (auth.role()='service_role' or public.tiene_acceso_ubicacion(p.ubicacion_id)) order by p.id for update of p skip locked loop
    for reserva in select * from public.reservas where referencia_id=pedido.id and estado='ACTIVA' order by producto_id,id for update loop
      update public.existencias set stock_reservado=stock_reservado-reserva.cantidad,stock_disponible=stock_disponible+reserva.cantidad where producto_id=reserva.producto_id and ubicacion_id=reserva.ubicacion_id;
      if not found then raise exception 'Existencia vinculada no encontrada'; end if;
      update public.reservas set estado='EXPIRADA',fecha_liberacion=now() where id=reserva.id;
      total:=total+1;
    end loop;
    update public.pedidos_ecommerce set estado='CANCELADO',fecha_cancelacion=now(),observaciones=coalesce(observaciones,'')||' | Reserva expirada' where id=pedido.id;
  end loop;
  return total;
end $$;

-- Alias de expiración existente de la tienda: misma firma/resultado, mismo protocolo autorizado.
create or replace function public.liberar_reservas_ecommerce_vencidas()
returns integer language sql security definer set search_path=public,pg_temp as $$
  select public.liberar_reservas_expiradas();
$$;

-- Las mutaciones de pedidos/reservas tampoco son rutas alternativas al protocolo.
revoke insert,update,delete on public.pedidos_ecommerce,public.pedidos_ecommerce_detalle,public.reservas from anon,authenticated;
-- REVOKE a nivel tabla no elimina grants explícitos de columnas preexistentes.
do $column_grants$
declare t text; columns_sql text;
begin
  foreach t in array array['ajustes_inventario','devoluciones_venta','conteos_inventario','existencias','movimientos','pedidos_ecommerce','pedidos_ecommerce_detalle','reservas'] loop
    select string_agg(quote_ident(attname),',') into columns_sql from pg_attribute where attrelid=('public.'||t)::regclass and attnum>0 and not attisdropped;
    execute format('revoke insert(%s),update(%s) on public.%I from anon,authenticated',columns_sql,columns_sql,t);
  end loop;
end $column_grants$;
grant update(stock_minimo,stock_maximo) on public.existencias to authenticated;
revoke all on all tables in schema erp_private from public,anon,authenticated,service_role;
revoke all on all functions in schema erp_private from public,anon,authenticated,service_role;
do $grants$
declare f record;
begin
  for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname=any(array['registrar_entrada_con_costo','transferir_inventario','erp_transferir_inventario','registrar_devolucion_venta','solicitar_ajuste_inventario','autorizar_ajuste_inventario','registrar_conteo_inventario','registrar_venta_pos','reservar_stock_ecommerce','confirmar_pago_ecommerce','cancelar_pedido_ecommerce','liberar_reservas_expiradas','liberar_reservas_ecommerce_vencidas']) loop
    execute format('revoke all on function %s from public,anon',f.oid::regprocedure);
    execute format('grant execute on function %s to authenticated,service_role',f.oid::regprocedure);
  end loop;
  for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('registrar_entrada','registrar_salida','ajustar_inventario') loop
    execute format('revoke all on function %s from public,anon,authenticated,service_role',f.oid::regprocedure);
  end loop;
end $grants$;
notify pgrst,'reload schema';
commit;
