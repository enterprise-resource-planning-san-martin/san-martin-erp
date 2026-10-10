import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';

const db=new PGlite();
const product='20000000-0000-0000-0000-000000000001';
const user='10000000-0000-0000-0000-000000000001';
const pathA=`${product}/aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa-a.png`;
const pathB=`${product}/bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb-b.png`;
const url=path=>`https://beasfybalepkdlomzazf.supabase.co/storage/v1/object/public/productos/${path}`;
await db.exec(`
  create role anon; create role authenticated; create role service_role bypassrls;
  create schema auth;create schema erp_private;create schema storage;
  grant usage on schema public,auth,storage to authenticated;
  create function auth.uid() returns uuid language sql stable as
    $$select (nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid$$;
  create function public.erp_usuario_activo() returns boolean language sql stable as
    $$select auth.uid() is not null and coalesce((nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'active')::boolean,false)$$;
  create function public.tiene_permiso(p text) returns boolean language sql stable as
    $$select coalesce((nullif(current_setting('request.jwt.claims',true),'')::jsonb->'permissions') ? p,false)$$;
  create function erp_private.require_staff(p_permission text,p_location uuid default null)
    returns void language plpgsql security definer as
    $$begin if not public.erp_usuario_activo() or not public.tiene_permiso(p_permission)
      then raise exception 'sin permiso' using errcode='42501';end if;end$$;
  create table public.productos(id uuid primary key,activo boolean not null default true);
  create table public.producto_imagenes(
    id uuid primary key default gen_random_uuid(),producto_id uuid not null references public.productos,
    storage_bucket varchar not null default 'productos',storage_path text not null,
    url_publica text,nombre_archivo varchar,tipo_imagen varchar not null default 'producto',
    orden integer not null default 0,es_principal boolean not null default false,
    alt_text text,ancho integer,alto integer,"tamaño_bytes" bigint,mime_type varchar,
    activo boolean not null default true,creado_por uuid,
    fecha_creacion timestamptz not null default now(),fecha_actualizacion timestamptz not null default now()
  );
  create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text not null,name text not null,
    unique(bucket_id,name));
  alter table public.producto_imagenes enable row level security;
  alter table storage.objects enable row level security;
  create policy ecommerce_authenticated_read_product_images on public.producto_imagenes
    for select to authenticated using (activo=true);
  create policy productos_storage_insert on storage.objects for insert to authenticated
    with check (bucket_id='productos' and public.tiene_permiso('productos.editar'));
  create policy productos_storage_update on storage.objects for update to authenticated
    using (bucket_id='productos' and public.tiene_permiso('productos.editar'));
  create policy productos_storage_delete on storage.objects for delete to authenticated
    using (bucket_id='productos' and public.tiene_permiso('productos.editar'));
  grant all on public.productos,public.producto_imagenes,storage.objects to authenticated;
  insert into public.productos(id) values('${product}');
`);
const source=new URL('../supabase/sql/estabilizacion/h12_imagenes_producto.sql',import.meta.url);
await db.exec(await readFile(source,'utf8'));
async function login(permissions=['productos.editar'],active=true,iss='https://beasfybalepkdlomzazf.supabase.co/auth/v1'){
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:user,role:'authenticated',active,permissions,iss})]);
  await db.exec('set role authenticated');
}
async function admin(){await db.exec('reset role');}
async function rpc(name,args){return (await db.query(`select public.${name}(${args.map((_,i)=>'$'+(i+1)).join(',')}) as value`,args)).rows[0].value;}
async function reserve(path,filename='imagen.png'){
  return rpc('erp_reservar_imagen_producto',[product,path,filename,'image/png',123,url(path)]);
}
await login([]);
await assert.rejects(reserve(pathA),/sin permiso/);
await login(['productos.editar'],false);
await assert.rejects(reserve(pathA),/sin permiso/);
await login();
await assert.rejects(db.query('insert into storage.objects(bucket_id,name) values($1,$2)',['productos',`${product}/sin-reserva.png`]),/row-level security/);
const a=await reserve(pathA,'a.png');
assert.ok(a);
assert.equal((await db.query('select count(*)::int n from public.producto_imagenes where activo')).rows[0].n,0);
await assert.rejects(rpc('erp_confirmar_carga_imagen_producto',[a]),/aún no existe/);
await db.query('insert into storage.objects(bucket_id,name) values($1,$2)',['productos',pathA]);
const confirmed=await rpc('erp_confirmar_carga_imagen_producto',[a]);
assert.equal(confirmed.es_principal,true);
assert.equal((await db.query('delete from storage.objects where bucket_id=$1 and name=$2 returning id',['productos',pathA])).rows.length,0);
const b=await reserve(pathB,'b.png');
await db.query('insert into storage.objects(bucket_id,name) values($1,$2)',['productos',pathB]);
const confirmedB=await rpc('erp_confirmar_carga_imagen_producto',[b]);
assert.equal(confirmedB.orden,1);
assert.equal(confirmedB.es_principal,false);
await assert.rejects(rpc('erp_organizar_imagenes_producto',[product,[b,b],b]),/exactamente/);
await rpc('erp_organizar_imagenes_producto',[product,[b,a],b]);
let images=(await db.query('select id,orden,es_principal from public.producto_imagenes where activo order by orden')).rows;
assert.deepEqual(images.map(x=>x.id),[b,a]);
assert.deepEqual(images.map(x=>x.es_principal),[true,false]);
await rpc('erp_preparar_borrado_imagen_producto',[b]);
await assert.rejects(rpc('erp_confirmar_borrado_imagen_producto',[b]),/aún existe/);
images=(await db.query('select id,es_principal from public.producto_imagenes where activo')).rows;
assert.deepEqual(images,[{id:a,es_principal:true}]);
await db.query('delete from storage.objects where bucket_id=$1 and name=$2',['productos',pathB]);
await rpc('erp_confirmar_borrado_imagen_producto',[b]);
assert.equal((await db.query('select count(*)::int n from public.producto_imagenes')).rows[0].n,1);
await assert.rejects(db.query(`insert into public.producto_imagenes(producto_id,storage_path) values($1,$2)`,[product,'x']),/permission denied/);
const pathC=`${product}/cccccccc-cccc-cccc-cccc-cccccccccccc-c.png`;
await login(['productos.editar'],true,'https://otro-proyecto.supabase.co/auth/v1');
await assert.rejects(reserve(pathC),/Datos de imagen inválidos/);
assert.ok(await rpc('erp_reservar_imagen_producto',[product,pathC,'c.png','image/png',123,
  `https://otro-proyecto.supabase.co/storage/v1/object/public/productos/${pathC}`]));
await login(['productos.editar'],true,'');
await assert.rejects(reserve(`${product}/dddddddd-dddd-dddd-dddd-dddddddddddd-d.png`),/El token no identifica/);
await admin();
await db.close();
console.log('H12 SQL: reserva, confirmación, orden/principal atómicos, borrado diferido y permisos: OK');
