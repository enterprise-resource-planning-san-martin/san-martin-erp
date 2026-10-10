-- SAN MARTÍN ERP: esquema base capturado el 09-oct-2026, después de la Etapa B.
-- Aplicar una sola vez a un proyecto Supabase nuevo con Auth y Storage disponibles.
-- No ejecutar sobre la base actual: allí ya existen estas tablas y datos.
-- No incluye usuarios, pedidos, inventario, configuración de empresa ni archivos de Storage.
begin;
create schema if not exists private;
create schema if not exists erp_private;
revoke all on schema private,erp_private from public,anon,authenticated;

create sequence "public"."pedidos_ecommerce_numero_seq" start with 1 increment by 1 minvalue 1 cache 1;

create table "erp_private"."compra_movement_context" (
  "backend" integer NOT NULL,
  "transaction_id" bigint NOT NULL,
  "usuario_id" uuid,
  "producto_id" uuid NOT NULL,
  "ubicacion_id" uuid NOT NULL,
  "cantidad" numeric NOT NULL,
  "referencia_numero" text NOT NULL
);

create table "erp_private"."installation" (
  "version" text NOT NULL,
  "installed_at" timestamp with time zone DEFAULT now() NOT NULL
);

create table "erp_private"."movement_context" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "backend" integer NOT NULL,
  "transaction_id" bigint NOT NULL,
  "producto_id" uuid NOT NULL,
  "ubicacion_id" uuid NOT NULL,
  "costo" numeric,
  "movimiento_id" uuid,
  "inserted" integer DEFAULT 0 NOT NULL
);

create table "public"."ajustes_inventario" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "producto_id" uuid NOT NULL,
  "ubicacion_id" uuid NOT NULL,
  "tipo" character varying NOT NULL,
  "cantidad" numeric NOT NULL,
  "motivo" character varying NOT NULL,
  "observaciones" text,
  "estado" character varying DEFAULT 'PENDIENTE'::character varying NOT NULL,
  "solicitado_por" uuid DEFAULT auth.uid() NOT NULL,
  "autorizado_por" uuid,
  "fecha_solicitud" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_autorizacion" timestamp with time zone,
  "comentario_autorizacion" text
);

create table "public"."alertas_inventario" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "existencia_id" uuid NOT NULL,
  "producto_id" uuid NOT NULL,
  "ubicacion_id" uuid NOT NULL,
  "estado" character varying NOT NULL,
  "stock_disponible" numeric NOT NULL,
  "stock_minimo" numeric DEFAULT 0 NOT NULL,
  "stock_maximo" numeric,
  "activa" boolean DEFAULT true NOT NULL,
  "enviada_en" timestamp with time zone,
  "resuelta_en" timestamp with time zone,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL,
  "envio_lote" uuid,
  "envio_reclamado_en" timestamp with time zone,
  "envio_usuario_id" uuid,
  "envio_payload" jsonb,
  "primer_intento_en" timestamp with time zone,
  "intentos" integer DEFAULT 0 NOT NULL,
  "ultimo_error" text,
  "proveedor_email_id" text
);

create table "public"."anuncios_editoriales_ecommerce" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "etiqueta" character varying(80),
  "titulo" character varying(180) NOT NULL,
  "descripcion" text,
  "cta_texto" character varying(80),
  "cta_url" text,
  "imagen_url" text,
  "storage_bucket" character varying(120),
  "storage_path" text,
  "alt_text" text,
  "orden" integer DEFAULT 0 NOT NULL,
  "activo" boolean DEFAULT true NOT NULL,
  "fecha_inicio" timestamp with time zone,
  "fecha_fin" timestamp with time zone,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."anuncios_inicio_ecommerce" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "titulo" character varying(180),
  "imagen_url" text,
  "storage_bucket" character varying(120) DEFAULT 'ecommerce-anuncios-inicio'::character varying NOT NULL,
  "storage_path" text NOT NULL,
  "alt_text" text,
  "cta_url" text,
  "orden" integer DEFAULT 0 NOT NULL,
  "activo" boolean DEFAULT true NOT NULL,
  "fecha_inicio" timestamp with time zone,
  "fecha_fin" timestamp with time zone,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."auditoria" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "tabla" character varying NOT NULL,
  "accion" character varying NOT NULL,
  "registro_id" uuid,
  "datos_anteriores" jsonb,
  "datos_nuevos" jsonb,
  "usuario_id" uuid,
  "fecha" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."banners_ecommerce" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "imagen_url" text,
  "storage_bucket" character varying,
  "storage_path" text,
  "alt_text" text,
  "etiqueta" character varying,
  "titulo" character varying NOT NULL,
  "descripcion" text,
  "cta_texto" character varying,
  "cta_url" text,
  "tema" character varying DEFAULT 'oscuro'::character varying NOT NULL,
  "orden" integer DEFAULT 0 NOT NULL,
  "activo" boolean DEFAULT true NOT NULL,
  "fecha_inicio" timestamp with time zone,
  "fecha_fin" timestamp with time zone,
  "creado_por" uuid,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."carritos_ecommerce" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "cliente_id" uuid NOT NULL,
  "items" jsonb DEFAULT '[]'::jsonb NOT NULL,
  "consentimiento_recordatorios" boolean DEFAULT false NOT NULL,
  "actualizado_en" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."categorias" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "nombre" character varying(150) NOT NULL,
  "slug" character varying(180) NOT NULL,
  "descripcion" text,
  "categoria_padre_id" uuid,
  "imagen_url" text,
  "icono" character varying(100),
  "orden" integer DEFAULT 0 NOT NULL,
  "activo" boolean DEFAULT true NOT NULL,
  "visible_pos" boolean DEFAULT true NOT NULL,
  "visible_ecommerce" boolean DEFAULT true NOT NULL,
  "destacada" boolean DEFAULT false NOT NULL,
  "seo_title" character varying(200),
  "seo_description" text,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."configuracion_ecommerce" (
  "id" boolean DEFAULT true NOT NULL,
  "ubicacion_ecommerce_id" uuid NOT NULL,
  "actualizado_en" timestamp with time zone DEFAULT now() NOT NULL,
  "max_cantidad_por_linea" numeric DEFAULT 100 NOT NULL,
  "umbral_pocas_unidades" numeric DEFAULT 5 NOT NULL
);

create table "public"."configuracion_erp" (
  "clave" character varying NOT NULL,
  "valor" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."conteos_inventario" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "producto_id" uuid NOT NULL,
  "ubicacion_id" uuid NOT NULL,
  "stock_sistema" numeric NOT NULL,
  "stock_contado" numeric NOT NULL,
  "diferencia" numeric NOT NULL,
  "estado" character varying DEFAULT 'APLICADO'::character varying NOT NULL,
  "observaciones" text,
  "usuario_id" uuid DEFAULT auth.uid(),
  "fecha_conteo" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."devoluciones_venta" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "canal" character varying NOT NULL,
  "referencia_venta" character varying NOT NULL,
  "producto_id" uuid NOT NULL,
  "ubicacion_id" uuid NOT NULL,
  "cantidad" numeric NOT NULL,
  "motivo" character varying NOT NULL,
  "observaciones" text,
  "usuario_id" uuid DEFAULT auth.uid(),
  "fecha_devolucion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."existencias" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "producto_id" uuid NOT NULL,
  "ubicacion_id" uuid NOT NULL,
  "stock_fisico" numeric(14,3) DEFAULT 0 NOT NULL,
  "stock_reservado" numeric(14,3) DEFAULT 0 NOT NULL,
  "stock_disponible" numeric(14,3) DEFAULT 0 NOT NULL,
  "stock_minimo" numeric(14,3) DEFAULT 0 NOT NULL,
  "stock_maximo" numeric(14,3) DEFAULT 0 NOT NULL,
  "punto_reorden" numeric(14,3) DEFAULT 0 NOT NULL,
  "activo" boolean DEFAULT true NOT NULL,
  "fecha_ultimo_movimiento" timestamp with time zone,
  "fecha_ultimo_conteo" timestamp with time zone,
  "creado_por" uuid,
  "actualizado_por" uuid,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL,
  "costo_promedio" numeric DEFAULT 0 NOT NULL
);

create table "public"."facturas_ecommerce" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "numero" bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  "pedido_id" uuid NOT NULL,
  "ubicacion_id" uuid NOT NULL,
  "fecha_emision" timestamp with time zone DEFAULT now() NOT NULL,
  "datos" jsonb NOT NULL
);

create table "public"."favoritos_ecommerce" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "usuario_id" uuid NOT NULL,
  "producto_id" uuid NOT NULL,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."marcas" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "nombre" character varying(150) NOT NULL,
  "slug" character varying(180) NOT NULL,
  "descripcion" text,
  "logo_url" text,
  "sitio_web" text,
  "pais_origen" character varying(100),
  "activo" boolean DEFAULT true NOT NULL,
  "destacada" boolean DEFAULT false NOT NULL,
  "orden" integer DEFAULT 0 NOT NULL,
  "seo_title" character varying(200),
  "seo_description" text,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."movimientos" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "producto_id" uuid NOT NULL,
  "ubicacion_id" uuid NOT NULL,
  "tipo_movimiento" character varying(40) NOT NULL,
  "cantidad" numeric(14,3) NOT NULL,
  "stock_anterior" numeric(14,3) NOT NULL,
  "stock_posterior" numeric(14,3) NOT NULL,
  "costo_unitario" numeric(14,4),
  "valor_total" numeric(16,4),
  "origen" character varying(30) NOT NULL,
  "referencia_tipo" character varying(50),
  "referencia_id" uuid,
  "referencia_numero" character varying(100),
  "grupo_movimiento_id" uuid,
  "observaciones" text,
  "usuario_id" uuid,
  "fecha_movimiento" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."notificaciones_operativas_ecommerce" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "tipo" character varying NOT NULL,
  "prioridad" character varying DEFAULT 'NORMAL'::character varying NOT NULL,
  "pedido_id" uuid,
  "alerta_inventario_id" uuid,
  "ubicacion_id" uuid,
  "payload" jsonb DEFAULT '{}'::jsonb NOT NULL,
  "estado" character varying DEFAULT 'PENDIENTE'::character varying NOT NULL,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL,
  "procesado_en" timestamp with time zone,
  "error_detalle" text
);

create table "public"."ofertas_producto" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "producto_id" uuid NOT NULL,
  "nombre" character varying(150) NOT NULL,
  "descripcion" text,
  "oferta_porcentaje" numeric(5,2) DEFAULT 0 NOT NULL,
  "fecha_inicio" timestamp with time zone NOT NULL,
  "fecha_fin" timestamp with time zone,
  "activo" boolean DEFAULT true NOT NULL,
  "aplica_pos" boolean DEFAULT true NOT NULL,
  "aplica_ecommerce" boolean DEFAULT true NOT NULL,
  "creado_por" uuid,
  "actualizado_por" uuid,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."ordenes_compra" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "numero" character varying NOT NULL,
  "proveedor_id" uuid NOT NULL,
  "estado" character varying DEFAULT 'BORRADOR'::character varying NOT NULL,
  "fecha_esperada" date,
  "observaciones" text,
  "creado_por" uuid DEFAULT auth.uid(),
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."ordenes_compra_detalle" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "orden_compra_id" uuid NOT NULL,
  "producto_id" uuid NOT NULL,
  "cantidad_solicitada" numeric NOT NULL,
  "cantidad_recibida" numeric DEFAULT 0 NOT NULL,
  "precio_estimado" numeric,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."pedidos_ecommerce" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "numero" character varying NOT NULL,
  "ubicacion_id" uuid NOT NULL,
  "estado" character varying DEFAULT 'RESERVADO'::character varying NOT NULL,
  "total" numeric DEFAULT 0 NOT NULL,
  "observaciones" text,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_pago" timestamp with time zone,
  "fecha_cancelacion" timestamp with time zone,
  "cliente_id" uuid,
  "direccion_envio" jsonb,
  "costo_envio" numeric DEFAULT 0 NOT NULL,
  "metodo_entrega" character varying,
  "metodo_pago" character varying,
  "estado_entrega" text DEFAULT 'PENDIENTE'::text NOT NULL,
  "fecha_preparado" timestamp with time zone,
  "fecha_envio" timestamp with time zone,
  "fecha_entrega" timestamp with time zone
);

create table "public"."pedidos_ecommerce_detalle" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "pedido_id" uuid NOT NULL,
  "producto_id" uuid NOT NULL,
  "cantidad" numeric NOT NULL,
  "precio_unitario" numeric NOT NULL,
  "total_linea" numeric NOT NULL
);

create table "public"."perfiles" (
  "id" uuid NOT NULL,
  "nombre" character varying(100),
  "apellido" character varying(100),
  "correo" character varying(255),
  "telefono" character varying(30),
  "avatar_url" text,
  "rol_id" uuid,
  "estado" character varying(20) DEFAULT 'ACTIVO'::character varying NOT NULL,
  "activo" boolean DEFAULT true NOT NULL,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL,
  "boletin" boolean DEFAULT false NOT NULL,
  "segundo_nombre" character varying,
  "segundo_apellido" character varying,
  "nombre_direccion" character varying,
  "departamento" character varying,
  "municipio" character varying,
  "direccion_completa" text,
  "referencia_direccion" text
);

create table "public"."permisos" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "codigo" character varying(120) NOT NULL,
  "modulo" character varying(60) NOT NULL,
  "accion" character varying(60) NOT NULL,
  "nombre" character varying(120) NOT NULL,
  "descripcion" text,
  "activo" boolean DEFAULT true NOT NULL,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."producto_imagenes" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "producto_id" uuid NOT NULL,
  "storage_bucket" character varying(100) DEFAULT 'productos'::character varying NOT NULL,
  "storage_path" text NOT NULL,
  "url_publica" text,
  "nombre_archivo" character varying(255),
  "tipo_imagen" character varying(50) DEFAULT 'producto'::character varying NOT NULL,
  "orden" integer DEFAULT 0 NOT NULL,
  "es_principal" boolean DEFAULT false NOT NULL,
  "alt_text" text,
  "ancho" integer,
  "alto" integer,
  "tamaño_bytes" bigint,
  "mime_type" character varying(100),
  "activo" boolean DEFAULT true NOT NULL,
  "creado_por" uuid,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL,
  "estado_storage" text DEFAULT 'ACTIVA'::text NOT NULL
);

create table "public"."productos" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "codigo_barras" character varying(50),
  "sku" character varying(80) NOT NULL,
  "codigo_interno" character varying(80),
  "nombre" character varying(250) NOT NULL,
  "nombre_corto" character varying(150),
  "categoria_id" uuid NOT NULL,
  "marca_id" uuid,
  "unidad_medida_id" uuid NOT NULL,
  "descripcion_corta" text,
  "descripcion_larga" text,
  "presentacion" character varying(150),
  "modelo" character varying(150),
  "color" character varying(100),
  "tamano" character varying(100),
  "material" character varying(150),
  "peso" numeric(12,3),
  "unidad_peso" character varying(20),
  "ancho" numeric(12,3),
  "alto" numeric(12,3),
  "profundidad" numeric(12,3),
  "unidad_dimensiones" character varying(20),
  "contenido" character varying(150),
  "piezas_por_paquete" integer,
  "es_vendible" boolean DEFAULT true NOT NULL,
  "es_comprable" boolean DEFAULT true NOT NULL,
  "controla_inventario" boolean DEFAULT true NOT NULL,
  "venta_fraccionada" boolean DEFAULT false NOT NULL,
  "requiere_codigo_barras" boolean DEFAULT false NOT NULL,
  "disponible_pos" boolean DEFAULT true NOT NULL,
  "publicado_ecommerce" boolean DEFAULT false NOT NULL,
  "visible_ecommerce" boolean DEFAULT true NOT NULL,
  "destacado_ecommerce" boolean DEFAULT false NOT NULL,
  "slug" character varying(280),
  "titulo_seo" character varying(200),
  "descripcion_seo" text,
  "palabras_clave" text[],
  "orden_ecommerce" integer DEFAULT 0 NOT NULL,
  "activo" boolean DEFAULT true NOT NULL,
  "descontinuado" boolean DEFAULT false NOT NULL,
  "creado_por" uuid,
  "actualizado_por" uuid,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL,
  "precio_base" numeric(12,2) DEFAULT 0 NOT NULL,
  "proveedor_id" uuid,
  "costo_ultimo" numeric
);

create table "public"."proveedores" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "nombre" character varying NOT NULL,
  "nit" character varying,
  "contacto_nombre" character varying,
  "correo" character varying,
  "telefono" character varying,
  "direccion" text,
  "activo" boolean DEFAULT true NOT NULL,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."recepciones_compra" (
  "id" uuid NOT NULL,
  "orden_compra_id" uuid NOT NULL,
  "ubicacion_id" uuid NOT NULL,
  "documento" character varying(120) NOT NULL,
  "observaciones" text,
  "creado_por" uuid DEFAULT auth.uid(),
  "fecha_recepcion" timestamp with time zone DEFAULT now() NOT NULL,
  "solicitud" jsonb NOT NULL,
  "resultado" jsonb
);

create table "public"."recepciones_compra_detalle" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "recepcion_id" uuid NOT NULL,
  "orden_detalle_id" uuid NOT NULL,
  "producto_id" uuid NOT NULL,
  "cantidad" numeric NOT NULL,
  "costo_unitario" numeric NOT NULL,
  "movimiento_id" uuid NOT NULL
);

create table "public"."recordatorios_carrito_ecommerce" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "carrito_id" uuid NOT NULL,
  "canal" character varying NOT NULL,
  "estado" character varying DEFAULT 'PENDIENTE'::character varying NOT NULL,
  "programado_para" timestamp with time zone NOT NULL,
  "creado_en" timestamp with time zone DEFAULT now() NOT NULL,
  "enviado_en" timestamp with time zone
);

