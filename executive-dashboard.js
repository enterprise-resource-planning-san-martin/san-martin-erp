// Resumen completo: las agregaciones respetan RLS y no dependen del detalle descargado.
dashboard = async function () {
  const view = captureView();
  const summary = await loadOperationalSummary();
  if (!isCurrentView(view)) return;
  const stock = summary.stock, moves = summary.movimientos;
  const top = moves?.top_productos || [];
  const count = Number(stock?.existencias || 0);
  const pct = value => count ? Math.round(Number(value) / count * 100) : 0;
  const health = stock ? [['Normal',stock.normal,'health-normal'],['Stock bajo',stock.bajo,'health-low'],['Sin stock',stock.sin_stock,'health-empty']].map(([label,value,style])=>`<div><span>${label}</span><strong>${qty(value)}</strong><i><b class="${style}" style="width:${pct(value)}%"></b></i></div>`).join('') : '<p class="muted">Sin permiso para consultar inventario.</p>';
  $('#content').innerHTML = `<section class="executive-hero"><div><p class="eyebrow">PANEL EJECUTIVO</p><h3>Inventario en tiempo real</h3><p>Totales de todas tus ubicaciones autorizadas.</p></div><button class="secondary" data-go="reports">Ver reporte completo</button></section>${operationalAccessNote(summary)}
    <div class="stats executive-stats">${operationalStat('PRODUCTOS ACTIVOS',summary.productos_activos,'Catálogo autorizado')}${operationalStat('UNIDADES DISPONIBLES',stock?.unidades_disponibles,'Todas tus ubicaciones')}${operationalStat('INVENTARIO CRÍTICO',stock ? Number(stock.sin_stock)+Number(stock.bajo) : null,'Sin stock o bajo')}${operationalStat('UNIDADES VENDIDAS',moves?.vendido,'Últimos 30 días')}</div>
    <div class="grid-2" style="margin-top:1rem"><section class="panel"><div class="panel-head"><h3>Salud del inventario</h3><button class="link" data-go="stock-alerts">Ver alertas</button></div><div class="health-bars">${health}</div></section>
    <section class="panel"><div class="panel-head"><h3>Flujo de inventario</h3><span class="muted">Últimos 30 días</span></div>${moves ? `<div class="flow-grid">${[['Entradas',moves.entradas],['Salidas',moves.salidas],['POS',moves.pos],['E-commerce',moves.ecommerce]].map(([label,value])=>`<div><span>${label}</span><strong>${qty(value)}</strong></div>`).join('')}</div>` : '<p class="muted">Sin permiso para consultar movimientos.</p>'}</section></div>
    <div class="grid-2" style="margin-top:1rem"><section class="panel"><div class="panel-head"><h3>Productos más vendidos</h3><span class="muted">Últimos 30 días</span></div>${!moves ? '<p class="muted">Sin permiso para consultar movimientos.</p>' : top.length ? `<div class="low-list">${top.map((row,index)=>`<div class="low-item"><div><strong>${index+1}. ${esc(row.nombre || 'Producto')}</strong><div class="sub-cell">${esc(row.sku || '')}</div></div><span class="badge ok">${qty(row.cantidad)} uds.</span></div>`).join('')}</div>` : '<p class="muted">Aún no hay ventas en este período.</p>'}</section>
    <section class="panel"><div class="panel-head"><h3>Atención inmediata</h3><button class="link" data-go="inventory">Ver existencias</button></div>${operationalAttention(stock)}</section></div>`;
};
