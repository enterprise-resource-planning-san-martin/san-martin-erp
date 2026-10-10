import assert from 'node:assert/strict';
import { createBaselineFixture } from './fixture.mjs';

const db = await createBaselineFixture({emptyAccess:true});
try {
  const user = '11111111-1111-4111-8111-111111111111';
  const role = '22222222-2222-4222-8222-222222222222';
  await db.exec([
    "insert into auth.users(id,email) values ('11111111-1111-4111-8111-111111111111','h13@example.com')",
    "insert into public.roles(id,codigo,nombre) values ('22222222-2222-4222-8222-222222222222','H13_TEST','Prueba H13')",
    "insert into public.permisos(codigo,modulo,accion,nombre) values ('usuarios.ver','usuarios','ver','Ver usuarios')",
    "insert into public.perfiles(id,correo,rol_id) values ('11111111-1111-4111-8111-111111111111','h13@example.com','22222222-2222-4222-8222-222222222222')",
    "insert into public.rol_permisos(rol_id,permiso_id) select '22222222-2222-4222-8222-222222222222',id from public.permisos where codigo='usuarios.ver'"
  ].join(';') + ';');
  const claims = JSON.stringify({sub:user,role:'authenticated'});
  await db.query('select set_config($1,$2,false)', ['request.jwt.claims',claims]);
  let result = await db.query('select codigo from public.erp_mis_permisos()');
  assert(result.rows.some(row => row.codigo === 'usuarios.ver'));
  await db.query('update public.perfiles set activo=false,estado=$1 where id=$2', ['INACTIVO',user]);
  result = await db.query('select codigo from public.erp_mis_permisos()');
  assert.equal(result.rows.length, 0);
  await db.query('update public.perfiles set activo=true,estado=$1 where id=$2', ['ACTIVO',user]);
  await db.query('update public.perfiles set rol_id=null where id=$1', [user]);
  assert.equal((await db.query('select public.erp_usuario_activo() activo')).rows[0].activo, true);
  await db.query('update public.perfiles set rol_id=$1 where id=$2', [role,user]);
  await db.query('update public.roles set activo=false where id=$1', [role]);
  result = await db.query('select codigo from public.erp_mis_permisos()');
  assert.equal(result.rows.length, 0);
  assert.equal((await db.query('select public.erp_usuario_activo() activo')).rows[0].activo, false);
  const grants = await db.query("select has_function_privilege('anon','public.erp_mis_permisos()','execute') anon, has_function_privilege('authenticated','public.erp_mis_permisos()','execute') authenticated");
  assert.equal(grants.rows[0].anon, false);
  assert.equal(grants.rows[0].authenticated, true);
  console.log('PASS H13 SQL: permisos efectivos, perfil inactivo y grants.');
} finally {
  await db.close();
}
