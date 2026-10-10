-- H12: la URL de Storage se deriva del emisor del JWT del proyecto actual.
-- No se cambia la firma ni los permisos concedidos a la función.
begin;

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
       ('^'||p_producto_id::text||'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}-[A-Za-z0-9._-]{1,180}$')
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

commit;
