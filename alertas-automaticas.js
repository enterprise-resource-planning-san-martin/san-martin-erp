// Cola completa y envío autorizado; errores visibles y pendientes separados de enviados.
async function dispatchInventoryAlerts() {
  const view = captureView();
  const button = $('#dispatch-alerts');
  if (button?.disabled) return;
  if (button) { button.disabled = true; button.textContent = 'Generando…'; }
  try {
    const { error: queueError } = await db.rpc('generar_alertas_inventario');
    if (queueError) throw queueError;
    const { data, error } = await db.functions.invoke('stock-alerts', { body: {} });
    let result = data;
    if (error) {
      if (error.context && typeof error.context.json === 'function') {
        try { result = await error.context.json(); } catch (_) { /* conserve error original */ }
      }
      const details = result?.errors?.map(item => item.message).join(' ');
      throw new Error(details || result?.error || result?.message || error.message || 'No se pudo enviar la cola de alertas.');
    }
    if (Number(result?.failed || 0) || Number(result?.blocked || 0)) {
      throw new Error(`${Number(result.sent || 0)} enviada(s); ${Number(result.failed || 0)} con error; ${Number(result.blocked || 0)} requieren revisión. ${result.errors?.map(item=>item.message).join(' ') || ''}`);
    }
    toast(`${Number(result?.sent || 0)} alerta(s) enviada(s).`);
  } catch (error) {
    toast(error.message || 'No se pudieron enviar las alertas.', true);
  } finally {
    if (button) { button.disabled = false; button.textContent = 'Generar y notificar'; }
    if (isCurrentView(view)) {
      try { await stockAlerts(); } catch (error) { toast(error.message, true); }
    }
  }
}
stockAlerts = async function () {
  const view = captureView();
  const [inventory, queued] = await Promise.all([
    fetchAllRows(() => db.from('existencias').select('id,stock_disponible,stock_minimo,stock_maximo,productos(nombre,sku,proveedores(id,nombre)),ubicaciones(nombre,codigo)',{count:'exact'}).eq('activo',true).order('id')),
    fetchAllRows(() => db.from('alertas_inventario').select('id,estado,stock_disponible,fecha_creacion,enviada_en,productos(nombre,sku),ubicaciones(nombre,codigo)',{count:'exact'}).eq('activa',true).order('fecha_creacion',{ascending:false}).order('id'))
  ]);
  if (!isCurrentView(view)) return;
  alertInventoryRows = inventory;
  const pending = queued.filter(row => !row.enviada_en), sent = queued.filter(row => row.enviada_en);
  const providers = [...new Map(inventory.map(row=>[row.productos?.proveedores?.id,row.productos?.proveedores]).filter(([id])=>id)).values()].sort((a,b)=>a.nombre.localeCompare(b.nombre));
  $('#content').innerHTML = `<section class="panel"><div class="panel-head"><div><h3>Alertas automáticas de inventario</h3><p class="muted">Sin stock, nivel mínimo o 40% del máximo por producto y ubicación.</p></div><button class="primary" id="dispatch-alerts">Generar y notificar</button></div><div id="alert-summary" class="alert-summary"></div><div class="toolbar"><label class="image-product-picker">Filtrar por proveedor<select id="alert-provider-filter"><option value="">Todos los proveedores</option>${providers.map(p=>`<option value="${esc(p.id)}">${esc(p.nombre)}</option>`).join('')}</select></label><div class="search"><input id="filter" placeholder="Buscar producto o ubicación…" /></div></div><div id="stock-alerts-table"></div></section><section class="panel" style="margin-top:1rem"><div class="panel-head"><div><h3>Notificaciones de alertas activas</h3><p class="muted">${pending.length} pendientes de envío · ${sent.length} enviadas.</p></div><span class="badge ${pending.length?'warn':'ok'}">${pending.length} PENDIENTE${pending.length===1?'':'S'}</span></div>${table(['ESTADO','PRODUCTO','UBICACIÓN','DISPONIBLE','CREADA','ENVÍO'],queued.map(row=>`<tr><td><span class="badge ${row.estado==='SIN_STOCK'?'danger-status':'warn'}">${esc(String(row.estado).replace('_',' '))}</span></td><td class="name-cell">${esc(row.productos?.nombre||'—')}<div class="sub-cell">${esc(row.productos?.sku||'')}</div></td><td>${esc(row.ubicaciones?.nombre||'—')}</td><td>${qty(row.stock_disponible)}</td><td>${esc(new Date(row.fecha_creacion).toLocaleString('es-GT',{timeZone:'America/Guatemala'}))}</td><td>${row.enviada_en?`Enviada ${esc(new Date(row.enviada_en).toLocaleString('es-GT',{timeZone:'America/Guatemala'}))}`:'Pendiente'}</td></tr>`).join(''))}</section>`;
  $('#alert-provider-filter').onchange = renderStockAlerts;
  renderStockAlerts();
  $('#filter').oninput = event => filterRows(event.target.value);
  $('#dispatch-alerts').onclick = dispatchInventoryAlerts;
};
