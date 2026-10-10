// Totales de servidor: el detalle paginado no limita los indicadores.
function reportStockState(row) {
  const available = Number(row.stock_disponible || 0);
  const minimum = Number(row.stock_minimo || 0);
  const maximum = Number(row.stock_maximo || 0);
  if (available <= 0) return 'SIN STOCK';
  if (available <= minimum || (maximum > 0 && available <= maximum * .4)) return 'BAJO';
  return 'NORMAL';
}
function reportRange(days) { return new Date(Date.now() - days * 864e5).toISOString(); }
async function loadOperationalSummary(days = 30) {
  const { data, error } = await db.rpc('erp_resumen_operativo', {
    p_fecha_desde: reportRange(days), p_fecha_hasta: new Date().toISOString()
  });
  if (error) {
    if (error.code === 'PGRST202' || error.code === '42883') {
      throw new Error('La actualización de reportes requiere aplicar la migración de la base de datos.');
    }
    throw error;
  }
  if (!data || typeof data.acceso !== 'object') throw new Error('No se recibió un resumen válido.');
  return data;
}
function operationalStat(label, value, caption) {
  const text = value === null || value === undefined ? 'Sin permiso' : qty(value);
  return `<div class="stat"><p>${esc(label)}</p><h3>${esc(text)}</h3><span>${esc(caption)}</span></div>`;
}
function operationalAccessNote(summary) {
  const missing = [['productos','catálogo'],['existencias','inventario'],['movimientos','movimientos']]
    .filter(([key]) => !summary.acceso[key]).map(([,label]) => label);
  return missing.length ? `<p class="muted" role="status">Tu rol no permite consultar: ${esc(missing.join(', '))}. Los demás totales incluyen todas tus ubicaciones autorizadas.</p>` : '';
}
function operationalAttention(stock, limit = 5) {
  if (!stock) return '<p class="muted">Sin permiso para consultar inventario.</p>';
  const rows = (stock.criticos || []).slice(0, limit);
  if (!rows.length) return '<p class="muted">No hay productos críticos en tus ubicaciones.</p>';
  return `<div class="low-list">${rows.map(row => `<div class="low-item"><div><strong>${esc(row.producto_nombre || 'Producto')}</strong><div class="sub-cell">${esc(row.ubicacion_nombre || 'Ubicación')} · ${esc(row.sku || '')}</div></div><span class="badge ${row.estado === 'SIN STOCK' ? 'danger-status' : 'warn'}">${qty(row.stock_disponible)} uds.</span></div>`).join('')}</div><p class="muted">Mostrando ${rows.length} de ${qty(stock.criticos_total)} existencias críticas.</p>`;
}
async function reports() {
  const view = captureView();
  const summary = await loadOperationalSummary();
  if (!isCurrentView(view)) return;
  const stock = summary.stock, moves = summary.movimientos;
  const critical = stock?.criticos || [], categories = stock?.categorias || [];
  const channelRows = moves ? [['POS', moves.pos, moves.pos_movimientos], ['E-COMMERCE', moves.ecommerce, moves.ecommerce_movimientos]] : [];
  $('#content').innerHTML = `<section class="panel"><div class="panel-head"><div><h3>Reporte operativo — últimos 30 días</h3><p class="muted">Totales completos calculados en la base de datos para tus ubicaciones autorizadas.</p></div><button class="secondary" id="print-report">Imprimir reporte</button></div>${operationalAccessNote(summary)}<div class="stats">${operationalStat('PRODUCTOS ACTIVOS',summary.productos_activos,'Catálogo autorizado')}${operationalStat('UNIDADES DISPONIBLES',stock?.unidades_disponibles,'Stock disponible')}${operationalStat('INVENTARIO CRÍTICO',stock ? Number(stock.sin_stock) + Number(stock.bajo) : null,'Sin stock o bajo')}${operationalStat('UNIDADES VENDIDAS',moves?.vendido,'POS y e-commerce')}</div></section>
    <div class="grid-2" style="margin-top:1rem"><section class="panel"><div class="panel-head"><h3>Ventas por canal</h3><span class="muted">Últimos 30 días</span></div>${moves ? table(['CANAL','UNIDADES VENDIDAS','MOVIMIENTOS'], channelRows.map(([channel,units,count])=>`<tr><td>${esc(channel)}</td><td><strong>${qty(units)}</strong></td><td>${qty(count)}</td></tr>`).join('')) : '<p class="muted">Sin permiso para consultar movimientos.</p>'}</section>
    <section class="panel"><div class="panel-head"><h3>Estado del inventario</h3></div>${stock ? table(['ESTADO','REGISTROS'],[['SIN STOCK',stock.sin_stock],['BAJO',stock.bajo],['NORMAL',stock.normal]].map(([label,count])=>`<tr><td>${esc(label)}</td><td>${qty(count)}</td></tr>`).join('')) : '<p class="muted">Sin permiso para consultar inventario.</p>'}</section></div>
    <section class="panel" style="margin-top:1rem"><div class="panel-head"><h3>Inventario por categoría</h3><span class="muted">Todas las categorías autorizadas</span></div>${stock ? table(['CATEGORÍA','REGISTROS','UNIDADES DISPONIBLES','CRÍTICOS'],categories.map(row=>`<tr><td class="name-cell">${esc(row.nombre)}</td><td>${qty(row.registros)}</td><td><strong>${qty(row.unidades_disponibles)}</strong></td><td>${qty(row.criticos)}</td></tr>`).join('')) : '<p class="muted">Sin permiso para consultar inventario.</p>'}</section>
    <section class="panel" style="margin-top:1rem"><div class="panel-head"><h3>Productos que requieren atención</h3><button class="link" data-go="stock-alerts">Ver alertas</button></div><p class="muted">${stock ? `Mostrando ${critical.length} de ${qty(stock.criticos_total)} existencias críticas. Los totales anteriores incluyen todas.` : 'Sin permiso para consultar inventario.'}</p>${stock ? table(['PRODUCTO','UBICACIÓN','DISPONIBLE','MÍNIMO','MÁXIMO','ESTADO'],critical.map(row=>`<tr><td class="name-cell">${esc(row.producto_nombre || '—')}<div class="sub-cell">${esc(row.sku || '')}</div></td><td>${esc(row.ubicacion_nombre || '—')}</td><td><strong>${qty(row.stock_disponible)}</strong></td><td>${qty(row.stock_minimo)}</td><td>${qty(row.stock_maximo)}</td><td><span class="badge ${row.estado==='SIN STOCK'?'danger-status':'warn'}">${esc(row.estado)}</span></td></tr>`).join('')) : ''}</section>`;
  $('#print-report').onclick = () => window.print();
}
