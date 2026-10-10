import {readFile} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';

export const projectRoot=new URL('../',import.meta.url);
export function projectFile(relativePath){return new URL(relativePath,projectRoot);}
export async function createDatabaseWithBaseline(baselinePath,{emptyAccess=false}={}) {
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
  await db.exec(await readFile(projectFile(baselinePath),'utf8'));
  if(emptyAccess) {
    await db.exec(`
      drop trigger if exists al_crear_usuario_perfil on auth.users;
      delete from public.rol_permisos;
      delete from public.permisos;
      delete from public.roles;
    `);
  }
  return db;
}
export async function createBaselineFixture(options={}) {
  return createDatabaseWithBaseline('supabase/baseline/20261009_post_etapa_b.sql',options);
}