create table "public"."reservas" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "producto_id" uuid NOT NULL,
  "ubicacion_id" uuid NOT NULL,
  "cantidad" numeric(14,3) NOT NULL,
  "estado" character varying(30) DEFAULT 'ACTIVA'::character varying NOT NULL,
  "origen" character varying(30) NOT NULL,
  "referencia_tipo" character varying(50),
  "referencia_id" uuid,
  "referencia_numero" character varying(100),
  "fecha_reserva" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_expiracion" timestamp with time zone,
  "fecha_liberacion" timestamp with time zone,
  "fecha_consumo" timestamp with time zone,
  "creado_por" uuid,
  "actualizado_por" uuid,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."rol_permisos" (
  "rol_id" uuid NOT NULL,
  "permiso_id" uuid NOT NULL,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."roles" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "codigo" character varying(50) NOT NULL,
  "nombre" character varying(100) NOT NULL,
  "descripcion" text,
  "activo" boolean DEFAULT true NOT NULL,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."suscripciones_newsletter" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "correo" text NOT NULL,
  "estado" character varying DEFAULT 'ACTIVA'::character varying NOT NULL,
  "origen" character varying DEFAULT 'SITIO_WEB'::character varying NOT NULL,
  "fecha_suscripcion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."ubicaciones" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "codigo" character varying(50) NOT NULL,
  "nombre" character varying(150) NOT NULL,
  "tipo" character varying(50) NOT NULL,
  "ubicacion_padre_id" uuid,
  "direccion" text,
  "descripcion" text,
  "responsable_id" uuid,
  "permite_inventario" boolean DEFAULT true NOT NULL,
  "permite_venta" boolean DEFAULT false NOT NULL,
  "permite_recepcion" boolean DEFAULT false NOT NULL,
  "permite_transferencia" boolean DEFAULT true NOT NULL,
  "activo" boolean DEFAULT true NOT NULL,
  "orden" integer DEFAULT 0 NOT NULL,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."unidades_medida" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "nombre" character varying(100) NOT NULL,
  "abreviatura" character varying(20) NOT NULL,
  "tipo" character varying(50) NOT NULL,
  "decimales_permitidos" smallint DEFAULT 0 NOT NULL,
  "permite_fraccion" boolean DEFAULT false NOT NULL,
  "factor_base" numeric(14,6) DEFAULT 1 NOT NULL,
  "unidad_base_id" uuid,
  "activo" boolean DEFAULT true NOT NULL,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."usuario_permisos" (
  "usuario_id" uuid NOT NULL,
  "permiso_id" uuid NOT NULL,
  "permitido" boolean DEFAULT true NOT NULL,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_actualizacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."usuario_ubicaciones" (
  "usuario_id" uuid NOT NULL,
  "ubicacion_id" uuid NOT NULL,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."ventas_pos" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "numero" character varying NOT NULL,
  "ubicacion_id" uuid NOT NULL,
  "estado" character varying DEFAULT 'COMPLETADA'::character varying NOT NULL,
  "subtotal" numeric DEFAULT 0 NOT NULL,
  "total" numeric DEFAULT 0 NOT NULL,
  "usuario_id" uuid DEFAULT auth.uid(),
  "observaciones" text,
  "fecha_venta" timestamp with time zone DEFAULT now() NOT NULL,
  "fecha_creacion" timestamp with time zone DEFAULT now() NOT NULL
);

create table "public"."ventas_pos_detalle" (
  "id" uuid DEFAULT gen_random_uuid() NOT NULL,
  "venta_id" uuid NOT NULL,
  "producto_id" uuid NOT NULL,
  "cantidad" numeric NOT NULL,
  "precio_unitario" numeric NOT NULL,
  "total_linea" numeric NOT NULL
);

CREATE OR REPLACE FUNCTION erp_private.actualizar_alerta_existencia(p_existencia_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION erp_private.capture_movement()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION erp_private.move(p_producto uuid, p_ubicacion uuid, p_cantidad numeric, p_tipo character varying, p_origen character varying, p_referencia_tipo character varying, p_referencia character varying, p_observaciones text, p_costo numeric DEFAULT NULL::numeric)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION erp_private.registrar_movimiento_inventario(p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_tipo_movimiento text, p_origen text DEFAULT 'MANUAL'::text, p_referencia_tipo text DEFAULT NULL::text, p_referencia_id uuid DEFAULT NULL::uuid, p_referencia_numero text DEFAULT NULL::text, p_observaciones text DEFAULT NULL::text, p_costo_unitario numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_anterior numeric := 0;
  v_reservado numeric := 0;
  v_nuevo numeric;
  v_disponible numeric;
  v_movimiento_id uuid;
begin
  -- Las integraciones deben usar un usuario autenticado dedicado con estos permisos.
  if auth.uid() is null
     or not (public.tiene_permiso('existencias.ajustar'::text) or erp_private.purchase_movement_allowed(p_producto_id,p_ubicacion_id,p_cantidad,p_tipo_movimiento,p_origen,p_referencia_tipo,p_referencia_numero))
     or not public.tiene_acceso_ubicacion(p_ubicacion_id) then
    raise exception 'No tiene permiso para ajustar stock en esta ubicación';
  end if;

  if p_cantidad = 0 then
    raise exception 'La cantidad debe ser distinta de cero';
  end if;

  -- Bloquea esta fila durante el cálculo para que dos ventas simultáneas no vendan el mismo stock.
  select stock_fisico, stock_reservado
    into v_anterior, v_reservado
  from public.existencias
  where producto_id = p_producto_id and ubicacion_id = p_ubicacion_id
  for update;

  v_anterior := coalesce(v_anterior, 0);
  v_reservado := coalesce(v_reservado, 0);
  v_nuevo := v_anterior + p_cantidad;
  v_disponible := v_nuevo - v_reservado;

  if v_nuevo < 0 or v_disponible < 0 then
    raise exception 'Stock insuficiente para completar el movimiento';
  end if;

  insert into public.existencias (
    producto_id, ubicacion_id, stock_fisico, stock_reservado, stock_disponible,
    activo, fecha_ultimo_movimiento, fecha_creacion, fecha_actualizacion
  ) values (
    p_producto_id, p_ubicacion_id, v_nuevo, v_reservado, v_disponible,
    true, now(), now(), now()
  )
  on conflict (producto_id, ubicacion_id) do update set
    stock_fisico = excluded.stock_fisico,
    stock_disponible = excluded.stock_disponible,
    fecha_ultimo_movimiento = now(),
    fecha_actualizacion = now();

  insert into public.movimientos (
    producto_id, ubicacion_id, tipo_movimiento, cantidad,
    stock_anterior, stock_posterior, costo_unitario, valor_total,
    origen, referencia_tipo, referencia_id, referencia_numero,
    observaciones, usuario_id, fecha_movimiento, fecha_creacion
  ) values (
    p_producto_id, p_ubicacion_id, p_tipo_movimiento, p_cantidad,
    v_anterior, v_nuevo, p_costo_unitario,
    abs(p_cantidad) * coalesce(p_costo_unitario, 0),
    p_origen, p_referencia_tipo, p_referencia_id, p_referencia_numero,
    p_observaciones, auth.uid(), now(), now()
  ) returning id into v_movimiento_id;

  return jsonb_build_object(
    'movimiento_id', v_movimiento_id,
    'stock_anterior', v_anterior,
    'stock_fisico', v_nuevo,
    'stock_disponible', v_disponible
  );
end;
$function$;

CREATE OR REPLACE FUNCTION erp_private.require_staff(p_permission text, p_location uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if auth.role()='service_role' then return; end if;
  if not public.erp_usuario_activo() or not coalesce(public.tiene_permiso(p_permission),false)
    or (p_location is not null and not coalesce(public.tiene_acceso_ubicacion(p_location),false)) then
    raise exception 'Sesión activa, permiso % y acceso a ubicación requeridos.',p_permission using errcode='42501';
  end if;
end $function$;

CREATE OR REPLACE FUNCTION private.obtener_existencia_bloqueada(p_producto_id uuid, p_ubicacion_id uuid, p_usuario_id uuid DEFAULT NULL::uuid)
 RETURNS existencias
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_existencia public.existencias;
BEGIN

    -- ========================================================
    -- VALIDACIÓN
    -- ========================================================

    IF p_producto_id IS NULL THEN
        RAISE EXCEPTION
            'PRODUCTO_REQUERIDO';
    END IF;

    IF p_ubicacion_id IS NULL THEN
        RAISE EXCEPTION
            'UBICACION_REQUERIDA';
    END IF;


    -- ========================================================
    -- CREAR EXISTENCIA SI NO EXISTE
    -- ========================================================

    INSERT INTO public.existencias (
        producto_id,
        ubicacion_id,
        creado_por,
        actualizado_por
    )
    VALUES (
        p_producto_id,
        p_ubicacion_id,
        p_usuario_id,
        p_usuario_id
    )
    ON CONFLICT (
        producto_id,
        ubicacion_id
    )
    DO NOTHING;


    -- ========================================================
    -- BLOQUEAR FILA
    -- ========================================================

    SELECT e.*
    INTO v_existencia
    FROM public.existencias AS e
    WHERE e.producto_id = p_producto_id
      AND e.ubicacion_id = p_ubicacion_id
    FOR UPDATE;


    IF v_existencia.id IS NULL THEN
        RAISE EXCEPTION
            'NO_SE_PUDO_OBTENER_EXISTENCIA';
    END IF;


    RETURN v_existencia;

END;
$function$;

CREATE OR REPLACE FUNCTION public.actualizar_alertas_despues_de_stock()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if tg_op='UPDATE' and
    (new.stock_disponible,new.stock_minimo,new.stock_maximo,new.activo,new.producto_id,new.ubicacion_id)
    is not distinct from
    (old.stock_disponible,old.stock_minimo,old.stock_maximo,old.activo,old.producto_id,old.ubicacion_id) then
    return new;
  end if;
  perform erp_private.actualizar_alerta_existencia(new.id);
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.actualizar_fecha_actualizacion()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
    NEW.fecha_actualizacion = now();
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.actualizar_mi_perfil(p_datos jsonb)
 RETURNS perfiles
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_usuario uuid := auth.uid();
  v_perfil public.perfiles;
  v_claves_permitidas constant text[] := array[
    'nombre', 'segundo_nombre', 'apellido', 'segundo_apellido', 'telefono',
    'nombre_direccion', 'departamento', 'municipio',
    'direccion_completa', 'referencia_direccion'
  ];
  v_clave text;
begin
  if v_usuario is null then
    raise exception 'Debes iniciar sesión para actualizar tu perfil';
  end if;

  if p_datos is null or jsonb_typeof(p_datos) <> 'object' then
    raise exception 'Los datos del perfil no tienen un formato válido';
  end if;

  for v_clave in select jsonb_object_keys(p_datos) loop
    if not (v_clave = any(v_claves_permitidas)) then
      raise exception 'No está permitido actualizar el campo: %', v_clave;
    end if;
  end loop;

  update public.perfiles
  set
    nombre = case when p_datos ? 'nombre' then nullif(trim(p_datos->>'nombre'), '') else nombre end,
    segundo_nombre = case when p_datos ? 'segundo_nombre' then nullif(trim(p_datos->>'segundo_nombre'), '') else segundo_nombre end,
    apellido = case when p_datos ? 'apellido' then nullif(trim(p_datos->>'apellido'), '') else apellido end,
    segundo_apellido = case when p_datos ? 'segundo_apellido' then nullif(trim(p_datos->>'segundo_apellido'), '') else segundo_apellido end,
    telefono = case when p_datos ? 'telefono' then nullif(trim(p_datos->>'telefono'), '') else telefono end,
    nombre_direccion = case when p_datos ? 'nombre_direccion' then nullif(trim(p_datos->>'nombre_direccion'), '') else nombre_direccion end,
    departamento = case when p_datos ? 'departamento' then nullif(trim(p_datos->>'departamento'), '') else departamento end,
    municipio = case when p_datos ? 'municipio' then nullif(trim(p_datos->>'municipio'), '') else municipio end,
    direccion_completa = case when p_datos ? 'direccion_completa' then nullif(trim(p_datos->>'direccion_completa'), '') else direccion_completa end,
    referencia_direccion = case when p_datos ? 'referencia_direccion' then nullif(trim(p_datos->>'referencia_direccion'), '') else referencia_direccion end
  where id = v_usuario
  returning * into v_perfil;

  if not found then
    raise exception 'No se encontró el perfil del usuario';
  end if;

  return v_perfil;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ajustar_inventario(p_producto_id uuid, p_ubicacion_id uuid, p_stock_nuevo numeric, p_origen character varying DEFAULT 'CONTEO'::character varying, p_referencia_tipo character varying DEFAULT NULL::character varying, p_referencia_id uuid DEFAULT NULL::uuid, p_referencia_numero character varying DEFAULT NULL::character varying, p_costo_unitario numeric DEFAULT NULL::numeric, p_observaciones text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario_id uuid;
    v_existencia public.existencias;
    v_diferencia numeric;
    v_tipo_movimiento varchar;
    v_movimiento_id uuid;
BEGIN

    /* ========================================================
       AUTENTICACIÓN
       ======================================================== */

    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'USUARIO_NO_AUTENTICADO';
    END IF;


    /* ========================================================
       AUTORIZACIÓN
       ======================================================== */

    IF NOT public.usuario_tiene_permiso(
        v_usuario_id,
        'existencias.ajustar'
    ) THEN
        RAISE EXCEPTION
            'PERMISO_DENEGADO: existencias.ajustar';
    END IF;


    /* ========================================================
       VALIDACIÓN BÁSICA
       ======================================================== */

    IF p_producto_id IS NULL THEN
        RAISE EXCEPTION 'PRODUCTO_REQUERIDO';
    END IF;

    IF p_ubicacion_id IS NULL THEN
        RAISE EXCEPTION 'UBICACION_REQUERIDA';
    END IF;

    IF p_stock_nuevo IS NULL OR p_stock_nuevo < 0 THEN
        RAISE EXCEPTION 'STOCK_NUEVO_INVALIDO';
    END IF;

    IF p_origen IS NULL OR btrim(p_origen) = '' THEN
        RAISE EXCEPTION 'ORIGEN_REQUERIDO';
    END IF;

    IF p_costo_unitario IS NOT NULL
       AND p_costo_unitario < 0 THEN
        RAISE EXCEPTION 'COSTO_UNITARIO_INVALIDO';
    END IF;


    /* ========================================================
       ACCESO A LA UBICACIÓN
       ======================================================== */

    IF NOT public.usuario_tiene_ubicacion(
        v_usuario_id,
        p_ubicacion_id
    ) THEN
        RAISE EXCEPTION 'ACCESO_UBICACION_DENEGADO';
    END IF;


    /* ========================================================
       OBTENER Y BLOQUEAR EXISTENCIA
       ======================================================== */

    v_existencia :=
        private.obtener_existencia_bloqueada(
            p_producto_id,
            p_ubicacion_id,
            v_usuario_id
        );


    /* ========================================================
       CALCULAR DIFERENCIA
       ======================================================== */

    v_diferencia :=
        p_stock_nuevo - v_existencia.stock_fisico;


    /* ========================================================
       EVITAR AJUSTES SIN CAMBIO
       ======================================================== */

    IF v_diferencia = 0 THEN
        RAISE EXCEPTION 'AJUSTE_SIN_CAMBIO';
    END IF;


    /* ========================================================
       DETERMINAR TIPO DE MOVIMIENTO
       ======================================================== */

    IF v_diferencia > 0 THEN
        v_tipo_movimiento := 'AJUSTE_POSITIVO';
    ELSE
        v_tipo_movimiento := 'AJUSTE_NEGATIVO';
    END IF;


    /* ========================================================
       ACTUALIZAR EXISTENCIA
       ======================================================== */

    UPDATE public.existencias
    SET
        stock_fisico = p_stock_nuevo,
        stock_disponible =
            p_stock_nuevo - stock_reservado,
        fecha_ultimo_movimiento = now(),
        fecha_ultimo_conteo = now(),
        actualizado_por = v_usuario_id,
        contado_por = v_usuario_id,
        fecha_actualizacion = now()
    WHERE id = v_existencia.id;


    /* ========================================================
       REGISTRAR MOVIMIENTO
       ======================================================== */

    INSERT INTO public.movimientos (
        producto_id,
        ubicacion_id,
        tipo_movimiento,
        cantidad,
        stock_anterior,
        stock_posterior,
        costo_unitario,
        costo_total,
        origen,
        referencia_tipo,
        referencia_id,
        referencia_numero,
        observaciones,
        usuario_id
    )
    VALUES (
        p_producto_id,
        p_ubicacion_id,
        v_tipo_movimiento,
        ABS(v_diferencia),
        v_existencia.stock_fisico,
        p_stock_nuevo,
        p_costo_unitario,
        CASE
            WHEN p_costo_unitario IS NOT NULL
            THEN ABS(v_diferencia) * p_costo_unitario
            ELSE NULL
        END,
        p_origen,
        p_referencia_tipo,
        p_referencia_id,
        p_referencia_numero,
        p_observaciones,
        v_usuario_id
    )
    RETURNING id
    INTO v_movimiento_id;


    /* ========================================================
       RESULTADO
       ======================================================== */

    RETURN v_movimiento_id;

END;
$function$;

CREATE OR REPLACE FUNCTION public.autorizar_ajuste_inventario(p_ajuste_id uuid, p_aprobar boolean, p_comentario text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.cancelar_pedido_ecommerce(p_pedido_id uuid, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.completar_costo_movimiento()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare v_costo numeric := 0;
begin
  select costo_promedio into v_costo
  from public.existencias
  where producto_id=new.producto_id and ubicacion_id=new.ubicacion_id;
  v_costo := coalesce(v_costo,0);
  if new.costo_unitario is null then new.costo_unitario := v_costo; end if;
  if new.valor_total is null or new.valor_total = 0 then new.valor_total := abs(coalesce(new.cantidad,0)) * coalesce(new.costo_unitario,0); end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.confirmar_pago_ecommerce(p_pedido_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.consumir_reserva(p_reserva_id uuid, p_costo_unitario numeric DEFAULT NULL::numeric, p_observaciones text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario_id uuid;
    v_reserva public.reservas;
    v_existencia public.existencias;
    v_nuevo_stock numeric;
    v_nuevo_reservado numeric;
    v_nuevo_disponible numeric;
    v_movimiento_id uuid;
BEGIN

    /* ========================================================
       AUTENTICACIÓN
       ======================================================== */

    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'USUARIO_NO_AUTENTICADO';
    END IF;


    /* ========================================================
       AUTORIZACIÓN
       ======================================================== */

    IF NOT public.usuario_tiene_permiso(
        v_usuario_id,
        'reservas.consumir'
    ) THEN
        RAISE EXCEPTION
            'PERMISO_DENEGADO: reservas.consumir';
    END IF;


    /* ========================================================
       VALIDACIÓN
       ======================================================== */

    IF p_reserva_id IS NULL THEN
        RAISE EXCEPTION 'RESERVA_REQUERIDA';
    END IF;

    IF p_costo_unitario IS NOT NULL
       AND p_costo_unitario < 0 THEN
        RAISE EXCEPTION 'COSTO_UNITARIO_INVALIDO';
    END IF;


    /* ========================================================
       BLOQUEAR RESERVA
       ======================================================== */

    SELECT r.*
    INTO v_reserva
    FROM public.reservas AS r
    WHERE r.id = p_reserva_id
    FOR UPDATE;


    IF v_reserva.id IS NULL THEN
        RAISE EXCEPTION 'RESERVA_NO_ENCONTRADA';
    END IF;


    /* ========================================================
       VALIDAR ESTADO
       ======================================================== */

    IF v_reserva.estado <> 'ACTIVA' THEN
        RAISE EXCEPTION
            'RESERVA_NO_ACTIVA: estado=%',
            v_reserva.estado;
    END IF;


    /* ========================================================
       VALIDAR ACCESO A LA UBICACIÓN
       ======================================================== */

    IF NOT public.usuario_tiene_ubicacion(
        v_usuario_id,
        v_reserva.ubicacion_id
    ) THEN
        RAISE EXCEPTION 'ACCESO_UBICACION_DENEGADO';
    END IF;


    /* ========================================================
       OBTENER Y BLOQUEAR EXISTENCIA
       ======================================================== */

    v_existencia :=
        private.obtener_existencia_bloqueada(
            v_reserva.producto_id,
            v_reserva.ubicacion_id,
            v_usuario_id
        );


    /* ========================================================
       VALIDAR STOCK
       ======================================================== */

    IF v_existencia.stock_reservado < v_reserva.cantidad THEN
        RAISE EXCEPTION
            'STOCK_RESERVADO_INSUFICIENTE';
    END IF;

    IF v_existencia.stock_fisico < v_reserva.cantidad THEN
        RAISE EXCEPTION
            'STOCK_FISICO_INSUFICIENTE';
    END IF;


    /* ========================================================
       CALCULAR NUEVOS VALORES
       ======================================================== */

    v_nuevo_stock :=
        v_existencia.stock_fisico - v_reserva.cantidad;

    v_nuevo_reservado :=
        v_existencia.stock_reservado - v_reserva.cantidad;

    v_nuevo_disponible :=
        v_nuevo_stock - v_nuevo_reservado;


    /* ========================================================
       ACTUALIZAR EXISTENCIA
       ======================================================== */

    UPDATE public.existencias
    SET
        stock_fisico = v_nuevo_stock,
        stock_reservado = v_nuevo_reservado,
        stock_disponible = v_nuevo_disponible,
        fecha_ultimo_movimiento = now(),
        actualizado_por = v_usuario_id,
        fecha_actualizacion = now()
    WHERE id = v_existencia.id;


    /* ========================================================
       REGISTRAR MOVIMIENTO
       ======================================================== */

    INSERT INTO public.movimientos (
        producto_id,
        ubicacion_id,
        tipo_movimiento,
        cantidad,
        stock_anterior,
        stock_posterior,
        costo_unitario,
        costo_total,
        origen,
        referencia_tipo,
        referencia_id,
        referencia_numero,
        observaciones,
        usuario_id
    )
    VALUES (
        v_reserva.producto_id,
        v_reserva.ubicacion_id,
        'SALIDA',
        v_reserva.cantidad,
        v_existencia.stock_fisico,
        v_nuevo_stock,
        p_costo_unitario,
        CASE
            WHEN p_costo_unitario IS NOT NULL
            THEN v_reserva.cantidad * p_costo_unitario
            ELSE NULL
        END,
        v_reserva.origen,
        v_reserva.referencia_tipo,
        v_reserva.referencia_id,
        v_reserva.referencia_numero,
        p_observaciones,
        v_usuario_id
    )
    RETURNING id
    INTO v_movimiento_id;


    /* ========================================================
       CONSUMIR RESERVA
       ======================================================== */

    UPDATE public.reservas
    SET
        estado = 'CONSUMIDA',
        fecha_consumo = now(),
        consumida_por = v_usuario_id,
        fecha_actualizacion = now()
    WHERE id = v_reserva.id;


    /* ========================================================
       RESULTADO
       ======================================================== */

    RETURN v_movimiento_id;

END;
$function$;

CREATE OR REPLACE FUNCTION public.crear_orden_compra(p_proveedor_id uuid, p_fecha_esperada date, p_observaciones text, p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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

CREATE OR REPLACE FUNCTION public.crear_pedido_ecommerce(p_items jsonb, p_metodo_entrega character varying, p_metodo_pago character varying)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user uuid := auth.uid();
  v_ubicacion uuid;
  v_maximo_por_linea numeric := 100;
  v_profile record;
  v_item jsonb;
  v_producto record;
  v_stock numeric;
  v_cantidad numeric;
  v_precio_original numeric;
  v_descuento_porcentaje numeric;
  v_precio numeric;
  v_total numeric := 0;
  v_pedido uuid;
  v_grupo_movimiento uuid := gen_random_uuid();
  v_numero varchar;
  v_direccion jsonb;
  v_costo_envio numeric := 0;
  v_expiracion timestamptz := now() + interval '15 minutes';
begin
  if v_user is null then raise exception 'Debes iniciar sesión para finalizar tu pedido'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'El carrito está vacío'; end if;
  if p_metodo_pago is distinct from 'CONTRA_ENTREGA' then raise exception 'Selecciona pago contra entrega'; end if;
  if p_metodo_entrega not in ('RETIRO_TIENDA','DOMICILIO') then raise exception 'Selecciona cómo deseas recibir tu pedido'; end if;
  select ubicacion_ecommerce_id, greatest(1, coalesce(max_cantidad_por_linea, 100))
  into v_ubicacion, v_maximo_por_linea
  from configuracion_ecommerce
  where id = true;
  if v_ubicacion is null then raise exception 'Configura la sucursal de ecommerce antes de recibir pedidos'; end if;

  -- Marca sólo esta transacción confiable para que el trigger de existencias
  -- pueda actualizar alertas sin conceder permisos administrativos al cliente.
  perform set_config('sanmartin.ecommerce_checkout', 'true', true);

  select * into v_profile from perfiles where id = v_user;
  if p_metodo_entrega = 'DOMICILIO' and (v_profile.direccion_completa is null or v_profile.departamento is null or v_profile.municipio is null) then
    raise exception 'Agrega tu dirección de entrega antes de finalizar el pedido';
  end if;
  v_direccion := case when p_metodo_entrega = 'DOMICILIO' then jsonb_build_object('nombre',v_profile.nombre_direccion,'departamento',v_profile.departamento,'municipio',v_profile.municipio,'direccion_completa',v_profile.direccion_completa,'referencia',v_profile.referencia_direccion) else jsonb_build_object('tipo','RETIRO_TIENDA','ubicacion_id',v_ubicacion) end;
  v_numero := 'EC-' || to_char(current_date,'YYYYMMDD') || '-' || nextval('public.pedidos_ecommerce_numero_seq')::text;

  -- El ERP define los valores permitidos para estado y método de entrega.
  -- Se usan sus valores por defecto para no imponer un texto inválido desde la tienda.
  insert into pedidos_ecommerce(numero,ubicacion_id,total,cliente_id,direccion_envio,costo_envio,metodo_entrega,metodo_pago)
  values(v_numero,v_ubicacion,0,v_user,v_direccion,v_costo_envio,p_metodo_entrega,p_metodo_pago) returning id into v_pedido;

  for v_item in select * from jsonb_array_elements(p_items) loop
    if jsonb_typeof(v_item->'cantidad') <> 'number' then raise exception 'La cantidad debe ser un número válido'; end if;
    v_cantidad := (v_item->>'cantidad')::numeric;
    if v_cantidad <= 0 then raise exception 'La cantidad debe ser mayor que cero'; end if;
    select p.id,p.nombre,p.precio_base,p.venta_fraccionada,
           coalesce(u.permite_fraccion,false) as permite_fraccion,
           greatest(0,least(6,coalesce(u.decimales_permitidos,0))) as decimales_permitidos
    into v_producto
    from productos p
    left join unidades_medida u on u.id=p.unidad_medida_id and u.activo=true
    where p.id = (v_item->>'producto_id')::uuid and p.activo=true and p.es_vendible=true and p.es_comprable=true and p.publicado_ecommerce=true and p.visible_ecommerce=true;
    if not found then raise exception 'Uno de los productos ya no está disponible'; end if;
    if v_cantidad > v_maximo_por_linea then raise exception 'La cantidad máxima por producto es de %', v_maximo_por_linea; end if;
    if not (coalesce(v_producto.venta_fraccionada,false) and coalesce(v_producto.permite_fraccion,false)) and v_cantidad <> trunc(v_cantidad) then
      raise exception '% solo se vende en unidades completas', v_producto.nombre;
    end if;
    if coalesce(v_producto.venta_fraccionada,false) and coalesce(v_producto.permite_fraccion,false) and round(v_cantidad,v_producto.decimales_permitidos::integer) <> v_cantidad then
      raise exception '% permite un máximo de % decimales', v_producto.nombre, v_producto.decimales_permitidos;
    end if;
    select stock_disponible into v_stock from existencias where producto_id=v_producto.id and ubicacion_id=v_ubicacion and activo=true for update;
    if coalesce(v_stock,0) < v_cantidad then raise exception 'Stock insuficiente para %',v_producto.nombre; end if;
    v_precio_original := v_producto.precio_base;
    select oferta_porcentaje into v_descuento_porcentaje from ofertas_producto where producto_id=v_producto.id and activo=true and aplica_ecommerce=true and fecha_inicio<=now() and (fecha_fin is null or fecha_fin>=now()) order by oferta_porcentaje desc limit 1;
    v_descuento_porcentaje := case when v_descuento_porcentaje between 0 and 100 then v_descuento_porcentaje else 0 end;
    v_precio := round(v_precio_original*(1-coalesce(v_descuento_porcentaje,0)/100),2);
    insert into pedidos_ecommerce_detalle(pedido_id,producto_id,cantidad,precio_unitario,total_linea) values(v_pedido,v_producto.id,v_cantidad,v_precio,round(v_precio*v_cantidad,2));
    -- El checkout reserva, pero no descuenta físico hasta confirmar el pedido.
    update existencias
    set stock_reservado=stock_reservado+v_cantidad,
        stock_disponible=stock_disponible-v_cantidad,
        fecha_ultimo_movimiento=now(),
        fecha_actualizacion=now()
    where producto_id=v_producto.id and ubicacion_id=v_ubicacion and activo=true;
    insert into reservas(producto_id,ubicacion_id,cantidad,estado,origen,referencia_tipo,referencia_id,referencia_numero,fecha_reserva,fecha_expiracion,creado_por,fecha_creacion,fecha_actualizacion)
    values(v_producto.id,v_ubicacion,v_cantidad,'ACTIVA','ECOMMERCE','PEDIDO_ECOMMERCE',v_pedido,v_numero,now(),v_expiracion,v_user,now(),now());
    insert into movimientos(producto_id,ubicacion_id,tipo_movimiento,cantidad,stock_anterior,stock_posterior,origen,referencia_tipo,referencia_id,referencia_numero,grupo_movimiento_id,usuario_id,fecha_movimiento)
    values(v_producto.id,v_ubicacion,'RESERVA',v_cantidad,v_stock,v_stock-v_cantidad,'ECOMMERCE','PEDIDO_ECOMMERCE',v_pedido,v_numero,v_grupo_movimiento,v_user,now());
    v_total := v_total + round(v_precio*v_cantidad,2);
  end loop;
  if p_metodo_entrega = 'DOMICILIO' and v_total < 100 then
    raise exception 'El pedido mínimo para envío a domicilio es de Q100.00';
  end if;
  if p_metodo_entrega = 'RETIRO_TIENDA' and v_total < 1 then
    raise exception 'El pedido mínimo para recoger en tienda es de Q1.00';
  end if;

  if p_metodo_entrega = 'DOMICILIO' and v_total <= 200 then
    v_costo_envio := 25;
  end if;
  v_total := v_total + v_costo_envio;
  update pedidos_ecommerce set total=v_total, costo_envio=v_costo_envio where id=v_pedido;
  return jsonb_build_object('pedido_id',v_pedido,'numero',v_numero,'total',v_total,'costo_envio',v_costo_envio);
end; $function$;

CREATE OR REPLACE FUNCTION public.crear_perfil_cliente()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- Solo se escriben los datos propios del cliente. estado, activo, rol_id y
  -- demás campos administrativos se resuelven con los defaults de perfiles.
  insert into public.perfiles (id, correo, nombre, apellido, telefono)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'nombre', ''),
    coalesce(new.raw_user_meta_data->>'apellido', ''),
    coalesce(new.raw_user_meta_data->>'telefono', '')
  )
  on conflict (id) do nothing;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.crear_reserva(p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_origen character varying, p_referencia_tipo character varying DEFAULT NULL::character varying, p_referencia_id uuid DEFAULT NULL::uuid, p_referencia_numero character varying DEFAULT NULL::character varying, p_fecha_expiracion timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario_id uuid;
    v_existencia public.existencias;
    v_nuevo_reservado numeric;
    v_nuevo_disponible numeric;
    v_reserva_id uuid;
BEGIN

    /* ========================================================
       AUTENTICACIÓN
       ======================================================== */

    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'USUARIO_NO_AUTENTICADO';
    END IF;


    /* ========================================================
       AUTORIZACIÓN
       ======================================================== */

    IF NOT public.usuario_tiene_permiso(
        v_usuario_id,
        'reservas.crear'
    ) THEN
        RAISE EXCEPTION
            'PERMISO_DENEGADO: reservas.crear';
    END IF;


    /* ========================================================
       VALIDACIÓN BÁSICA
       ======================================================== */

    IF p_producto_id IS NULL THEN
        RAISE EXCEPTION 'PRODUCTO_REQUERIDO';
    END IF;

    IF p_ubicacion_id IS NULL THEN
        RAISE EXCEPTION 'UBICACION_REQUERIDA';
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'CANTIDAD_INVALIDA';
    END IF;

    IF p_origen IS NULL OR btrim(p_origen) = '' THEN
        RAISE EXCEPTION 'ORIGEN_REQUERIDO';
    END IF;


    /* ========================================================
       ACCESO A LA UBICACIÓN
       ======================================================== */

    IF NOT public.usuario_tiene_ubicacion(
        v_usuario_id,
        p_ubicacion_id
    ) THEN
        RAISE EXCEPTION 'ACCESO_UBICACION_DENEGADO';
    END IF;


    /* ========================================================
       OBTENER Y BLOQUEAR EXISTENCIA
       ======================================================== */

    v_existencia :=
        private.obtener_existencia_bloqueada(
            p_producto_id,
            p_ubicacion_id,
            v_usuario_id
        );


    /* ========================================================
       VALIDAR STOCK DISPONIBLE
       ======================================================== */

    IF v_existencia.stock_disponible < p_cantidad THEN
        RAISE EXCEPTION
            'STOCK_INSUFICIENTE: disponible=% solicitado=%',
            v_existencia.stock_disponible,
            p_cantidad;
    END IF;


    /* ========================================================
       CALCULAR RESERVA Y DISPONIBLE
       ======================================================== */

    v_nuevo_reservado :=
        v_existencia.stock_reservado + p_cantidad;

    v_nuevo_disponible :=
        v_existencia.stock_fisico - v_nuevo_reservado;


    /* ========================================================
       ACTUALIZAR EXISTENCIA
       ======================================================== */

    UPDATE public.existencias
    SET
        stock_reservado = v_nuevo_reservado,
        stock_disponible = v_nuevo_disponible,
        actualizado_por = v_usuario_id,
        fecha_actualizacion = now()
    WHERE id = v_existencia.id;


    /* ========================================================
       CREAR RESERVA
       ======================================================== */

    INSERT INTO public.reservas (
        producto_id,
        ubicacion_id,
        cantidad,
        estado,
        origen,
        referencia_tipo,
        referencia_id,
        referencia_numero,
        fecha_expiracion,
        creado_por
    )
    VALUES (
        p_producto_id,
        p_ubicacion_id,
        p_cantidad,
        'ACTIVA',
        p_origen,
        p_referencia_tipo,
        p_referencia_id,
        p_referencia_numero,
        p_fecha_expiracion,
        v_usuario_id
    )
    RETURNING id
    INTO v_reserva_id;


    /* ========================================================
       RESULTADO
       ======================================================== */

    RETURN v_reserva_id;

END;
$function$;

CREATE OR REPLACE FUNCTION public.encolar_alerta_inventario_ecommerce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.activa and (tg_op='INSERT' or old.activa=false or old.estado is distinct from new.estado) then
    insert into public.notificaciones_operativas_ecommerce(tipo,prioridad,alerta_inventario_id,ubicacion_id,payload)
    values('INVENTARIO_BAJO',case when new.estado='SIN_STOCK' then 'ALTA' else 'NORMAL' end,new.id,new.ubicacion_id,jsonb_build_object('estado',new.estado,'producto_id',new.producto_id));
  end if;
  return new;
end; $function$;

CREATE OR REPLACE FUNCTION public.encolar_alerta_pedido_ecommerce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_op='INSERT' then
    insert into public.notificaciones_operativas_ecommerce(tipo,prioridad,pedido_id,ubicacion_id,payload)
    values('PEDIDO_NUEVO','ALTA',new.id,new.ubicacion_id,jsonb_build_object('numero',new.numero,'total',new.total,'metodo_entrega',new.metodo_entrega));
  elsif new.estado='CONFIRMADO' and old.estado is distinct from new.estado then
    insert into public.notificaciones_operativas_ecommerce(tipo,prioridad,pedido_id,ubicacion_id,payload)
    values('PEDIDO_POR_PREPARAR','ALTA',new.id,new.ubicacion_id,jsonb_build_object('numero',new.numero,'estado',new.estado));
  end if;
  return new;
end; $function$;

CREATE OR REPLACE FUNCTION public.erp_accion_pedido(p_pedido_id uuid, p_accion text, p_motivo text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare pedido public.pedidos_ecommerce%rowtype; siguiente text;
begin
 select * into pedido from public.pedidos_ecommerce where id=p_pedido_id for update;
 if not found then raise exception 'Pedido no encontrado'; end if;
 if auth.uid() is null or not coalesce(public.tiene_permiso('productos.editar'),false)
 or not coalesce(public.tiene_acceso_ubicacion(pedido.ubicacion_id),false) then
 raise exception 'Necesitas productos.editar y acceso a la ubicación del pedido' using errcode='42501'; end if;
 -- Orden de bloqueos consistente con las funciones locales de pago/cancelación.
 perform id from public.reservas where referencia_id=p_pedido_id for update;
 if p_accion='PAGAR' then
 if pedido.estado <> 'RESERVADO' then raise exception 'Solo se confirma pago de pedidos reservados'; end if;
 if not exists(select 1 from public.pedidos_ecommerce_detalle where pedido_id=p_pedido_id)
 or not exists(select 1 from public.reservas where referencia_id=p_pedido_id) then
 raise exception 'El pedido no tiene detalle o reservas vinculadas. Revisa el checkout; no se confirmó el pago'; end if;
 if exists(select 1 from public.reservas where referencia_id=p_pedido_id and
 (estado <> 'ACTIVA' or ubicacion_id <> pedido.ubicacion_id or (fecha_expiracion is not null and fecha_expiracion <= now()))) then
 raise exception 'Hay reservas vencidas, inactivas o de otra ubicación. No se confirmó el pago'; end if;
 if exists(
 with detalles as (select producto_id,sum(cantidad) cantidad from public.pedidos_ecommerce_detalle where pedido_id=p_pedido_id group by producto_id),
 retenidas as (select producto_id,sum(cantidad) cantidad from public.reservas where referencia_id=p_pedido_id and estado='ACTIVA' group by producto_id)
 select 1 from detalles d full join retenidas r using(producto_id) where d.cantidad is distinct from r.cantidad
 ) then raise exception 'Las cantidades reservadas no coinciden con el pedido'; end if;
 perform public.confirmar_pago_ecommerce(p_pedido_id);
 elsif p_accion='CANCELAR' then
 if pedido.estado <> 'RESERVADO' then raise exception 'Un pedido pagado requiere devolución/reembolso; no se cancela por este flujo'; end if;
 perform public.cancelar_pedido_ecommerce(p_pedido_id,p_motivo);
 update public.pedidos_ecommerce set estado_entrega='CANCELADO' where id=p_pedido_id;
 else
 if pedido.estado <> 'PAGADO' then raise exception 'Confirma el pago antes de actualizar la entrega'; end if;
 siguiente := case pedido.estado_entrega when 'PENDIENTE' then 'PREPARADO' when 'PREPARADO' then 'ENVIADO' when 'ENVIADO' then 'ENTREGADO' else null end;
 if p_accion is distinct from siguiente then raise exception 'Transición de entrega no permitida'; end if;
 update public.pedidos_ecommerce set estado_entrega=p_accion,
 fecha_preparado=case when p_accion='PREPARADO' then now() else fecha_preparado end,
 fecha_envio=case when p_accion='ENVIADO' then now() else fecha_envio end,
 fecha_entrega=case when p_accion='ENTREGADO' then now() else fecha_entrega end where id=p_pedido_id;
 end if;
 return jsonb_build_object('id',p_pedido_id,'accion',p_accion);
end $function$;

CREATE OR REPLACE FUNCTION public.erp_buscar_existencias(p_busqueda text DEFAULT ''::text, p_offset integer DEFAULT 0, p_limite integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.erp_confirmar_borrado_imagen_producto(p_imagen_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.erp_confirmar_carga_imagen_producto(p_imagen_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.erp_confirmar_orden_compra(p_orden_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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

CREATE OR REPLACE FUNCTION public.erp_detalle_reservas_pedido(p_pedido_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare pedido public.pedidos_ecommerce%rowtype; resultado jsonb;
begin
 select * into pedido from public.pedidos_ecommerce where id=p_pedido_id;
 if not found then raise exception 'Pedido no encontrado'; end if;
 if auth.uid() is null or not coalesce(public.tiene_permiso('productos.ver'),false)
 or not coalesce(public.tiene_acceso_ubicacion(pedido.ubicacion_id),false) then
 raise exception 'Necesitas productos.ver y acceso a la ubicación del pedido' using errcode='42501'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('producto_id',r.producto_id,'ubicacion_id',r.ubicacion_id,
 'estado',r.estado,'cantidad',r.cantidad,'fecha_reserva',r.fecha_reserva,'fecha_expiracion',r.fecha_expiracion,
 'fecha_liberacion',r.fecha_liberacion,'fecha_consumo',r.fecha_consumo,'referencia_tipo',r.referencia_tipo,
 'productos',jsonb_build_object('nombre',p.nombre,'sku',p.sku)) order by r.fecha_reserva),'[]'::jsonb)
 into resultado from public.reservas r left join public.productos p on p.id=r.producto_id where r.referencia_id=p_pedido_id;
 return resultado;
end $function$;

CREATE OR REPLACE FUNCTION public.erp_emitir_comprobante_interno(p_pedido_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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

CREATE OR REPLACE FUNCTION public.erp_factura_al_confirmar_pago()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.estado = 'PAGADO' then perform public.erp_emitir_comprobante_interno(new.id); end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.erp_finalizar_envio_alerta(p_alerta_id uuid, p_lote uuid, p_email_id text DEFAULT NULL::text, p_error text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.erp_guardar_permisos_rol(p_rol_id uuid, p_permiso_ids uuid[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.erp_organizar_imagenes_producto(p_producto_id uuid, p_imagen_ids uuid[], p_principal_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.erp_preparar_borrado_imagen_producto(p_imagen_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.erp_preparar_envio_alerta(p_alerta_id uuid, p_lote uuid, p_remitente text, p_destinatarios text[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.erp_recibir_orden_compra(p_recepcion_id uuid, p_orden_id uuid, p_ubicacion_id uuid, p_documento character varying, p_observaciones text, p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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

CREATE OR REPLACE FUNCTION public.erp_reclamar_alertas(p_lote uuid, p_limite integer DEFAULT 20)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.erp_reservar_imagen_producto(p_producto_id uuid, p_storage_path text, p_nombre_archivo text, p_mime_type text, p_tamano_bytes bigint, p_url_publica text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.erp_resumen_kardex(p_producto_id uuid, p_ubicacion_id uuid DEFAULT NULL::uuid, p_fecha_desde timestamp with time zone DEFAULT (now() - '30 days'::interval), p_fecha_hasta timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.erp_resumen_operativo(p_fecha_desde timestamp with time zone DEFAULT (now() - '30 days'::interval), p_fecha_hasta timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.erp_sincronizar_facturas_ecommerce()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_pedido record; v_total integer := 0;
begin
  if auth.uid() is null or not coalesce(public.tiene_permiso('productos.ver'),false) then
    raise exception 'No tienes permiso para consultar pedidos.';
  end if;
  for v_pedido in select p.id from public.pedidos_ecommerce p
    where p.estado='PAGADO' and public.tiene_acceso_ubicacion(p.ubicacion_id)
    and not exists(select 1 from public.facturas_ecommerce f where f.pedido_id=p.id)
    order by p.id
  loop
    perform public.erp_emitir_comprobante_interno(v_pedido.id); v_total:=v_total+1;
  end loop;
  return v_total;
end;
$function$;

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

CREATE OR REPLACE FUNCTION public.es_administrador()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN

    RETURN public.obtener_rol_actual() = 'ADMINISTRADOR';

END;
$function$;

CREATE OR REPLACE FUNCTION public.estado_disponibilidad_ecommerce(p_producto_id uuid)
 RETURNS TABLE(estado text, mensaje text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_ubicacion uuid; v_stock numeric := 0; v_umbral numeric := 5;
begin
  select ubicacion_ecommerce_id,greatest(1,coalesce(umbral_pocas_unidades,5)) into v_ubicacion,v_umbral from public.configuracion_ecommerce where id=true;
  if v_ubicacion is null then return query select 'AGOTADO'::text,'No disponible por el momento'::text; return; end if;
  select coalesce(stock_disponible,0) into v_stock from public.existencias where producto_id=p_producto_id and ubicacion_id=v_ubicacion and activo=true;
  if coalesce(v_stock,0)<=0 then return query select 'AGOTADO'::text,'Agotado por el momento'::text;
  elsif v_stock<=v_umbral then return query select 'POCAS_UNIDADES'::text,'Pocas unidades disponibles'::text;
  else return query select 'DISPONIBLE'::text,'Disponible para comprar'::text; end if;
end; $function$;

CREATE OR REPLACE FUNCTION public.generar_alertas_inventario()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.liberar_reserva(p_reserva_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario_id uuid;
    v_reserva public.reservas;
    v_existencia public.existencias;
BEGIN

    /* ========================================================
       AUTENTICACIÓN
       ======================================================== */

    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'USUARIO_NO_AUTENTICADO';
    END IF;


    /* ========================================================
       AUTORIZACIÓN
       ======================================================== */

    IF NOT public.usuario_tiene_permiso(
        v_usuario_id,
        'reservas.liberar'
    ) THEN
        RAISE EXCEPTION
            'PERMISO_DENEGADO: reservas.liberar';
    END IF;


    /* ========================================================
       VALIDACIÓN
       ======================================================== */

    IF p_reserva_id IS NULL THEN
        RAISE EXCEPTION 'RESERVA_REQUERIDA';
    END IF;


    /* ========================================================
       BLOQUEAR RESERVA
       ======================================================== */

    SELECT r.*
    INTO v_reserva
    FROM public.reservas AS r
    WHERE r.id = p_reserva_id
    FOR UPDATE;


    IF v_reserva.id IS NULL THEN
        RAISE EXCEPTION 'RESERVA_NO_ENCONTRADA';
    END IF;


    /* ========================================================
       VALIDAR ESTADO
       ======================================================== */

    IF v_reserva.estado <> 'ACTIVA' THEN
        RAISE EXCEPTION
            'RESERVA_NO_ACTIVA: estado=%',
            v_reserva.estado;
    END IF;


    /* ========================================================
       VALIDAR ACCESO A LA UBICACIÓN
       ======================================================== */

    IF NOT public.usuario_tiene_ubicacion(
        v_usuario_id,
        v_reserva.ubicacion_id
    ) THEN
        RAISE EXCEPTION 'ACCESO_UBICACION_DENEGADO';
    END IF;


    /* ========================================================
       OBTENER Y BLOQUEAR EXISTENCIA
       ======================================================== */

    v_existencia :=
        private.obtener_existencia_bloqueada(
            v_reserva.producto_id,
            v_reserva.ubicacion_id,
            v_usuario_id
        );


    /* ========================================================
       VALIDAR STOCK RESERVADO
       ======================================================== */

    IF v_existencia.stock_reservado < v_reserva.cantidad THEN
        RAISE EXCEPTION
            'STOCK_RESERVADO_INSUFICIENTE';
    END IF;


    /* ========================================================
       LIBERAR STOCK RESERVADO
       ======================================================== */

    UPDATE public.existencias
    SET
        stock_reservado =
            stock_reservado - v_reserva.cantidad,
        stock_disponible =
            stock_fisico -
            (stock_reservado - v_reserva.cantidad),
        actualizado_por = v_usuario_id,
        fecha_actualizacion = now()
    WHERE id = v_existencia.id;


    /* ========================================================
       ACTUALIZAR RESERVA
       ======================================================== */

    UPDATE public.reservas
    SET
        estado = 'LIBERADA',
        fecha_liberacion = now(),
        liberada_por = v_usuario_id,
        fecha_actualizacion = now()
    WHERE id = v_reserva.id;


    /* ========================================================
       RESULTADO
       ======================================================== */

    RETURN true;

END;
$function$;

CREATE OR REPLACE FUNCTION public.liberar_reservas_expiradas()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.obtener_rol_actual()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_rol TEXT;
BEGIN

    SELECT r.codigo
    INTO v_rol

    FROM public.perfiles p

    INNER JOIN public.roles r
        ON r.id = p.rol_id

    WHERE p.id = (SELECT auth.uid())
      AND p.estado = 'ACTIVO'
      AND p.activo = TRUE
      AND r.activo = TRUE

    LIMIT 1;


    RETURN v_rol;

END;
$function$;

CREATE OR REPLACE FUNCTION public.procesar_estado_pedido_ecommerce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record; v_stock numeric;
begin
  if new.estado=old.estado then return new; end if;
  if new.estado='CONFIRMADO' then
    for r in select * from public.reservas where referencia_id=new.id and estado='ACTIVA' for update loop
      if r.fecha_expiracion<=now() then raise exception 'La reserva del pedido % venció; valida inventario nuevamente',new.numero; end if;
      select stock_fisico into v_stock from public.existencias where producto_id=r.producto_id and ubicacion_id=r.ubicacion_id and activo=true for update;
      update public.existencias set stock_fisico=stock_fisico-r.cantidad,stock_reservado=stock_reservado-r.cantidad,fecha_ultimo_movimiento=now(),fecha_actualizacion=now() where producto_id=r.producto_id and ubicacion_id=r.ubicacion_id and activo=true;
      update public.reservas set estado='CONSUMIDA',fecha_consumo=now(),fecha_actualizacion=now() where id=r.id;
      insert into public.movimientos(producto_id,ubicacion_id,tipo_movimiento,cantidad,stock_anterior,stock_posterior,origen,referencia_tipo,referencia_id,referencia_numero,grupo_movimiento_id,usuario_id,fecha_movimiento) values(r.producto_id,r.ubicacion_id,'SALIDA',r.cantidad,v_stock,v_stock-r.cantidad,'ECOMMERCE','PEDIDO_ECOMMERCE',new.id,new.numero,gen_random_uuid(),auth.uid(),now());
    end loop;
  elsif new.estado='CANCELADO' then
    for r in select * from public.reservas where referencia_id=new.id and estado='ACTIVA' for update loop
      update public.existencias set stock_reservado=stock_reservado-r.cantidad,stock_disponible=stock_disponible+r.cantidad,fecha_actualizacion=now() where producto_id=r.producto_id and ubicacion_id=r.ubicacion_id and activo=true;
      update public.reservas set estado='LIBERADA',fecha_liberacion=now(),fecha_actualizacion=now() where id=r.id;
    end loop;
  end if;
  return new;
end; $function$;

CREATE OR REPLACE FUNCTION public.registrar_auditoria()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_old jsonb; v_new jsonb; v_id uuid;
begin
  if tg_op='DELETE' then v_old:=to_jsonb(old);v_new:=null;v_id:=old.id;
  else v_new:=to_jsonb(new);v_id:=new.id;if tg_op='UPDATE' then v_old:=to_jsonb(old);end if;end if;
  insert into public.auditoria(tabla,accion,registro_id,datos_anteriores,datos_nuevos,usuario_id)
  values(tg_table_name,tg_op,v_id,v_old,v_new,auth.uid());
  return coalesce(new,old);
end;$function$;

CREATE OR REPLACE FUNCTION public.registrar_conteo_inventario(p_producto_id uuid, p_ubicacion_id uuid, p_stock_contado numeric, p_observaciones text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.registrar_devolucion_venta(p_canal character varying, p_referencia_venta character varying, p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_motivo character varying, p_observaciones text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.registrar_entrada(p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_origen character varying, p_referencia_tipo character varying DEFAULT NULL::character varying, p_referencia_id uuid DEFAULT NULL::uuid, p_referencia_numero character varying DEFAULT NULL::character varying, p_costo_unitario numeric DEFAULT NULL::numeric, p_observaciones text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario_id uuid;
    v_existencia public.existencias;
    v_nuevo_stock numeric;
    v_movimiento_id uuid;
BEGIN

    /* ========================================================
       AUTENTICACIÓN
       ======================================================== */

    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'USUARIO_NO_AUTENTICADO';
    END IF;


    /* ========================================================
       AUTORIZACIÓN
       ======================================================== */

    IF NOT public.usuario_tiene_permiso(
        v_usuario_id,
        'entradas.crear'
    ) THEN
        RAISE EXCEPTION 'PERMISO_DENEGADO: entradas.crear';
    END IF;


    /* ========================================================
       VALIDACIÓN BÁSICA
       ======================================================== */

    IF p_producto_id IS NULL THEN
        RAISE EXCEPTION 'PRODUCTO_REQUERIDO';
    END IF;

    IF p_ubicacion_id IS NULL THEN
        RAISE EXCEPTION 'UBICACION_REQUERIDA';
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'CANTIDAD_INVALIDA';
    END IF;

    IF p_origen IS NULL OR btrim(p_origen) = '' THEN
        RAISE EXCEPTION 'ORIGEN_REQUERIDO';
    END IF;

    IF p_costo_unitario IS NOT NULL
       AND p_costo_unitario < 0 THEN
        RAISE EXCEPTION 'COSTO_UNITARIO_INVALIDO';
    END IF;


    /* ========================================================
       ACCESO A LA UBICACIÓN
       ======================================================== */

    IF NOT public.usuario_tiene_ubicacion(
        v_usuario_id,
        p_ubicacion_id
    ) THEN
        RAISE EXCEPTION 'ACCESO_UBICACION_DENEGADO';
    END IF;


    /* ========================================================
       OBTENER Y BLOQUEAR EXISTENCIA
       ======================================================== */

    v_existencia :=
        private.obtener_existencia_bloqueada(
            p_producto_id,
            p_ubicacion_id,
            v_usuario_id
        );


    /* ========================================================
       CALCULAR NUEVO STOCK
       ======================================================== */

    v_nuevo_stock :=
        v_existencia.stock_fisico + p_cantidad;


    /* ========================================================
       ACTUALIZAR EXISTENCIA
       ======================================================== */

    UPDATE public.existencias
    SET
        stock_fisico = v_nuevo_stock,
        stock_disponible =
            v_nuevo_stock - stock_reservado,
        fecha_ultimo_movimiento = now(),
        actualizado_por = v_usuario_id,
        fecha_actualizacion = now()
    WHERE id = v_existencia.id;


    /* ========================================================
       REGISTRAR MOVIMIENTO
       ======================================================== */

    INSERT INTO public.movimientos (
        producto_id,
        ubicacion_id,
        tipo_movimiento,
        cantidad,
        stock_anterior,
        stock_posterior,
        costo_unitario,
        costo_total,
        origen,
        referencia_tipo,
        referencia_id,
        referencia_numero,
        observaciones,
        usuario_id
    )
    VALUES (
        p_producto_id,
        p_ubicacion_id,
        'ENTRADA',
        p_cantidad,
        v_existencia.stock_fisico,
        v_nuevo_stock,
        p_costo_unitario,
        CASE
            WHEN p_costo_unitario IS NOT NULL
            THEN p_cantidad * p_costo_unitario
            ELSE NULL
        END,
        p_origen,
        p_referencia_tipo,
        p_referencia_id,
        p_referencia_numero,
        p_observaciones,
        v_usuario_id
    )
    RETURNING id
    INTO v_movimiento_id;


    /* ========================================================
       RESULTADO
       ======================================================== */

    RETURN v_movimiento_id;

END;
$function$;

CREATE OR REPLACE FUNCTION public.registrar_entrada_con_costo(p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_costo_unitario numeric, p_origen character varying, p_referencia_numero character varying DEFAULT NULL::character varying, p_observaciones text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.registrar_movimiento_inventario(p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_tipo_movimiento text, p_origen text DEFAULT 'MANUAL'::text, p_referencia_tipo text DEFAULT NULL::text, p_referencia_id uuid DEFAULT NULL::uuid, p_referencia_numero text DEFAULT NULL::text, p_observaciones text DEFAULT NULL::text, p_costo_unitario numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    begin
      perform erp_private.require_staff('existencias.ajustar',p_ubicacion_id);
      if p_origen is distinct from 'COMPRA' or p_tipo_movimiento is distinct from 'ENTRADA' or p_cantidad is null or p_cantidad<=0 or p_cantidad::text in('NaN','Infinity','-Infinity') then
        raise exception 'Usa la RPC específica de ajustes, conteos, devolución, POS o transferencia; solo COMPRA/ENTRADA directa.' using errcode='42501';
      end if;
      if not exists(select 1 from public.ubicaciones where id=p_ubicacion_id and activo and permite_recepcion) then raise exception 'Ubicación no habilitada para recepción'; end if;
      return erp_private.registrar_movimiento_inventario(p_producto_id=>p_producto_id,p_ubicacion_id=>p_ubicacion_id,p_cantidad=>p_cantidad,p_tipo_movimiento=>p_tipo_movimiento,p_origen=>p_origen,p_referencia_tipo=>p_referencia_tipo,p_referencia_id=>p_referencia_id,p_referencia_numero=>p_referencia_numero,p_observaciones=>p_observaciones,p_costo_unitario=>p_costo_unitario);
    end $function$;

CREATE OR REPLACE FUNCTION public.registrar_salida(p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_origen character varying, p_referencia_tipo character varying DEFAULT NULL::character varying, p_referencia_id uuid DEFAULT NULL::uuid, p_referencia_numero character varying DEFAULT NULL::character varying, p_costo_unitario numeric DEFAULT NULL::numeric, p_observaciones text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_usuario_id uuid;
    v_existencia public.existencias;
    v_nuevo_stock numeric;
    v_movimiento_id uuid;
BEGIN

    /* ========================================================
       AUTENTICACIÓN
       ======================================================== */

    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'USUARIO_NO_AUTENTICADO';
    END IF;


    /* ========================================================
       AUTORIZACIÓN
       ======================================================== */

    IF NOT public.usuario_tiene_permiso(
        v_usuario_id,
        'salidas.crear'
    ) THEN
        RAISE EXCEPTION 'PERMISO_DENEGADO: salidas.crear';
    END IF;


    /* ========================================================
       VALIDACIÓN BÁSICA
       ======================================================== */

    IF p_producto_id IS NULL THEN
        RAISE EXCEPTION 'PRODUCTO_REQUERIDO';
    END IF;

    IF p_ubicacion_id IS NULL THEN
        RAISE EXCEPTION 'UBICACION_REQUERIDA';
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RAISE EXCEPTION 'CANTIDAD_INVALIDA';
    END IF;

    IF p_origen IS NULL OR btrim(p_origen) = '' THEN
        RAISE EXCEPTION 'ORIGEN_REQUERIDO';
    END IF;

    IF p_costo_unitario IS NOT NULL
       AND p_costo_unitario < 0 THEN
        RAISE EXCEPTION 'COSTO_UNITARIO_INVALIDO';
    END IF;


    /* ========================================================
       ACCESO A LA UBICACIÓN
       ======================================================== */

    IF NOT public.usuario_tiene_ubicacion(
        v_usuario_id,
        p_ubicacion_id
    ) THEN
        RAISE EXCEPTION 'ACCESO_UBICACION_DENEGADO';
    END IF;


    /* ========================================================
       OBTENER Y BLOQUEAR EXISTENCIA
       ======================================================== */

    v_existencia :=
        private.obtener_existencia_bloqueada(
            p_producto_id,
            p_ubicacion_id,
            v_usuario_id
        );


    /* ========================================================
       VALIDAR STOCK DISPONIBLE
       ======================================================== */

    IF v_existencia.stock_disponible < p_cantidad THEN
        RAISE EXCEPTION
            'STOCK_INSUFICIENTE: disponible=% solicitado=%',
            v_existencia.stock_disponible,
            p_cantidad;
    END IF;


    /* ========================================================
       CALCULAR NUEVO STOCK
       ======================================================== */

    v_nuevo_stock :=
        v_existencia.stock_fisico - p_cantidad;


    /* ========================================================
       ACTUALIZAR EXISTENCIA
       ======================================================== */

    UPDATE public.existencias
    SET
        stock_fisico = v_nuevo_stock,
        stock_disponible =
            v_nuevo_stock - stock_reservado,
        fecha_ultimo_movimiento = now(),
        actualizado_por = v_usuario_id,
        fecha_actualizacion = now()
    WHERE id = v_existencia.id;


    /* ========================================================
       REGISTRAR MOVIMIENTO
       ======================================================== */

    INSERT INTO public.movimientos (
        producto_id,
        ubicacion_id,
        tipo_movimiento,
        cantidad,
        stock_anterior,
        stock_posterior,
        costo_unitario,
        costo_total,
        origen,
        referencia_tipo,
        referencia_id,
        referencia_numero,
        observaciones,
        usuario_id
    )
    VALUES (
        p_producto_id,
        p_ubicacion_id,
        'SALIDA',
        p_cantidad,
        v_existencia.stock_fisico,
        v_nuevo_stock,
        p_costo_unitario,
        CASE
            WHEN p_costo_unitario IS NOT NULL
            THEN p_cantidad * p_costo_unitario
            ELSE NULL
        END,
        p_origen,
        p_referencia_tipo,
        p_referencia_id,
        p_referencia_numero,
        p_observaciones,
        v_usuario_id
    )
    RETURNING id
    INTO v_movimiento_id;


    /* ========================================================
       RESULTADO
       ======================================================== */

    RETURN v_movimiento_id;

END;
$function$;

CREATE OR REPLACE FUNCTION public.registrar_venta_pos(p_ubicacion_id uuid, p_items jsonb, p_numero character varying DEFAULT NULL::character varying, p_observaciones text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_venta_id uuid;
declare v_numero varchar := coalesce(p_numero,'POS-' || to_char(now(),'YYYYMMDDHH24MISSMS'));
declare v_item record;
declare v_stock numeric;
declare v_precio numeric;
declare v_total numeric := 0;
begin
  perform erp_private.require_staff('pos.vender',p_ubicacion_id);
  if not tiene_permiso('pos.vender'::text) then raise exception 'No tienes permiso para registrar ventas POS.' using errcode='P0001'; end if;
  if not exists(select 1 from ubicaciones where id=p_ubicacion_id and activo=true and permite_venta=true) then raise exception 'La ubicación no permite ventas.' using errcode='P0001'; end if;
  if p_items is null or jsonb_array_length(p_items)=0 then raise exception 'La venta debe incluir al menos un producto.' using errcode='P0001'; end if;

  insert into ventas_pos(numero,ubicacion_id,observaciones) values(v_numero,p_ubicacion_id,p_observaciones) returning id into v_venta_id;
  for v_item in select * from jsonb_to_recordset(p_items) as x(producto_id uuid,cantidad numeric,precio_unitario numeric)
  loop
    if v_item.cantidad is null or v_item.cantidad<=0 then raise exception 'Cada artículo requiere cantidad mayor que cero.' using errcode='P0001'; end if;
    select e.stock_disponible,coalesce(p.precio_base,0) into v_stock,v_precio
    from existencias e join productos p on p.id=e.producto_id
    where e.producto_id=v_item.producto_id and e.ubicacion_id=p_ubicacion_id and e.activo=true and p.activo=true and p.disponible_pos=true
    for update;
    if not found then raise exception 'Producto no disponible para POS en esta ubicación.' using errcode='P0001'; end if;
    if v_stock < v_item.cantidad then raise exception 'Stock insuficiente para producto %.',v_item.producto_id using errcode='P0001'; end if;
    v_precio := coalesce(v_item.precio_unitario,v_precio);
    insert into ventas_pos_detalle(venta_id,producto_id,cantidad,precio_unitario,total_linea)
    values(v_venta_id,v_item.producto_id,v_item.cantidad,v_precio,v_item.cantidad*v_precio);
    perform erp_private.registrar_movimiento_inventario(
      p_producto_id=>v_item.producto_id,p_ubicacion_id=>p_ubicacion_id,p_cantidad=>-v_item.cantidad,
      p_tipo_movimiento=>'SALIDA',p_origen=>'POS',p_referencia_tipo=>'venta_pos',p_referencia_numero=>v_numero,p_observaciones=>p_observaciones
    );
    v_total := v_total + v_item.cantidad*v_precio;
  end loop;
  update ventas_pos set subtotal=v_total,total=v_total where id=v_venta_id;
  return jsonb_build_object('id',v_venta_id,'numero',v_numero,'total',v_total,'estado','COMPLETADA');
end;
$function$;

CREATE OR REPLACE FUNCTION public.reservar_stock_ecommerce(p_ubicacion_id uuid, p_items jsonb, p_numero character varying DEFAULT NULL::character varying, p_observaciones text DEFAULT NULL::text, p_minutos_expiracion integer DEFAULT 30)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.sincronizar_alerta_existencia_ecommerce()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_estado varchar;
begin
  if not new.activo then
    update public.alertas_inventario set activa=false,resuelta_en=now(),fecha_actualizacion=now()
      where existencia_id=new.id and activa=true;
    return new;
  end if;
  v_estado := case
    when coalesce(new.stock_disponible,0)<=0 then 'SIN_STOCK'
    when coalesce(new.stock_disponible,0)<=coalesce(new.stock_minimo,0)
      or (coalesce(new.stock_maximo,0)>0 and new.stock_disponible<=new.stock_maximo*.40) then 'STOCK_BAJO'
    else null end;
  if v_estado is null then
    update public.alertas_inventario set activa=false,resuelta_en=now(),fecha_actualizacion=now()
      where existencia_id=new.id and activa=true;
  else
    update public.alertas_inventario set activa=false,resuelta_en=now(),fecha_actualizacion=now()
      where existencia_id=new.id and activa=true and estado<>v_estado;
    if not exists(select 1 from public.alertas_inventario where existencia_id=new.id and estado=v_estado and activa=true) then
      insert into public.alertas_inventario(existencia_id,producto_id,ubicacion_id,estado,stock_disponible,stock_minimo,stock_maximo)
      values(new.id,new.producto_id,new.ubicacion_id,v_estado,new.stock_disponible,new.stock_minimo,new.stock_maximo);
    end if;
  end if;
  return new;
end; $function$;

CREATE OR REPLACE FUNCTION public.solicitar_ajuste_inventario(p_producto_id uuid, p_ubicacion_id uuid, p_tipo character varying, p_cantidad numeric, p_motivo character varying, p_observaciones text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare result uuid;
begin
  perform erp_private.require_staff('existencias.ajustar',p_ubicacion_id);
  if auth.uid() is null then raise exception 'La solicitud requiere identidad de usuario'; end if;
  if p_tipo is null or p_tipo not in('ENTRADA','SALIDA') or p_cantidad is null or p_cantidad<=0 or p_cantidad::text in('NaN','Infinity','-Infinity') or nullif(trim(p_motivo),'') is null then raise exception 'Solicitud inválida'; end if;
  insert into public.ajustes_inventario(producto_id,ubicacion_id,tipo,cantidad,motivo,observaciones,solicitado_por,estado)
    values(p_producto_id,p_ubicacion_id,p_tipo,p_cantidad,p_motivo,p_observaciones,auth.uid(),'PENDIENTE') returning id into result;
  return result;
end $function$;

CREATE OR REPLACE FUNCTION public.suscribir_newsletter(p_correo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_correo text := lower(trim(coalesce(p_correo, '')));
begin
  if v_correo = '' or v_correo !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'Ingresa un correo electrónico válido';
  end if;

  insert into public.suscripciones_newsletter (correo, estado, origen, fecha_suscripcion, fecha_actualizacion)
  values (v_correo, 'ACTIVA', 'SITIO_WEB', now(), now())
  on conflict (correo) do update
    set estado = 'ACTIVA',
        fecha_actualizacion = now();

  return jsonb_build_object('correo', v_correo, 'estado', 'ACTIVA');
end;
$function$;

CREATE OR REPLACE FUNCTION public.tiene_acceso_ubicacion(p_ubicacion_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN

    RETURN public.usuario_tiene_ubicacion(
        (SELECT auth.uid()),
        p_ubicacion_id
    );

END;
$function$;

CREATE OR REPLACE FUNCTION public.tiene_algun_permiso(p_permisos text[])
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_permiso TEXT;
BEGIN

    IF p_permisos IS NULL
       OR array_length(p_permisos, 1) IS NULL THEN

        RETURN FALSE;

    END IF;


    FOREACH v_permiso IN ARRAY p_permisos
    LOOP

        IF public.tiene_permiso(v_permiso) THEN
            RETURN TRUE;
        END IF;

    END LOOP;


    RETURN FALSE;

END;
$function$;

CREATE OR REPLACE FUNCTION public.tiene_permiso(p_permiso_codigo text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN

    RETURN public.usuario_tiene_permiso(
        (SELECT auth.uid()),
        p_permiso_codigo
    );

END;
$function$;

CREATE OR REPLACE FUNCTION public.tiene_permisos(p_permisos text[])
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_permiso TEXT;
BEGIN

    IF p_permisos IS NULL
       OR array_length(p_permisos, 1) IS NULL THEN

        RETURN FALSE;

    END IF;


    FOREACH v_permiso IN ARRAY p_permisos
    LOOP

        IF NOT public.tiene_permiso(v_permiso) THEN
            RETURN FALSE;
        END IF;

    END LOOP;


    RETURN TRUE;

END;
$function$;

CREATE OR REPLACE FUNCTION public.transferir_inventario(p_producto_id uuid, p_ubicacion_origen_id uuid, p_ubicacion_destino_id uuid, p_cantidad numeric, p_costo_unitario numeric DEFAULT NULL::numeric, p_referencia_tipo character varying DEFAULT 'TRANSFERENCIA'::character varying, p_referencia_id uuid DEFAULT NULL::uuid, p_referencia_numero character varying DEFAULT NULL::character varying, p_observaciones text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.transferir_inventario(p_producto_id uuid, p_ubicacion_origen_id uuid, p_ubicacion_destino_id uuid, p_cantidad numeric, p_referencia_numero character varying DEFAULT NULL::character varying, p_observaciones text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$;

CREATE OR REPLACE FUNCTION public.usuario_tiene_permiso(p_usuario_id uuid, p_permiso_codigo text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_permitido BOOLEAN;
BEGIN

    /* --------------------------------------------------------
       Validaciones básicas
       -------------------------------------------------------- */

    IF p_usuario_id IS NULL THEN
        RETURN FALSE;
    END IF;

    IF p_permiso_codigo IS NULL
       OR btrim(p_permiso_codigo) = '' THEN
        RETURN FALSE;
    END IF;


    /* --------------------------------------------------------
       1. Validar que el usuario tenga un perfil activo
       -------------------------------------------------------- */

    IF NOT EXISTS (
        SELECT 1
        FROM public.perfiles p
        INNER JOIN public.roles r
            ON r.id = p.rol_id
        WHERE p.id = p_usuario_id
          AND p.estado = 'ACTIVO'
          AND p.activo = TRUE
          AND r.activo = TRUE
    ) THEN

        RETURN FALSE;

    END IF;


    /* --------------------------------------------------------
       2. Validar que el permiso exista y esté activo
       -------------------------------------------------------- */

    IF NOT EXISTS (
        SELECT 1
        FROM public.permisos pe
        WHERE pe.codigo = p_permiso_codigo
          AND pe.activo = TRUE
    ) THEN

        RETURN FALSE;

    END IF;


    /* --------------------------------------------------------
       3. EXCEPCIÓN INDIVIDUAL

       Si existe una configuración específica para este
       usuario y permiso, tiene prioridad sobre el rol.

       permitido = TRUE  → permitir
       permitido = FALSE → denegar
       -------------------------------------------------------- */

    SELECT up.permitido
    INTO v_permitido

    FROM public.usuario_permisos up

    INNER JOIN public.permisos pe
        ON pe.id = up.permiso_id

    WHERE up.usuario_id = p_usuario_id
      AND pe.codigo = p_permiso_codigo
      AND pe.activo = TRUE

    LIMIT 1;


    IF FOUND THEN
        RETURN COALESCE(v_permitido, FALSE);
    END IF;


    /* --------------------------------------------------------
       4. PERMISO DEL ROL

       Si no existe excepción individual, se consulta
       el permiso asignado al rol del usuario.
       -------------------------------------------------------- */

    RETURN EXISTS (

        SELECT 1

        FROM public.perfiles p

        INNER JOIN public.roles r
            ON r.id = p.rol_id

        INNER JOIN public.rol_permisos rp
            ON rp.rol_id = r.id

        INNER JOIN public.permisos pe
            ON pe.id = rp.permiso_id

        WHERE p.id = p_usuario_id

          AND p.estado = 'ACTIVO'
          AND p.activo = TRUE

          AND r.activo = TRUE

          AND pe.codigo = p_permiso_codigo
          AND pe.activo = TRUE

    );

END;
$function$;

CREATE OR REPLACE FUNCTION public.usuario_tiene_ubicacion(p_usuario_id uuid, p_ubicacion_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
    v_rol TEXT;
BEGIN

    /* --------------------------------------------------------
       Validaciones básicas
       -------------------------------------------------------- */

    IF p_usuario_id IS NULL
       OR p_ubicacion_id IS NULL THEN

        RETURN FALSE;

    END IF;


    /* --------------------------------------------------------
       1. Validar usuario activo
       -------------------------------------------------------- */

    SELECT r.codigo
    INTO v_rol

    FROM public.perfiles p

    INNER JOIN public.roles r
        ON r.id = p.rol_id

    WHERE p.id = p_usuario_id
      AND p.estado = 'ACTIVO'
      AND p.activo = TRUE
      AND r.activo = TRUE

    LIMIT 1;


    IF v_rol IS NULL THEN
        RETURN FALSE;
    END IF;


    /* --------------------------------------------------------
       2. Validar ubicación activa
       -------------------------------------------------------- */

    IF NOT EXISTS (
        SELECT 1
        FROM public.ubicaciones u
        WHERE u.id = p_ubicacion_id
          AND u.activo = TRUE
    ) THEN

        RETURN FALSE;

    END IF;


    /* --------------------------------------------------------
       3. ADMINISTRADOR

       Tiene acceso global a todas las ubicaciones activas.
       -------------------------------------------------------- */

    IF v_rol = 'ADMINISTRADOR' THEN
        RETURN TRUE;
    END IF;


    /* --------------------------------------------------------
       4. OTROS USUARIOS

       Deben tener asignación explícita.
       -------------------------------------------------------- */

    RETURN EXISTS (
        SELECT 1
        FROM public.usuario_ubicaciones uu

        INNER JOIN public.ubicaciones u
            ON u.id = uu.ubicacion_id

        WHERE uu.usuario_id = p_usuario_id
          AND uu.ubicacion_id = p_ubicacion_id
          AND u.activo = TRUE
    );

END;
$function$;

CREATE OR REPLACE FUNCTION public.validar_existencia_no_negativa()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if coalesce(new.stock_fisico, 0) < 0 then
    raise exception 'Stock insuficiente: el stock físico no puede quedar negativo.'
      using errcode = 'P0001', hint = 'Registra una entrada de inventario antes de realizar la salida.';
  end if;

  if coalesce(new.stock_reservado, 0) < 0 then
    raise exception 'El stock reservado no puede quedar negativo.'
      using errcode = 'P0001';
  end if;

  if coalesce(new.stock_disponible, 0) < 0 then
    raise exception 'Stock insuficiente: el stock disponible no puede quedar negativo.'
      using errcode = 'P0001', hint = 'Reduce la cantidad solicitada o repón inventario.';
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION erp_private.purchase_movement_allowed(p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_tipo text, p_origen text, p_referencia_tipo text, p_referencia_numero text)
 RETURNS boolean
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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

CREATE OR REPLACE FUNCTION public.erp_delta_movimiento(p_tipo text, p_cantidad numeric, p_anterior numeric, p_posterior numeric)
 RETURNS numeric
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case
    -- Reservation changes available/reserved stock, never physical stock.
    when p_tipo='RESERVA' then 0
    when p_tipo='ENTRADA' then abs(coalesce(p_cantidad,0))
    when p_tipo='SALIDA' then -abs(coalesce(p_cantidad,0))
    when p_anterior is not null and p_posterior is not null then p_posterior-p_anterior
    else coalesce(p_cantidad,0)
  end;
$function$;

CREATE OR REPLACE FUNCTION public.erp_mis_permisos()
 RETURNS TABLE(codigo text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select pe.codigo::text
  from public.permisos pe
  where auth.uid() is not null
    and pe.activo = true
    and public.usuario_tiene_permiso(auth.uid(), pe.codigo::text)
  order by pe.codigo;
$function$;

CREATE OR REPLACE FUNCTION public.erp_transferir_inventario(p_producto_id uuid, p_ubicacion_origen_id uuid, p_ubicacion_destino_id uuid, p_cantidad numeric, p_referencia_numero character varying DEFAULT NULL::character varying, p_observaciones text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select public.transferir_inventario(p_producto_id,p_ubicacion_origen_id,p_ubicacion_destino_id,p_cantidad,p_referencia_numero,p_observaciones);
$function$;

CREATE OR REPLACE FUNCTION public.liberar_reservas_ecommerce_vencidas()
 RETURNS integer
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  select public.liberar_reservas_expiradas();
$function$;

CREATE OR REPLACE FUNCTION public.productos_comprados_juntos_ecommerce(p_producto_id uuid, p_limite integer DEFAULT 4)
 RETURNS TABLE(id uuid, slug character varying, nombre character varying, nombre_corto character varying, precio_base numeric, veces_comprados_juntos bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select producto.id, producto.slug, producto.nombre, producto.nombre_corto, producto.precio_base, count(*)::bigint
  from public.pedidos_ecommerce_detalle origen
  join public.pedidos_ecommerce pedido on pedido.id = origen.pedido_id
  join public.pedidos_ecommerce_detalle candidato on candidato.pedido_id = origen.pedido_id and candidato.producto_id <> origen.producto_id
  join public.productos producto on producto.id = candidato.producto_id
  where origen.producto_id = p_producto_id
    and pedido.estado in ('CONFIRMADO','PREPARANDO','LISTO_PARA_RETIRO','ENVIADO','ENTREGADO')
    and producto.activo = true and producto.publicado_ecommerce = true and producto.visible_ecommerce = true and producto.slug is not null
  group by producto.id, producto.slug, producto.nombre, producto.nombre_corto, producto.precio_base
  order by count(*) desc, producto.nombre asc
  limit greatest(1, least(coalesce(p_limite, 4), 8));
$function$;

alter table "erp_private"."compra_movement_context" add constraint "compra_movement_context_pkey" PRIMARY KEY (backend, transaction_id, producto_id, ubicacion_id);

alter table "erp_private"."installation" add constraint "installation_pkey" PRIMARY KEY (version);

alter table "erp_private"."movement_context" add constraint "movement_context_pkey" PRIMARY KEY (id);

alter table "public"."ajustes_inventario" add constraint "ajustes_inventario_pkey" PRIMARY KEY (id);

alter table "public"."alertas_inventario" add constraint "alertas_inventario_pkey" PRIMARY KEY (id);

alter table "public"."anuncios_editoriales_ecommerce" add constraint "anuncios_editoriales_ecommerce_pkey" PRIMARY KEY (id);

alter table "public"."anuncios_inicio_ecommerce" add constraint "anuncios_inicio_ecommerce_pkey" PRIMARY KEY (id);

alter table "public"."auditoria" add constraint "auditoria_pkey" PRIMARY KEY (id);

alter table "public"."banners_ecommerce" add constraint "banners_ecommerce_pkey" PRIMARY KEY (id);

alter table "public"."carritos_ecommerce" add constraint "carritos_ecommerce_pkey" PRIMARY KEY (id);

alter table "public"."categorias" add constraint "categorias_pkey" PRIMARY KEY (id);

alter table "public"."configuracion_ecommerce" add constraint "configuracion_ecommerce_pkey" PRIMARY KEY (id);

alter table "public"."configuracion_erp" add constraint "configuracion_erp_pkey" PRIMARY KEY (clave);

alter table "public"."conteos_inventario" add constraint "conteos_inventario_pkey" PRIMARY KEY (id);

alter table "public"."devoluciones_venta" add constraint "devoluciones_venta_pkey" PRIMARY KEY (id);

alter table "public"."existencias" add constraint "existencias_pkey" PRIMARY KEY (id);

alter table "public"."facturas_ecommerce" add constraint "facturas_ecommerce_pkey" PRIMARY KEY (id);

alter table "public"."favoritos_ecommerce" add constraint "favoritos_ecommerce_pkey" PRIMARY KEY (id);

alter table "public"."marcas" add constraint "marcas_pkey" PRIMARY KEY (id);

alter table "public"."movimientos" add constraint "movimientos_pkey" PRIMARY KEY (id);

alter table "public"."notificaciones_operativas_ecommerce" add constraint "notificaciones_operativas_ecommerce_pkey" PRIMARY KEY (id);

alter table "public"."ofertas_producto" add constraint "ofertas_producto_pkey" PRIMARY KEY (id);

alter table "public"."ordenes_compra" add constraint "ordenes_compra_pkey" PRIMARY KEY (id);

alter table "public"."ordenes_compra_detalle" add constraint "ordenes_compra_detalle_pkey" PRIMARY KEY (id);

alter table "public"."pedidos_ecommerce" add constraint "pedidos_ecommerce_pkey" PRIMARY KEY (id);

alter table "public"."pedidos_ecommerce_detalle" add constraint "pedidos_ecommerce_detalle_pkey" PRIMARY KEY (id);

alter table "public"."perfiles" add constraint "perfiles_pkey" PRIMARY KEY (id);

alter table "public"."permisos" add constraint "permisos_pkey" PRIMARY KEY (id);

alter table "public"."producto_imagenes" add constraint "producto_imagenes_pkey" PRIMARY KEY (id);

alter table "public"."productos" add constraint "productos_pkey" PRIMARY KEY (id);

alter table "public"."proveedores" add constraint "proveedores_pkey" PRIMARY KEY (id);

alter table "public"."recepciones_compra" add constraint "recepciones_compra_pkey" PRIMARY KEY (id);

alter table "public"."recepciones_compra_detalle" add constraint "recepciones_compra_detalle_pkey" PRIMARY KEY (id);

alter table "public"."recordatorios_carrito_ecommerce" add constraint "recordatorios_carrito_ecommerce_pkey" PRIMARY KEY (id);

alter table "public"."reservas" add constraint "reservas_pkey" PRIMARY KEY (id);

alter table "public"."rol_permisos" add constraint "rol_permisos_pk" PRIMARY KEY (rol_id, permiso_id);

alter table "public"."roles" add constraint "roles_pkey" PRIMARY KEY (id);

alter table "public"."suscripciones_newsletter" add constraint "suscripciones_newsletter_pkey" PRIMARY KEY (id);

alter table "public"."ubicaciones" add constraint "ubicaciones_pkey" PRIMARY KEY (id);

alter table "public"."unidades_medida" add constraint "unidades_medida_pkey" PRIMARY KEY (id);

alter table "public"."usuario_permisos" add constraint "usuario_permisos_pk" PRIMARY KEY (usuario_id, permiso_id);

alter table "public"."usuario_ubicaciones" add constraint "usuario_ubicaciones_pk" PRIMARY KEY (usuario_id, ubicacion_id);

alter table "public"."ventas_pos" add constraint "ventas_pos_pkey" PRIMARY KEY (id);

alter table "public"."ventas_pos_detalle" add constraint "ventas_pos_detalle_pkey" PRIMARY KEY (id);

alter table "erp_private"."movement_context" add constraint "movement_context_backend_transaction_id_producto_id_ubicaci_key" UNIQUE (backend, transaction_id, producto_id, ubicacion_id);

alter table "public"."carritos_ecommerce" add constraint "carritos_ecommerce_cliente_id_key" UNIQUE (cliente_id);

alter table "public"."categorias" add constraint "categorias_nombre_unique" UNIQUE (nombre);

alter table "public"."categorias" add constraint "categorias_slug_unique" UNIQUE (slug);

alter table "public"."existencias" add constraint "existencias_producto_ubicacion_unique" UNIQUE (producto_id, ubicacion_id);

alter table "public"."facturas_ecommerce" add constraint "facturas_ecommerce_numero_key" UNIQUE (numero);

alter table "public"."facturas_ecommerce" add constraint "facturas_ecommerce_pedido_id_key" UNIQUE (pedido_id);

alter table "public"."favoritos_ecommerce" add constraint "favoritos_ecommerce_usuario_id_producto_id_key" UNIQUE (usuario_id, producto_id);

alter table "public"."marcas" add constraint "marcas_nombre_unique" UNIQUE (nombre);

alter table "public"."marcas" add constraint "marcas_slug_unique" UNIQUE (slug);

alter table "public"."ordenes_compra" add constraint "ordenes_compra_numero_key" UNIQUE (numero);

alter table "public"."pedidos_ecommerce" add constraint "pedidos_ecommerce_numero_key" UNIQUE (numero);

alter table "public"."permisos" add constraint "permisos_codigo_unique" UNIQUE (codigo);

alter table "public"."permisos" add constraint "permisos_modulo_accion_unique" UNIQUE (modulo, accion);

alter table "public"."productos" add constraint "productos_codigo_barras_unique" UNIQUE (codigo_barras);

alter table "public"."productos" add constraint "productos_codigo_interno_unique" UNIQUE (codigo_interno);

alter table "public"."productos" add constraint "productos_sku_unique" UNIQUE (sku);

alter table "public"."productos" add constraint "productos_slug_unique" UNIQUE (slug);

alter table "public"."proveedores" add constraint "proveedores_nit_key" UNIQUE (nit);

alter table "public"."proveedores" add constraint "proveedores_nombre_key" UNIQUE (nombre);

alter table "public"."recepciones_compra" add constraint "recepciones_compra_orden_compra_id_documento_key" UNIQUE (orden_compra_id, documento);

alter table "public"."recepciones_compra_detalle" add constraint "recepciones_compra_detalle_movimiento_id_key" UNIQUE (movimiento_id);

alter table "public"."recepciones_compra_detalle" add constraint "recepciones_compra_detalle_recepcion_id_orden_detalle_id_key" UNIQUE (recepcion_id, orden_detalle_id);

alter table "public"."roles" add constraint "roles_codigo_unique" UNIQUE (codigo);

alter table "public"."suscripciones_newsletter" add constraint "suscripciones_newsletter_correo_key" UNIQUE (correo);

alter table "public"."ubicaciones" add constraint "ubicaciones_codigo_unique" UNIQUE (codigo);

alter table "public"."unidades_medida" add constraint "unidades_abreviatura_unique" UNIQUE (abreviatura);

alter table "public"."unidades_medida" add constraint "unidades_nombre_unique" UNIQUE (nombre);

alter table "public"."ventas_pos" add constraint "ventas_pos_numero_key" UNIQUE (numero);

alter table "public"."ajustes_inventario" add constraint "ajustes_inventario_cantidad_check" CHECK (cantidad > 0::numeric);

alter table "public"."ajustes_inventario" add constraint "ajustes_inventario_estado_check" CHECK (estado::text = ANY (ARRAY['PENDIENTE'::character varying, 'APROBADO'::character varying, 'RECHAZADO'::character varying]::text[]));

alter table "public"."ajustes_inventario" add constraint "ajustes_inventario_tipo_check" CHECK (tipo::text = ANY (ARRAY['ENTRADA'::character varying, 'SALIDA'::character varying]::text[]));

alter table "public"."alertas_inventario" add constraint "alertas_inventario_estado_check" CHECK (estado::text = ANY (ARRAY['SIN_STOCK'::character varying, 'STOCK_BAJO'::character varying]::text[]));

alter table "public"."anuncios_editoriales_ecommerce" add constraint "anuncios_editoriales_fechas_chk" CHECK (fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio);

alter table "public"."anuncios_inicio_ecommerce" add constraint "anuncios_inicio_fechas_chk" CHECK (fecha_fin IS NULL OR fecha_inicio IS NULL OR fecha_fin >= fecha_inicio);

alter table "public"."auditoria" add constraint "auditoria_accion_check" CHECK (accion::text = ANY (ARRAY['INSERT'::character varying, 'UPDATE'::character varying, 'DELETE'::character varying]::text[]));

alter table "public"."banners_ecommerce" add constraint "banner_imagen_requerida" CHECK (imagen_url IS NOT NULL OR storage_bucket IS NOT NULL AND storage_path IS NOT NULL);

alter table "public"."banners_ecommerce" add constraint "banners_ecommerce_tema_check" CHECK (tema::text = ANY (ARRAY['oscuro'::character varying, 'claro'::character varying, 'esmeralda'::character varying, 'dorado'::character varying, 'coral'::character varying, 'nocturno'::character varying]::text[]));

alter table "public"."categorias" add constraint "categorias_no_auto_padre_chk" CHECK (categoria_padre_id IS NULL OR categoria_padre_id <> id);

alter table "public"."categorias" add constraint "categorias_nombre_chk" CHECK (length(TRIM(BOTH FROM nombre)) > 0);

alter table "public"."categorias" add constraint "categorias_orden_chk" CHECK (orden >= 0);

alter table "public"."categorias" add constraint "categorias_slug_chk" CHECK (length(TRIM(BOTH FROM slug)) > 0);

alter table "public"."configuracion_ecommerce" add constraint "configuracion_ecommerce_id_check" CHECK (id = true);

alter table "public"."configuracion_erp" add constraint "erp_configuracion_moneda_gtq" CHECK (clave::text <> 'moneda'::text OR COALESCE(valor ->> 'valor'::text, ''::text) = 'GTQ'::text);

alter table "public"."conteos_inventario" add constraint "conteos_inventario_stock_contado_check" CHECK (stock_contado >= 0::numeric);

alter table "public"."devoluciones_venta" add constraint "devoluciones_venta_canal_check" CHECK (canal::text = ANY (ARRAY['POS'::character varying, 'ECOMMERCE'::character varying]::text[]));

alter table "public"."devoluciones_venta" add constraint "devoluciones_venta_cantidad_check" CHECK (cantidad > 0::numeric);

alter table "public"."existencias" add constraint "existencias_punto_reorden_chk" CHECK (punto_reorden >= 0::numeric);

alter table "public"."existencias" add constraint "existencias_stock_consistencia_chk" CHECK (stock_disponible = (stock_fisico - stock_reservado));

alter table "public"."existencias" add constraint "existencias_stock_disponible_chk" CHECK (stock_disponible >= 0::numeric);

alter table "public"."existencias" add constraint "existencias_stock_fisico_chk" CHECK (stock_fisico >= 0::numeric);

alter table "public"."existencias" add constraint "existencias_stock_maximo_chk" CHECK (stock_maximo >= 0::numeric);

alter table "public"."existencias" add constraint "existencias_stock_maximo_minimo_chk" CHECK (stock_maximo >= stock_minimo);

alter table "public"."existencias" add constraint "existencias_stock_minimo_chk" CHECK (stock_minimo >= 0::numeric);

alter table "public"."existencias" add constraint "existencias_stock_reservado_chk" CHECK (stock_reservado >= 0::numeric);

alter table "public"."marcas" add constraint "marcas_nombre_chk" CHECK (length(TRIM(BOTH FROM nombre)) > 0);

alter table "public"."marcas" add constraint "marcas_orden_chk" CHECK (orden >= 0);

alter table "public"."marcas" add constraint "marcas_slug_chk" CHECK (length(TRIM(BOTH FROM slug)) > 0);

alter table "public"."movimientos" add constraint "movimientos_cantidad_chk" CHECK (cantidad > 0::numeric);

alter table "public"."movimientos" add constraint "movimientos_costo_chk" CHECK (costo_unitario IS NULL OR costo_unitario >= 0::numeric);

alter table "public"."movimientos" add constraint "movimientos_origen_chk" CHECK (origen::text = ANY (ARRAY['COMPRA'::character varying, 'POS'::character varying, 'ECOMMERCE'::character varying, 'CONTEO'::character varying, 'AJUSTE'::character varying, 'TRANSFERENCIA'::character varying, 'DEVOLUCION'::character varying, 'MANUAL'::character varying, 'SISTEMA'::character varying]::text[]));

alter table "public"."movimientos" add constraint "movimientos_stock_anterior_chk" CHECK (stock_anterior >= 0::numeric);

alter table "public"."movimientos" add constraint "movimientos_stock_posterior_chk" CHECK (stock_posterior >= 0::numeric);

alter table "public"."movimientos" add constraint "movimientos_tipo_chk" CHECK (tipo_movimiento::text = ANY (ARRAY['ENTRADA'::text, 'SALIDA'::text, 'AJUSTE_POSITIVO'::text, 'AJUSTE_NEGATIVO'::text, 'DEVOLUCION_VENTA'::text, 'DEVOLUCION_COMPRA'::text, 'TRANSFERENCIA_SALIDA'::text, 'TRANSFERENCIA_ENTRADA'::text, 'RESERVA'::text]));

alter table "public"."movimientos" add constraint "movimientos_valor_chk" CHECK (valor_total IS NULL OR valor_total >= 0::numeric);

alter table "public"."notificaciones_operativas_ecommerce" add constraint "notificaciones_operativas_ecommerce_estado_check" CHECK (estado::text = ANY (ARRAY['PENDIENTE'::character varying, 'PROCESADA'::character varying, 'DESCARTADA'::character varying, 'ERROR'::character varying]::text[]));

alter table "public"."notificaciones_operativas_ecommerce" add constraint "notificaciones_operativas_ecommerce_prioridad_check" CHECK (prioridad::text = ANY (ARRAY['NORMAL'::character varying, 'ALTA'::character varying]::text[]));

alter table "public"."notificaciones_operativas_ecommerce" add constraint "notificaciones_operativas_ecommerce_tipo_check" CHECK (tipo::text = ANY (ARRAY['PEDIDO_NUEVO'::character varying, 'PEDIDO_POR_PREPARAR'::character varying, 'INVENTARIO_BAJO'::character varying]::text[]));

alter table "public"."ofertas_producto" add constraint "ofertas_producto_fechas_chk" CHECK (fecha_fin IS NULL OR fecha_fin > fecha_inicio);

alter table "public"."ofertas_producto" add constraint "ofertas_producto_porcentaje_chk" CHECK (oferta_porcentaje >= 0::numeric AND oferta_porcentaje <= 100::numeric);

alter table "public"."ofertas_producto" add constraint "ofertas_producto_porcentaje_rango" CHECK (oferta_porcentaje >= 0::numeric AND oferta_porcentaje <= 100::numeric);

alter table "public"."ordenes_compra" add constraint "ordenes_compra_estado_check" CHECK (estado::text = ANY (ARRAY['BORRADOR'::character varying, 'ENVIADA'::character varying, 'PARCIAL'::character varying, 'RECIBIDA'::character varying, 'CANCELADA'::character varying]::text[]));

alter table "public"."ordenes_compra_detalle" add constraint "erp_orden_cantidad_recibida_limite" CHECK (cantidad_recibida <= cantidad_solicitada);

alter table "public"."ordenes_compra_detalle" add constraint "ordenes_compra_detalle_cantidad_recibida_check" CHECK (cantidad_recibida >= 0::numeric);

alter table "public"."ordenes_compra_detalle" add constraint "ordenes_compra_detalle_cantidad_solicitada_check" CHECK (cantidad_solicitada > 0::numeric);

alter table "public"."pedidos_ecommerce" add constraint "pedidos_ecommerce_estado_check" CHECK (estado::text = ANY (ARRAY['RESERVADO'::character varying, 'PAGADO'::character varying, 'CANCELADO'::character varying]::text[]));

alter table "public"."pedidos_ecommerce_detalle" add constraint "pedidos_ecommerce_detalle_cantidad_check" CHECK (cantidad > 0::numeric);

alter table "public"."perfiles" add constraint "perfiles_estado_check" CHECK (estado::text = ANY (ARRAY['ACTIVO'::character varying, 'INACTIVO'::character varying, 'BLOQUEADO'::character varying]::text[]));

alter table "public"."permisos" add constraint "permisos_accion_no_vacio" CHECK (length(TRIM(BOTH FROM accion)) > 0);

alter table "public"."permisos" add constraint "permisos_codigo_no_vacio" CHECK (length(TRIM(BOTH FROM codigo)) > 0);

alter table "public"."permisos" add constraint "permisos_modulo_no_vacio" CHECK (length(TRIM(BOTH FROM modulo)) > 0);

alter table "public"."permisos" add constraint "permisos_nombre_no_vacio" CHECK (length(TRIM(BOTH FROM nombre)) > 0);

alter table "public"."producto_imagenes" add constraint "producto_imagenes_alto_chk" CHECK (alto IS NULL OR alto >= 0);

alter table "public"."producto_imagenes" add constraint "producto_imagenes_ancho_chk" CHECK (ancho IS NULL OR ancho >= 0);

alter table "public"."producto_imagenes" add constraint "producto_imagenes_estado_storage_chk" CHECK ((estado_storage = ANY (ARRAY['CARGANDO'::text, 'ACTIVA'::text, 'BORRANDO'::text])) AND activo = (estado_storage = 'ACTIVA'::text));

alter table "public"."producto_imagenes" add constraint "producto_imagenes_orden_chk" CHECK (orden >= 0);

alter table "public"."producto_imagenes" add constraint "producto_imagenes_path_chk" CHECK (length(TRIM(BOTH FROM storage_path)) > 0);

alter table "public"."producto_imagenes" add constraint "producto_imagenes_tamano_chk" CHECK ("tamaño_bytes" IS NULL OR "tamaño_bytes" >= 0);

alter table "public"."productos" add constraint "productos_alto_chk" CHECK (alto IS NULL OR alto >= 0::numeric);

alter table "public"."productos" add constraint "productos_ancho_chk" CHECK (ancho IS NULL OR ancho >= 0::numeric);

alter table "public"."productos" add constraint "productos_codigo_barras_chk" CHECK (codigo_barras IS NULL OR length(TRIM(BOTH FROM codigo_barras)) > 0);

alter table "public"."productos" add constraint "productos_codigo_interno_chk" CHECK (codigo_interno IS NULL OR length(TRIM(BOTH FROM codigo_interno)) > 0);

alter table "public"."productos" add constraint "productos_nombre_chk" CHECK (length(TRIM(BOTH FROM nombre)) > 0);

alter table "public"."productos" add constraint "productos_orden_ecommerce_chk" CHECK (orden_ecommerce >= 0);

alter table "public"."productos" add constraint "productos_peso_chk" CHECK (peso IS NULL OR peso >= 0::numeric);

alter table "public"."productos" add constraint "productos_piezas_chk" CHECK (piezas_por_paquete IS NULL OR piezas_por_paquete > 0);

alter table "public"."productos" add constraint "productos_precio_base_chk" CHECK (precio_base >= 0::numeric);

alter table "public"."productos" add constraint "productos_profundidad_chk" CHECK (profundidad IS NULL OR profundidad >= 0::numeric);

alter table "public"."productos" add constraint "productos_sku_chk" CHECK (length(TRIM(BOTH FROM sku)) > 0);

alter table "public"."recepciones_compra" add constraint "recepciones_compra_documento_check" CHECK (length(btrim(documento::text)) > 0);

alter table "public"."recepciones_compra_detalle" add constraint "recepciones_compra_detalle_cantidad_check" CHECK (cantidad > 0::numeric AND (cantidad::text <> ALL (ARRAY['NaN'::text, 'Infinity'::text, '-Infinity'::text])));

alter table "public"."recepciones_compra_detalle" add constraint "recepciones_compra_detalle_costo_unitario_check" CHECK (costo_unitario >= 0::numeric AND (costo_unitario::text <> ALL (ARRAY['NaN'::text, 'Infinity'::text, '-Infinity'::text])));

alter table "public"."recordatorios_carrito_ecommerce" add constraint "recordatorios_carrito_ecommerce_canal_check" CHECK (canal::text = ANY (ARRAY['EMAIL'::character varying, 'WHATSAPP'::character varying]::text[]));

alter table "public"."recordatorios_carrito_ecommerce" add constraint "recordatorios_carrito_ecommerce_estado_check" CHECK (estado::text = ANY (ARRAY['PENDIENTE'::character varying, 'ENVIADO'::character varying, 'CANCELADO'::character varying, 'ERROR'::character varying]::text[]));

alter table "public"."reservas" add constraint "reservas_cantidad_chk" CHECK (cantidad > 0::numeric);

alter table "public"."reservas" add constraint "reservas_estado_chk" CHECK (estado::text = ANY (ARRAY['ACTIVA'::character varying, 'LIBERADA'::character varying, 'CONSUMIDA'::character varying, 'CANCELADA'::character varying, 'EXPIRADA'::character varying]::text[]));

alter table "public"."reservas" add constraint "reservas_fechas_chk" CHECK (fecha_expiracion IS NULL OR fecha_expiracion >= fecha_reserva);

alter table "public"."reservas" add constraint "reservas_origen_chk" CHECK (origen::text = ANY (ARRAY['POS'::character varying, 'ECOMMERCE'::character varying, 'APARTADO'::character varying, 'PEDIDO'::character varying, 'INTERNO'::character varying, 'MANUAL'::character varying, 'SISTEMA'::character varying]::text[]));

alter table "public"."roles" add constraint "roles_codigo_no_vacio" CHECK (length(TRIM(BOTH FROM codigo)) > 0);

alter table "public"."roles" add constraint "roles_nombre_no_vacio" CHECK (length(TRIM(BOTH FROM nombre)) > 0);

alter table "public"."suscripciones_newsletter" add constraint "suscripciones_newsletter_estado_check" CHECK (estado::text = ANY (ARRAY['ACTIVA'::character varying, 'CANCELADA'::character varying]::text[]));

alter table "public"."ubicaciones" add constraint "ubicaciones_codigo_chk" CHECK (length(TRIM(BOTH FROM codigo)) > 0);

alter table "public"."ubicaciones" add constraint "ubicaciones_no_auto_padre_chk" CHECK (ubicacion_padre_id IS NULL OR ubicacion_padre_id <> id);

alter table "public"."ubicaciones" add constraint "ubicaciones_nombre_chk" CHECK (length(TRIM(BOTH FROM nombre)) > 0);

alter table "public"."ubicaciones" add constraint "ubicaciones_orden_chk" CHECK (orden >= 0);

alter table "public"."ubicaciones" add constraint "ubicaciones_tipo_chk" CHECK (length(TRIM(BOTH FROM tipo)) > 0);

alter table "public"."unidades_medida" add constraint "unidades_abreviatura_chk" CHECK (length(TRIM(BOTH FROM abreviatura)) > 0);

alter table "public"."unidades_medida" add constraint "unidades_decimales_chk" CHECK (decimales_permitidos >= 0 AND decimales_permitidos <= 6);

alter table "public"."unidades_medida" add constraint "unidades_factor_base_chk" CHECK (factor_base > 0::numeric);

alter table "public"."unidades_medida" add constraint "unidades_no_auto_base_chk" CHECK (unidad_base_id IS NULL OR unidad_base_id <> id);

alter table "public"."unidades_medida" add constraint "unidades_nombre_chk" CHECK (length(TRIM(BOTH FROM nombre)) > 0);

alter table "public"."unidades_medida" add constraint "unidades_tipo_chk" CHECK (length(TRIM(BOTH FROM tipo)) > 0);

alter table "public"."ventas_pos" add constraint "ventas_pos_estado_check" CHECK (estado::text = ANY (ARRAY['COMPLETADA'::character varying, 'ANULADA'::character varying]::text[]));

alter table "public"."ventas_pos_detalle" add constraint "ventas_pos_detalle_cantidad_check" CHECK (cantidad > 0::numeric);

alter table "public"."ajustes_inventario" add constraint "ajustes_inventario_producto_id_fkey" FOREIGN KEY (producto_id) REFERENCES productos(id);

alter table "public"."ajustes_inventario" add constraint "ajustes_inventario_ubicacion_id_fkey" FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id);

alter table "public"."alertas_inventario" add constraint "alertas_inventario_existencia_id_fkey" FOREIGN KEY (existencia_id) REFERENCES existencias(id) ON DELETE CASCADE;

alter table "public"."alertas_inventario" add constraint "alertas_inventario_producto_id_fkey" FOREIGN KEY (producto_id) REFERENCES productos(id);

alter table "public"."alertas_inventario" add constraint "alertas_inventario_ubicacion_id_fkey" FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id);

alter table "public"."auditoria" add constraint "auditoria_usuario_id_fkey" FOREIGN KEY (usuario_id) REFERENCES perfiles(id);

alter table "public"."banners_ecommerce" add constraint "banners_ecommerce_creado_por_fkey" FOREIGN KEY (creado_por) REFERENCES auth.users(id);

alter table "public"."carritos_ecommerce" add constraint "carritos_ecommerce_cliente_id_fkey" FOREIGN KEY (cliente_id) REFERENCES perfiles(id) ON DELETE CASCADE;

alter table "public"."categorias" add constraint "categorias_padre_fk" FOREIGN KEY (categoria_padre_id) REFERENCES categorias(id) ON UPDATE CASCADE ON DELETE RESTRICT;

alter table "public"."configuracion_ecommerce" add constraint "configuracion_ecommerce_ubicacion_ecommerce_id_fkey" FOREIGN KEY (ubicacion_ecommerce_id) REFERENCES ubicaciones(id);

alter table "public"."conteos_inventario" add constraint "conteos_inventario_producto_id_fkey" FOREIGN KEY (producto_id) REFERENCES productos(id);

alter table "public"."conteos_inventario" add constraint "conteos_inventario_ubicacion_id_fkey" FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id);

alter table "public"."devoluciones_venta" add constraint "devoluciones_venta_producto_id_fkey" FOREIGN KEY (producto_id) REFERENCES productos(id);

alter table "public"."devoluciones_venta" add constraint "devoluciones_venta_ubicacion_id_fkey" FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id);

alter table "public"."existencias" add constraint "existencias_actualizado_por_fk" FOREIGN KEY (actualizado_por) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE SET NULL;

alter table "public"."existencias" add constraint "existencias_creado_por_fk" FOREIGN KEY (creado_por) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE SET NULL;

alter table "public"."existencias" add constraint "existencias_producto_fk" FOREIGN KEY (producto_id) REFERENCES productos(id) ON UPDATE CASCADE ON DELETE RESTRICT;

alter table "public"."existencias" add constraint "existencias_ubicacion_fk" FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id) ON UPDATE CASCADE ON DELETE RESTRICT;

alter table "public"."facturas_ecommerce" add constraint "facturas_ecommerce_pedido_id_fkey" FOREIGN KEY (pedido_id) REFERENCES pedidos_ecommerce(id);

alter table "public"."facturas_ecommerce" add constraint "facturas_ecommerce_ubicacion_id_fkey" FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id);

alter table "public"."favoritos_ecommerce" add constraint "favoritos_ecommerce_producto_id_fkey" FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE CASCADE;

alter table "public"."favoritos_ecommerce" add constraint "favoritos_ecommerce_usuario_id_fkey" FOREIGN KEY (usuario_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table "public"."movimientos" add constraint "movimientos_producto_fk" FOREIGN KEY (producto_id) REFERENCES productos(id) ON UPDATE CASCADE ON DELETE RESTRICT;

alter table "public"."movimientos" add constraint "movimientos_ubicacion_fk" FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id) ON UPDATE CASCADE ON DELETE RESTRICT;

alter table "public"."movimientos" add constraint "movimientos_usuario_fk" FOREIGN KEY (usuario_id) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE SET NULL;

alter table "public"."notificaciones_operativas_ecommerce" add constraint "notificaciones_operativas_ecommerce_alerta_inventario_id_fkey" FOREIGN KEY (alerta_inventario_id) REFERENCES alertas_inventario(id) ON DELETE CASCADE;

alter table "public"."notificaciones_operativas_ecommerce" add constraint "notificaciones_operativas_ecommerce_pedido_id_fkey" FOREIGN KEY (pedido_id) REFERENCES pedidos_ecommerce(id) ON DELETE CASCADE;

alter table "public"."notificaciones_operativas_ecommerce" add constraint "notificaciones_operativas_ecommerce_ubicacion_id_fkey" FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id);

alter table "public"."ofertas_producto" add constraint "ofertas_producto_actualizado_por_fk" FOREIGN KEY (actualizado_por) REFERENCES perfiles(id) ON DELETE SET NULL;

alter table "public"."ofertas_producto" add constraint "ofertas_producto_creado_por_fk" FOREIGN KEY (creado_por) REFERENCES perfiles(id) ON DELETE SET NULL;

alter table "public"."ofertas_producto" add constraint "ofertas_producto_producto_fk" FOREIGN KEY (producto_id) REFERENCES productos(id) ON DELETE RESTRICT;

alter table "public"."ordenes_compra" add constraint "ordenes_compra_proveedor_id_fkey" FOREIGN KEY (proveedor_id) REFERENCES proveedores(id);

alter table "public"."ordenes_compra_detalle" add constraint "ordenes_compra_detalle_orden_compra_id_fkey" FOREIGN KEY (orden_compra_id) REFERENCES ordenes_compra(id) ON DELETE CASCADE;

alter table "public"."ordenes_compra_detalle" add constraint "ordenes_compra_detalle_producto_id_fkey" FOREIGN KEY (producto_id) REFERENCES productos(id);

alter table "public"."pedidos_ecommerce" add constraint "pedidos_ecommerce_cliente_id_fkey" FOREIGN KEY (cliente_id) REFERENCES auth.users(id);

alter table "public"."pedidos_ecommerce" add constraint "pedidos_ecommerce_ubicacion_id_fkey" FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id);

alter table "public"."pedidos_ecommerce_detalle" add constraint "pedidos_ecommerce_detalle_pedido_id_fkey" FOREIGN KEY (pedido_id) REFERENCES pedidos_ecommerce(id) ON DELETE CASCADE;

alter table "public"."pedidos_ecommerce_detalle" add constraint "pedidos_ecommerce_detalle_producto_id_fkey" FOREIGN KEY (producto_id) REFERENCES productos(id);

alter table "public"."perfiles" add constraint "perfiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table "public"."perfiles" add constraint "perfiles_rol_fk" FOREIGN KEY (rol_id) REFERENCES roles(id) ON DELETE SET NULL;

alter table "public"."producto_imagenes" add constraint "producto_imagenes_creado_por_fk" FOREIGN KEY (creado_por) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE SET NULL;

alter table "public"."producto_imagenes" add constraint "producto_imagenes_producto_fk" FOREIGN KEY (producto_id) REFERENCES productos(id) ON UPDATE CASCADE ON DELETE CASCADE;

alter table "public"."productos" add constraint "productos_actualizado_por_fk" FOREIGN KEY (actualizado_por) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE SET NULL;

alter table "public"."productos" add constraint "productos_categoria_fk" FOREIGN KEY (categoria_id) REFERENCES categorias(id) ON UPDATE CASCADE ON DELETE RESTRICT;

alter table "public"."productos" add constraint "productos_creado_por_fk" FOREIGN KEY (creado_por) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE SET NULL;

alter table "public"."productos" add constraint "productos_marca_fk" FOREIGN KEY (marca_id) REFERENCES marcas(id) ON UPDATE CASCADE ON DELETE RESTRICT;

alter table "public"."productos" add constraint "productos_proveedor_id_fkey" FOREIGN KEY (proveedor_id) REFERENCES proveedores(id) ON DELETE SET NULL;

alter table "public"."productos" add constraint "productos_unidad_fk" FOREIGN KEY (unidad_medida_id) REFERENCES unidades_medida(id) ON UPDATE CASCADE ON DELETE RESTRICT;

alter table "public"."recepciones_compra" add constraint "recepciones_compra_orden_compra_id_fkey" FOREIGN KEY (orden_compra_id) REFERENCES ordenes_compra(id);

alter table "public"."recepciones_compra" add constraint "recepciones_compra_ubicacion_id_fkey" FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id);

alter table "public"."recepciones_compra_detalle" add constraint "recepciones_compra_detalle_movimiento_id_fkey" FOREIGN KEY (movimiento_id) REFERENCES movimientos(id);

alter table "public"."recepciones_compra_detalle" add constraint "recepciones_compra_detalle_orden_detalle_id_fkey" FOREIGN KEY (orden_detalle_id) REFERENCES ordenes_compra_detalle(id);

alter table "public"."recepciones_compra_detalle" add constraint "recepciones_compra_detalle_producto_id_fkey" FOREIGN KEY (producto_id) REFERENCES productos(id);

alter table "public"."recepciones_compra_detalle" add constraint "recepciones_compra_detalle_recepcion_id_fkey" FOREIGN KEY (recepcion_id) REFERENCES recepciones_compra(id);

alter table "public"."recordatorios_carrito_ecommerce" add constraint "recordatorios_carrito_ecommerce_carrito_id_fkey" FOREIGN KEY (carrito_id) REFERENCES carritos_ecommerce(id) ON DELETE CASCADE;

alter table "public"."reservas" add constraint "reservas_actualizado_por_fk" FOREIGN KEY (actualizado_por) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE SET NULL;

alter table "public"."reservas" add constraint "reservas_creado_por_fk" FOREIGN KEY (creado_por) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE SET NULL;

alter table "public"."reservas" add constraint "reservas_producto_fk" FOREIGN KEY (producto_id) REFERENCES productos(id) ON UPDATE CASCADE ON DELETE RESTRICT;

alter table "public"."reservas" add constraint "reservas_ubicacion_fk" FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id) ON UPDATE CASCADE ON DELETE RESTRICT;

alter table "public"."rol_permisos" add constraint "rol_permisos_permiso_fk" FOREIGN KEY (permiso_id) REFERENCES permisos(id) ON DELETE CASCADE;

alter table "public"."rol_permisos" add constraint "rol_permisos_rol_fk" FOREIGN KEY (rol_id) REFERENCES roles(id) ON DELETE CASCADE;

alter table "public"."ubicaciones" add constraint "ubicaciones_padre_fk" FOREIGN KEY (ubicacion_padre_id) REFERENCES ubicaciones(id) ON UPDATE CASCADE ON DELETE RESTRICT;

alter table "public"."ubicaciones" add constraint "ubicaciones_responsable_fk" FOREIGN KEY (responsable_id) REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE SET NULL;

alter table "public"."unidades_medida" add constraint "unidades_base_fk" FOREIGN KEY (unidad_base_id) REFERENCES unidades_medida(id) ON UPDATE CASCADE ON DELETE RESTRICT;

alter table "public"."usuario_permisos" add constraint "usuario_permisos_permiso_fk" FOREIGN KEY (permiso_id) REFERENCES permisos(id) ON DELETE CASCADE;

alter table "public"."usuario_permisos" add constraint "usuario_permisos_usuario_fk" FOREIGN KEY (usuario_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table "public"."usuario_ubicaciones" add constraint "usuario_ubicaciones_ubicacion_fk" FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id) ON DELETE CASCADE;

alter table "public"."usuario_ubicaciones" add constraint "usuario_ubicaciones_usuario_fk" FOREIGN KEY (usuario_id) REFERENCES auth.users(id) ON DELETE CASCADE;

alter table "public"."ventas_pos" add constraint "ventas_pos_ubicacion_id_fkey" FOREIGN KEY (ubicacion_id) REFERENCES ubicaciones(id);

alter table "public"."ventas_pos_detalle" add constraint "ventas_pos_detalle_producto_id_fkey" FOREIGN KEY (producto_id) REFERENCES productos(id);

alter table "public"."ventas_pos_detalle" add constraint "ventas_pos_detalle_venta_id_fkey" FOREIGN KEY (venta_id) REFERENCES ventas_pos(id) ON DELETE CASCADE;

CREATE INDEX alertas_inventario_activas_idx ON public.alertas_inventario USING btree (existencia_id, estado) WHERE activa;

CREATE INDEX alertas_inventario_pendientes_idx ON public.alertas_inventario USING btree (fecha_creacion, id) WHERE (activa AND (enviada_en IS NULL));

CREATE UNIQUE INDEX alertas_inventario_una_activa_idx ON public.alertas_inventario USING btree (existencia_id) WHERE activa;

CREATE INDEX anuncios_editoriales_ecommerce_activo_orden_idx ON public.anuncios_editoriales_ecommerce USING btree (activo, orden);

CREATE INDEX anuncios_inicio_ecommerce_activo_orden_idx ON public.anuncios_inicio_ecommerce USING btree (activo, orden);

CREATE INDEX auditoria_fecha_idx ON public.auditoria USING btree (fecha DESC);

CREATE INDEX auditoria_tabla_idx ON public.auditoria USING btree (tabla, fecha DESC);

CREATE INDEX categorias_activo_idx ON public.categorias USING btree (activo);

CREATE INDEX categorias_ecommerce_idx ON public.categorias USING btree (visible_ecommerce);

CREATE INDEX categorias_padre_idx ON public.categorias USING btree (categoria_padre_id);

CREATE INDEX categorias_pos_idx ON public.categorias USING btree (visible_pos);

CREATE UNIQUE INDEX existencias_producto_ubicacion_unica ON public.existencias USING btree (producto_id, ubicacion_id);

CREATE INDEX idx_existencias_activo ON public.existencias USING btree (activo);

CREATE INDEX idx_existencias_producto ON public.existencias USING btree (producto_id);

CREATE INDEX idx_existencias_stock_bajo ON public.existencias USING btree (punto_reorden, stock_disponible);

CREATE INDEX idx_existencias_ubicacion ON public.existencias USING btree (ubicacion_id);

CREATE INDEX marcas_activo_idx ON public.marcas USING btree (activo);

CREATE INDEX marcas_destacada_idx ON public.marcas USING btree (destacada);

CREATE INDEX idx_movimientos_fecha ON public.movimientos USING btree (fecha_movimiento DESC);

CREATE INDEX idx_movimientos_grupo ON public.movimientos USING btree (grupo_movimiento_id);

CREATE INDEX idx_movimientos_origen ON public.movimientos USING btree (origen);

CREATE INDEX idx_movimientos_producto ON public.movimientos USING btree (producto_id);

CREATE INDEX idx_movimientos_producto_fecha ON public.movimientos USING btree (producto_id, fecha_movimiento DESC);

CREATE INDEX idx_movimientos_referencia ON public.movimientos USING btree (referencia_tipo, referencia_id);

CREATE INDEX idx_movimientos_tipo ON public.movimientos USING btree (tipo_movimiento);

CREATE INDEX idx_movimientos_ubicacion ON public.movimientos USING btree (ubicacion_id);

CREATE INDEX idx_movimientos_ubicacion_fecha ON public.movimientos USING btree (ubicacion_id, fecha_movimiento DESC);

CREATE UNIQUE INDEX notificaciones_operativas_alerta_unica ON public.notificaciones_operativas_ecommerce USING btree (tipo, alerta_inventario_id) WHERE ((alerta_inventario_id IS NOT NULL) AND ((estado)::text = 'PENDIENTE'::text));

CREATE UNIQUE INDEX notificaciones_operativas_pedido_unica ON public.notificaciones_operativas_ecommerce USING btree (tipo, pedido_id) WHERE ((pedido_id IS NOT NULL) AND ((estado)::text = 'PENDIENTE'::text));

CREATE INDEX idx_ofertas_producto_activo ON public.ofertas_producto USING btree (activo);

CREATE INDEX idx_ofertas_producto_fecha_fin ON public.ofertas_producto USING btree (fecha_fin);

CREATE INDEX idx_ofertas_producto_fecha_inicio ON public.ofertas_producto USING btree (fecha_inicio);

CREATE INDEX idx_ofertas_producto_producto_activo ON public.ofertas_producto USING btree (producto_id, activo);

CREATE INDEX idx_ofertas_producto_producto_id ON public.ofertas_producto USING btree (producto_id);

CREATE INDEX idx_perfiles_activo ON public.perfiles USING btree (activo);

CREATE INDEX idx_perfiles_estado ON public.perfiles USING btree (estado);

CREATE INDEX idx_perfiles_rol ON public.perfiles USING btree (rol_id);

CREATE INDEX idx_permisos_accion ON public.permisos USING btree (accion);

CREATE INDEX idx_permisos_activo ON public.permisos USING btree (activo);

CREATE INDEX idx_permisos_modulo ON public.permisos USING btree (modulo);

CREATE UNIQUE INDEX producto_imagen_principal_unica_idx ON public.producto_imagenes USING btree (producto_id) WHERE (es_principal = true);

CREATE INDEX producto_imagenes_orden_idx ON public.producto_imagenes USING btree (producto_id, orden);

CREATE UNIQUE INDEX producto_imagenes_principal_activa_uniq ON public.producto_imagenes USING btree (producto_id) WHERE (activo AND es_principal);

CREATE INDEX producto_imagenes_producto_idx ON public.producto_imagenes USING btree (producto_id);

CREATE UNIQUE INDEX producto_imagenes_storage_path_uniq ON public.producto_imagenes USING btree (storage_bucket, storage_path);

CREATE INDEX productos_activo_idx ON public.productos USING btree (activo);

CREATE INDEX productos_categoria_idx ON public.productos USING btree (categoria_id);

CREATE INDEX productos_descontinuado_idx ON public.productos USING btree (descontinuado);

CREATE INDEX productos_ecommerce_idx ON public.productos USING btree (publicado_ecommerce, visible_ecommerce);

CREATE INDEX productos_marca_idx ON public.productos USING btree (marca_id);

CREATE INDEX productos_pos_idx ON public.productos USING btree (disponible_pos);

CREATE INDEX productos_unidad_idx ON public.productos USING btree (unidad_medida_id);

CREATE UNIQUE INDEX recepciones_compra_documento_ci_idx ON public.recepciones_compra USING btree (orden_compra_id, lower((documento)::text));

CREATE INDEX recepciones_compra_orden_fecha_idx ON public.recepciones_compra USING btree (orden_compra_id, fecha_recepcion DESC);

CREATE INDEX recepciones_compra_detalle_orden_idx ON public.recepciones_compra_detalle USING btree (orden_detalle_id);

CREATE INDEX idx_reservas_estado ON public.reservas USING btree (estado);

CREATE INDEX idx_reservas_expiracion ON public.reservas USING btree (fecha_expiracion) WHERE ((estado)::text = 'ACTIVA'::text);

CREATE INDEX idx_reservas_producto ON public.reservas USING btree (producto_id);

CREATE INDEX idx_reservas_producto_ubicacion_estado ON public.reservas USING btree (producto_id, ubicacion_id, estado);

CREATE INDEX idx_reservas_referencia ON public.reservas USING btree (referencia_tipo, referencia_id);

CREATE INDEX idx_reservas_ubicacion ON public.reservas USING btree (ubicacion_id);

CREATE INDEX idx_rol_permisos_permiso ON public.rol_permisos USING btree (permiso_id);

CREATE INDEX ubicaciones_activo_idx ON public.ubicaciones USING btree (activo);

CREATE INDEX ubicaciones_padre_idx ON public.ubicaciones USING btree (ubicacion_padre_id);

CREATE INDEX ubicaciones_responsable_idx ON public.ubicaciones USING btree (responsable_id);

CREATE INDEX ubicaciones_tipo_idx ON public.ubicaciones USING btree (tipo);

CREATE INDEX unidades_activo_idx ON public.unidades_medida USING btree (activo);

CREATE INDEX unidades_base_idx ON public.unidades_medida USING btree (unidad_base_id);

CREATE INDEX idx_usuario_permisos_permiso ON public.usuario_permisos USING btree (permiso_id);

CREATE INDEX idx_usuario_permisos_usuario ON public.usuario_permisos USING btree (usuario_id);

CREATE INDEX idx_usuario_ubicaciones_ubicacion ON public.usuario_ubicaciones USING btree (ubicacion_id);

CREATE INDEX idx_usuario_ubicaciones_usuario ON public.usuario_ubicaciones USING btree (usuario_id);

create view "public"."auditoria_calidad_catalogo_ecommerce" as
 SELECT p.id,
    p.sku,
    p.nombre,
    p.slug,
    p.publicado_ecommerce,
    p.visible_ecommerce,
    count(img.id) FILTER (WHERE img.activo = true) AS imagenes_activas,
    count(img.id) FILTER (WHERE img.activo = true AND img.es_principal = true) AS imagenes_principales,
    array_remove(ARRAY[
        CASE
            WHEN NULLIF(TRIM(BOTH FROM p.slug), ''::text) IS NULL THEN 'Falta slug'::text
            ELSE NULL::text
        END,
        CASE
            WHEN NULLIF(TRIM(BOTH FROM p.nombre_corto), ''::text) IS NULL THEN 'Falta nombre corto'::text
            ELSE NULL::text
        END,
        CASE
            WHEN NULLIF(TRIM(BOTH FROM p.descripcion_corta), ''::text) IS NULL THEN 'Falta descripción corta'::text
            ELSE NULL::text
        END,
        CASE
            WHEN NULLIF(TRIM(BOTH FROM p.titulo_seo), ''::text) IS NULL THEN 'Falta título SEO'::text
            ELSE NULL::text
        END,
        CASE
            WHEN NULLIF(TRIM(BOTH FROM p.descripcion_seo), ''::text) IS NULL THEN 'Falta descripción SEO'::text
            ELSE NULL::text
        END,
        CASE
            WHEN count(img.id) FILTER (WHERE img.activo = true) = 0 THEN 'Falta imagen'::text
            ELSE NULL::text
        END,
        CASE
            WHEN count(img.id) FILTER (WHERE img.activo = true AND img.es_principal = true) = 0 THEN 'Falta imagen principal'::text
            ELSE NULL::text
        END,
        CASE
            WHEN p.presentacion IS NULL AND p.modelo IS NULL AND p.color IS NULL AND p.contenido IS NULL AND p.piezas_por_paquete IS NULL THEN 'Faltan atributos de producto'::text
            ELSE NULL::text
        END], NULL::text) AS pendientes,
        CASE
            WHEN count(img.id) FILTER (WHERE img.activo = true) >= 2 THEN 'GALERIA_COMPLETA'::text
            WHEN count(img.id) FILTER (WHERE img.activo = true) = 1 THEN 'UNA_IMAGEN'::text
            ELSE 'SIN_IMAGEN'::text
        END AS calidad_imagenes
   FROM productos p
     LEFT JOIN producto_imagenes img ON img.producto_id = p.id
  GROUP BY p.id;

create view "public"."catalogo_producto_detalle" as
 SELECT id,
    slug,
    nombre,
    nombre_corto,
    categoria_id,
    marca_id,
    descripcion_corta,
    descripcion_larga,
    precio_base,
    presentacion,
    modelo,
    color,
    tamano,
    material,
    peso,
    unidad_peso,
    ancho,
    alto,
    profundidad,
    unidad_dimensiones,
    contenido,
    piezas_por_paquete,
    venta_fraccionada,
    titulo_seo,
    descripcion_seo,
    sku,
    codigo_barras
   FROM productos p
  WHERE activo = true AND publicado_ecommerce = true AND visible_ecommerce = true AND es_vendible = true AND es_comprable = true AND COALESCE(descontinuado, false) = false;

create view "public"."catalogo_productos" as
 SELECT id,
    nombre,
    nombre_corto,
    slug,
    categoria_id,
    marca_id,
    descripcion_corta,
    precio_base,
    destacado_ecommerce,
    orden_ecommerce,
    color,
    piezas_por_paquete,
    sku
   FROM productos p
  WHERE activo = true AND publicado_ecommerce = true AND visible_ecommerce = true AND es_vendible = true AND es_comprable = true AND COALESCE(descontinuado, false) = false;

create view "public"."catalogo_publico" as
 SELECT p.id,
    p.sku AS codigo,
    p.nombre,
    m.nombre AS marca,
    c.nombre AS categoria,
    COALESCE(p.descripcion_corta, p.descripcion_larga) AS descripcion,
    p.precio_base AS precio,
        CASE
            WHEN oferta.oferta_porcentaje IS NULL THEN NULL::numeric
            ELSE round(p.precio_base * (1::numeric - oferta.oferta_porcentaje / 100::numeric), 2)
        END AS oferta,
    COALESCE(sum(e.stock_disponible) FILTER (WHERE e.activo), 0::numeric) AS stock,
    ( SELECT pi.url_publica
           FROM producto_imagenes pi
          WHERE pi.producto_id = p.id AND pi.activo = true
          ORDER BY pi.es_principal DESC, pi.orden
         LIMIT 1) AS imagen_url
   FROM productos p
     JOIN categorias c ON c.id = p.categoria_id
     LEFT JOIN marcas m ON m.id = p.marca_id
     LEFT JOIN existencias e ON e.producto_id = p.id
     LEFT JOIN LATERAL ( SELECT op.oferta_porcentaje
           FROM ofertas_producto op
          WHERE op.producto_id = p.id AND op.activo = true AND op.aplica_ecommerce = true AND op.fecha_inicio <= now() AND (op.fecha_fin IS NULL OR op.fecha_fin >= now())
          ORDER BY op.fecha_inicio DESC
         LIMIT 1) oferta ON true
  WHERE p.activo = true AND p.descontinuado = false AND p.es_vendible = true AND p.publicado_ecommerce = true AND p.visible_ecommerce = true AND c.activo = true AND c.visible_ecommerce = true
  GROUP BY p.id, p.sku, p.nombre, m.nombre, c.nombre, p.descripcion_corta, p.descripcion_larga, p.precio_base, oferta.oferta_porcentaje;

CREATE TRIGGER alertas_inventario_alertas_operativas AFTER INSERT OR UPDATE OF activa, estado ON alertas_inventario FOR EACH ROW EXECUTE FUNCTION encolar_alerta_inventario_ecommerce();

CREATE TRIGGER auditoria_categorias AFTER INSERT OR DELETE OR UPDATE ON categorias FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER categorias_updated_at BEFORE UPDATE ON categorias FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_actualizacion();

CREATE TRIGGER auditoria_existencias AFTER INSERT OR DELETE OR UPDATE ON existencias FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER existencias_generar_alertas AFTER INSERT OR UPDATE ON existencias FOR EACH ROW EXECUTE FUNCTION actualizar_alertas_despues_de_stock();

CREATE TRIGGER existencias_no_negativas BEFORE INSERT OR UPDATE OF stock_fisico, stock_reservado, stock_disponible ON existencias FOR EACH ROW EXECUTE FUNCTION validar_existencia_no_negativa();

CREATE TRIGGER trg_existencias_fecha_actualizacion BEFORE UPDATE ON existencias FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_actualizacion();

CREATE TRIGGER auditoria_marcas AFTER INSERT OR DELETE OR UPDATE ON marcas FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER marcas_updated_at BEFORE UPDATE ON marcas FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_actualizacion();

CREATE TRIGGER auditoria_movimientos AFTER INSERT OR DELETE OR UPDATE ON movimientos FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER erp_00_capture_movement BEFORE INSERT ON movimientos FOR EACH ROW EXECUTE FUNCTION erp_private.capture_movement();

CREATE TRIGGER movimientos_completar_costo BEFORE INSERT ON movimientos FOR EACH ROW EXECUTE FUNCTION completar_costo_movimiento();

CREATE TRIGGER auditoria_ofertas_producto AFTER INSERT OR DELETE OR UPDATE ON ofertas_producto FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER auditoria_ordenes_compra AFTER INSERT OR DELETE OR UPDATE ON ordenes_compra FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER factura_ecommerce_pago_confirmado AFTER UPDATE OF estado ON pedidos_ecommerce FOR EACH ROW EXECUTE FUNCTION erp_factura_al_confirmar_pago();

CREATE TRIGGER pedidos_ecommerce_alertas_operativas AFTER INSERT OR UPDATE OF estado ON pedidos_ecommerce FOR EACH ROW EXECUTE FUNCTION encolar_alerta_pedido_ecommerce();

CREATE TRIGGER pedidos_ecommerce_procesar_reserva BEFORE UPDATE OF estado ON pedidos_ecommerce FOR EACH ROW EXECUTE FUNCTION procesar_estado_pedido_ecommerce();

CREATE TRIGGER auditoria_perfiles AFTER INSERT OR DELETE OR UPDATE ON perfiles FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER trg_perfiles_fecha_actualizacion BEFORE UPDATE ON perfiles FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_actualizacion();

CREATE TRIGGER auditoria_permisos AFTER INSERT OR DELETE OR UPDATE ON permisos FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER trg_permisos_fecha_actualizacion BEFORE UPDATE ON permisos FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_actualizacion();

CREATE TRIGGER auditoria_producto_imagenes AFTER INSERT OR DELETE OR UPDATE ON producto_imagenes FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER producto_imagenes_updated_at BEFORE UPDATE ON producto_imagenes FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_actualizacion();

CREATE TRIGGER auditoria_productos AFTER INSERT OR DELETE OR UPDATE ON productos FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER productos_updated_at BEFORE UPDATE ON productos FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_actualizacion();

CREATE TRIGGER auditoria_proveedores AFTER INSERT OR DELETE OR UPDATE ON proveedores FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER auditoria_reservas AFTER INSERT OR DELETE OR UPDATE ON reservas FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER trg_reservas_fecha_actualizacion BEFORE UPDATE ON reservas FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_actualizacion();

CREATE TRIGGER auditoria_roles AFTER INSERT OR DELETE OR UPDATE ON roles FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER trg_roles_fecha_actualizacion BEFORE UPDATE ON roles FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_actualizacion();

CREATE TRIGGER auditoria_ubicaciones AFTER INSERT OR DELETE OR UPDATE ON ubicaciones FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER ubicaciones_updated_at BEFORE UPDATE ON ubicaciones FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_actualizacion();

CREATE TRIGGER auditoria_unidades_medida AFTER INSERT OR DELETE OR UPDATE ON unidades_medida FOR EACH ROW EXECUTE FUNCTION registrar_auditoria();

CREATE TRIGGER unidades_medida_updated_at BEFORE UPDATE ON unidades_medida FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_actualizacion();

CREATE TRIGGER trg_usuario_permisos_fecha_actualizacion BEFORE UPDATE ON usuario_permisos FOR EACH ROW EXECUTE FUNCTION actualizar_fecha_actualizacion();

CREATE TRIGGER al_crear_usuario_perfil AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION crear_perfil_cliente();

alter table "public"."ajustes_inventario" enable row level security;

alter table "public"."alertas_inventario" enable row level security;

alter table "public"."anuncios_editoriales_ecommerce" enable row level security;

alter table "public"."anuncios_inicio_ecommerce" enable row level security;

alter table "public"."auditoria" enable row level security;

alter table "public"."banners_ecommerce" enable row level security;

alter table "public"."carritos_ecommerce" enable row level security;

alter table "public"."categorias" enable row level security;

alter table "public"."configuracion_ecommerce" enable row level security;

alter table "public"."configuracion_erp" enable row level security;

alter table "public"."conteos_inventario" enable row level security;

alter table "public"."devoluciones_venta" enable row level security;

alter table "public"."existencias" enable row level security;

alter table "public"."facturas_ecommerce" enable row level security;

alter table "public"."favoritos_ecommerce" enable row level security;

alter table "public"."marcas" enable row level security;

alter table "public"."movimientos" enable row level security;

alter table "public"."notificaciones_operativas_ecommerce" enable row level security;

alter table "public"."ofertas_producto" enable row level security;

alter table "public"."ordenes_compra" enable row level security;

alter table "public"."ordenes_compra_detalle" enable row level security;

alter table "public"."pedidos_ecommerce" enable row level security;

alter table "public"."pedidos_ecommerce_detalle" enable row level security;

alter table "public"."perfiles" enable row level security;

alter table "public"."permisos" enable row level security;

alter table "public"."producto_imagenes" enable row level security;

alter table "public"."productos" enable row level security;

alter table "public"."proveedores" enable row level security;

alter table "public"."recepciones_compra" enable row level security;

alter table "public"."recepciones_compra_detalle" enable row level security;

alter table "public"."recordatorios_carrito_ecommerce" enable row level security;

alter table "public"."reservas" enable row level security;

alter table "public"."rol_permisos" enable row level security;

alter table "public"."roles" enable row level security;

alter table "public"."suscripciones_newsletter" enable row level security;

alter table "public"."ubicaciones" enable row level security;

alter table "public"."unidades_medida" enable row level security;

alter table "public"."usuario_permisos" enable row level security;

alter table "public"."usuario_ubicaciones" enable row level security;

alter table "public"."ventas_pos" enable row level security;

alter table "public"."ventas_pos_detalle" enable row level security;

create policy "ajustes_inventario_select" on "public"."ajustes_inventario" as permissive for select to "authenticated" using ((tiene_permiso('existencias.ajustar'::text) AND tiene_acceso_ubicacion(ubicacion_id)));

create policy "alertas_inventario_select" on "public"."alertas_inventario" as permissive for select to "authenticated" using ((erp_usuario_activo() AND COALESCE(tiene_permiso('existencias.ver'::text), false) AND COALESCE(tiene_acceso_ubicacion(ubicacion_id), false)));

create policy "ecommerce_public_read_anuncios_editoriales" on "public"."anuncios_editoriales_ecommerce" as permissive for select to "anon", "authenticated" using ((activo = true));

create policy "ecommerce_public_read_anuncios_inicio" on "public"."anuncios_inicio_ecommerce" as permissive for select to "anon", "authenticated" using ((activo = true));

create policy "erp_manage_anuncios_inicio" on "public"."anuncios_inicio_ecommerce" as permissive for all to "authenticated" using (tiene_permiso('banners.editar'::text)) with check (tiene_permiso('banners.editar'::text));

create policy "auditoria_select" on "public"."auditoria" as permissive for select to "authenticated" using (tiene_permiso('usuarios.ver'::text));

create policy "ecommerce_authenticated_read_banners" on "public"."banners_ecommerce" as permissive for select to "authenticated" using ((activo = true));

create policy "ecommerce_public_read_banners" on "public"."banners_ecommerce" as permissive for select to "anon" using ((activo = true));

create policy "erp_manage_banners" on "public"."banners_ecommerce" as permissive for all to "authenticated" using (tiene_permiso('banners.editar'::text)) with check (tiene_permiso('banners.editar'::text));

create policy "cliente administra su carrito" on "public"."carritos_ecommerce" as permissive for all to "authenticated" using ((cliente_id = auth.uid())) with check ((cliente_id = auth.uid()));

create policy "categorias_insert" on "public"."categorias" as permissive for insert to "authenticated" with check (tiene_permiso('categorias.crear'::text));

create policy "categorias_select" on "public"."categorias" as permissive for select to "authenticated" using (tiene_permiso('categorias.ver'::text));

create policy "categorias_update" on "public"."categorias" as permissive for update to "authenticated" using (tiene_permiso('categorias.editar'::text)) with check (tiene_permiso('categorias.editar'::text));

create policy "ecommerce_authenticated_read_categories" on "public"."categorias" as permissive for select to "authenticated" using (((activo = true) AND (visible_ecommerce = true)));

create policy "ecommerce_public_read_categories" on "public"."categorias" as permissive for select to "anon" using (((activo = true) AND (visible_ecommerce = true)));

create policy "configuracion_erp_insert" on "public"."configuracion_erp" as permissive for insert to "authenticated" with check (tiene_permiso('configuracion.editar'::text));

create policy "configuracion_erp_select" on "public"."configuracion_erp" as permissive for select to "authenticated" using ((tiene_permiso('configuracion.ver'::text) OR tiene_permiso('configuracion.editar'::text)));

create policy "configuracion_erp_update" on "public"."configuracion_erp" as permissive for update to "authenticated" using (tiene_permiso('configuracion.editar'::text)) with check (tiene_permiso('configuracion.editar'::text));

create policy "conteos_inventario_insert" on "public"."conteos_inventario" as permissive for insert to "authenticated" with check ((tiene_permiso('existencias.ajustar'::text) AND tiene_acceso_ubicacion(ubicacion_id)));

create policy "conteos_inventario_select" on "public"."conteos_inventario" as permissive for select to "authenticated" using ((tiene_permiso('existencias.ver'::text) AND tiene_acceso_ubicacion(ubicacion_id)));

create policy "devoluciones_venta_insert" on "public"."devoluciones_venta" as permissive for insert to "authenticated" with check ((tiene_permiso('existencias.ajustar'::text) AND tiene_acceso_ubicacion(ubicacion_id)));

create policy "devoluciones_venta_select" on "public"."devoluciones_venta" as permissive for select to "authenticated" using ((tiene_permiso('existencias.ver'::text) AND tiene_acceso_ubicacion(ubicacion_id)));

create policy "existencias_insert" on "public"."existencias" as permissive for insert to "authenticated" with check ((tiene_permiso('existencias.ajustar'::text) AND tiene_acceso_ubicacion(ubicacion_id)));

create policy "existencias_select" on "public"."existencias" as permissive for select to "authenticated" using ((tiene_permiso('existencias.ver'::text) AND tiene_acceso_ubicacion(ubicacion_id)));

create policy "existencias_update" on "public"."existencias" as permissive for update to "authenticated" using ((tiene_permiso('existencias.ajustar'::text) AND tiene_acceso_ubicacion(ubicacion_id))) with check ((tiene_permiso('existencias.ajustar'::text) AND tiene_acceso_ubicacion(ubicacion_id)));

create policy "erp_facturas_select" on "public"."facturas_ecommerce" as permissive for select to "authenticated" using ((tiene_permiso('productos.ver'::text) AND tiene_acceso_ubicacion(ubicacion_id)));

create policy "cliente_manage_own_favorites" on "public"."favoritos_ecommerce" as permissive for all to "authenticated" using ((usuario_id = auth.uid())) with check ((usuario_id = auth.uid()));

create policy "ecommerce_authenticated_read_brands" on "public"."marcas" as permissive for select to "authenticated" using ((activo = true));

create policy "ecommerce_public_read_brands" on "public"."marcas" as permissive for select to "anon" using ((activo = true));

create policy "marcas_insert" on "public"."marcas" as permissive for insert to "authenticated" with check (tiene_permiso('marcas.crear'::text));

create policy "marcas_select" on "public"."marcas" as permissive for select to "authenticated" using (tiene_permiso('marcas.ver'::text));

create policy "marcas_update" on "public"."marcas" as permissive for update to "authenticated" using (tiene_permiso('marcas.editar'::text)) with check (tiene_permiso('marcas.editar'::text));

create policy "movimientos_select" on "public"."movimientos" as permissive for select to "authenticated" using ((tiene_permiso('movimientos.ver'::text) AND tiene_acceso_ubicacion(ubicacion_id)));

create policy "ecommerce_authenticated_read_product_offers" on "public"."ofertas_producto" as permissive for select to "authenticated" using (((activo = true) AND (aplica_ecommerce = true)));

create policy "ecommerce_public_read_product_offers" on "public"."ofertas_producto" as permissive for select to "anon" using (((activo = true) AND (aplica_ecommerce = true)));

create policy "ofertas_producto_delete" on "public"."ofertas_producto" as permissive for delete to "authenticated" using (tiene_permiso('productos.editar'::text));

create policy "ofertas_producto_insert" on "public"."ofertas_producto" as permissive for insert to "authenticated" with check (tiene_permiso('productos.editar'::text));

create policy "ofertas_producto_select" on "public"."ofertas_producto" as permissive for select to "authenticated" using (tiene_permiso('productos.ver'::text));

create policy "ofertas_producto_update" on "public"."ofertas_producto" as permissive for update to "authenticated" using (tiene_permiso('productos.editar'::text)) with check (tiene_permiso('productos.editar'::text));

create policy "ordenes_compra_select" on "public"."ordenes_compra" as permissive for select to "authenticated" using (tiene_permiso('compras.ver'::text));

create policy "ordenes_compra_detalle_select" on "public"."ordenes_compra_detalle" as permissive for select to "authenticated" using (tiene_permiso('compras.ver'::text));

create policy "cliente ve sus pedidos" on "public"."pedidos_ecommerce" as permissive for select to "authenticated" using ((cliente_id = auth.uid()));

create policy "pedidos_ecommerce_select" on "public"."pedidos_ecommerce" as permissive for select to "authenticated" using (tiene_permiso('productos.ver'::text));

create policy "cliente_read_own_order_lines" on "public"."pedidos_ecommerce_detalle" as permissive for select to "authenticated" using ((EXISTS ( SELECT 1
   FROM pedidos_ecommerce pedido
  WHERE ((pedido.id = pedidos_ecommerce_detalle.pedido_id) AND (pedido.cliente_id = auth.uid())))));

create policy "pedidos_ecommerce_detalle_select" on "public"."pedidos_ecommerce_detalle" as permissive for select to "authenticated" using (tiene_permiso('productos.ver'::text));

create policy "cliente ve su perfil" on "public"."perfiles" as permissive for select to "authenticated" using ((id = auth.uid()));

create policy "perfiles_insert" on "public"."perfiles" as permissive for insert to "authenticated" with check (tiene_permiso('usuarios.crear'::text));

create policy "perfiles_select" on "public"."perfiles" as permissive for select to "authenticated" using (tiene_permiso('usuarios.ver'::text));

create policy "perfiles_update" on "public"."perfiles" as permissive for update to "authenticated" using (tiene_permiso('usuarios.editar'::text)) with check (tiene_permiso('usuarios.editar'::text));

create policy "permisos_insert" on "public"."permisos" as permissive for insert to "authenticated" with check (tiene_permiso('permisos.asignar'::text));

create policy "permisos_select" on "public"."permisos" as permissive for select to "authenticated" using (tiene_permiso('permisos.ver'::text));

create policy "permisos_update" on "public"."permisos" as permissive for update to "authenticated" using (tiene_permiso('permisos.asignar'::text)) with check (tiene_permiso('permisos.asignar'::text));

create policy "ecommerce_authenticated_read_product_images" on "public"."producto_imagenes" as permissive for select to "authenticated" using ((activo = true));

create policy "ecommerce_public_read_product_images" on "public"."producto_imagenes" as permissive for select to "anon" using ((activo = true));

create policy "producto_imagenes_delete" on "public"."producto_imagenes" as permissive for delete to "authenticated" using (tiene_permiso('productos.editar'::text));

create policy "producto_imagenes_insert" on "public"."producto_imagenes" as permissive for insert to "authenticated" with check (tiene_permiso('productos.editar'::text));

create policy "producto_imagenes_pending_select" on "public"."producto_imagenes" as permissive for select to "authenticated" using (((estado_storage <> 'ACTIVA'::text) AND erp_usuario_activo() AND tiene_permiso('productos.editar'::text)));

create policy "producto_imagenes_select" on "public"."producto_imagenes" as permissive for select to "authenticated" using (tiene_permiso('productos.ver'::text));

create policy "producto_imagenes_update" on "public"."producto_imagenes" as permissive for update to "authenticated" using (tiene_permiso('productos.editar'::text)) with check (tiene_permiso('productos.editar'::text));

create policy "erp_staff_read_products" on "public"."productos" as permissive for select to "authenticated" using (tiene_permiso('productos.ver'::text));

create policy "productos_insert" on "public"."productos" as permissive for insert to "authenticated" with check (tiene_permiso('productos.crear'::text));

create policy "productos_select" on "public"."productos" as permissive for select to "authenticated" using (tiene_permiso('productos.ver'::text));

create policy "productos_update" on "public"."productos" as permissive for update to "authenticated" using (tiene_permiso('productos.editar'::text)) with check (tiene_permiso('productos.editar'::text));

create policy "proveedores_insert" on "public"."proveedores" as permissive for insert to "authenticated" with check (tiene_permiso('productos.crear'::text));

create policy "proveedores_select" on "public"."proveedores" as permissive for select to "authenticated" using (tiene_permiso('productos.ver'::text));

create policy "proveedores_update" on "public"."proveedores" as permissive for update to "authenticated" using (tiene_permiso('productos.editar'::text)) with check (tiene_permiso('productos.editar'::text));

create policy "recepciones_compra_select" on "public"."recepciones_compra" as permissive for select to "authenticated" using ((tiene_permiso('compras.ver'::text) AND tiene_acceso_ubicacion(ubicacion_id)));

create policy "recepciones_compra_detalle_select" on "public"."recepciones_compra_detalle" as permissive for select to "authenticated" using ((EXISTS ( SELECT 1
   FROM recepciones_compra r
  WHERE ((r.id = recepciones_compra_detalle.recepcion_id) AND tiene_permiso('compras.ver'::text) AND tiene_acceso_ubicacion(r.ubicacion_id)))));

create policy "reservas_select" on "public"."reservas" as permissive for select to "authenticated" using ((tiene_permiso('reservas.ver'::text) AND tiene_acceso_ubicacion(ubicacion_id)));

create policy "rol_permisos_delete" on "public"."rol_permisos" as permissive for delete to "authenticated" using (tiene_permiso('permisos.asignar'::text));

create policy "rol_permisos_insert" on "public"."rol_permisos" as permissive for insert to "authenticated" with check (tiene_permiso('permisos.asignar'::text));

create policy "rol_permisos_select" on "public"."rol_permisos" as permissive for select to "authenticated" using (tiene_permiso('roles.ver'::text));

create policy "roles_insert" on "public"."roles" as permissive for insert to "authenticated" with check (tiene_permiso('roles.crear'::text));

create policy "roles_select" on "public"."roles" as permissive for select to "authenticated" using (tiene_permiso('roles.ver'::text));

create policy "roles_update" on "public"."roles" as permissive for update to "authenticated" using (tiene_permiso('roles.editar'::text)) with check (tiene_permiso('roles.editar'::text));

create policy "ubicaciones_insert" on "public"."ubicaciones" as permissive for insert to "authenticated" with check (tiene_permiso('ubicaciones.crear'::text));

create policy "ubicaciones_select" on "public"."ubicaciones" as permissive for select to "authenticated" using (tiene_permiso('ubicaciones.ver'::text));

create policy "ubicaciones_update" on "public"."ubicaciones" as permissive for update to "authenticated" using (tiene_permiso('ubicaciones.editar'::text)) with check (tiene_permiso('ubicaciones.editar'::text));

create policy "unidades_medida_insert" on "public"."unidades_medida" as permissive for insert to "authenticated" with check (tiene_permiso('unidades.crear'::text));

create policy "unidades_medida_select" on "public"."unidades_medida" as permissive for select to "authenticated" using (tiene_permiso('unidades.ver'::text));

create policy "unidades_medida_update" on "public"."unidades_medida" as permissive for update to "authenticated" using (tiene_permiso('unidades.editar'::text)) with check (tiene_permiso('unidades.editar'::text));

create policy "usuario_permisos_delete" on "public"."usuario_permisos" as permissive for delete to "authenticated" using (tiene_permiso('permisos.asignar'::text));

create policy "usuario_permisos_insert" on "public"."usuario_permisos" as permissive for insert to "authenticated" with check (tiene_permiso('permisos.asignar'::text));

create policy "usuario_permisos_select" on "public"."usuario_permisos" as permissive for select to "authenticated" using (tiene_permiso('permisos.ver'::text));

create policy "usuario_permisos_update" on "public"."usuario_permisos" as permissive for update to "authenticated" using (tiene_permiso('permisos.asignar'::text)) with check (tiene_permiso('permisos.asignar'::text));

create policy "usuario_ubicaciones_delete" on "public"."usuario_ubicaciones" as permissive for delete to "authenticated" using (tiene_permiso('ubicaciones.administrar'::text));

create policy "usuario_ubicaciones_insert" on "public"."usuario_ubicaciones" as permissive for insert to "authenticated" with check (tiene_permiso('ubicaciones.administrar'::text));

create policy "usuario_ubicaciones_select" on "public"."usuario_ubicaciones" as permissive for select to "authenticated" using (tiene_permiso('ubicaciones.ver'::text));

create policy "usuario_ubicaciones_update" on "public"."usuario_ubicaciones" as permissive for update to "authenticated" using (tiene_permiso('ubicaciones.administrar'::text)) with check (tiene_permiso('ubicaciones.administrar'::text));

create policy "ventas_pos_select" on "public"."ventas_pos" as permissive for select to "authenticated" using ((tiene_permiso('pos.vender'::text) AND tiene_acceso_ubicacion(ubicacion_id)));

create policy "ventas_pos_detalle_select" on "public"."ventas_pos_detalle" as permissive for select to "authenticated" using (tiene_permiso('pos.vender'::text));

create policy "Authenticated users can delete ecommerce banners" on "storage"."objects" as permissive for delete to "authenticated" using ((bucket_id = 'ecommerce-banners'::text));

create policy "Authenticated users can read ecommerce banners" on "storage"."objects" as permissive for select to "authenticated" using ((bucket_id = 'ecommerce-banners'::text));

create policy "Authenticated users can update ecommerce banners" on "storage"."objects" as permissive for update to "authenticated" using ((bucket_id = 'ecommerce-banners'::text)) with check ((bucket_id = 'ecommerce-banners'::text));

create policy "Authenticated users can upload ecommerce banners" on "storage"."objects" as permissive for insert to "authenticated" with check ((bucket_id = 'ecommerce-banners'::text));

create policy "ecommerce_public_read_anuncios_inicio_files" on "storage"."objects" as permissive for select to PUBLIC using ((bucket_id = 'ecommerce-anuncios-inicio'::text));

create policy "productos_storage_delete" on "storage"."objects" as permissive for delete to "authenticated" using (((bucket_id = 'productos'::text) AND erp_usuario_activo() AND tiene_permiso('productos.editar'::text) AND (EXISTS ( SELECT 1
   FROM producto_imagenes i
  WHERE (((i.storage_bucket)::text = objects.bucket_id) AND (i.storage_path = objects.name) AND (i.estado_storage = 'BORRANDO'::text))))));

create policy "productos_storage_insert" on "storage"."objects" as permissive for insert to "authenticated" with check (((bucket_id = 'productos'::text) AND erp_usuario_activo() AND tiene_permiso('productos.editar'::text) AND (EXISTS ( SELECT 1
   FROM producto_imagenes i
  WHERE (((i.storage_bucket)::text = objects.bucket_id) AND (i.storage_path = objects.name) AND (i.estado_storage = 'CARGANDO'::text) AND (i.creado_por = auth.uid()))))));

create policy "productos_storage_select_editor" on "storage"."objects" as permissive for select to "authenticated" using (((bucket_id = 'productos'::text) AND erp_usuario_activo() AND tiene_permiso('productos.editar'::text)));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('ecommerce-anuncios-editoriales','ecommerce-anuncios-editoriales',true,5242880,ARRAY['image/jpeg','image/png','image/webp','image/avif']::text[]) on conflict(id) do nothing;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('ecommerce-anuncios-inicio','ecommerce-anuncios-inicio',true,NULL,NULL) on conflict(id) do nothing;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('ecommerce-banners','ecommerce-banners',true,5242880,ARRAY['image/jpeg','image/png','image/webp','image/avif']::text[]) on conflict(id) do nothing;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('ecommerce-categorias','ecommerce-categorias',true,5242880,ARRAY['image/jpeg','image/png','image/webp','image/avif']::text[]) on conflict(id) do nothing;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('ecommerce-marcas','ecommerce-marcas',true,5242880,ARRAY['image/jpeg','image/png','image/webp','image/avif']::text[]) on conflict(id) do nothing;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('productos','productos',true,NULL,NULL) on conflict(id) do nothing;

revoke all on all tables in schema "public" from public,anon,authenticated,service_role;

revoke all on all sequences in schema "public" from public,anon,authenticated,service_role;

revoke all on all functions in schema "public" from public,anon,authenticated,service_role;

revoke all on all tables in schema "private" from public,anon,authenticated,service_role;

revoke all on all sequences in schema "private" from public,anon,authenticated,service_role;

revoke all on all functions in schema "private" from public,anon,authenticated,service_role;

revoke all on all tables in schema "erp_private" from public,anon,authenticated,service_role;

revoke all on all sequences in schema "erp_private" from public,anon,authenticated,service_role;

revoke all on all functions in schema "erp_private" from public,anon,authenticated,service_role;

grant usage on schema public to anon,authenticated,service_role;

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."ajustes_inventario" to "anon";

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."ajustes_inventario" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."ajustes_inventario" to "service_role";

grant SELECT on table "public"."alertas_inventario" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."alertas_inventario" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."anuncios_editoriales_ecommerce" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."anuncios_editoriales_ecommerce" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."anuncios_editoriales_ecommerce" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."anuncios_inicio_ecommerce" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."anuncios_inicio_ecommerce" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."anuncios_inicio_ecommerce" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."auditoria" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."auditoria" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."auditoria" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."auditoria_calidad_catalogo_ecommerce" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."banners_ecommerce" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."banners_ecommerce" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."banners_ecommerce" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."carritos_ecommerce" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."carritos_ecommerce" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."carritos_ecommerce" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."catalogo_producto_detalle" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."catalogo_producto_detalle" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."catalogo_producto_detalle" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."catalogo_productos" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."catalogo_productos" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."catalogo_productos" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."catalogo_publico" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."catalogo_publico" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."catalogo_publico" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."categorias" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."categorias" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."categorias" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."configuracion_ecommerce" to "service_role";

grant INSERT,SELECT,UPDATE on table "public"."configuracion_erp" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."configuracion_erp" to "service_role";

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."conteos_inventario" to "anon";

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."conteos_inventario" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."conteos_inventario" to "service_role";

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."devoluciones_venta" to "anon";

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."devoluciones_venta" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."devoluciones_venta" to "service_role";

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."existencias" to "anon";

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."existencias" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."existencias" to "service_role";

grant SELECT on table "public"."facturas_ecommerce" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."facturas_ecommerce" to "service_role";

grant SELECT,UPDATE,USAGE on sequence "public"."facturas_ecommerce_numero_seq" to "anon";

grant SELECT,UPDATE,USAGE on sequence "public"."facturas_ecommerce_numero_seq" to "authenticated";

grant SELECT,UPDATE,USAGE on sequence "public"."facturas_ecommerce_numero_seq" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."favoritos_ecommerce" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."favoritos_ecommerce" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."favoritos_ecommerce" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."marcas" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."marcas" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."marcas" to "service_role";

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."movimientos" to "anon";

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."movimientos" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."movimientos" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."notificaciones_operativas_ecommerce" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."ofertas_producto" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."ofertas_producto" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."ofertas_producto" to "service_role";

grant SELECT on table "public"."ordenes_compra" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."ordenes_compra" to "service_role";

grant SELECT on table "public"."ordenes_compra_detalle" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."ordenes_compra_detalle" to "service_role";

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."pedidos_ecommerce" to "anon";

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."pedidos_ecommerce" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."pedidos_ecommerce" to "service_role";

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."pedidos_ecommerce_detalle" to "anon";

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."pedidos_ecommerce_detalle" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."pedidos_ecommerce_detalle" to "service_role";

grant SELECT,UPDATE,USAGE on sequence "public"."pedidos_ecommerce_numero_seq" to "anon";

grant SELECT,UPDATE,USAGE on sequence "public"."pedidos_ecommerce_numero_seq" to "authenticated";

grant SELECT,UPDATE,USAGE on sequence "public"."pedidos_ecommerce_numero_seq" to "service_role";

grant DELETE,MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."perfiles" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."perfiles" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."permisos" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."permisos" to "service_role";

grant MAINTAIN,REFERENCES,SELECT on table "public"."producto_imagenes" to "anon";

grant MAINTAIN,REFERENCES,SELECT on table "public"."producto_imagenes" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."producto_imagenes" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,TRIGGER,UPDATE on table "public"."productos" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."productos" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."productos" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."proveedores" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."proveedores" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."proveedores" to "service_role";

grant SELECT on table "public"."recepciones_compra" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."recepciones_compra" to "service_role";

grant SELECT on table "public"."recepciones_compra_detalle" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."recepciones_compra_detalle" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."recordatorios_carrito_ecommerce" to "service_role";

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."reservas" to "anon";

grant MAINTAIN,REFERENCES,SELECT,TRIGGER on table "public"."reservas" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."reservas" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."rol_permisos" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."rol_permisos" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."roles" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."roles" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."suscripciones_newsletter" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."ubicaciones" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."ubicaciones" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."ubicaciones" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."unidades_medida" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."unidades_medida" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."unidades_medida" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."usuario_permisos" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."usuario_permisos" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."usuario_ubicaciones" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."usuario_ubicaciones" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."ventas_pos" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."ventas_pos" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."ventas_pos" to "service_role";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."ventas_pos_detalle" to "anon";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,UPDATE on table "public"."ventas_pos_detalle" to "authenticated";

grant DELETE,INSERT,MAINTAIN,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE on table "public"."ventas_pos_detalle" to "service_role";

grant UPDATE("stock_maximo") on table "public"."existencias" to "authenticated";

grant UPDATE("stock_minimo") on table "public"."existencias" to "authenticated";

grant EXECUTE on function "public"."actualizar_alertas_despues_de_stock"() to "service_role";

grant EXECUTE on function "public"."actualizar_fecha_actualizacion"() to PUBLIC;

grant EXECUTE on function "public"."actualizar_fecha_actualizacion"() to "anon";

grant EXECUTE on function "public"."actualizar_fecha_actualizacion"() to "authenticated";

grant EXECUTE on function "public"."actualizar_fecha_actualizacion"() to "service_role";

grant EXECUTE on function "public"."actualizar_mi_perfil"(p_datos jsonb) to "authenticated";

grant EXECUTE on function "public"."actualizar_mi_perfil"(p_datos jsonb) to "service_role";

grant EXECUTE on function "public"."autorizar_ajuste_inventario"(p_ajuste_id uuid, p_aprobar boolean, p_comentario text) to "authenticated";

grant EXECUTE on function "public"."autorizar_ajuste_inventario"(p_ajuste_id uuid, p_aprobar boolean, p_comentario text) to "service_role";

grant EXECUTE on function "public"."cancelar_pedido_ecommerce"(p_pedido_id uuid, p_motivo text) to "authenticated";

grant EXECUTE on function "public"."cancelar_pedido_ecommerce"(p_pedido_id uuid, p_motivo text) to "service_role";

grant EXECUTE on function "public"."completar_costo_movimiento"() to PUBLIC;

grant EXECUTE on function "public"."completar_costo_movimiento"() to "anon";

grant EXECUTE on function "public"."completar_costo_movimiento"() to "authenticated";

grant EXECUTE on function "public"."completar_costo_movimiento"() to "service_role";

grant EXECUTE on function "public"."confirmar_pago_ecommerce"(p_pedido_id uuid) to "authenticated";

grant EXECUTE on function "public"."confirmar_pago_ecommerce"(p_pedido_id uuid) to "service_role";

grant EXECUTE on function "public"."consumir_reserva"(p_reserva_id uuid, p_costo_unitario numeric, p_observaciones text) to "authenticated";

grant EXECUTE on function "public"."consumir_reserva"(p_reserva_id uuid, p_costo_unitario numeric, p_observaciones text) to "service_role";

grant EXECUTE on function "public"."crear_orden_compra"(p_proveedor_id uuid, p_fecha_esperada date, p_observaciones text, p_items jsonb) to "authenticated";

grant EXECUTE on function "public"."crear_orden_compra"(p_proveedor_id uuid, p_fecha_esperada date, p_observaciones text, p_items jsonb) to "service_role";

grant EXECUTE on function "public"."crear_pedido_ecommerce"(p_items jsonb, p_metodo_entrega character varying, p_metodo_pago character varying) to "anon";

grant EXECUTE on function "public"."crear_pedido_ecommerce"(p_items jsonb, p_metodo_entrega character varying, p_metodo_pago character varying) to "authenticated";

grant EXECUTE on function "public"."crear_pedido_ecommerce"(p_items jsonb, p_metodo_entrega character varying, p_metodo_pago character varying) to "service_role";

grant EXECUTE on function "public"."crear_perfil_cliente"() to PUBLIC;

grant EXECUTE on function "public"."crear_perfil_cliente"() to "anon";

grant EXECUTE on function "public"."crear_perfil_cliente"() to "authenticated";

grant EXECUTE on function "public"."crear_perfil_cliente"() to "service_role";

grant EXECUTE on function "public"."crear_reserva"(p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_origen character varying, p_referencia_tipo character varying, p_referencia_id uuid, p_referencia_numero character varying, p_fecha_expiracion timestamp with time zone) to "authenticated";

grant EXECUTE on function "public"."crear_reserva"(p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_origen character varying, p_referencia_tipo character varying, p_referencia_id uuid, p_referencia_numero character varying, p_fecha_expiracion timestamp with time zone) to "service_role";

grant EXECUTE on function "public"."encolar_alerta_inventario_ecommerce"() to PUBLIC;

grant EXECUTE on function "public"."encolar_alerta_inventario_ecommerce"() to "anon";

grant EXECUTE on function "public"."encolar_alerta_inventario_ecommerce"() to "authenticated";

grant EXECUTE on function "public"."encolar_alerta_inventario_ecommerce"() to "service_role";

grant EXECUTE on function "public"."encolar_alerta_pedido_ecommerce"() to PUBLIC;

grant EXECUTE on function "public"."encolar_alerta_pedido_ecommerce"() to "anon";

grant EXECUTE on function "public"."encolar_alerta_pedido_ecommerce"() to "authenticated";

grant EXECUTE on function "public"."encolar_alerta_pedido_ecommerce"() to "service_role";

grant EXECUTE on function "public"."erp_accion_pedido"(p_pedido_id uuid, p_accion text, p_motivo text) to "authenticated";

grant EXECUTE on function "public"."erp_accion_pedido"(p_pedido_id uuid, p_accion text, p_motivo text) to "service_role";

grant EXECUTE on function "public"."erp_buscar_existencias"(p_busqueda text, p_offset integer, p_limite integer) to "authenticated";

grant EXECUTE on function "public"."erp_buscar_existencias"(p_busqueda text, p_offset integer, p_limite integer) to "service_role";

grant EXECUTE on function "public"."erp_confirmar_borrado_imagen_producto"(p_imagen_id uuid) to "authenticated";

grant EXECUTE on function "public"."erp_confirmar_borrado_imagen_producto"(p_imagen_id uuid) to "service_role";

grant EXECUTE on function "public"."erp_confirmar_carga_imagen_producto"(p_imagen_id uuid) to "authenticated";

grant EXECUTE on function "public"."erp_confirmar_carga_imagen_producto"(p_imagen_id uuid) to "service_role";

grant EXECUTE on function "public"."erp_confirmar_orden_compra"(p_orden_id uuid) to "authenticated";

grant EXECUTE on function "public"."erp_confirmar_orden_compra"(p_orden_id uuid) to "service_role";

grant EXECUTE on function "public"."erp_delta_movimiento"(p_tipo text, p_cantidad numeric, p_anterior numeric, p_posterior numeric) to "authenticated";

grant EXECUTE on function "public"."erp_delta_movimiento"(p_tipo text, p_cantidad numeric, p_anterior numeric, p_posterior numeric) to "service_role";

grant EXECUTE on function "public"."erp_detalle_reservas_pedido"(p_pedido_id uuid) to "authenticated";

grant EXECUTE on function "public"."erp_detalle_reservas_pedido"(p_pedido_id uuid) to "service_role";

grant EXECUTE on function "public"."erp_emitir_comprobante_interno"(p_pedido_id uuid) to "service_role";

grant EXECUTE on function "public"."erp_factura_al_confirmar_pago"() to "service_role";

grant EXECUTE on function "public"."erp_finalizar_envio_alerta"(p_alerta_id uuid, p_lote uuid, p_email_id text, p_error text) to "service_role";

grant EXECUTE on function "public"."erp_guardar_permisos_rol"(p_rol_id uuid, p_permiso_ids uuid[]) to "authenticated";

grant EXECUTE on function "public"."erp_guardar_permisos_rol"(p_rol_id uuid, p_permiso_ids uuid[]) to "service_role";

grant EXECUTE on function "public"."erp_mis_permisos"() to "authenticated";

grant EXECUTE on function "public"."erp_mis_permisos"() to "service_role";

grant EXECUTE on function "public"."erp_organizar_imagenes_producto"(p_producto_id uuid, p_imagen_ids uuid[], p_principal_id uuid) to "authenticated";

grant EXECUTE on function "public"."erp_organizar_imagenes_producto"(p_producto_id uuid, p_imagen_ids uuid[], p_principal_id uuid) to "service_role";

grant EXECUTE on function "public"."erp_preparar_borrado_imagen_producto"(p_imagen_id uuid) to "authenticated";

grant EXECUTE on function "public"."erp_preparar_borrado_imagen_producto"(p_imagen_id uuid) to "service_role";

grant EXECUTE on function "public"."erp_preparar_envio_alerta"(p_alerta_id uuid, p_lote uuid, p_remitente text, p_destinatarios text[]) to "service_role";

grant EXECUTE on function "public"."erp_recibir_orden_compra"(p_recepcion_id uuid, p_orden_id uuid, p_ubicacion_id uuid, p_documento character varying, p_observaciones text, p_items jsonb) to "authenticated";

grant EXECUTE on function "public"."erp_recibir_orden_compra"(p_recepcion_id uuid, p_orden_id uuid, p_ubicacion_id uuid, p_documento character varying, p_observaciones text, p_items jsonb) to "service_role";

grant EXECUTE on function "public"."erp_reclamar_alertas"(p_lote uuid, p_limite integer) to "authenticated";

grant EXECUTE on function "public"."erp_reclamar_alertas"(p_lote uuid, p_limite integer) to "service_role";

grant EXECUTE on function "public"."erp_reservar_imagen_producto"(p_producto_id uuid, p_storage_path text, p_nombre_archivo text, p_mime_type text, p_tamano_bytes bigint, p_url_publica text) to "authenticated";

grant EXECUTE on function "public"."erp_reservar_imagen_producto"(p_producto_id uuid, p_storage_path text, p_nombre_archivo text, p_mime_type text, p_tamano_bytes bigint, p_url_publica text) to "service_role";

grant EXECUTE on function "public"."erp_resumen_kardex"(p_producto_id uuid, p_ubicacion_id uuid, p_fecha_desde timestamp with time zone, p_fecha_hasta timestamp with time zone) to "authenticated";

grant EXECUTE on function "public"."erp_resumen_kardex"(p_producto_id uuid, p_ubicacion_id uuid, p_fecha_desde timestamp with time zone, p_fecha_hasta timestamp with time zone) to "service_role";

grant EXECUTE on function "public"."erp_resumen_operativo"(p_fecha_desde timestamp with time zone, p_fecha_hasta timestamp with time zone) to "authenticated";

grant EXECUTE on function "public"."erp_resumen_operativo"(p_fecha_desde timestamp with time zone, p_fecha_hasta timestamp with time zone) to "service_role";

grant EXECUTE on function "public"."erp_sincronizar_facturas_ecommerce"() to "authenticated";

grant EXECUTE on function "public"."erp_sincronizar_facturas_ecommerce"() to "service_role";

grant EXECUTE on function "public"."erp_transferir_inventario"(p_producto_id uuid, p_ubicacion_origen_id uuid, p_ubicacion_destino_id uuid, p_cantidad numeric, p_referencia_numero character varying, p_observaciones text) to "authenticated";

grant EXECUTE on function "public"."erp_transferir_inventario"(p_producto_id uuid, p_ubicacion_origen_id uuid, p_ubicacion_destino_id uuid, p_cantidad numeric, p_referencia_numero character varying, p_observaciones text) to "service_role";

grant EXECUTE on function "public"."erp_usuario_activo"() to "authenticated";

grant EXECUTE on function "public"."erp_usuario_activo"() to "service_role";

grant EXECUTE on function "public"."es_administrador"() to "authenticated";

grant EXECUTE on function "public"."es_administrador"() to "service_role";

grant EXECUTE on function "public"."estado_disponibilidad_ecommerce"(p_producto_id uuid) to "anon";

grant EXECUTE on function "public"."estado_disponibilidad_ecommerce"(p_producto_id uuid) to "authenticated";

grant EXECUTE on function "public"."estado_disponibilidad_ecommerce"(p_producto_id uuid) to "service_role";

grant EXECUTE on function "public"."generar_alertas_inventario"() to "authenticated";

grant EXECUTE on function "public"."generar_alertas_inventario"() to "service_role";

grant EXECUTE on function "public"."liberar_reserva"(p_reserva_id uuid) to "authenticated";

grant EXECUTE on function "public"."liberar_reserva"(p_reserva_id uuid) to "service_role";

grant EXECUTE on function "public"."liberar_reservas_ecommerce_vencidas"() to "authenticated";

grant EXECUTE on function "public"."liberar_reservas_ecommerce_vencidas"() to "service_role";

grant EXECUTE on function "public"."liberar_reservas_expiradas"() to "authenticated";

grant EXECUTE on function "public"."liberar_reservas_expiradas"() to "service_role";

grant EXECUTE on function "public"."obtener_rol_actual"() to "authenticated";

grant EXECUTE on function "public"."obtener_rol_actual"() to "service_role";

grant EXECUTE on function "public"."procesar_estado_pedido_ecommerce"() to PUBLIC;

grant EXECUTE on function "public"."procesar_estado_pedido_ecommerce"() to "anon";

grant EXECUTE on function "public"."procesar_estado_pedido_ecommerce"() to "authenticated";

grant EXECUTE on function "public"."procesar_estado_pedido_ecommerce"() to "service_role";

grant EXECUTE on function "public"."productos_comprados_juntos_ecommerce"(p_producto_id uuid, p_limite integer) to "anon";

grant EXECUTE on function "public"."productos_comprados_juntos_ecommerce"(p_producto_id uuid, p_limite integer) to "authenticated";

grant EXECUTE on function "public"."productos_comprados_juntos_ecommerce"(p_producto_id uuid, p_limite integer) to "service_role";

grant EXECUTE on function "public"."registrar_auditoria"() to PUBLIC;

grant EXECUTE on function "public"."registrar_auditoria"() to "anon";

grant EXECUTE on function "public"."registrar_auditoria"() to "authenticated";

grant EXECUTE on function "public"."registrar_auditoria"() to "service_role";

grant EXECUTE on function "public"."registrar_conteo_inventario"(p_producto_id uuid, p_ubicacion_id uuid, p_stock_contado numeric, p_observaciones text) to "authenticated";

grant EXECUTE on function "public"."registrar_conteo_inventario"(p_producto_id uuid, p_ubicacion_id uuid, p_stock_contado numeric, p_observaciones text) to "service_role";

grant EXECUTE on function "public"."registrar_devolucion_venta"(p_canal character varying, p_referencia_venta character varying, p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_motivo character varying, p_observaciones text) to "authenticated";

grant EXECUTE on function "public"."registrar_devolucion_venta"(p_canal character varying, p_referencia_venta character varying, p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_motivo character varying, p_observaciones text) to "service_role";

grant EXECUTE on function "public"."registrar_entrada_con_costo"(p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_costo_unitario numeric, p_origen character varying, p_referencia_numero character varying, p_observaciones text) to "authenticated";

grant EXECUTE on function "public"."registrar_entrada_con_costo"(p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_costo_unitario numeric, p_origen character varying, p_referencia_numero character varying, p_observaciones text) to "service_role";

grant EXECUTE on function "public"."registrar_movimiento_inventario"(p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_tipo_movimiento text, p_origen text, p_referencia_tipo text, p_referencia_id uuid, p_referencia_numero text, p_observaciones text, p_costo_unitario numeric) to "authenticated";

grant EXECUTE on function "public"."registrar_movimiento_inventario"(p_producto_id uuid, p_ubicacion_id uuid, p_cantidad numeric, p_tipo_movimiento text, p_origen text, p_referencia_tipo text, p_referencia_id uuid, p_referencia_numero text, p_observaciones text, p_costo_unitario numeric) to "service_role";

grant EXECUTE on function "public"."registrar_venta_pos"(p_ubicacion_id uuid, p_items jsonb, p_numero character varying, p_observaciones text) to "authenticated";

grant EXECUTE on function "public"."registrar_venta_pos"(p_ubicacion_id uuid, p_items jsonb, p_numero character varying, p_observaciones text) to "service_role";

grant EXECUTE on function "public"."reservar_stock_ecommerce"(p_ubicacion_id uuid, p_items jsonb, p_numero character varying, p_observaciones text, p_minutos_expiracion integer) to "authenticated";

grant EXECUTE on function "public"."reservar_stock_ecommerce"(p_ubicacion_id uuid, p_items jsonb, p_numero character varying, p_observaciones text, p_minutos_expiracion integer) to "service_role";

grant EXECUTE on function "public"."sincronizar_alerta_existencia_ecommerce"() to PUBLIC;

grant EXECUTE on function "public"."sincronizar_alerta_existencia_ecommerce"() to "anon";

grant EXECUTE on function "public"."sincronizar_alerta_existencia_ecommerce"() to "authenticated";

grant EXECUTE on function "public"."sincronizar_alerta_existencia_ecommerce"() to "service_role";

grant EXECUTE on function "public"."solicitar_ajuste_inventario"(p_producto_id uuid, p_ubicacion_id uuid, p_tipo character varying, p_cantidad numeric, p_motivo character varying, p_observaciones text) to "authenticated";

grant EXECUTE on function "public"."solicitar_ajuste_inventario"(p_producto_id uuid, p_ubicacion_id uuid, p_tipo character varying, p_cantidad numeric, p_motivo character varying, p_observaciones text) to "service_role";

grant EXECUTE on function "public"."suscribir_newsletter"(p_correo text) to "anon";

grant EXECUTE on function "public"."suscribir_newsletter"(p_correo text) to "authenticated";

grant EXECUTE on function "public"."suscribir_newsletter"(p_correo text) to "service_role";

grant EXECUTE on function "public"."tiene_acceso_ubicacion"(p_ubicacion_id uuid) to "authenticated";

grant EXECUTE on function "public"."tiene_acceso_ubicacion"(p_ubicacion_id uuid) to "service_role";

grant EXECUTE on function "public"."tiene_algun_permiso"(p_permisos text[]) to "authenticated";

grant EXECUTE on function "public"."tiene_algun_permiso"(p_permisos text[]) to "service_role";

grant EXECUTE on function "public"."tiene_permiso"(p_permiso_codigo text) to "authenticated";

grant EXECUTE on function "public"."tiene_permiso"(p_permiso_codigo text) to "service_role";

grant EXECUTE on function "public"."tiene_permisos"(p_permisos text[]) to "authenticated";

grant EXECUTE on function "public"."tiene_permisos"(p_permisos text[]) to "service_role";

grant EXECUTE on function "public"."transferir_inventario"(p_producto_id uuid, p_ubicacion_origen_id uuid, p_ubicacion_destino_id uuid, p_cantidad numeric, p_costo_unitario numeric, p_referencia_tipo character varying, p_referencia_id uuid, p_referencia_numero character varying, p_observaciones text) to "authenticated";

grant EXECUTE on function "public"."transferir_inventario"(p_producto_id uuid, p_ubicacion_origen_id uuid, p_ubicacion_destino_id uuid, p_cantidad numeric, p_costo_unitario numeric, p_referencia_tipo character varying, p_referencia_id uuid, p_referencia_numero character varying, p_observaciones text) to "service_role";

grant EXECUTE on function "public"."transferir_inventario"(p_producto_id uuid, p_ubicacion_origen_id uuid, p_ubicacion_destino_id uuid, p_cantidad numeric, p_referencia_numero character varying, p_observaciones text) to "authenticated";

grant EXECUTE on function "public"."transferir_inventario"(p_producto_id uuid, p_ubicacion_origen_id uuid, p_ubicacion_destino_id uuid, p_cantidad numeric, p_referencia_numero character varying, p_observaciones text) to "service_role";

grant EXECUTE on function "public"."usuario_tiene_permiso"(p_usuario_id uuid, p_permiso_codigo text) to "authenticated";

grant EXECUTE on function "public"."usuario_tiene_permiso"(p_usuario_id uuid, p_permiso_codigo text) to "service_role";

grant EXECUTE on function "public"."usuario_tiene_ubicacion"(p_usuario_id uuid, p_ubicacion_id uuid) to "authenticated";

grant EXECUTE on function "public"."usuario_tiene_ubicacion"(p_usuario_id uuid, p_ubicacion_id uuid) to "service_role";

grant EXECUTE on function "public"."validar_existencia_no_negativa"() to PUBLIC;

grant EXECUTE on function "public"."validar_existencia_no_negativa"() to "anon";

grant EXECUTE on function "public"."validar_existencia_no_negativa"() to "authenticated";

grant EXECUTE on function "public"."validar_existencia_no_negativa"() to "service_role";

insert into public."roles"("id","activo","codigo","nombre","descripcion","fecha_creacion","fecha_actualizacion") values
  ('782202f2-8f22-4053-be94-d14dfef942c4',true,'ADMINISTRADOR','Administrador','Control integral del sistema de inventario, configuración, usuarios, permisos, operaciones y supervisión general.','2026-09-25T21:55:51.855604+00:00','2026-09-25T21:55:51.855604+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671',true,'AUDITOR','Auditor','Permite consultar información histórica, movimientos, operaciones y trazabilidad para fines de auditoría.','2026-09-25T21:55:51.855604+00:00','2026-09-25T21:55:51.855604+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d',true,'COMPRAS','Compras','Gestiona proveedores, compras, recepción de mercancía, costos y operaciones relacionadas con adquisiciones.','2026-09-25T21:55:51.855604+00:00','2026-09-25T21:55:51.855604+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac',true,'CONSULTA','Consulta','Permite consultar información autorizada del inventario sin modificar datos ni ejecutar operaciones.','2026-09-25T21:55:51.855604+00:00','2026-09-25T21:55:51.855604+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1',true,'OPERADOR_INVENTARIO','Operador de Inventario','Realiza las operaciones diarias autorizadas de inventario, incluyendo entradas, salidas, conteos y operaciones de ubicación.','2026-09-25T21:55:51.855604+00:00','2026-09-25T21:55:51.855604+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c',true,'SUPERVISOR_INVENTARIO','Supervisor de Inventario','Supervisa las operaciones de inventario, existencias, movimientos, conteos, transferencias, alertas y controles operativos.','2026-09-25T21:55:51.855604+00:00','2026-09-25T21:55:51.855604+00:00') on conflict do nothing;

insert into public."permisos"("id","accion","activo","codigo","modulo","nombre","descripcion","fecha_creacion","fecha_actualizacion") values
  ('0ea5f946-9534-422b-b0bd-d8a21a999a6b','administrar',true,'alertas.administrar','alertas','Administrar alertas','Permite administrar las alertas del sistema.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('c43a3ad9-ddd9-4712-8b1e-ae313404e36a','configurar',true,'alertas.configurar','alertas','Configurar alertas','Permite configurar reglas y parámetros de alertas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('4716c020-406d-4e88-851c-77fd47087eb1','descartar',true,'alertas.descartar','alertas','Descartar alertas','Permite descartar alertas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('b8bfa72a-48ba-4d4f-a213-14029307258f','ver',true,'alertas.ver','alertas','Ver alertas','Permite consultar alertas de inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('f8026e8b-b8bd-4c89-a75e-44834d2d2d3d','administrar',true,'auditoria.administrar','auditoria','Administrar auditoría','Permite administrar configuraciones relacionadas con auditoría.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('43246fb3-9e90-4740-97ca-7bc5fe2e79cb','exportar',true,'auditoria.exportar','auditoria','Exportar auditoría','Permite exportar registros de auditoría.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('66dcaf57-ec15-49eb-b07a-7cddafb9ece7','ver',true,'auditoria.ver','auditoria','Ver auditoría','Permite consultar registros de auditoría.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('3deb6ab1-fbda-4451-b1b9-63fe6425d5b2','ver_detalle',true,'auditoria.ver_detalle','auditoria','Ver detalle de auditoría','Permite consultar el detalle de eventos de auditoría.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('046b6c62-b40b-4aa7-8a7c-5760380d2c20','administrar',true,'categorias.administrar','categorias','Administrar categorías','Permite administrar integralmente las categorías.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('32891802-f853-45e5-b5ae-93e8e340d2bb','crear',true,'categorias.crear','categorias','Crear categorías','Permite crear categorías.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('73b8ce23-89fd-4cad-9615-54c25f5e5268','desactivar',true,'categorias.desactivar','categorias','Desactivar categorías','Permite desactivar categorías.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('f234953e-75fa-46ce-8882-175ed9c9f38f','editar',true,'categorias.editar','categorias','Editar categorías','Permite modificar categorías.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('f64d85c6-3872-48f7-9685-1f41c1c0b94f','ordenar',true,'categorias.ordenar','categorias','Ordenar categorías','Permite modificar el orden de las categorías.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('9e4ad3c3-f797-4de9-9e6d-d6bca4fe5534','ver',true,'categorias.ver','categorias','Ver categorías','Permite consultar categorías.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('bcb06493-ab9f-4d7c-91e9-cbb832e0f0cb','cancelar',true,'compras.cancelar','compras','Cancelar compras','Permite cancelar compras autorizadas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('19af057b-35f1-4e99-92a1-ed8e69435598','confirmar',true,'compras.confirmar','compras','Confirmar compras','Permite confirmar compras.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('9b894292-c7c5-41a7-afa6-90d2baa77604','crear',true,'compras.crear','compras','Crear compras','Permite crear compras.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('976d39e5-4dd4-488e-9fea-bd8586ac2d99','editar',true,'compras.editar','compras','Editar compras','Permite modificar compras antes de su confirmación.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('c6106cc3-d096-43fb-bd3c-8614fec80eac','exportar',true,'compras.exportar','compras','Exportar compras','Permite exportar compras.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('13b4b968-92fd-429f-b949-ac96babff5c7','recibir',true,'compras.recibir','compras','Recibir compras','Permite recibir mercancía asociada a compras.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('a1c4dc1d-1e4c-4146-b529-5ed8be7bb4af','ver',true,'compras.ver','compras','Ver compras','Permite consultar compras.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('4adad843-5353-4efe-b30a-17149961fc11','editar',true,'configuracion.editar','configuracion','Editar configuración','Permite modificar configuraciones autorizadas del sistema.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('c928d691-cc75-4182-9ca6-5f031091622f','ver',true,'configuracion.ver','configuracion','Ver configuración','Permite consultar la configuración del sistema.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('c61d5398-4f40-405d-a119-c49feafdd296','aprobar',true,'conteos.aprobar','conteos','Aprobar conteos','Permite aprobar resultados de conteos.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('e653a0cd-3378-4c44-9541-334bea68c90e','cerrar',true,'conteos.cerrar','conteos','Cerrar conteos','Permite cerrar conteos de inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('e16abc17-f099-4523-b601-1287e611d9e8','crear',true,'conteos.crear','conteos','Crear conteos','Permite crear conteos de inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('3b8d0db9-b6f9-4536-ae3e-66296332e995','editar',true,'conteos.editar','conteos','Editar conteos','Permite editar conteos antes de su cierre.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('136fcfac-1f5b-40ba-840b-aabcf4da96e2','ejecutar',true,'conteos.ejecutar','conteos','Ejecutar conteos','Permite realizar conteos físicos.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('b0860ed5-a785-4d16-85bf-51aa6d1752c2','exportar',true,'conteos.exportar','conteos','Exportar conteos','Permite exportar información de conteos.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('1fd7e1fa-8ec6-4344-93a4-c748cac6c16f','ver',true,'conteos.ver','conteos','Ver conteos','Permite consultar conteos de inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('f8f57a75-bf14-41a8-bb0e-21182288213a','anular',true,'entradas.anular','entradas','Anular entradas','Permite anular entradas autorizadas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('f03c44f8-89e9-4d24-8d20-96190d39b34a','confirmar',true,'entradas.confirmar','entradas','Confirmar entradas','Permite confirmar entradas y afectar existencias.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('418ec142-94ea-4ee6-b561-09261484620e','crear',true,'entradas.crear','entradas','Crear entradas','Permite registrar entradas de inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('bad26c00-d6a8-45c2-8493-e1d1348f10ab','editar',true,'entradas.editar','entradas','Editar entradas','Permite editar entradas antes de su confirmación.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('b6141364-44c5-4267-9190-514d6d037bab','exportar',true,'entradas.exportar','entradas','Exportar entradas','Permite exportar entradas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('8c957ccc-2836-4b94-844c-05504cbd5822','ver',true,'entradas.ver','entradas','Ver entradas','Permite consultar entradas de inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('ade68156-3860-46c2-b7bf-ff7ff7dcf59a','administrar',true,'existencias.administrar','existencias','Administrar existencias','Permite administrar integralmente las existencias.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('99548f4c-5d62-4377-bbf4-4e5af25ae3ad','ajustar',true,'existencias.ajustar','existencias','Ajustar existencias','Permite realizar ajustes controlados de inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('bfc48c96-e5ad-405a-b056-4bbb0050e8c8','configurar_maximos',true,'existencias.configurar_maximos','existencias','Configurar stock máximo','Permite configurar niveles máximos de inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('a48202bf-8899-4936-977b-09e18e7b6718','configurar_minimos',true,'existencias.configurar_minimos','existencias','Configurar stock mínimo','Permite configurar niveles mínimos de inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('f9975b91-9710-4bc5-9b23-a0b990d55871','configurar_reorden',true,'existencias.configurar_reorden','existencias','Configurar punto de reorden','Permite configurar puntos de reorden.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('dc2cd85f-89e0-4cbd-b8c9-e4666b9e3e3b','ver',true,'existencias.ver','existencias','Ver existencias','Permite consultar existencias.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('6521d48c-db1a-4d7b-94b9-f74a327ff0ad','ver_costos',true,'existencias.ver_costos','existencias','Ver costos de existencias','Permite consultar costos asociados al inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('ce557f80-1cbd-432e-8adc-08cb1b3e6390','ver_disponible',true,'existencias.ver_disponible','existencias','Ver stock disponible','Permite consultar stock disponible.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('6834d140-1c51-4322-9421-153ea5b2072f','ver_reservado',true,'existencias.ver_reservado','existencias','Ver stock reservado','Permite consultar stock reservado.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('a3b53fbf-0332-44f6-a7a4-f6c53a792408','administrar',true,'marcas.administrar','marcas','Administrar marcas','Permite administrar integralmente las marcas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('8096b097-5f69-436c-9c50-f6682a6aef62','crear',true,'marcas.crear','marcas','Crear marcas','Permite crear marcas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('a169291f-b4fc-47d8-ae53-8dff41aaa33b','desactivar',true,'marcas.desactivar','marcas','Desactivar marcas','Permite desactivar marcas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('b05e39d3-04f1-4c89-8137-5642811fcd05','editar',true,'marcas.editar','marcas','Editar marcas','Permite modificar marcas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('a35ec89c-6dec-4b11-b24c-b94e0b642187','ver',true,'marcas.ver','marcas','Ver marcas','Permite consultar marcas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('c4c6be41-1b91-45bc-91d4-3f58d80d3ecd','administrar',true,'movimientos.administrar','movimientos','Administrar movimientos','Permite administrar operaciones relacionadas con movimientos.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('fd82515f-9c2d-48c0-ae09-df415ec2ff2d','exportar',true,'movimientos.exportar','movimientos','Exportar movimientos','Permite exportar movimientos.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('71c190bf-c633-4d74-b58c-64244a38b6bd','revertir',true,'movimientos.revertir','movimientos','Revertir movimientos','Permite revertir movimientos mediante mecanismos autorizados.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('1b7802b4-6075-418d-a7b8-ae93e28b8171','ver',true,'movimientos.ver','movimientos','Ver movimientos','Permite consultar movimientos de inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('4566230a-fd2e-45c2-9914-79937245f3eb','ver_detalle',true,'movimientos.ver_detalle','movimientos','Ver detalle de movimientos','Permite consultar el detalle completo de los movimientos.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('ca95b5c6-ef25-4c50-9733-e8b335a60c85','asignar',true,'permisos.asignar','permisos','Asignar permisos','Permite asignar permisos a roles o usuarios.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('c02404fe-8fb1-4a41-9728-ff8c8bb9ca69','ver',true,'permisos.ver','permisos','Ver permisos','Permite consultar permisos disponibles.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('29713ee0-306d-45f0-8b6e-a4c8d803bfa1','vender',true,'pos.vender','pos','Registrar ventas POS','Permite registrar ventas desde el punto de venta.','2026-10-02T17:19:49.771768+00:00','2026-10-02T17:19:49.771768+00:00'),
  ('a9f13d08-404f-403f-a78a-b54d75aba81a','activar',true,'productos.activar','productos','Activar productos','Permite volver a activar productos.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('940eb8eb-27e1-4b4e-a67b-46ba3b692598','administrar',true,'productos.administrar','productos','Administrar productos','Permite administrar integralmente el catálogo de productos.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('68c4466b-e7d0-4484-a7c7-512ff1a5e625','crear',true,'productos.crear','productos','Crear productos','Permite registrar nuevos productos.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('c6e84cca-2457-4702-9ccd-9670bb77e0a9','desactivar',true,'productos.desactivar','productos','Desactivar productos','Permite desactivar productos.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('2c85492c-ac61-4f46-9542-7d74db9df367','editar',true,'productos.editar','productos','Editar productos','Permite modificar información de productos.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('f4fa9542-7b0f-4dd0-b68a-e710967bbd99','exportar',true,'productos.exportar','productos','Exportar productos','Permite exportar información de productos.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('531a72c1-2e31-4228-a795-4b7ec62a24e3','importar',true,'productos.importar','productos','Importar productos','Permite importar productos de forma masiva.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('8f4c7a95-b651-4d76-ab9d-2f479bf9fb7a','ver',true,'productos.ver','productos','Ver productos','Permite consultar productos del inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('dd8de49c-83f2-4ad9-9213-afe2f28b7386','ver_costos',true,'productos.ver_costos','productos','Ver costos de productos','Permite consultar costos de productos.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('aa4a905f-8059-4710-b415-25aa77cbeedd','ver_margenes',true,'productos.ver_margenes','productos','Ver márgenes de productos','Permite consultar márgenes de productos.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('c9d79eed-2712-4b45-b604-4354157cec8d','crear',true,'proveedores.crear','proveedores','Crear proveedores','Permite crear proveedores.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('bbcf99b8-710d-4119-a7d5-9b730ca30b10','desactivar',true,'proveedores.desactivar','proveedores','Desactivar proveedores','Permite desactivar proveedores.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('cc18b96b-ad0d-4ace-a854-e04fcdb7ac23','editar',true,'proveedores.editar','proveedores','Editar proveedores','Permite modificar proveedores.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('422a7e03-a4fa-4bb2-a2e2-323457234614','exportar',true,'proveedores.exportar','proveedores','Exportar proveedores','Permite exportar proveedores.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('7083cae3-d45c-44de-8f3b-7f847003004c','ver',true,'proveedores.ver','proveedores','Ver proveedores','Permite consultar proveedores.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('a6ddbcbe-df33-4f91-8297-9c2a88ab0e8f','abc',true,'reportes.abc','reportes','Análisis ABC','Permite consultar análisis ABC del inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('a35a8ac5-fc86-4f0c-8b82-c5831b5a9e6d','administrar',true,'reportes.administrar','reportes','Administrar reportes','Permite administrar configuraciones de reportes.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('7cc5fedd-fe09-4972-9657-ffe10d982693','compras',true,'reportes.compras','reportes','Reportes de compras','Permite consultar reportes de compras.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('0eaf0640-1df5-494a-ad2d-c88426b4169c','exportar',true,'reportes.exportar','reportes','Exportar reportes','Permite exportar reportes.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('5e3ac3d8-8d38-46ba-8242-187c9f44b5c7','inventario',true,'reportes.inventario','reportes','Reportes de inventario','Permite consultar reportes de inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('d6b213ed-aef3-4cbe-a4b6-ffaa63cacb00','movimientos',true,'reportes.movimientos','reportes','Reportes de movimientos','Permite consultar reportes de movimientos.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('8d5cf699-04c7-4bbe-be43-d5dbab08510b','valuacion',true,'reportes.valuacion','reportes','Reportes de valoración','Permite consultar reportes de valoración.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('617046ca-fd18-4a33-939d-e4a74dd5be52','ver',true,'reportes.ver','reportes','Ver reportes','Permite acceder a reportes.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('c416fdec-a543-49b8-a05e-5495bdd57926','administrar',true,'reservas.administrar','reservas','Administrar reservas','Permite administrar integralmente las reservas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('785eb99b-8e2c-4d1a-9f60-8df878f12f04','cancelar',true,'reservas.cancelar','reservas','Cancelar reservas','Permite cancelar reservas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('91929713-ddf5-45b9-aa9e-edd953773239','consumir',true,'reservas.consumir','reservas','Consumir reservas','Permite consumir reservas al completar una operación.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('44cf4ae6-4a66-4589-8452-298202777718','crear',true,'reservas.crear','reservas','Crear reservas','Permite crear reservas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('8d454087-acc3-4b65-bceb-fc8df44bd673','liberar',true,'reservas.liberar','reservas','Liberar reservas','Permite liberar reservas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('0e415bf4-093d-4997-b401-65ff974d5d62','ver',true,'reservas.ver','reservas','Ver reservas','Permite consultar reservas de inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('7ca26c3c-d0dc-4022-ba9a-87f858c3e0c1','asignar',true,'roles.asignar','roles','Asignar roles','Permite asignar roles a usuarios.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('0132f0cb-d605-447b-b1ae-1c8a4e6a3bd6','crear',true,'roles.crear','roles','Crear roles','Permite crear roles.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('938082a2-6e59-4579-a41e-37949a885a02','editar',true,'roles.editar','roles','Editar roles','Permite modificar roles.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('04ff5156-6ffc-4fed-b3af-134589ac950a','ver',true,'roles.ver','roles','Ver roles','Permite consultar roles del sistema.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('6217ae49-5ceb-49af-9621-add420a1476b','anular',true,'salidas.anular','salidas','Anular salidas','Permite anular salidas autorizadas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('a44ff8cd-132b-423f-949c-d6f73cfd27a2','confirmar',true,'salidas.confirmar','salidas','Confirmar salidas','Permite confirmar salidas y afectar existencias.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('37b84d50-d583-48b7-af6d-411d8a58f77a','crear',true,'salidas.crear','salidas','Crear salidas','Permite registrar salidas de inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('9bfc0e30-c5e9-4618-ac41-91ddb244542f','exportar',true,'salidas.exportar','salidas','Exportar salidas','Permite exportar salidas.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('d5a646d3-812e-4e56-881f-4fc50527f864','ver',true,'salidas.ver','salidas','Ver salidas','Permite consultar salidas de inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('be651acf-a74c-4f12-baeb-c198c93cb9ce','aprobar',true,'transferencias.aprobar','transferencias','Aprobar transferencias','Permite aprobar transferencias.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('c1e8b74f-25a4-458d-8535-1716355854b2','cancelar',true,'transferencias.cancelar','transferencias','Cancelar transferencias','Permite cancelar transferencias.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('db313000-b40a-481f-bbbd-e428221545eb','crear',true,'transferencias.crear','transferencias','Crear transferencias','Permite crear transferencias.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('54fa5045-0e40-4bff-a0d7-7582234e1bba','enviar',true,'transferencias.enviar','transferencias','Enviar transferencias','Permite ejecutar la salida de una transferencia.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00') on conflict do nothing;

insert into public."permisos"("id","accion","activo","codigo","modulo","nombre","descripcion","fecha_creacion","fecha_actualizacion") values
  ('ab639c36-5c00-4680-8013-b4903f981a76','recibir',true,'transferencias.recibir','transferencias','Recibir transferencias','Permite recibir transferencias.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('ad1919fc-f05a-4d98-9353-29691d9596c6','ver',true,'transferencias.ver','transferencias','Ver transferencias','Permite consultar transferencias.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('e00af276-846a-408a-a20b-0641e19de422','administrar',true,'ubicaciones.administrar','ubicaciones','Administrar ubicaciones','Permite administrar integralmente las ubicaciones.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('06946aeb-86af-4635-a468-a513507790b2','crear',true,'ubicaciones.crear','ubicaciones','Crear ubicaciones','Permite crear ubicaciones.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('9595b045-0de9-47b1-a984-df446752f4ff','desactivar',true,'ubicaciones.desactivar','ubicaciones','Desactivar ubicaciones','Permite desactivar ubicaciones.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('fc33362e-7492-4296-bbf0-137592f5d377','editar',true,'ubicaciones.editar','ubicaciones','Editar ubicaciones','Permite modificar ubicaciones.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('4ecb0c61-e209-47d5-9f3f-4f406c1f85ee','transferir',true,'ubicaciones.transferir','ubicaciones','Transferir entre ubicaciones','Permite realizar transferencias de inventario entre ubicaciones.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('82104f4e-537a-4305-bbf3-0017fc64735f','ver',true,'ubicaciones.ver','ubicaciones','Ver ubicaciones','Permite consultar ubicaciones de inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('6ae0c01b-6ddd-427f-a2dd-fb7b2e369130','administrar',true,'unidades.administrar','unidades','Administrar unidades de medida','Permite administrar integralmente las unidades de medida.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('d7287460-a6cd-408e-9ba1-ece7fa1c8a77','crear',true,'unidades.crear','unidades','Crear unidades de medida','Permite crear unidades de medida.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('ac897894-8a59-4bcc-8672-d35e1f666797','desactivar',true,'unidades.desactivar','unidades','Desactivar unidades de medida','Permite desactivar unidades de medida.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('865805a8-a2b8-4f3c-b870-6d7b36a9207e','editar',true,'unidades.editar','unidades','Editar unidades de medida','Permite modificar unidades de medida.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('86641858-9b1b-4f69-9e50-6d2be9c15fc0','ver',true,'unidades.ver','unidades','Ver unidades de medida','Permite consultar unidades de medida.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('52f38c39-e757-401f-9b18-35b53c2aab54','crear',true,'usuarios.crear','usuarios','Crear usuarios','Permite crear usuarios del sistema.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('59cc8167-f1ac-450e-9bba-f7bfe5fdd17c','desactivar',true,'usuarios.desactivar','usuarios','Desactivar usuarios','Permite desactivar usuarios.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('d8eb8374-e8e5-4f07-9a06-b895a4fbf24e','editar',true,'usuarios.editar','usuarios','Editar usuarios','Permite modificar perfiles de usuarios.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('29e1da3c-90b0-4fd6-aa0e-0c24d3f8ca82','ver',true,'usuarios.ver','usuarios','Ver usuarios','Permite consultar usuarios del sistema.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('33c712bb-9e2c-4129-aef8-798e998313ed','administrar',true,'valoracion.administrar','valoracion','Administrar valoración','Permite administrar parámetros de valoración.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('8479509d-2216-40e8-bce1-b85cc782d3d2','calcular',true,'valoracion.calcular','valoracion','Calcular valoración','Permite ejecutar cálculos de valoración.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('1731879a-8083-450a-91ad-169fa7be2707','exportar',true,'valoracion.exportar','valoracion','Exportar valoración','Permite exportar información de valoración.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('3fe8c184-f20c-474c-bedb-0e728b71834c','ver',true,'valoracion.ver','valoracion','Ver valoración','Permite consultar valoración del inventario.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00'),
  ('ca57110b-63a9-47d7-a650-096893b41698','ver_costos',true,'valoracion.ver_costos','valoracion','Ver costos de valoración','Permite consultar costos utilizados en la valoración.','2026-09-25T21:57:26.829379+00:00','2026-09-25T21:57:26.829379+00:00') on conflict do nothing;

insert into public."rol_permisos"("rol_id","permiso_id","fecha_creacion") values
  ('782202f2-8f22-4053-be94-d14dfef942c4','0132f0cb-d605-447b-b1ae-1c8a4e6a3bd6','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','046b6c62-b40b-4aa7-8a7c-5760380d2c20','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','04ff5156-6ffc-4fed-b3af-134589ac950a','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','06946aeb-86af-4635-a468-a513507790b2','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','0e415bf4-093d-4997-b401-65ff974d5d62','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','0ea5f946-9534-422b-b0bd-d8a21a999a6b','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','0eaf0640-1df5-494a-ad2d-c88426b4169c','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','136fcfac-1f5b-40ba-840b-aabcf4da96e2','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','13b4b968-92fd-429f-b949-ac96babff5c7','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','1731879a-8083-450a-91ad-169fa7be2707','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','19af057b-35f1-4e99-92a1-ed8e69435598','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','1b7802b4-6075-418d-a7b8-ae93e28b8171','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','1fd7e1fa-8ec6-4344-93a4-c748cac6c16f','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','29e1da3c-90b0-4fd6-aa0e-0c24d3f8ca82','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','2c85492c-ac61-4f46-9542-7d74db9df367','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','32891802-f853-45e5-b5ae-93e8e340d2bb','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','33c712bb-9e2c-4129-aef8-798e998313ed','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','37b84d50-d583-48b7-af6d-411d8a58f77a','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','3b8d0db9-b6f9-4536-ae3e-66296332e995','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','3deb6ab1-fbda-4451-b1b9-63fe6425d5b2','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','3fe8c184-f20c-474c-bedb-0e728b71834c','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','418ec142-94ea-4ee6-b561-09261484620e','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','422a7e03-a4fa-4bb2-a2e2-323457234614','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','43246fb3-9e90-4740-97ca-7bc5fe2e79cb','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','44cf4ae6-4a66-4589-8452-298202777718','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','4566230a-fd2e-45c2-9914-79937245f3eb','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','4716c020-406d-4e88-851c-77fd47087eb1','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','4adad843-5353-4efe-b30a-17149961fc11','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','4ecb0c61-e209-47d5-9f3f-4f406c1f85ee','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','52f38c39-e757-401f-9b18-35b53c2aab54','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','531a72c1-2e31-4228-a795-4b7ec62a24e3','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','54fa5045-0e40-4bff-a0d7-7582234e1bba','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','59cc8167-f1ac-450e-9bba-f7bfe5fdd17c','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','5e3ac3d8-8d38-46ba-8242-187c9f44b5c7','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','617046ca-fd18-4a33-939d-e4a74dd5be52','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','6217ae49-5ceb-49af-9621-add420a1476b','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','6521d48c-db1a-4d7b-94b9-f74a327ff0ad','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','66dcaf57-ec15-49eb-b07a-7cddafb9ece7','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','6834d140-1c51-4322-9421-153ea5b2072f','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','68c4466b-e7d0-4484-a7c7-512ff1a5e625','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','6ae0c01b-6ddd-427f-a2dd-fb7b2e369130','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','7083cae3-d45c-44de-8f3b-7f847003004c','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','71c190bf-c633-4d74-b58c-64244a38b6bd','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','73b8ce23-89fd-4cad-9615-54c25f5e5268','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','785eb99b-8e2c-4d1a-9f60-8df878f12f04','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','7ca26c3c-d0dc-4022-ba9a-87f858c3e0c1','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','7cc5fedd-fe09-4972-9657-ffe10d982693','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','8096b097-5f69-436c-9c50-f6682a6aef62','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','82104f4e-537a-4305-bbf3-0017fc64735f','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','8479509d-2216-40e8-bce1-b85cc782d3d2','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','865805a8-a2b8-4f3c-b870-6d7b36a9207e','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','86641858-9b1b-4f69-9e50-6d2be9c15fc0','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','8c957ccc-2836-4b94-844c-05504cbd5822','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','8d454087-acc3-4b65-bceb-fc8df44bd673','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','8d5cf699-04c7-4bbe-be43-d5dbab08510b','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','8f4c7a95-b651-4d76-ab9d-2f479bf9fb7a','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','91929713-ddf5-45b9-aa9e-edd953773239','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','938082a2-6e59-4579-a41e-37949a885a02','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','940eb8eb-27e1-4b4e-a67b-46ba3b692598','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','9595b045-0de9-47b1-a984-df446752f4ff','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','976d39e5-4dd4-488e-9fea-bd8586ac2d99','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','99548f4c-5d62-4377-bbf4-4e5af25ae3ad','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','9b894292-c7c5-41a7-afa6-90d2baa77604','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','9bfc0e30-c5e9-4618-ac41-91ddb244542f','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','9e4ad3c3-f797-4de9-9e6d-d6bca4fe5534','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','a169291f-b4fc-47d8-ae53-8dff41aaa33b','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','a1c4dc1d-1e4c-4146-b529-5ed8be7bb4af','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','a35a8ac5-fc86-4f0c-8b82-c5831b5a9e6d','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','a35ec89c-6dec-4b11-b24c-b94e0b642187','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','a3b53fbf-0332-44f6-a7a4-f6c53a792408','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','a44ff8cd-132b-423f-949c-d6f73cfd27a2','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','a48202bf-8899-4936-977b-09e18e7b6718','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','a6ddbcbe-df33-4f91-8297-9c2a88ab0e8f','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','a9f13d08-404f-403f-a78a-b54d75aba81a','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','aa4a905f-8059-4710-b415-25aa77cbeedd','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','ab639c36-5c00-4680-8013-b4903f981a76','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','ac897894-8a59-4bcc-8672-d35e1f666797','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','ad1919fc-f05a-4d98-9353-29691d9596c6','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','ade68156-3860-46c2-b7bf-ff7ff7dcf59a','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','b05e39d3-04f1-4c89-8137-5642811fcd05','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','b0860ed5-a785-4d16-85bf-51aa6d1752c2','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','b6141364-44c5-4267-9190-514d6d037bab','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','b8bfa72a-48ba-4d4f-a213-14029307258f','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','bad26c00-d6a8-45c2-8493-e1d1348f10ab','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','bbcf99b8-710d-4119-a7d5-9b730ca30b10','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','bcb06493-ab9f-4d7c-91e9-cbb832e0f0cb','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','be651acf-a74c-4f12-baeb-c198c93cb9ce','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','bfc48c96-e5ad-405a-b056-4bbb0050e8c8','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','c02404fe-8fb1-4a41-9728-ff8c8bb9ca69','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','c1e8b74f-25a4-458d-8535-1716355854b2','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','c416fdec-a543-49b8-a05e-5495bdd57926','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','c43a3ad9-ddd9-4712-8b1e-ae313404e36a','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','c4c6be41-1b91-45bc-91d4-3f58d80d3ecd','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','c6106cc3-d096-43fb-bd3c-8614fec80eac','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','c61d5398-4f40-405d-a119-c49feafdd296','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','c6e84cca-2457-4702-9ccd-9670bb77e0a9','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','c928d691-cc75-4182-9ca6-5f031091622f','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','c9d79eed-2712-4b45-b604-4354157cec8d','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','ca57110b-63a9-47d7-a650-096893b41698','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','ca95b5c6-ef25-4c50-9733-e8b335a60c85','2026-09-25T22:01:11.831048+00:00') on conflict do nothing;

insert into public."rol_permisos"("rol_id","permiso_id","fecha_creacion") values
  ('782202f2-8f22-4053-be94-d14dfef942c4','cc18b96b-ad0d-4ace-a854-e04fcdb7ac23','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','ce557f80-1cbd-432e-8adc-08cb1b3e6390','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','d5a646d3-812e-4e56-881f-4fc50527f864','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','d6b213ed-aef3-4cbe-a4b6-ffaa63cacb00','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','d7287460-a6cd-408e-9ba1-ece7fa1c8a77','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','d8eb8374-e8e5-4f07-9a06-b895a4fbf24e','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','db313000-b40a-481f-bbbd-e428221545eb','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','dc2cd85f-89e0-4cbd-b8c9-e4666b9e3e3b','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','dd8de49c-83f2-4ad9-9213-afe2f28b7386','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','e00af276-846a-408a-a20b-0641e19de422','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','e16abc17-f099-4523-b601-1287e611d9e8','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','e653a0cd-3378-4c44-9541-334bea68c90e','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','f03c44f8-89e9-4d24-8d20-96190d39b34a','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','f234953e-75fa-46ce-8882-175ed9c9f38f','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','f4fa9542-7b0f-4dd0-b68a-e710967bbd99','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','f64d85c6-3872-48f7-9685-1f41c1c0b94f','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','f8026e8b-b8bd-4c89-a75e-44834d2d2d3d','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','f8f57a75-bf14-41a8-bb0e-21182288213a','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','f9975b91-9710-4bc5-9b23-a0b990d55871','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','fc33362e-7492-4296-bbf0-137592f5d377','2026-09-25T22:01:11.831048+00:00'),
  ('782202f2-8f22-4053-be94-d14dfef942c4','fd82515f-9c2d-48c0-ae09-df415ec2ff2d','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','046b6c62-b40b-4aa7-8a7c-5760380d2c20','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','06946aeb-86af-4635-a468-a513507790b2','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','0e415bf4-093d-4997-b401-65ff974d5d62','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','0ea5f946-9534-422b-b0bd-d8a21a999a6b','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','0eaf0640-1df5-494a-ad2d-c88426b4169c','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','136fcfac-1f5b-40ba-840b-aabcf4da96e2','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','13b4b968-92fd-429f-b949-ac96babff5c7','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','1731879a-8083-450a-91ad-169fa7be2707','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','19af057b-35f1-4e99-92a1-ed8e69435598','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','1b7802b4-6075-418d-a7b8-ae93e28b8171','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','1fd7e1fa-8ec6-4344-93a4-c748cac6c16f','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','2c85492c-ac61-4f46-9542-7d74db9df367','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','32891802-f853-45e5-b5ae-93e8e340d2bb','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','33c712bb-9e2c-4129-aef8-798e998313ed','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','37b84d50-d583-48b7-af6d-411d8a58f77a','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','3b8d0db9-b6f9-4536-ae3e-66296332e995','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','3deb6ab1-fbda-4451-b1b9-63fe6425d5b2','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','3fe8c184-f20c-474c-bedb-0e728b71834c','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','418ec142-94ea-4ee6-b561-09261484620e','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','422a7e03-a4fa-4bb2-a2e2-323457234614','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','43246fb3-9e90-4740-97ca-7bc5fe2e79cb','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','44cf4ae6-4a66-4589-8452-298202777718','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','4566230a-fd2e-45c2-9914-79937245f3eb','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','4716c020-406d-4e88-851c-77fd47087eb1','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','4ecb0c61-e209-47d5-9f3f-4f406c1f85ee','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','531a72c1-2e31-4228-a795-4b7ec62a24e3','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','54fa5045-0e40-4bff-a0d7-7582234e1bba','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','5e3ac3d8-8d38-46ba-8242-187c9f44b5c7','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','617046ca-fd18-4a33-939d-e4a74dd5be52','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','6217ae49-5ceb-49af-9621-add420a1476b','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','6521d48c-db1a-4d7b-94b9-f74a327ff0ad','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','66dcaf57-ec15-49eb-b07a-7cddafb9ece7','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','6834d140-1c51-4322-9421-153ea5b2072f','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','68c4466b-e7d0-4484-a7c7-512ff1a5e625','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','6ae0c01b-6ddd-427f-a2dd-fb7b2e369130','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','7083cae3-d45c-44de-8f3b-7f847003004c','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','71c190bf-c633-4d74-b58c-64244a38b6bd','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','73b8ce23-89fd-4cad-9615-54c25f5e5268','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','785eb99b-8e2c-4d1a-9f60-8df878f12f04','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','7cc5fedd-fe09-4972-9657-ffe10d982693','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','8096b097-5f69-436c-9c50-f6682a6aef62','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','82104f4e-537a-4305-bbf3-0017fc64735f','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','8479509d-2216-40e8-bce1-b85cc782d3d2','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','865805a8-a2b8-4f3c-b870-6d7b36a9207e','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','86641858-9b1b-4f69-9e50-6d2be9c15fc0','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','8c957ccc-2836-4b94-844c-05504cbd5822','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','8d454087-acc3-4b65-bceb-fc8df44bd673','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','8d5cf699-04c7-4bbe-be43-d5dbab08510b','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','8f4c7a95-b651-4d76-ab9d-2f479bf9fb7a','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','91929713-ddf5-45b9-aa9e-edd953773239','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','940eb8eb-27e1-4b4e-a67b-46ba3b692598','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','9595b045-0de9-47b1-a984-df446752f4ff','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','976d39e5-4dd4-488e-9fea-bd8586ac2d99','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','99548f4c-5d62-4377-bbf4-4e5af25ae3ad','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','9b894292-c7c5-41a7-afa6-90d2baa77604','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','9bfc0e30-c5e9-4618-ac41-91ddb244542f','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','9e4ad3c3-f797-4de9-9e6d-d6bca4fe5534','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','a169291f-b4fc-47d8-ae53-8dff41aaa33b','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','a1c4dc1d-1e4c-4146-b529-5ed8be7bb4af','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','a35a8ac5-fc86-4f0c-8b82-c5831b5a9e6d','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','a35ec89c-6dec-4b11-b24c-b94e0b642187','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','a3b53fbf-0332-44f6-a7a4-f6c53a792408','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','a44ff8cd-132b-423f-949c-d6f73cfd27a2','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','a48202bf-8899-4936-977b-09e18e7b6718','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','a6ddbcbe-df33-4f91-8297-9c2a88ab0e8f','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','a9f13d08-404f-403f-a78a-b54d75aba81a','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','aa4a905f-8059-4710-b415-25aa77cbeedd','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','ab639c36-5c00-4680-8013-b4903f981a76','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','ac897894-8a59-4bcc-8672-d35e1f666797','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','ad1919fc-f05a-4d98-9353-29691d9596c6','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','ade68156-3860-46c2-b7bf-ff7ff7dcf59a','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','b05e39d3-04f1-4c89-8137-5642811fcd05','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','b0860ed5-a785-4d16-85bf-51aa6d1752c2','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','b6141364-44c5-4267-9190-514d6d037bab','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','b8bfa72a-48ba-4d4f-a213-14029307258f','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','bad26c00-d6a8-45c2-8493-e1d1348f10ab','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','bbcf99b8-710d-4119-a7d5-9b730ca30b10','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','bcb06493-ab9f-4d7c-91e9-cbb832e0f0cb','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','be651acf-a74c-4f12-baeb-c198c93cb9ce','2026-09-25T22:01:11.831048+00:00') on conflict do nothing;

insert into public."rol_permisos"("rol_id","permiso_id","fecha_creacion") values
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','bfc48c96-e5ad-405a-b056-4bbb0050e8c8','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','c1e8b74f-25a4-458d-8535-1716355854b2','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','c416fdec-a543-49b8-a05e-5495bdd57926','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','c43a3ad9-ddd9-4712-8b1e-ae313404e36a','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','c4c6be41-1b91-45bc-91d4-3f58d80d3ecd','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','c6106cc3-d096-43fb-bd3c-8614fec80eac','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','c61d5398-4f40-405d-a119-c49feafdd296','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','c6e84cca-2457-4702-9ccd-9670bb77e0a9','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','c9d79eed-2712-4b45-b604-4354157cec8d','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','ca57110b-63a9-47d7-a650-096893b41698','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','cc18b96b-ad0d-4ace-a854-e04fcdb7ac23','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','ce557f80-1cbd-432e-8adc-08cb1b3e6390','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','d5a646d3-812e-4e56-881f-4fc50527f864','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','d6b213ed-aef3-4cbe-a4b6-ffaa63cacb00','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','d7287460-a6cd-408e-9ba1-ece7fa1c8a77','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','db313000-b40a-481f-bbbd-e428221545eb','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','dc2cd85f-89e0-4cbd-b8c9-e4666b9e3e3b','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','dd8de49c-83f2-4ad9-9213-afe2f28b7386','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','e00af276-846a-408a-a20b-0641e19de422','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','e16abc17-f099-4523-b601-1287e611d9e8','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','e653a0cd-3378-4c44-9541-334bea68c90e','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','f03c44f8-89e9-4d24-8d20-96190d39b34a','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','f234953e-75fa-46ce-8882-175ed9c9f38f','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','f4fa9542-7b0f-4dd0-b68a-e710967bbd99','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','f64d85c6-3872-48f7-9685-1f41c1c0b94f','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','f8f57a75-bf14-41a8-bb0e-21182288213a','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','f9975b91-9710-4bc5-9b23-a0b990d55871','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','fc33362e-7492-4296-bbf0-137592f5d377','2026-09-25T22:01:11.831048+00:00'),
  ('8a38dc8e-e91b-4bcb-be18-1e0878493b2c','fd82515f-9c2d-48c0-ae09-df415ec2ff2d','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','0e415bf4-093d-4997-b401-65ff974d5d62','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','0eaf0640-1df5-494a-ad2d-c88426b4169c','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','1b7802b4-6075-418d-a7b8-ae93e28b8171','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','1fd7e1fa-8ec6-4344-93a4-c748cac6c16f','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','3deb6ab1-fbda-4451-b1b9-63fe6425d5b2','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','3fe8c184-f20c-474c-bedb-0e728b71834c','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','422a7e03-a4fa-4bb2-a2e2-323457234614','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','43246fb3-9e90-4740-97ca-7bc5fe2e79cb','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','4566230a-fd2e-45c2-9914-79937245f3eb','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','5e3ac3d8-8d38-46ba-8242-187c9f44b5c7','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','617046ca-fd18-4a33-939d-e4a74dd5be52','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','66dcaf57-ec15-49eb-b07a-7cddafb9ece7','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','7083cae3-d45c-44de-8f3b-7f847003004c','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','7cc5fedd-fe09-4972-9657-ffe10d982693','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','82104f4e-537a-4305-bbf3-0017fc64735f','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','86641858-9b1b-4f69-9e50-6d2be9c15fc0','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','8c957ccc-2836-4b94-844c-05504cbd5822','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','8d5cf699-04c7-4bbe-be43-d5dbab08510b','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','8f4c7a95-b651-4d76-ab9d-2f479bf9fb7a','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','9bfc0e30-c5e9-4618-ac41-91ddb244542f','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','9e4ad3c3-f797-4de9-9e6d-d6bca4fe5534','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','a1c4dc1d-1e4c-4146-b529-5ed8be7bb4af','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','a35ec89c-6dec-4b11-b24c-b94e0b642187','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','a6ddbcbe-df33-4f91-8297-9c2a88ab0e8f','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','ad1919fc-f05a-4d98-9353-29691d9596c6','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','b0860ed5-a785-4d16-85bf-51aa6d1752c2','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','b6141364-44c5-4267-9190-514d6d037bab','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','b8bfa72a-48ba-4d4f-a213-14029307258f','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','c6106cc3-d096-43fb-bd3c-8614fec80eac','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','ce557f80-1cbd-432e-8adc-08cb1b3e6390','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','d5a646d3-812e-4e56-881f-4fc50527f864','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','d6b213ed-aef3-4cbe-a4b6-ffaa63cacb00','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','dc2cd85f-89e0-4cbd-b8c9-e4666b9e3e3b','2026-09-25T22:01:11.831048+00:00'),
  ('8b4a228b-bcf8-45e8-aaad-64834dbaafac','fd82515f-9c2d-48c0-ae09-df415ec2ff2d','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','0e415bf4-093d-4997-b401-65ff974d5d62','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','0eaf0640-1df5-494a-ad2d-c88426b4169c','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','1731879a-8083-450a-91ad-169fa7be2707','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','1b7802b4-6075-418d-a7b8-ae93e28b8171','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','1fd7e1fa-8ec6-4344-93a4-c748cac6c16f','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','3deb6ab1-fbda-4451-b1b9-63fe6425d5b2','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','3fe8c184-f20c-474c-bedb-0e728b71834c','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','422a7e03-a4fa-4bb2-a2e2-323457234614','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','43246fb3-9e90-4740-97ca-7bc5fe2e79cb','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','4566230a-fd2e-45c2-9914-79937245f3eb','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','5e3ac3d8-8d38-46ba-8242-187c9f44b5c7','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','617046ca-fd18-4a33-939d-e4a74dd5be52','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','6521d48c-db1a-4d7b-94b9-f74a327ff0ad','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','66dcaf57-ec15-49eb-b07a-7cddafb9ece7','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','6834d140-1c51-4322-9421-153ea5b2072f','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','7083cae3-d45c-44de-8f3b-7f847003004c','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','7cc5fedd-fe09-4972-9657-ffe10d982693','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','82104f4e-537a-4305-bbf3-0017fc64735f','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','86641858-9b1b-4f69-9e50-6d2be9c15fc0','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','8c957ccc-2836-4b94-844c-05504cbd5822','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','8d5cf699-04c7-4bbe-be43-d5dbab08510b','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','8f4c7a95-b651-4d76-ab9d-2f479bf9fb7a','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','9bfc0e30-c5e9-4618-ac41-91ddb244542f','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','9e4ad3c3-f797-4de9-9e6d-d6bca4fe5534','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','a1c4dc1d-1e4c-4146-b529-5ed8be7bb4af','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','a35ec89c-6dec-4b11-b24c-b94e0b642187','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','a6ddbcbe-df33-4f91-8297-9c2a88ab0e8f','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','aa4a905f-8059-4710-b415-25aa77cbeedd','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','ad1919fc-f05a-4d98-9353-29691d9596c6','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','b0860ed5-a785-4d16-85bf-51aa6d1752c2','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','b6141364-44c5-4267-9190-514d6d037bab','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','b8bfa72a-48ba-4d4f-a213-14029307258f','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','c6106cc3-d096-43fb-bd3c-8614fec80eac','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','ca57110b-63a9-47d7-a650-096893b41698','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','ce557f80-1cbd-432e-8adc-08cb1b3e6390','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','d5a646d3-812e-4e56-881f-4fc50527f864','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','d6b213ed-aef3-4cbe-a4b6-ffaa63cacb00','2026-09-25T22:01:11.831048+00:00') on conflict do nothing;

insert into public."rol_permisos"("rol_id","permiso_id","fecha_creacion") values
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','dc2cd85f-89e0-4cbd-b8c9-e4666b9e3e3b','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','dd8de49c-83f2-4ad9-9213-afe2f28b7386','2026-09-25T22:01:11.831048+00:00'),
  ('a5afd7be-1c11-413b-92b1-bd488ce72671','fd82515f-9c2d-48c0-ae09-df415ec2ff2d','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','13b4b968-92fd-429f-b949-ac96babff5c7','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','19af057b-35f1-4e99-92a1-ed8e69435598','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','1b7802b4-6075-418d-a7b8-ae93e28b8171','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','2c85492c-ac61-4f46-9542-7d74db9df367','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','3fe8c184-f20c-474c-bedb-0e728b71834c','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','418ec142-94ea-4ee6-b561-09261484620e','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','422a7e03-a4fa-4bb2-a2e2-323457234614','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','4566230a-fd2e-45c2-9914-79937245f3eb','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','5e3ac3d8-8d38-46ba-8242-187c9f44b5c7','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','617046ca-fd18-4a33-939d-e4a74dd5be52','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','6521d48c-db1a-4d7b-94b9-f74a327ff0ad','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','68c4466b-e7d0-4484-a7c7-512ff1a5e625','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','7083cae3-d45c-44de-8f3b-7f847003004c','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','7cc5fedd-fe09-4972-9657-ffe10d982693','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','82104f4e-537a-4305-bbf3-0017fc64735f','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','86641858-9b1b-4f69-9e50-6d2be9c15fc0','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','8c957ccc-2836-4b94-844c-05504cbd5822','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','8f4c7a95-b651-4d76-ab9d-2f479bf9fb7a','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','976d39e5-4dd4-488e-9fea-bd8586ac2d99','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','9b894292-c7c5-41a7-afa6-90d2baa77604','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','9e4ad3c3-f797-4de9-9e6d-d6bca4fe5534','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','a1c4dc1d-1e4c-4146-b529-5ed8be7bb4af','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','a35ec89c-6dec-4b11-b24c-b94e0b642187','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','b6141364-44c5-4267-9190-514d6d037bab','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','bad26c00-d6a8-45c2-8493-e1d1348f10ab','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','bbcf99b8-710d-4119-a7d5-9b730ca30b10','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','bcb06493-ab9f-4d7c-91e9-cbb832e0f0cb','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','c6106cc3-d096-43fb-bd3c-8614fec80eac','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','c9d79eed-2712-4b45-b604-4354157cec8d','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','ca57110b-63a9-47d7-a650-096893b41698','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','cc18b96b-ad0d-4ace-a854-e04fcdb7ac23','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','ce557f80-1cbd-432e-8adc-08cb1b3e6390','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','dc2cd85f-89e0-4cbd-b8c9-e4666b9e3e3b','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','dd8de49c-83f2-4ad9-9213-afe2f28b7386','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','f03c44f8-89e9-4d24-8d20-96190d39b34a','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','f4fa9542-7b0f-4dd0-b68a-e710967bbd99','2026-09-25T22:01:11.831048+00:00'),
  ('e2563954-e612-4a37-82bc-2f112085eb0d','fd82515f-9c2d-48c0-ae09-df415ec2ff2d','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','0e415bf4-093d-4997-b401-65ff974d5d62','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','136fcfac-1f5b-40ba-840b-aabcf4da96e2','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','1b7802b4-6075-418d-a7b8-ae93e28b8171','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','1fd7e1fa-8ec6-4344-93a4-c748cac6c16f','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','37b84d50-d583-48b7-af6d-411d8a58f77a','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','3b8d0db9-b6f9-4536-ae3e-66296332e995','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','418ec142-94ea-4ee6-b561-09261484620e','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','44cf4ae6-4a66-4589-8452-298202777718','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','4566230a-fd2e-45c2-9914-79937245f3eb','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','4ecb0c61-e209-47d5-9f3f-4f406c1f85ee','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','54fa5045-0e40-4bff-a0d7-7582234e1bba','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','5e3ac3d8-8d38-46ba-8242-187c9f44b5c7','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','617046ca-fd18-4a33-939d-e4a74dd5be52','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','6834d140-1c51-4322-9421-153ea5b2072f','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','82104f4e-537a-4305-bbf3-0017fc64735f','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','86641858-9b1b-4f69-9e50-6d2be9c15fc0','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','8c957ccc-2836-4b94-844c-05504cbd5822','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','8d454087-acc3-4b65-bceb-fc8df44bd673','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','8f4c7a95-b651-4d76-ab9d-2f479bf9fb7a','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','91929713-ddf5-45b9-aa9e-edd953773239','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','9e4ad3c3-f797-4de9-9e6d-d6bca4fe5534','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','a35ec89c-6dec-4b11-b24c-b94e0b642187','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','ab639c36-5c00-4680-8013-b4903f981a76','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','ad1919fc-f05a-4d98-9353-29691d9596c6','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','b8bfa72a-48ba-4d4f-a213-14029307258f','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','bad26c00-d6a8-45c2-8493-e1d1348f10ab','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','ce557f80-1cbd-432e-8adc-08cb1b3e6390','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','d5a646d3-812e-4e56-881f-4fc50527f864','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','d6b213ed-aef3-4cbe-a4b6-ffaa63cacb00','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','db313000-b40a-481f-bbbd-e428221545eb','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','dc2cd85f-89e0-4cbd-b8c9-e4666b9e3e3b','2026-09-25T22:01:11.831048+00:00'),
  ('fec7330f-b3c9-4ebd-9833-462c9855bbf1','e16abc17-f099-4523-b601-1287e611d9e8','2026-09-25T22:01:11.831048+00:00') on conflict do nothing;

insert into erp_private.installation(version) values('202610090001') on conflict do nothing;

commit;
