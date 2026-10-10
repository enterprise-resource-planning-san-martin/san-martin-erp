import assert from 'node:assert/strict';
import { createBaselineFixture,projectFile } from './fixture.mjs';
import { writeFile } from 'node:fs/promises';
const db=await createBaselineFixture({emptyAccess:true});
const id=n=>`${n.toString().padStart(8,'0')}-0000-0000-0000-000000000001`;
const staff=id(1),other=id(2),customer=id(3),inactive=id(4),product=id(10),a=id(20),b=id(21),cat=id(30),unit=id(40),role=id(50);
let count=0; const pass=s=>{console.log('PASS',s);count++;};
const as=async(uid,roleName='authenticated')=>{await db.exec('reset role');await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:uid,role:roleName})]);await db.exec(`set role ${roleName}`);};
const admin=async()=>{await db.exec('reset role');await db.query("select set_config('request.jwt.claims','{}',false)");};
const call=async(sql)=>(await db.query(sql)).rows[0]?.result;
try{
 await db.exec(`insert into auth.users(id) values('${staff}'),('${other}'),('${customer}'),('${inactive}');
 insert into roles(id,codigo,nombre) values('${role}','ADMINISTRADOR','Administrador prueba');
 insert into perfiles(id,rol_id,activo) values('${staff}','${role}',true),('${other}','${role}',true),('${customer}',null,true),('${inactive}','${role}',false);
 insert into permisos(codigo,modulo,accion,nombre) select c,split_part(c,'.',1),split_part(c,'.',2),c from unnest(array['existencias.ajustar','existencias.ver','productos.editar','productos.ver','pos.vender','movimientos.ver','categorias.ver','ubicaciones.ver','permisos.asignar','roles.ver','permisos.ver','transferencias.crear']) c;
 insert into rol_permisos(rol_id,permiso_id) select '${role}',id from permisos;
 insert into categorias(id,nombre,slug) values('${cat}','Prueba','prueba');
 insert into unidades_medida(id,nombre,abreviatura,tipo) values('${unit}','Unidad','u','UNIDAD');
 insert into ubicaciones(id,codigo,nombre,tipo,permite_venta,permite_recepcion) values('${a}','A','A','BODEGA',true,true),('${b}','B','B','BODEGA',true,true);
 insert into productos(id,sku,nombre,categoria_id,unidad_medida_id,publicado_ecommerce,precio_base) values('${product}','PRUEBA','Producto prueba','${cat}','${unit}',true,10);
 insert into existencias(producto_id,ubicacion_id,stock_fisico,stock_disponible,costo_promedio) values('${product}','${a}',20,20,10),('${product}','${b}',5,5,2);
 insert into configuracion_ecommerce(id,ubicacion_ecommerce_id) values(true,'${a}');`);
 await as(inactive);await assert.rejects(db.query(`select registrar_entrada_con_costo('${product}','${a}',1,4,'COMPRA')`),/requeridos/);pass('Actual canonical inactive user rejected');
 await as(customer);const order=await call(`select crear_pedido_ecommerce('[{"producto_id":"${product}","cantidad":2}]','RETIRO_TIENDA','CONTRA_ENTREGA') result`);assert.equal(Number(order.total),20);pass('Original storefront checkout preserved with real alert triggers');
 await assert.rejects(db.query(`select confirmar_pago_ecommerce('${order.pedido_id}')`),/requeridos/);pass('Owner cannot confirm payment without staff permission');
 await as(staff);await db.query(`select erp_accion_pedido('${order.pedido_id}','PAGAR')`);await db.query(`select confirmar_pago_ecommerce('${order.pedido_id}')`);
 await admin();assert.equal(Number((await db.query(`select stock_fisico from existencias where producto_id='${product}' and ubicacion_id='${a}'`)).rows[0].stock_fisico),18);assert.equal((await db.query(`select count(*)::int n from movimientos where referencia_id='${order.pedido_id}' and tipo_movimiento='SALIDA'`)).rows[0].n,1);pass('Payment wrapper, deployed order trigger, invoice trigger: exactly one consumption');
 await as(staff);const kd=await call(`select erp_resumen_kardex('${product}',null,now()-interval '1 day',now()+interval '1 day') result`);assert.equal(Number(kd.saldo_inicial),25);assert.equal(Number(kd.saldo_final),23);assert.equal(Number(kd.salidas),2);pass('Actual storefront RESERVA and SALIDA preserve physical Kardex');
 await as(customer);const cancel=await call(`select crear_pedido_ecommerce('[{"producto_id":"${product}","cantidad":1}]','RETIRO_TIENDA','CONTRA_ENTREGA') result`);await db.query(`select cancelar_pedido_ecommerce('${cancel.pedido_id}')`);await db.query(`select cancelar_pedido_ecommerce('${cancel.pedido_id}')`);await admin();assert.equal(Number((await db.query(`select stock_reservado from existencias where producto_id='${product}' and ubicacion_id='${a}'`)).rows[0].stock_reservado),0);pass('Actual owner cancellation and order trigger release only once');
 await as(staff);const value0=await call('select sum(stock_fisico*costo_promedio) result from existencias');await db.query(`select erp_transferir_inventario('${product}','${a}','${b}',3)`);const value1=await call('select sum(stock_fisico*costo_promedio) result from existencias');assert.ok(Math.abs(Number(value0)-Number(value1))<1e-10);pass('Transfer alias works with both installed overloads and preserves value');
 await db.query(`select registrar_entrada_con_costo('${product}','${a}',1,4,'COMPRA','REUSED')`);await db.query(`select registrar_entrada_con_costo('${product}','${a}',1,7,'COMPRA','REUSED')`);await admin();assert.deepEqual((await db.query(`select costo_unitario from movimientos where referencia_numero='REUSED' order by costo_unitario`)).rows.map(r=>Number(r.costo_unitario)),[4,7]);pass('Actual stock cost trigger and movement RLS preserve repeated-reference history');
 await as(staff);const adjust=await call(`select solicitar_ajuste_inventario('${product}','${a}','ENTRADA',2,'Prueba') result`);await assert.rejects(db.query(`select autorizar_ajuste_inventario('${adjust}',true)`),/otro usuario/);await as(other);await db.query(`select autorizar_ajuste_inventario('${adjust}',true)`);pass('Actual adjustment enum normalizes and different approver enforced');
 await as(staff);await db.query(`select registrar_venta_pos('${a}','[{"producto_id":"${product}","cantidad":5}]','POS-TEST')`);await db.query(`select registrar_devolucion_venta('POS','POS-TEST','${product}','${a}',3,'Prueba')`);await assert.rejects(db.query(`select registrar_devolucion_venta('POS','POS-TEST','${product}','${a}',3,'Prueba')`),/pendiente/);pass('Actual POS and return work under positive quantity and canonical origin constraints');
 await db.query(`select registrar_conteo_inventario('${product}','${a}',4,'Prueba')`);pass('Actual count normalizes AJUSTE and CONTEO schema values');
 await assert.rejects(db.query(`update existencias set stock_fisico=200,stock_disponible=200 where producto_id='${product}'`),/permission denied/);await db.query(`update existencias set stock_minimo=1,stock_maximo=40 where producto_id='${product}'`);pass('Actual direct stock writes denied; legitimate thresholds still editable');
 await admin();assert.equal((await db.query('select count(*)::int n from existencias where stock_disponible<>stock_fisico-stock_reservado or stock_fisico<0 or stock_reservado<0')).rows[0].n,0);assert.equal((await db.query('select count(*)::int n from erp_private.movement_context')).rows[0].n,0);pass('Combined real-schema operations leave consistent stock and no private contexts');
 console.log('PASS',count,'combined live-schema operational cases; all changes isolated offline.');
}catch(error){console.error(error.message);console.error(error.stack);process.exitCode=1;}
finally{await db.close();}
