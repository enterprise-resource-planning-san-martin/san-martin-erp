-- H03/H04. Después de la migración de autorización (erp_usuario_activo).
-- Todos los accesos son SECURITY INVOKER: conservan RLS, permisos y ubicación del usuario.
begin;

create or replace function public.erp_delta_movimiento(p_tipo text,p_cantidad numeric,p_anterior numeric,p_posterior numeric)
returns numeric language sql immutable security invoker set search_path=public
as $$
  select case
    -- Reservation changes available/reserved stock, never physical stock.
    when p_tipo='RESERVA' then 0
    when p_tipo='ENTRADA' then abs(coalesce(p_cantidad,0))
    when p_tipo='SALIDA' then -abs(coalesce(p_cantidad,0))
    when p_anterior is not null and p_posterior is not null then p_posterior-p_anterior
    else coalesce(p_cantidad,0)
  end;
$$;

create or replace function public.erp_resumen_operativo(
  p_fecha_desde timestamptz default now()-interval '30 days',p_fecha_hasta timestamptz default now()
)
returns jsonb language plpgsql stable security invoker set search_path=public
as $$
declare
  v_productos boolean; v_existencias boolean; v_movimientos boolean;
  v_count bigint; v_stock jsonb; v_moves jsonb;
begin
  if not public.erp_usuario_activo() then raise exception 'Sesión activa requerida.' using errcode='42501'; end if;
  if p_fecha_desde is null or p_fecha_hasta is null or p_fecha_hasta<=p_fecha_desde then
    raise exception 'Período de reporte inválido.' using errcode='22023';
  end if;
  v_productos:=coalesce(public.tiene_permiso('productos.ver'),false);
  v_existencias:=coalesce(public.tiene_permiso('existencias.ver'),false);
  v_movimientos:=coalesce(public.tiene_permiso('movimientos.ver'),false);
  if v_productos then select count(*) into v_count from public.productos where activo; end if;
  if v_existencias then
    with stock as materialized (
      select e.id,e.producto_id,e.ubicacion_id,e.stock_fisico,e.stock_disponible,e.stock_minimo,e.stock_maximo,e.costo_promedio,
        p.nombre producto_nombre,p.sku,u.nombre ubicacion_nombre,u.codigo,c.nombre categoria_nombre,
        case when coalesce(e.stock_disponible,0)<=0 then 'SIN STOCK'
          when coalesce(e.stock_disponible,0)<=coalesce(e.stock_minimo,0)
            or (coalesce(e.stock_maximo,0)>0 and e.stock_disponible<=e.stock_maximo*.4) then 'BAJO' else 'NORMAL' end estado
      from public.existencias e
      left join public.productos p on p.id=e.producto_id
      left join public.ubicaciones u on u.id=e.ubicacion_id
      left join public.categorias c on c.id=p.categoria_id
      where e.activo and public.tiene_acceso_ubicacion(e.ubicacion_id)
    ), categorias as (
      select coalesce(categoria_nombre,'Sin categoría') nombre,count(*) registros,
        coalesce(sum(stock_disponible),0) unidades_disponibles,count(*) filter(where estado<>'NORMAL') criticos
      from stock group by coalesce(categoria_nombre,'Sin categoría')
    ), criticos as (
      select producto_id,producto_nombre,sku,ubicacion_id,ubicacion_nombre,codigo,
        stock_disponible,stock_minimo,stock_maximo,estado
      from stock where estado<>'NORMAL' order by stock_disponible,id limit 20
    )
    select jsonb_build_object(
      'unidades_fisicas',coalesce(sum(stock_fisico),0),'unidades_disponibles',coalesce(sum(stock_disponible),0),
      'valor_total',coalesce(sum(stock_fisico*coalesce(costo_promedio,0)),0),'existencias',count(*),
      'sin_stock',count(*) filter(where estado='SIN STOCK'),'bajo',count(*) filter(where estado='BAJO'),
      'normal',count(*) filter(where estado='NORMAL'),'criticos_total',count(*) filter(where estado<>'NORMAL'),
      'categorias',coalesce((select jsonb_agg(to_jsonb(categorias) order by unidades_disponibles desc,nombre) from categorias),'[]'::jsonb),
      'criticos',coalesce((select jsonb_agg(to_jsonb(criticos)) from criticos),'[]'::jsonb)
    ) into v_stock from stock;
  end if;
  if v_movimientos then
    with moves as materialized (
      select m.*,public.erp_delta_movimiento(m.tipo_movimiento,m.cantidad,m.stock_anterior,m.stock_posterior) delta,
        upper(coalesce(m.origen,'')) canal
      from public.movimientos m where m.fecha_movimiento>=p_fecha_desde and m.fecha_movimiento<p_fecha_hasta
        and public.tiene_acceso_ubicacion(m.ubicacion_id)
    ), sales as materialized (
      select * from moves where tipo_movimiento='SALIDA' and canal in ('POS','ECOMMERCE','E_COMMERCE','E-COMMERCE')
    ), top as (
      select s.producto_id,p.nombre,p.sku,sum(abs(s.cantidad)) cantidad
      from sales s left join public.productos p on p.id=s.producto_id
      group by s.producto_id,p.nombre,p.sku order by cantidad desc,s.producto_id limit 5
    )
    select jsonb_build_object(
      'cantidad',count(*),'entradas',coalesce(sum(greatest(delta,0)),0),'salidas',coalesce(sum(greatest(-delta,0)),0),
      'vendido',coalesce((select sum(abs(cantidad)) from sales),0),
      'pos',coalesce((select sum(abs(cantidad)) from sales where canal='POS'),0),
      'ecommerce',coalesce((select sum(abs(cantidad)) from sales where canal<>'POS'),0),
      'pos_movimientos',(select count(*) from sales where canal='POS'),
      'ecommerce_movimientos',(select count(*) from sales where canal<>'POS'),
      'top_productos',coalesce((select jsonb_agg(to_jsonb(top) order by cantidad desc,producto_id) from top),'[]'::jsonb)
    ) into v_moves from moves;
  end if;
  return jsonb_build_object('acceso',jsonb_build_object('productos',v_productos,'existencias',v_existencias,'movimientos',v_movimientos),
    'productos_activos',v_count,'stock',v_stock,'movimientos',v_moves);
