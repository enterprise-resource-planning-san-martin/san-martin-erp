/* Comprobantes internos: cada impresión usa la instantánea guardada al emitir. */
function ecommerceInvoiceCurrency(invoice) {
  // Los comprobantes anteriores no tienen la clave moneda; sus importes eran GTQ.
  return invoice?.datos?.moneda === 'USD' ? 'USD' : 'GTQ';
}

function ecommerceInvoiceMoney(value, currency) {
  const amount = Number(value ?? 0);
  return new Intl.NumberFormat('es-GT', { style:'currency', currency }).format(Number.isFinite(amount) ? amount : 0);
}

function ecommerceAmountWords(value, currency = 'GTQ') {
  const cents=Math.round(Number(value||0)*100);
  if(!Number.isSafeInteger(cents)||cents<0)return 'Importe fuera de rango';
  const units=['cero','uno','dos','tres','cuatro','cinco','seis','siete','ocho','nueve','diez','once','doce','trece','catorce','quince','dieciséis','diecisiete','dieciocho','diecinueve','veinte','veintiuno','veintidós','veintitrés','veinticuatro','veinticinco','veintiséis','veintisiete','veintiocho','veintinueve'];
  const tens=['','','','treinta','cuarenta','cincuenta','sesenta','setenta','ochenta','noventa'];
  const hundreds=['','ciento','doscientos','trescientos','cuatrocientos','quinientos','seiscientos','setecientos','ochocientos','novecientos'];
  const apocope=text=>text.replace(/veintiuno$/,'veintiún').replace(/uno$/,'un');
  function words(n){
    if(n<30)return units[n];
    if(n<100)return tens[Math.floor(n/10)]+(n%10?' y '+units[n%10]:'');
    if(n===100)return 'cien';
    if(n<1000)return hundreds[Math.floor(n/100)]+(n%100?' '+words(n%100):'');
    if(n<1000000)return (Math.floor(n/1000)===1?'mil':apocope(words(Math.floor(n/1000)))+' mil')+(n%1000?' '+words(n%1000):'');
    if(n<1000000000000)return (Math.floor(n/1000000)===1?'un millón':apocope(words(Math.floor(n/1000000)))+' millones')+(n%1000000?' '+words(n%1000000):'');
    return (Math.floor(n/1000000000000)===1?'un billón':apocope(words(Math.floor(n/1000000000000)))+' billones')+(n%1000000000000?' '+words(n%1000000000000):'');
  }
  const whole=Math.floor(cents/100);
  const unit = currency === 'USD' ? (whole === 1 ? ' dólar' : ' dólares') : (whole === 1 ? ' quetzal' : ' quetzales');
  return (apocope(words(whole))+(whole>=1000000&&whole%1000000===0?' de':'')+unit+' con '+String(cents%100).padStart(2,'0')+'/100').toUpperCase();
}

