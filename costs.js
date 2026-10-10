/* Costing and inventory valuation module. Requires supabase_costos_inventario.sql. */
async function valuation() {
  const view = captureView();
  const rows = await fetchAllRows(() => db.from('existencias').select('id,stock_fisico,stock_disponible,costo_promedio,productos(nombre,sku,costo_ultimo,proveedores(nombre)),ubicaciones(nombre,codigo)',{count:'exact'}).eq('activo',true).order('id'));
  if (!isCurrentView(view)) return;
  const total = rows.reduce((sum,row)=>sum + Number(row.stock_fisico||0) * Number(row.costo_promedio||0),0);
  const units = rows.reduce((sum,row)=>sum + Number(row.stock_fisico||0),0);
  $('#content').innerHTML = `<section class="panel"><div class="panel-head"><div><h3>Valorización de inventario</h3><p class="muted">Valor calculado con costo promedio por producto y ubicación.</p></div></div><div class="stats kardex-stats"><div class="stat"><p>VALOR TOTAL</p><h3>${money(total)}</h3><span>Stock físico × costo promedio</span></div><div class="stat"><p>UNIDADES FÍSICAS</p><h3>${qty(units)}</h3><span>En todas las ubicaciones</span></div><div class="stat"><p>EXISTENCIAS VALORIZADAS</p><h3>${rows.filter(x=>Number(x.costo_promedio)>0).length}</h3><span>Con costo registrado</span></div></div><div class="toolbar"><div class="search"><input id="filter" placeholder="Buscar producto, proveedor o ubicación…" /></div></div>${table(['PRODUCTO','PROVEEDOR','UBICACIÓN','STOCK FÍSICO','COSTO PROMEDIO','ÚLTIMO COSTO','VALOR'],rows.map(x=>{const value=Number(x.stock_fisico||0)*Number(x.costo_promedio||0);return `<tr><td class="name-cell">${esc(x.productos?.nombre||'—')}<div class="sub-cell">${esc(x.productos?.sku||'')}</div></td><td>${esc(x.productos?.proveedores?.nombre||'—')}</td><td>${esc(x.ubicaciones?.nombre||'—')}<div class="sub-cell">${esc(x.ubicaciones?.codigo||'')}</div></td><td>${qty(x.stock_fisico)}</td><td>${money(x.costo_promedio)}</td><td>${x.productos?.costo_ultimo===null||x.productos?.costo_ultimo===undefined?'—':money(x.productos.costo_ultimo)}</td><td><strong>${money(value)}</strong></td></tr>`}).join(''))}</section>`;
  $('#filter').oninput=e=>filterRows(e.target.value);
}

openInboundCreate = async function () {
  const [productsResult,locationsResult] = await Promise.all([
    db.from('productos').select('id,nombre,sku,costo_ultimo').eq('activo',true).eq('controla_inventario',true).order('nombre'),
    db.from('ubicaciones').select('id,nombre,codigo').eq('activo',true).eq('permite_recepcion',true).order('nombre')
  ]);
  if (productsResult.error || locationsResult.error) { toast(productsResult.error?.message || locationsResult.error?.message,true); return; }
  const products=productsResult.data||[], locations=locationsResult.data||[];
  if (!products.length || !locations.length) { toast('Necesitas un producto inventariable y una ubicación que permita recepción.',true); return; }
  $('#modal-title').textContent='Registrar entrada con costo';
  $('#modal-form').innerHTML=`<label>Producto<select name="producto_id" id="inbound-product" required>${products.map(x=>`<option value="${x.id}" data-cost="${Number(x.costo_ultimo||0)}">${esc(x.nombre)} (${esc(x.sku)})</option>`).join('')}</select></label><label>Ubicación<select name="ubicacion_id" required>${locations.map(x=>`<option value="${x.id}">${esc(x.nombre)} (${esc(x.codigo)})</option>`).join('')}</select></label><input type="hidden" name="origen" value="COMPRA"><p class="wide muted">Esta entrada registra una compra. Para devolver una venta usa Devoluciones; para corregir inventario usa Ajustes autorizados.</p><label>Cantidad<input name="cantidad" type="number" min="0.01" step="0.01" required></label><label>Costo unitario<input name="costo_unitario" id="inbound-cost" type="number" min="0" step="0.0001" value="${Number(products[0].costo_ultimo||0)}" required><small class="field-help">Actualiza el costo promedio de esta ubicación.</small></label><label class="wide">Referencia / documento<input name="referencia_numero" placeholder="Ej. OC-001 o factura del proveedor"></label><label class="wide">Observaciones<textarea name="observaciones" placeholder="Detalle de la entrada"></textarea></label><div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Registrar entrada</button></div>`;
  $('#inbound-product').onchange=e=>{const option=e.target.selectedOptions[0];$('#inbound-cost').value=option.dataset.cost||0;};
  $('#modal').showModal(); $('#modal-form').onsubmit = saveInbound;
};

saveInbound = async function(event) {
  event.preventDefault(); const button=event.submitter,form=new FormData(event.target),quantity=Number(form.get('cantidad')),cost=Number(form.get('costo_unitario'));
  if (!Number.isFinite(quantity) || !(quantity>0) || !Number.isFinite(cost) || cost<0) { toast('Ingresa cantidad válida y costo unitario de cero o mayor.',true);return; }
  button.disabled=true;button.textContent='Registrando…';
  const { data, error }=await db.rpc('registrar_entrada_con_costo',{p_producto_id:form.get('producto_id'),p_ubicacion_id:form.get('ubicacion_id'),p_cantidad:quantity,p_costo_unitario:cost,p_origen:'COMPRA',p_referencia_numero:form.get('referencia_numero')||null,p_observaciones:form.get('observaciones')||null});
  if(error){button.disabled=false;button.textContent='Registrar entrada';toast(error.message,true);return;}
  $('#modal').close();toast(`Entrada registrada. Costo promedio: ${money(data?.costo_promedio)}.`);render();
};
