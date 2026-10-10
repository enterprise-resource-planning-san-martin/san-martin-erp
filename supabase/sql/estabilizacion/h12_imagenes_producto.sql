-- Etapa B, H12: coordinar metadatos y Storage sin publicar referencias incompletas.
-- Los RPC son las únicas escrituras de producto_imagenes desde el navegador.
begin;

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
declare v_id uuid; v_issuer text; v_url_esperada text;
begin
  perform erp_private.require_staff('productos.editar');
  v_issuer := nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'iss';
  if v_issuer is null or v_issuer !~ '^https?://[^/?#]+/auth/v1$' then
    raise exception 'El token no identifica el proyecto de Storage.' using errcode='42501';
  end if;
  v_url_esperada := left(v_issuer,length(v_issuer)-length('/auth/v1'))||
    '/storage/v1/object/public/productos/'||p_storage_path;
  if p_producto_id is null or p_storage_path is null or p_storage_path !~
       ('^'||p_producto_id::text||'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}-[A-Za-z0-9._-]{1,180}$')
     or p_nombre_archivo is null or btrim(p_nombre_archivo)='' or length(p_nombre_archivo)>255
     or p_mime_type is null or p_mime_type not in ('image/jpeg','image/png','image/webp','image/gif','image/avif')
     or p_tamano_bytes is null or p_tamano_bytes<=0
     or p_url_publica is distinct from v_url_esperada then
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

commit;
