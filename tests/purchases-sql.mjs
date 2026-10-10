import assert from 'node:assert/strict';
import { createBaselineFixture } from './fixture.mjs';

const db=await createBaselineFixture({emptyAccess:true});
const id=n=>`${n.toString().padStart(8,'0')}-0000-0000-0000-000000000001`;
const staff=id(101),restricted=id(102),role=id(103),otherRole=id(104),supplier=id(105),product=id(106),location=id(107),category=id(108),unit=id(109),receipt1=id(110),receipt2=id(111),receipt3=id(112);
const as=async uid=>{
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:uid,role:'authenticated'})]);
  await db.exec('set role authenticated');
};
const admin=async()=>{await db.exec('reset role');await db.query("select set_config('request.jwt.claims','{}',false)");};
try {
  await db.exec(`
    insert into auth.users(id) values ('${staff}'),('${restricted}');
    insert into public.roles(id,codigo,nombre) values
      ('${role}','ADMINISTRADOR','Administrador compra'),
      ('${otherRole}','RESTRINGIDO','Restringido compra');
    insert into public.perfiles(id,rol_id) values
      ('${staff}','${role}'),('${restricted}','${otherRole}');
    insert into public.permisos(codigo,modulo,accion,nombre)
      select c,split_part(c,'.',1),split_part(c,'.',2),c
      from unnest(array['compras.crear','compras.ver','compras.confirmar','compras.recibir',
        'existencias.ajustar','productos.crear']) c;
    insert into public.rol_permisos(rol_id,permiso_id)
      select '${role}',id from public.permisos where codigo not in ('productos.crear','existencias.ajustar');
    insert into public.rol_permisos(rol_id,permiso_id)
      select '${otherRole}',id from public.permisos where codigo='productos.crear';
    insert into public.categorias(id,nombre,slug)
      values ('${category}','Compras','compras-prueba');
    insert into public.unidades_medida(id,nombre,abreviatura,tipo)
      values ('${unit}','Unidad compra','UC','UNIDAD');
    insert into public.ubicaciones(id,codigo,nombre,tipo,permite_recepcion,permite_inventario)
      values ('${location}','COMP','Bodega compras','BODEGA',true,true);
    insert into public.usuario_ubicaciones(usuario_id,ubicacion_id)
      values ('${staff}','${location}');
    insert into public.proveedores(id,nombre) values ('${supplier}','Proveedor prueba');
    insert into public.productos(id,sku,nombre,categoria_id,unidad_medida_id,precio_base)
      values ('${product}','COMP-001','Producto compra','${category}','${unit}',15);
  `);

  await as(restricted);
  await assert.rejects(db.query('select public.crear_orden_compra($1,null,null,$2) as result',
    [supplier,JSON.stringify([{producto_id:product,cantidad:5,precio_estimado:10}])]),/compras.crear|permission denied/);
  await as(staff);
  assert.equal((await db.query("select public.tiene_permiso('existencias.ajustar') as value")).rows[0].value,false);
  await assert.rejects(db.query('select public.registrar_movimiento_inventario($1,$2,1,\'ENTRADA\',\'COMPRA\')',
    [product,location]),/existencias.ajustar|requeridos/);
  await assert.rejects(db.query('select erp_private.purchase_movement_allowed($1,$2,1,\'ENTRADA\',\'COMPRA\',\'orden_compra\',\'OC-X\')',
    [product,location]),/permission denied/);
  await assert.rejects(db.query('select public.crear_orden_compra($1,null,null,$2) as result',
    [supplier,JSON.stringify([{producto_id:product,cantidad:5},{producto_id:product,cantidad:1}])]),/una sola vez/);
  const order=(await db.query('select public.crear_orden_compra($1,null,null,$2) as result',
    [supplier,JSON.stringify([{producto_id:product,cantidad:5,precio_estimado:10}])])).rows[0].result;
  assert.equal(order.estado,'BORRADOR');
  const detail=(await db.query('select id from public.ordenes_compra_detalle where orden_compra_id=$1',[order.id])).rows[0].id;
  const item1=JSON.stringify([{detalle_id:detail,cantidad:2,costo_unitario:8}]);
  await assert.rejects(db.query('select public.erp_recibir_orden_compra($1,$2,$3,$4,null,$5) as result',
    [receipt1,order.id,location,'FACT-001',item1]),/confirmadas/);
  assert.equal((await db.query('select public.erp_confirmar_orden_compra($1) as result',[order.id])).rows[0].result.estado,'ENVIADA');
  const first=(await db.query('select public.erp_recibir_orden_compra($1,$2,$3,$4,null,$5) as result',
    [receipt1,order.id,location,'FACT-001',item1])).rows[0].result;
  assert.equal(first.estado,'PARCIAL');
  assert.equal(first.lineas,1);
  const repeated=(await db.query('select public.erp_recibir_orden_compra($1,$2,$3,$4,null,$5) as result',
    [receipt1,order.id,location,'FACT-001',item1])).rows[0].result;
  assert.deepEqual(repeated,first);
  await assert.rejects(db.query('select public.erp_recibir_orden_compra($1,$2,$3,$4,null,$5) as result',
    [receipt2,order.id,location,'FACT-001',item1]),/documento ya/);
  await assert.rejects(db.query('select public.erp_recibir_orden_compra($1,$2,$3,$4,null,$5) as result',
    [receipt2,order.id,location,'FACT-002',JSON.stringify([{detalle_id:detail,cantidad:4,costo_unitario:12}])]),/excede/);
  await admin();
  assert.equal(Number((await db.query('select stock_fisico from public.existencias where producto_id=$1 and ubicacion_id=$2',[product,location])).rows[0].stock_fisico),2);
  assert.equal(Number((await db.query('select cantidad_recibida from public.ordenes_compra_detalle where id=$1',[detail])).rows[0].cantidad_recibida),2);
  await as(staff);
  const final=(await db.query('select public.erp_recibir_orden_compra($1,$2,$3,$4,null,$5) as result',
    [receipt3,order.id,location,'FACT-002',JSON.stringify([{detalle_id:detail,cantidad:3,costo_unitario:12}])])).rows[0].result;
  assert.equal(final.estado,'RECIBIDA');
  await assert.rejects(db.query('select public.erp_recibir_orden_compra($1,$2,$3,$4,null,$5) as result',
    [receipt2,order.id,location,'FACT-003',item1]),/confirmadas/);
  await assert.rejects(db.query("update public.ordenes_compra_detalle set cantidad_recibida=100 where id=$1",[detail]),/permission denied/);
  await admin();
  const stock=(await db.query('select stock_fisico,costo_promedio from public.existencias where producto_id=$1 and ubicacion_id=$2',[product,location])).rows[0];
  assert.equal(Number(stock.stock_fisico),5);
  assert.equal(Number(stock.costo_promedio),10.4);
  assert.equal(Number((await db.query('select cantidad_recibida from public.ordenes_compra_detalle where id=$1',[detail])).rows[0].cantidad_recibida),5);
  assert.equal((await db.query('select count(*)::int as n from public.recepciones_compra_detalle')).rows[0].n,2);
  const costs=(await db.query('select costo_unitario from public.movimientos where producto_id=$1 order by fecha_movimiento, costo_unitario',[product])).rows.map(x=>Number(x.costo_unitario));
  assert.deepEqual(costs,[8,12]);
  console.log('PASS compras: autorización, orden, confirmación, parcial/final, costos, idempotencia y límites.');
} finally {
  await db.close();
}
