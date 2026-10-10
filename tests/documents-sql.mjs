import assert from 'node:assert/strict';
import { createBaselineFixture } from './fixture.mjs';

const db = await createBaselineFixture({emptyAccess:true});
try {
  const location = '11111111-1111-4111-8111-111111111111';
  const category = '22222222-2222-4222-8222-222222222222';
  const unit = '33333333-3333-4333-8333-333333333333';
  const product = '44444444-4444-4444-8444-444444444444';
  const oldOrder = '55555555-5555-4555-8555-555555555555';
  const newOrder = '66666666-6666-4666-8666-666666666666';

  await db.exec(`
    insert into public.ubicaciones(id,codigo,nombre,tipo) values
      ('${location}','BOD-H11','Bodega prueba','BODEGA');
    insert into public.categorias(id,nombre,slug) values
      ('${category}','H11 categoría','h11-categoria');
    insert into public.unidades_medida(id,nombre,abreviatura,tipo) values
      ('${unit}','Unidad H11','U-H11','UNIDAD');
    insert into public.productos(id,sku,nombre,categoria_id,unidad_medida_id,precio_base) values
      ('${product}','H11-001','Producto prueba','${category}','${unit}',25.00);
    insert into public.pedidos_ecommerce(id,numero,ubicacion_id,estado,total,fecha_pago)
      values ('${oldOrder}','WEB-OLD','${location}','PAGADO',25.00,'2026-10-08T12:00:00Z');
    insert into public.facturas_ecommerce(pedido_id,ubicacion_id,datos)
      values ('${oldOrder}','${location}','{"empresa":{"empresa_nombre":"Nombre histórico"},"pedido":{"numero":"WEB-OLD","total":25},"lineas":[]}'::jsonb);
    insert into public.configuracion_erp(clave,valor) values
      ('empresa_nombre','{"valor":"Papelería Nueva"}'::jsonb),
      ('empresa_nit','{"valor":"1234567"}'::jsonb),
      ('empresa_direccion','{"valor":"Calle Nueva 1"}'::jsonb),
      ('empresa_telefono','{"valor":"5555-5555"}'::jsonb),
      ('empresa_correo','{"valor":"nueva@example.com"}'::jsonb),
      ('moneda','{"valor":"GTQ"}'::jsonb),
      ('zona_horaria','{"valor":"America/Guatemala"}'::jsonb);
  `);

  await db.exec(`
    insert into public.pedidos_ecommerce(id,numero,ubicacion_id,estado,total,fecha_pago)
      values ('${newOrder}','WEB-NEW','${location}','PAGADO',50.00,'2026-10-09T12:00:00Z');
    insert into public.pedidos_ecommerce_detalle(pedido_id,producto_id,cantidad,precio_unitario,total_linea)
      values ('${newOrder}','${product}',2,25.00,50.00);
  `);
  const emitted = await db.query('select public.erp_emitir_comprobante_interno($1) as id', [newOrder]);
  const invoiceId = emitted.rows[0].id;
  const newer = await db.query('select datos from public.facturas_ecommerce where id=$1', [invoiceId]);
  const data = newer.rows[0].datos;
  assert.equal(data.moneda, 'GTQ');
  assert.equal(data.zona_horaria, 'America/Guatemala');
  assert.equal(data.empresa.empresa_nombre, 'Papelería Nueva');
  assert.equal(data.empresa.empresa_nit, '1234567');
  assert.equal(data.empresa.empresa_direccion, 'Calle Nueva 1');
  assert.equal(data.empresa.empresa_telefono, '5555-5555');
  assert.equal(data.empresa.empresa_correo, 'nueva@example.com');
  assert.equal(data.lineas.length, 1);
  assert.equal(data.lineas[0].total_linea, 50);
  assert.equal((await db.query('select public.erp_emitir_comprobante_interno($1) as id', [newOrder])).rows[0].id, invoiceId);

  await db.exec(`update public.configuracion_erp set valor='{"valor":"Otra Empresa"}'::jsonb where clave='empresa_nombre';`);
  const afterChange = await db.query('select datos from public.facturas_ecommerce where id=$1', [invoiceId]);
  assert.equal(afterChange.rows[0].datos.empresa.empresa_nombre, 'Papelería Nueva');
  const old = await db.query(`select datos from public.facturas_ecommerce where pedido_id='${oldOrder}'`);
  assert.equal(old.rows[0].datos.empresa.empresa_nombre, 'Nombre histórico');
  assert.equal(old.rows[0].datos.moneda, undefined);

  await assert.rejects(
    db.exec(`update public.configuracion_erp set valor='{"valor":"USD"}'::jsonb where clave='moneda';`),
    /erp_configuracion_moneda_gtq/
  );
  const policies = await db.query(`select policyname,qual,with_check from pg_policies where schemaname='public' and tablename='configuracion_erp'`);
  assert.equal(policies.rows.length, 3);
  assert(policies.rows.every(row => !`${row.qual} ${row.with_check}`.includes('usuarios.')));
  assert(policies.rows.some(row => `${row.qual} ${row.with_check}`.includes('configuracion.editar')));
  const roleRead = '77777777-7777-4777-8777-777777777777';
  const roleEdit = '88888888-8888-4888-8888-888888888888';
  const roleUsers = '99999999-9999-4999-8999-999999999999';
  const permissionRead = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const permissionEdit = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const permissionUsers = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
  const userRead = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
  const userEdit = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
  const userUsers = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
  await db.exec(`
    insert into public.roles(id,codigo,nombre) values
      ('${roleRead}','H11_READ','Lectura'),('${roleEdit}','H11_EDIT','Edición'),('${roleUsers}','H11_USERS','Usuarios');
    insert into public.permisos(id,codigo,modulo,accion,nombre) values
      ('${permissionRead}','configuracion.ver','configuracion','ver','Ver configuración'),
      ('${permissionEdit}','configuracion.editar','configuracion','editar','Editar configuración'),
      ('${permissionUsers}','usuarios.ver','usuarios','ver','Ver usuarios');
    insert into public.rol_permisos(rol_id,permiso_id) values
      ('${roleRead}','${permissionRead}'),('${roleEdit}','${permissionEdit}'),('${roleUsers}','${permissionUsers}');
    insert into auth.users(id,email) values
      ('${userRead}','read@example.test'),('${userEdit}','edit@example.test'),('${userUsers}','users@example.test');
    insert into public.perfiles(id,rol_id,estado,activo) values
      ('${userRead}','${roleRead}','ACTIVO',true),
      ('${userEdit}','${roleEdit}','ACTIVO',true),
      ('${userUsers}','${roleUsers}','ACTIVO',true);
  `);
  const asUser = async (userId, callback) => {
    await db.exec(`set role authenticated; set request.jwt.claims='{"sub":"${userId}","role":"authenticated"}';`);
    try { return await callback(); }
    finally { await db.exec('reset role; reset request.jwt.claims;'); }
  };
  await asUser(userRead, async () => {
    assert.equal((await db.query("select count(*)::int as n from public.configuracion_erp where clave='moneda'")).rows[0].n, 1);
    assert.equal((await db.query("update public.configuracion_erp set valor='{" + '"valor":"GTQ"' + "}'::jsonb where clave='moneda' returning clave")).rows.length, 0);
  });
  await asUser(userEdit, async () => {
    assert.equal((await db.query("select count(*)::int as n from public.configuracion_erp where clave='moneda'")).rows[0].n, 1);
    assert.equal((await db.query("update public.configuracion_erp set valor='{" + '"valor":"GTQ"' + "}'::jsonb where clave='moneda' returning clave")).rows.length, 1);
  });
  await asUser(userUsers, async () => {
    assert.equal((await db.query("select count(*)::int as n from public.configuracion_erp where clave='moneda'")).rows[0].n, 0);
    assert.equal((await db.query("update public.configuracion_erp set valor='{" + '"valor":"GTQ"' + "}'::jsonb where clave='moneda' returning clave")).rows.length, 0);
  });
  console.log('PASS H11: emisión, instantánea de empresa/GTQ, documentos históricos, idempotencia y RLS.');
} finally {
  await db.close();
}