end;
$$;

create or replace function public.erp_resumen_kardex(
  p_producto_id uuid,p_ubicacion_id uuid default null,
  p_fecha_desde timestamptz default now()-interval '30 days',p_fecha_hasta timestamptz default now()
)
returns jsonb language plpgsql stable security invoker set search_path=public
as $$
declare v_result jsonb;
begin
  if not public.erp_usuario_activo() or not coalesce(public.tiene_permiso('movimientos.ver'),false)
    or not coalesce(public.tiene_permiso('existencias.ver'),false) then
    raise exception 'Necesitas permisos de existencias y movimientos para consultar los saldos de Kardex.' using errcode='42501';
  end if;
  if p_producto_id is null or p_fecha_desde is null or p_fecha_hasta is null or p_fecha_hasta<=p_fecha_desde then
    raise exception 'Producto y período de Kardex válidos requeridos.' using errcode='22023';
  end if;
  if p_ubicacion_id is not null and not public.tiene_acceso_ubicacion(p_ubicacion_id) then
    raise exception 'No tienes acceso a esta ubicación.' using errcode='42501';
  end if;
  with moves as materialized (
    select m.*,public.erp_delta_movimiento(m.tipo_movimiento,m.cantidad,m.stock_anterior,m.stock_posterior) delta,
      case when m.tipo_movimiento='RESERVA' then 0
        else coalesce(m.stock_posterior-m.stock_anterior,public.erp_delta_movimiento(m.tipo_movimiento,m.cantidad,m.stock_anterior,m.stock_posterior)) end balance_delta
    from public.movimientos m where m.producto_id=p_producto_id
      and (p_ubicacion_id is null or m.ubicacion_id=p_ubicacion_id)
      and public.tiene_acceso_ubicacion(m.ubicacion_id)
  ), balances as (
    -- Current physical stock anchors histories, including locations without movements in the period.
    select e.ubicacion_id,e.stock_fisico current_stock from public.existencias e
      where e.producto_id=p_producto_id and (p_ubicacion_id is null or e.ubicacion_id=p_ubicacion_id)
        and public.tiene_acceso_ubicacion(e.ubicacion_id)
    union all
    (select distinct on(m.ubicacion_id) m.ubicacion_id,m.stock_posterior from moves m
      where not exists(select 1 from public.existencias e where e.producto_id=p_producto_id and e.ubicacion_id=m.ubicacion_id)
      order by m.ubicacion_id,m.fecha_movimiento desc,m.id desc)
  ), location_balances as (
    select b.ubicacion_id,
      coalesce(b.current_stock,0)-coalesce(sum(m.balance_delta) filter(where m.fecha_movimiento>=p_fecha_desde),0) saldo_inicial,
      coalesce(b.current_stock,0)-coalesce(sum(m.balance_delta) filter(where m.fecha_movimiento>=p_fecha_hasta),0) saldo_final
    from balances b left join moves m on m.ubicacion_id=b.ubicacion_id group by b.ubicacion_id,b.current_stock
  ), period as (
    select * from moves where fecha_movimiento>=p_fecha_desde and fecha_movimiento<p_fecha_hasta
  )
  select jsonb_build_object(
    'saldo_inicial',coalesce((select sum(saldo_inicial) from location_balances),0),
    'saldo_final',coalesce((select sum(saldo_final) from location_balances),0),
    'entradas',coalesce(sum(greatest(delta,0)),0),'salidas',coalesce(sum(greatest(-delta,0)),0),'movimientos',count(*)
  ) into v_result from period;
  return v_result;
