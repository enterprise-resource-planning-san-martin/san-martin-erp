import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createDatabaseWithBaseline,projectFile} from './fixture.mjs';

// The pre-B fixture has Stage A. Restore two historical exposures to test the
// real upgrade path: duplicate Auth trigger and TRUNCATE grants.
const db=await createDatabaseWithBaseline('tests/fixtures/pre_b_baseline.sql');
try {
  await db.exec(`
    create trigger on_auth_cliente_created after insert on auth.users
      for each row execute function public.crear_perfil_cliente();
    grant truncate on all tables in schema public to anon,authenticated;
  `);
  const migration=await readFile(projectFile('supabase/migrations/20261009184222_etapa_b_h10_h14.sql'),'utf8');
  await db.exec(migration);
  const roleMigration=await readFile(projectFile('supabase/migrations/20261009184808_etapa_b_rol_activo.sql'),'utf8');
  await db.exec(roleMigration);
  const customerMigration=await readFile(projectFile('supabase/migrations/20261009185206_etapa_b_cliente_sin_rol.sql'),'utf8');
  await db.exec(customerMigration);
  const imageUrlMigration=await readFile(projectFile('supabase/migrations/20261009185850_etapa_b_imagen_url_portable.sql'),'utf8');
  await db.exec(imageUrlMigration);
  const scalar=async sql=>Number((await db.query(sql)).rows[0].n);
  assert.equal(await scalar("select count(*) n from information_schema.tables where table_schema in ('public','private','erp_private') and table_type='BASE TABLE'"),44);
  assert.equal(await scalar("select count(*) n from pg_proc p join pg_namespace s on s.oid=p.pronamespace where s.nspname in ('public','private','erp_private')"),75);
  assert.equal(await scalar("select count(*) n from pg_trigger where tgrelid='auth.users'::regclass and not tgisinternal"),1);
  assert.equal(await scalar("select count(*) n from information_schema.role_table_grants where table_schema='public' and grantee in ('anon','authenticated') and privilege_type='TRUNCATE'"),0);
  assert.equal(await scalar("select count(*) n from information_schema.columns where table_schema='public' and table_name='producto_imagenes' and column_name='estado_storage'"),1);
  assert.match((await db.query("select pg_get_functiondef('public.erp_usuario_activo()'::regprocedure) definition")).rows[0].definition,/r\.activo = true/i);
  assert.match((await db.query("select pg_get_functiondef('public.erp_usuario_activo()'::regprocedure) definition")).rows[0].definition,/p\.rol_id is null/i);
  assert.match((await db.query("select pg_get_functiondef('public.erp_reservar_imagen_producto(uuid,text,text,text,bigint,text)'::regprocedure) definition")).rows[0].definition,/v_issuer/);
  console.log('Migración B sobre Etapa A: estructura, acceso e imágenes reconstruidos: OK');
} finally {
  await db.close();
}
