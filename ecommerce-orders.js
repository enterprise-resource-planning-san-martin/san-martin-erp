/* Pedidos e-commerce: consulta y transiciones mediante las RPC existentes. */
let ecommerceOrderRows = [];
let ecommerceOrderPage = 0;
const ecommerceOrderPageSize = 50;
const orderDate = value => value ? new Date(value).toLocaleString('es-GT') : '—';
const orderBadge = value => `<span class="badge ${value === 'PAGADO' || value === 'CONSUMIDA' ? 'ok' : value === 'RESERVADO' || value === 'ACTIVA' ? 'warn' : 'off'}">${esc(value || '—')}</span>`;
async function ecommerceOrders() {
  ecommerceOrderPage = 0;
  $('#content').innerHTML = `<section class="panel"><div class="panel-head"><div><h3>Pedidos e-commerce</h3><p class="muted">Consulta los pedidos recibidos, sus productos y reservas.</p></div></div><div class="toolbar"><div class="search"><input id="order-search" placeholder="Buscar número de pedido" aria-label="Número de pedido"></div><label>Estado<select id="order-status"><option value="">Todos</option><option>RESERVADO</option><option>PAGADO</option><option>CANCELADO</option></select></label><button class="secondary" id="order-search-button">Buscar</button></div><div id="order-results"></div><div class="panel-head"><button class="secondary" id="order-prev">Anterior</button><span class="muted" id="order-page"></span><button class="secondary" id="order-next">Siguiente</button></div></section>`;
  $('#order-search-button').onclick = () => { ecommerceOrderPage = 0; loadEcommerceOrders(); };
  $('#order-status').onchange = () => { ecommerceOrderPage = 0; loadEcommerceOrders(); };
  $('#order-search').onkeydown = event => { if (event.key === 'Enter') $('#order-search-button').click(); };
  $('#order-prev').onclick = () => { ecommerceOrderPage--; loadEcommerceOrders(); };
  $('#order-next').onclick = () => { ecommerceOrderPage++; loadEcommerceOrders(); };
  await loadEcommerceOrders();
}
let ecommerceOrderRequest = 0;
async function loadEcommerceOrders() {
  const request = ++ecommerceOrderRequest;
  $('#order-results').innerHTML = '<p class="muted">Cargando pedidos…</p>';
  $('#order-prev').disabled = $('#order-next').disabled = true;
  try {
    let query = db.from('pedidos_ecommerce').select('*,ubicaciones(nombre)', {count:'exact'}).order('fecha_creacion',{ascending:false}).order('id');
    const status = $('#order-status').value, search = $('#order-search').value.trim();
    if (status) query = query.eq('estado',status);
    if (search) query = query.ilike('numero',`%${search.replace(/[%_]/g,'')}%`);
    const {data,error,count} = await query.range(ecommerceOrderPage * ecommerceOrderPageSize,(ecommerceOrderPage + 1) * ecommerceOrderPageSize - 1);
    if (request !== ecommerceOrderRequest || state.page !== 'ecommerce-orders') return;
    if (error) throw error;
    ecommerceOrderRows = data || [];
    $('#order-results').innerHTML = table(['PEDIDO','UBICACIÓN','PAGO','ENTREGA','TOTAL','CREADO','PAGO','CANCELACIÓN',''],ecommerceOrderRows.map(order => `<tr><td class="name-cell">${esc(order.numero)}</td><td>${esc(order.ubicaciones?.nombre || '—')}</td><td>${orderBadge(order.estado)}</td><td>${orderBadge(order.estado === 'CANCELADO' ? 'CANCELADO' : order.estado_entrega || 'PENDIENTE')}</td><td>${money(order.total)}</td><td>${esc(orderDate(order.fecha_creacion))}</td><td>${esc(orderDate(order.fecha_pago))}</td><td>${esc(orderDate(order.fecha_cancelacion))}</td><td><button class="link" data-order-detail="${esc(order.id)}">Ver detalle</button></td></tr>`).join(''));
    $('#order-page').textContent = `Página ${ecommerceOrderPage + 1} · ${count || 0} pedidos`;
    $('#order-prev').disabled = ecommerceOrderPage === 0;
    $('#order-next').disabled = (ecommerceOrderPage + 1) * ecommerceOrderPageSize >= (count || 0);
    document.querySelectorAll('[data-order-detail]').forEach(button => button.onclick = () => openEcommerceOrder(button.dataset.orderDetail));
  } catch (error) { if (request === ecommerceOrderRequest && state.page === 'ecommerce-orders') $('#order-results').innerHTML = `<p class="muted">${esc(error.message)}</p>`; }
}
async function openEcommerceOrder(id) {
  try {
    const results = await Promise.all([
      db.from('pedidos_ecommerce').select('*').eq('id',id).single(),
      db.from('pedidos_ecommerce_detalle').select('cantidad,precio_unitario,total_linea,productos(nombre,sku)').eq('pedido_id',id),
      db.rpc('erp_detalle_reservas_pedido',{p_pedido_id:id})
    ]);
    const error = results.slice(0,2).find(result => result.error)?.error; if (error) throw error;
    if (state.page !== 'ecommerce-orders') return;
    const order = results[0].data, lines = results[1].data || [], reservations = Array.isArray(results[2].data) ? results[2].data : [];
    const reservationError = results[2].error;
    const paymentBlock = reservationError ? 'No se pudieron consultar las reservas: ' + reservationError.message + '. Si falta la función, ejecuta supabase_pedidos_seguimiento.sql.' : !reservations.length ? 'No hay reservas vinculadas a este pedido. El checkout pudo no crearlas; no se puede confirmar el pago sin verificar el inventario.' : reservations.some(row => row.estado !== 'ACTIVA') && order.estado === 'RESERVADO' ? 'Hay reservas inactivas. Revisa el pedido antes de confirmar el pago.' : '';
    const delivery = order.estado === 'CANCELADO' ? 'CANCELADO' : order.estado_entrega || 'PENDIENTE';
    const nextDelivery = {PENDIENTE:'PREPARADO',PREPARADO:'ENVIADO',ENVIADO:'ENTREGADO'}[delivery];
    const expired = reservations.some(row => row.estado === 'ACTIVA' && row.fecha_expiracion && new Date(row.fecha_expiracion) <= new Date());
    $('#modal-title').textContent = `Pedido ${order.numero}`;
    $('#modal-form').onsubmit = event => event.preventDefault();
    $('#modal-form').innerHTML = `<div class="wide"><p>${orderBadge(order.estado)} · <strong>${money(order.total)}</strong></p><p class="muted">Creado: ${esc(orderDate(order.fecha_creacion))}<br>Pago: ${esc(orderDate(order.fecha_pago))}<br>Cancelación: ${esc(orderDate(order.fecha_cancelacion))}</p><p>${esc(order.observaciones || '')}</p><h3>Productos</h3>${table(['PRODUCTO','CANTIDAD','PRECIO','TOTAL'],lines.map(row => `<tr><td>${esc(row.productos?.nombre || '—')}<div class="sub-cell">${esc(row.productos?.sku || '')}</div></td><td>${qty(row.cantidad)}</td><td>${money(row.precio_unitario)}</td><td>${money(row.total_linea)}</td></tr>`).join(''))}<h3>Seguimiento de entrega</h3><p>${orderBadge(delivery)}</p><p class="muted">Preparado: ${esc(orderDate(order.fecha_preparado))}<br>Enviado: ${esc(orderDate(order.fecha_envio))}<br>Entregado: ${esc(orderDate(order.fecha_entrega))}</p>${order.estado === 'PAGADO' && nextDelivery ? `<button type="button" class="primary" id="order-delivery">Marcar ${esc(nextDelivery.toLowerCase())}</button>` : ''}<h3>Reservas</h3>${paymentBlock ? `<p role="alert" class="warn">${esc(paymentBlock)}</p>` : ''}${table(['PRODUCTO','ESTADO','CANTIDAD','RESERVA','VENCE','LIBERACIÓN','CONSUMO'],reservations.map(row => `<tr><td>${esc(row.productos?.nombre || '—')}</td><td>${orderBadge(row.estado)}</td><td>${qty(row.cantidad)}</td><td>${esc(orderDate(row.fecha_reserva))}</td><td>${esc(orderDate(row.fecha_expiracion))}</td><td>${esc(orderDate(row.fecha_liberacion))}</td><td>${esc(orderDate(row.fecha_consumo))}</td></tr>`).join(''))}${expired ? '<p class="warn">Hay reservas vencidas. Revisa o cancela el pedido antes de confirmar el pago.</p>' : ''}</div>${order.estado === 'RESERVADO' ? '<label class="wide">Motivo de cancelación<textarea id="order-cancel-reason" maxlength="1000"></textarea></label><p class="wide muted">Confirmar pago descuenta el inventario físico. Cancelar libera las reservas.</p>' : ''}<div class="form-actions"><button type="button" class="secondary" data-close>Cerrar</button>${order.estado === 'RESERVADO' ? `<button type="button" class="secondary" id="order-cancel">Cancelar pedido</button><button type="button" class="primary" id="order-pay" ${reservationError || expired || !reservations.length || reservations.some(row => row.estado !== 'ACTIVA') ? 'disabled' : ''}>Confirmar pago</button>` : ''}</div>`;
    if (!$('#modal').open) $('#modal').showModal();
    if ($('#order-delivery')) $('#order-delivery').onclick = () => processEcommerceOrder(order,nextDelivery);
    if ($('#order-pay') && !$('#order-pay').disabled) {
      const finiteDates = reservations.filter(r=>r.fecha_expiracion).map(r=>new Date(r.fecha_expiracion).getTime()).filter(Number.isFinite);
      if (finiteDates.length) { const delay=Math.min(...finiteDates)-Date.now(); setTimeout(()=>{if (Date.now() >= Math.min(...finiteDates) && $('#modal').open && $('#order-pay') && $('#modal-title').textContent === `Pedido ${order.numero}`) { $('#order-pay').disabled=true; toast('La reserva venció. Vuelve a abrir el detalle.',true); }}, Math.max(0,Math.min(delay,2147483647))); }
    }
    if (order.estado === 'RESERVADO') {
      $('#order-pay').onclick = () => processEcommerceOrder(order,'pay');
      $('#order-cancel').onclick = () => processEcommerceOrder(order,'cancel');
    }
  } catch (error) { toast(error.message,true); }
}
async function processEcommerceOrder(order,action) {
  const paying = action === 'pay';
  if (!confirm(action !== 'pay' && action !== 'cancel' ? `¿Marcar el pedido ${order.numero} como ${action.toLowerCase()}?` : paying ? `¿Confirmar que recibiste el pago del pedido ${order.numero}? Se descontará el inventario físico.` : `¿Cancelar el pedido ${order.numero} y liberar sus reservas?`)) return;
  const buttons = [...$('#modal-form').querySelectorAll('button')];
  const previous = buttons.map(button => button.disabled);
  buttons.forEach(button => button.disabled = true);
  try {
    const {error} = await db.rpc('erp_accion_pedido',{p_pedido_id:order.id,p_accion:paying ? 'PAGAR' : action === 'cancel' ? 'CANCELAR' : action,p_motivo:action === 'cancel' ? $('#order-cancel-reason').value.trim() || null : null});
    if (error) throw error;
    $('#modal').close(); toast(paying ? 'Pago confirmado; inventario actualizado.' : action === 'cancel' ? 'Pedido cancelado; reservas liberadas.' : `Pedido marcado como ${action.toLowerCase()}.`);
    if (state.page === 'ecommerce-orders') await loadEcommerceOrders();
  } catch (error) { buttons.forEach((button,index) => button.disabled = previous[index]); toast(error.message,true); }
}