end;
$$;

create or replace function public.erp_buscar_existencias(p_busqueda text default '',p_offset integer default 0,p_limite integer default 50)
returns jsonb language plpgsql stable security invoker set search_path=public
as $$
declare v_pattern text; v_result jsonb;
begin
  if not public.erp_usuario_activo() or not coalesce(public.tiene_permiso('existencias.ver'),false) then
    raise exception 'No tienes permiso para consultar existencias.' using errcode='42501';
  end if;
  if p_offset is null or p_offset<0 or p_limite is null or p_limite<1 or p_limite>100 then
    raise exception 'Paginación inválida.' using errcode='22023';
  end if;
  v_pattern:='%'||replace(replace(replace(trim(coalesce(p_busqueda,'')),'\','\\'),'%','\%'),'_','\_')||'%';
  with matches as materialized (
    select e.*,jsonb_build_object('nombre',p.nombre,'sku',p.sku) productos,
      jsonb_build_object('nombre',u.nombre,'codigo',u.codigo) ubicaciones
    from public.existencias e left join public.productos p on p.id=e.producto_id
      left join public.ubicaciones u on u.id=e.ubicacion_id
    where e.activo and public.tiene_acceso_ubicacion(e.ubicacion_id)
      and (trim(coalesce(p_busqueda,''))='' or p.nombre ilike v_pattern or p.sku ilike v_pattern
        or u.nombre ilike v_pattern or u.codigo ilike v_pattern)
  ), page as (select * from matches order by stock_disponible,id offset p_offset limit p_limite)
  select jsonb_build_object('count',(select count(*) from matches),
    'rows',coalesce((select jsonb_agg(to_jsonb(page) order by stock_disponible,id) from page),'[]'::jsonb)) into v_result;
  return v_result;
end;
$$;

revoke all on function public.erp_delta_movimiento(text,numeric,numeric,numeric) from public,anon;
revoke all on function public.erp_resumen_operativo(timestamptz,timestamptz) from public,anon;
revoke all on function public.erp_resumen_kardex(uuid,uuid,timestamptz,timestamptz) from public,anon;
revoke all on function public.erp_buscar_existencias(text,integer,integer) from public,anon;
grant execute on function public.erp_delta_movimiento(text,numeric,numeric,numeric) to authenticated;
grant execute on function public.erp_resumen_operativo(timestamptz,timestamptz) to authenticated;
grant execute on function public.erp_resumen_kardex(uuid,uuid,timestamptz,timestamptz) to authenticated;
grant execute on function public.erp_buscar_existencias(text,integer,integer) to authenticated;

commit;