function ecommerceInvoiceDocument(invoice) {
  const data=invoice.datos, company=data.empresa||{}, customer=data.cliente||{}, order=data.pedido||{};
  const currency=ecommerceInvoiceCurrency(invoice);
  const invoiceMoney=value=>ecommerceInvoiceMoney(value,currency);
  const zone=data.zona_horaria==='America/Guatemala'?data.zona_horaria:'America/Guatemala';
  const companyValue=(key,fallback)=>String(company[key]??'').trim()||fallback;
  const companyName=companyValue('empresa_nombre','San Martín');
  const companyNit=companyValue('empresa_nit','42299039');
  const companyAddress=companyValue('empresa_direccion','5ta c. 7-01 col. Belén apto. A av. La Brigada z. 7, Mixco, Guatemala');
  const companyPhone=companyValue('empresa_telefono','+502 4902-7035');
  const companyEmail=companyValue('empresa_correo','sanmartinlibreriapapeleria@gmail.com');
  const address=order.direccion_envio||{};
  const invoiceNumber=`EC-${String(invoice.numero).padStart(8,'0')}`;
  const date=new Date(invoice.fecha_emision).toLocaleString('es-GT',{timeZone:zone});
  const deliveryMethod=String(order.metodo_entrega||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
  const deliveryType=/recoger|retiro|tienda|pickup/.test(deliveryMethod)?'Recoger en Tienda':/envio|domicilio|delivery/.test(deliveryMethod)?'Envío':'No registrado';
  const name=address.nombre_completo||address.nombre||customer.nombre||'Consumidor final';
  const printedAt=new Date().toLocaleString('es-GT',{timeZone:zone});
  const paymentMethod=String(order.metodo_pago||'').replace(/_/g,' ').toLowerCase()||'No registrado';
  const deliveryLabel=deliveryType==='Recoger en Tienda'?'Retiro en Tienda':deliveryType==='Envío'?'Envío a domicilio':'No registrado';
  const shippingAddress=typeof address==='string'?address.trim():[address.direccion_completa||address.direccion,address.municipio,address.departamento,address.referencia_direccion].filter(value=>String(value||'').trim()).join(', ');
  const profileAddress=[customer.direccion_completa,customer.municipio,customer.departamento,customer.referencia_direccion].filter(value=>String(value||'').trim()).join(', ');
  const destination=shippingAddress||profileAddress;
  const lines=data.lineas||[], subtotal=lines.reduce((sum,line)=>sum+Number(line.total_linea||0),0);
  const logo=new URL('assets/logo-san-martin.png',document.baseURI).href;
  const qrImage=new URL('assets/sanmartin.jpeg',document.baseURI).href;
  const brandImages=[['maped.png','Maped'],['pilot.png','Pilot'],['scribe.png','Scribe'],['sysabe.png','Sysabe'],['tucan.jpeg','Tucán'],['yplus.jpeg','Yplus']].map(([file,name])=>'<img src="'+esc(new URL('assets/'+file,document.baseURI).href)+'" alt="'+esc(name)+'">').join('');
  const html=`<!doctype html><html lang="es"><head><meta charset="utf-8"><title>${esc(invoiceNumber)} · ${esc(companyName)}</title><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@600&display=swap"><style>
  @page{size:A4;margin:12mm}*{box-sizing:border-box}body{font:12px Arial,sans-serif;color:#111;margin:0}.sheet{position:relative;width:186mm;height:273mm;margin:auto;display:flex;flex-direction:column;break-after:page;page-break-after:always}.sheet:last-child{break-after:auto;page-break-after:auto}.sheet>header,.sheet>.customer,.sheet>table{flex-shrink:0}.page-bottom{margin-top:2px;flex:1;display:flex;flex-direction:column}.invoice-brand-space{flex:1;min-height:24mm;padding-top:8px;padding-left:28mm;display:flex;align-items:flex-end;padding-bottom:8mm}.invoice-brands{width:100%}.invoice-brands{display:grid;grid-template-columns:repeat(6,minmax(0,1fr));gap:12px;align-items:center;break-inside:avoid}.invoice-brands img{display:block;width:100%;height:15mm;object-fit:contain}.invoice-qr{position:absolute;left:0;bottom:8mm;width:22mm;height:22mm;object-fit:contain}.invoice-contact{text-align:center;white-space:nowrap;font-size:10px;margin-top:8px}.page-number{text-align:right;font-size:10px;margin-top:6px}.continuation{font-size:11px;text-align:right}.header{display:grid;grid-template-columns:1fr 1fr 1fr;gap:16px;align-items:center;padding-bottom:14px;border-bottom:0.25px solid #000;margin-bottom:12px}.company{text-align:center;line-height:1.5}.company strong{font-size:17px}.brand{text-align:center}.brand img{max-width:100%;height:96px;object-fit:contain}.brand h1{font-family:"Playfair Display",serif;font-weight:600;font-size:25px;margin:4px}.brand p{font-size:11px;margin:0}.meta{line-height:1.7}.heading{text-align:center;margin:16px 0 8px;font-size:17px}.internal{text-align:center;font-size:10px;margin-bottom:14px}.customer{display:grid;grid-template-columns:1.4fr 1fr;gap:6px 20px;margin-bottom:16px;line-height:1.5}.wide{grid-column:1/-1}table{width:100%;table-layout:fixed;border-collapse:collapse;font-size:10px}th:nth-child(1){width:15%}th:nth-child(2){width:10%}th:nth-child(3){width:10%}th:nth-child(4){width:39%}th:nth-child(5),th:nth-child(6){width:13%}tbody tr{height:6mm}thead{display:table-header-group}th{background:#ddd;border-top:0.25px solid #111;border-bottom:0.25px solid #111;text-align:left;padding:7px 4px}td{padding:3px 4px;overflow-wrap:anywhere;border-bottom:0.25px solid #eee;vertical-align:top}tr{break-inside:avoid}.number{text-align:right;white-space:nowrap}.totals{margin:2px 0;display:grid;grid-template-columns:minmax(0,1fr) 270px;column-gap:20px;break-inside:avoid}.amount-words{grid-column:1;grid-row:1 / 5;align-self:end;font-size:12px;line-height:1.4;padding:2px 0}.totals p{grid-column:2;display:flex;justify-content:space-between;padding:2px 5px;margin:0}.total{font-size:12px;font-weight:400;border-top:0.25px solid #111}.footer{border-top:0.25px solid #111;padding-top:3px;line-height:1.4;break-inside:avoid}.signatures{display:flex;justify-content:space-between;gap:30px;margin-top:18px}.signatures span{border-top:0.25px solid #111;width:45%;text-align:center;padding-top:6px}@media screen{body{background:#eee;padding:24px}.sheet{background:white;padding:0;margin-bottom:24px;box-shadow:0 2px 8px #0002}}
  </style></head><body><main class="sheet"><header class="header"><div class="company"><strong>${esc(companyName)}</strong><br>${esc(companyAddress).replace(/\r?\n/g,'<br>')}<br>Tel. ${esc(companyPhone)}<br>${esc(companyEmail)}</div><div class="brand"><img src="${esc(logo)}" alt="${esc(companyName)}"><h1>${esc(companyName.toLocaleUpperCase('es-GT'))}</h1><p>PAPELERÍA · LIBRERÍA</p></div><div class="meta">NIT Empresa: ${esc(companyNit)}<br>No: ${esc(invoiceNumber)}<br>Pedido: ${esc(order.numero)}<br>Emisión: ${esc(date)}<br>Tipo Pedido: ${esc(deliveryType)}</div></header>
  <section class="customer"><div><strong>Cliente:</strong> ${esc(name)}</div><div>Guatemala: <span data-print-date="true">${esc(printedAt)}</span></div><div><strong>Dirección:</strong> ${esc(destination||'No registrada')}</div><div><strong>Teléfono:</strong> ${esc(address.telefono||customer.telefono||'No registrado')}</div><div><strong>Pago:</strong> Confirmado &nbsp; <strong>Método:</strong> ${esc(paymentMethod)}</div><div><strong>Entrega:</strong> ${esc(deliveryLabel)}</div><div><strong>Pedido:</strong> ${esc(order.numero)}</div><div><strong>Elaborado:</strong> E-commerce</div></section>
  <table><thead><tr><th>SKU</th><th class="number">Cantidad</th><th>Medida</th><th>Descripción</th><th class="number">P. unitario</th><th class="number">Total</th></tr></thead><tbody>${lines.map(line=>`<tr><td>${esc(line.sku||'—')}</td><td class="number">${qty(line.cantidad)}</td><td>${esc(line.medida||'—')}</td><td>${esc(line.nombre)}</td><td class="number">${invoiceMoney(line.precio_unitario)}</td><td class="number">${invoiceMoney(line.total_linea)}</td></tr>`).join('')}</tbody></table><section class="totals"><div class="amount-words">${esc(ecommerceAmountWords(order.total,currency))}</div><p><span>Productos</span><span>${invoiceMoney(subtotal)}</span></p><p><span>Envío</span><span>${invoiceMoney(order.costo_envio)}</span></p>${Math.abs(Number(order.total)-subtotal-Number(order.costo_envio||0))>.005?`<p><span>Otros ajustes del pedido</span><span>${invoiceMoney(Number(order.total)-subtotal-Number(order.costo_envio||0))}</span></p>`:''}<p class="total"><span>TOTAL (${esc(currency)})</span><span>${invoiceMoney(order.total)}</span></p></section><footer class="footer">${order.observaciones?`Observaciones: ${esc(order.observaciones)}<br>`:''}Referencia del pedido: ${esc(order.numero)} · Pago recibido: ${esc(new Date(order.fecha_pago||invoice.fecha_emision).toLocaleString('es-GT',{timeZone:zone}))}</footer></main></body></html>`;
  const mainStart=html.indexOf('<main class="sheet">');
  const tableStart=html.indexOf('<table>',mainStart);
  const bodyStart=html.indexOf('<tbody>',tableStart)+7;
  const bodyEnd=html.indexOf('</tbody>',bodyStart);
  const tableEnd=html.indexOf('</table>',bodyEnd)+8;
  const footerStart=html.indexOf('<footer class="footer">',tableEnd);
  const mainEnd=html.indexOf('</main>',footerStart);
  const rows=html.slice(bodyStart,bodyEnd).match(/<tr>[\s\S]*?<\/tr>/g)||[];
  const pageCount=Math.max(1,Math.ceil(rows.length/20));
  const pages=Array.from({length:pageCount},(_,page)=>{
    const pageRows=rows.slice(page*20,page*20+20);
    while(pageRows.length<20)pageRows.push('<tr class="empty-product">'+ '<td>&nbsp;</td>'.repeat(6)+'</tr>');
    const totals=page===pageCount-1?html.slice(tableEnd,footerStart):'<section class="totals continuation">Continúa en la siguiente hoja</section>';
    return '<main class="sheet">'+html.slice(mainStart+20,tableStart)+html.slice(tableStart,bodyStart)+pageRows.join('')+html.slice(bodyEnd,tableEnd)+'<div class="page-bottom">'+totals+html.slice(footerStart,mainEnd)+'<div class="invoice-brand-space"><div class="invoice-brands" aria-label="Marcas">'+brandImages+'</div></div><img class="invoice-qr" src="'+esc(qrImage)+'" alt="Código QR '+esc(companyName)+'"><div class="invoice-contact">'+esc(companyName)+' · '+esc(companyEmail)+'</div><div class="page-number">Hoja '+(page+1)+' de '+pageCount+'</div></div></main>';
  });
  return html.slice(0,mainStart)+pages.join('')+'</body></html>';

}

let ecommerceInvoicesRequest=0;
async function ecommerceInvoices(){
  $('#page-title').textContent='Facturas e-commerce';$('#crumb').textContent='OPERACIÓN';$('#new-button').style.visibility='hidden';
  $('#content').innerHTML=`<section class="panel"><div class="panel-head"><div><h3>Facturas e-commerce</h3><p class="muted">Comprobantes internos emitidos automáticamente al confirmar el pago. Una emisión por pedido.</p></div><button type="button" class="secondary" id="invoice-sync">Recuperar pedidos pagados anteriores</button></div><div class="toolbar"><div class="search"><input id="invoice-search" placeholder="Buscar en esta página por comprobante o pedido"></div></div><div id="invoice-results"></div><div class="panel-head"><button class="secondary" id="invoice-prev">Anterior</button><span id="invoice-page"></span><button class="secondary" id="invoice-next">Siguiente</button></div></section>`;
  let page=0,rows=[];const size=50;
  function show(){const term=$('#invoice-search').value.toLowerCase().trim();const filtered=rows.filter(row=>`${row.numero} EC-${String(row.numero).padStart(8,'0')} ${row.datos.pedido.numero} ${row.datos.cliente?.nombre||''}`.toLowerCase().includes(term));$('#invoice-results').innerHTML=filtered.length?table(['COMPROBANTE','PEDIDO','CLIENTE','EMISIÓN','TOTAL',''],filtered.map(row=>`<tr><td>EC-${String(row.numero).padStart(8,'0')}</td><td>${esc(row.datos.pedido.numero)}</td><td>${esc(row.datos.cliente?.nombre||'Consumidor final')}</td><td>${esc(orderDate(row.fecha_emision))}</td><td>${ecommerceInvoiceMoney(row.datos.pedido.total,ecommerceInvoiceCurrency(row))}</td><td><button type="button" class="link" data-invoice="${esc(row.id)}">Ver / imprimir</button></td></tr>`).join('')):'<p class="muted">No hay comprobantes para mostrar.</p>';document.querySelectorAll('[data-invoice]').forEach(button=>button.onclick=()=>openEcommerceInvoice(rows.find(row=>row.id===button.dataset.invoice)));}
  async function load(){const request=++ecommerceInvoicesRequest;try{const result=await db.from('facturas_ecommerce').select('*',{count:'exact'}).order('numero',{ascending:false}).range(page*size,(page+1)*size-1);if(state.page!=='ecommerce-invoices'||request!==ecommerceInvoicesRequest)return;if(result.error)throw result.error;rows=result.data||[];show();$('#invoice-page').textContent=`Página ${page+1} · ${result.count||0} comprobantes`;$('#invoice-prev').disabled=page===0;$('#invoice-next').disabled=(page+1)*size>=(result.count||0);}catch(error){if(state.page==='ecommerce-invoices')$('#invoice-results').innerHTML=`<p role="alert">${esc(error.message)}</p><p class="muted">Comprueba tu conexión y permisos. Si el error persiste, consulta al administrador.</p>`;}}
  $('#invoice-search').oninput=show;$('#invoice-prev').onclick=()=>{page--;load();};$('#invoice-next').onclick=()=>{page++;load();};
  $('#invoice-sync').onclick=async()=>{const button=$('#invoice-sync');button.disabled=true;try{const result=await db.rpc('erp_sincronizar_facturas_ecommerce');if(result.error)throw result.error;toast(`${result.data||0} pedidos procesados.`);await load();}catch(error){toast(error.message,true);}finally{button.disabled=false;}};
  await load();
}
async function openEcommerceInvoice(invoice){
  // Compatibilidad con comprobantes anteriores que no copiaron la dirección del perfil.
  const customer=invoice.datos.cliente||{}, order=invoice.datos.pedido||{};
  if(!String(customer.direccion_completa||'').trim() && order.cliente_id){
    const {data,error}=await db.from('perfiles').select('direccion_completa,municipio,departamento,referencia_direccion').eq('id',order.cliente_id).maybeSingle();
    if(error)toast('No se pudo consultar la dirección del cliente: '+error.message,true);
    else if(data)invoice={...invoice,datos:{...invoice.datos,cliente:{...customer,...data}}};
  }
  $('#modal-title').textContent=`Comprobante EC-${String(invoice.numero).padStart(8,'0')}`;
  $('#modal-form').onsubmit=event=>event.preventDefault();
  $('#modal-form').innerHTML='<div class="wide"><iframe id="invoice-preview" title="Vista previa del comprobante" style="width:100%;height:65vh;border:1px solid #ddd" sandbox="allow-same-origin allow-modals"></iframe></div><div class="form-actions"><button type="button" class="secondary" data-close>Cerrar</button><button type="button" class="primary" id="invoice-print" disabled>Imprimir / guardar PDF</button></div>';
  const frame=$('#invoice-preview');frame.onload=()=>{const updatePrintDate=()=>{frame.contentDocument.querySelectorAll("[data-print-date]").forEach(label=>label.textContent=new Date().toLocaleString("es-GT",{timeZone:invoice.datos?.zona_horaria==='America/Guatemala'?invoice.datos.zona_horaria:'America/Guatemala'}));};frame.contentWindow.addEventListener('beforeprint',updatePrintDate);$('#invoice-print').disabled=false;};frame.srcdoc=ecommerceInvoiceDocument(invoice);
  $('#invoice-print').onclick=()=>{frame.contentWindow.focus();frame.contentWindow.print();};
  if(!$('#modal').open)$('#modal').showModal();
}
const renderBeforeEcommerceInvoices=render;
render=async function(){if(state.page==='ecommerce-invoices'){try{await ecommerceInvoices();}catch(error){toast(error.message,true);}return;}return renderBeforeEcommerceInvoices();};
















