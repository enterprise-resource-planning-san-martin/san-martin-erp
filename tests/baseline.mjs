import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';

const db=new PGlite();
await db.exec(`
  create role anon;create role authenticated;create role service_role bypassrls;
  create schema auth;create schema storage;
  create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb);
  create function auth.uid() returns uuid language sql stable as
    $$select (nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid$$;
  create function auth.role() returns text language sql stable as
    $$select nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'role'$$;
  create table storage.buckets(id text primary key,name text not null,public boolean not null,
    file_size_limit bigint,allowed_mime_types text[]);
  create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
  alter table storage.objects enable row level security;
`);
const source=new URL('../supabase/baseline/20261009_post_etapa_b.sql',import.meta.url);
await db.exec(await readFile(source,'utf8'));
async function count(sql){return Number((await db.query(sql)).rows[0].n);}
assert.equal(await count("select count(*) n from information_schema.tables where table_schema in ('public','erp_private','private') and table_type='BASE TABLE'"),44);
assert.equal(await count("select count(*) n from pg_views where schemaname='public' and viewname in ('catalogo_publico','catalogo_productos','catalogo_producto_detalle','auditoria_calidad_catalogo_ecommerce')"),4);
assert.equal(await count("select count(*) n from pg_proc p join pg_namespace s on s.oid=p.pronamespace where s.nspname in ('public','erp_private','private' )"),75);
assert.equal(await count('select count(*) n from public.roles'),6);
assert.equal(await count('select count(*) n from public.permisos'),122);
assert.equal(await count('select count(*) n from public.rol_permisos'),372);
assert.equal(await count('select count(*) n from storage.buckets'),6);
assert.equal(await count("select count(*) n from pg_trigger where tgrelid='auth.users'::regclass and not tgisinternal"),1);
assert.equal(await count("select count(*) n from pg_policies where schemaname in ('public','private','erp_private','storage')"),99);
assert.equal(await count("select count(*) n from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private','erp_private') and not t.tgisinternal"),35);
const privileges=(await db.query("select has_table_privilege('anon','public.productos','TRUNCATE') anon_truncate,has_table_privilege('authenticated','public.productos','TRUNCATE') auth_truncate")).rows[0];
assert.equal(privileges.anon_truncate,false);
assert.equal(privileges.auth_truncate,false);
await db.close();
console.log('H14 baseline completo: tablas, vistas, funciones, roles, permisos, buckets y Auth: OK');
