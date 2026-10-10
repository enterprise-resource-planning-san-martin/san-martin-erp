/* Núcleo Inventory — frontend connected to the supplied Supabase project. */
const SUPABASE_URL = 'https://beasfybalepkdlomzazf.supabase.co';
const SUPABASE_KEY = 'sb_publishable_WPNx9dnbcylQWB6_AXP-HA_KvTbHamZ';
// Cambia este valor si tu bucket de Supabase Storage tiene otro nombre.
const PRODUCT_IMAGE_BUCKET = 'productos';
const AUTH_CALLBACK_TYPE = new URLSearchParams(location.hash.slice(1)).get('type');
const db = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
const state = { page: 'dashboard', renderVersion: 0, profile: null, permissions: new Set(), products: [], locations: [] };
const $ = (s) => document.querySelector(s);
const toast = (message, error = false) => { const el = $('#toast'); el.textContent = message; el.style.background = error ? '#a53845' : '#173b38'; el.style.display = 'block'; setTimeout(() => el.style.display = 'none', 3800); };
const esc = (v = '') => String(v).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));
const qty = (n) => Number(n || 0).toLocaleString('es-GT', { maximumFractionDigits: 2 });
const money = (n) => new Intl.NumberFormat('es-GT', { style:'currency', currency:'GTQ' }).format(n || 0);

async function initialize() {
  const { data: { session }, error } = await db.auth.getSession();
  if (error) toast(error.message, true);
  if (session && (AUTH_CALLBACK_TYPE === 'invite' || AUTH_CALLBACK_TYPE === 'recovery')) {
    showPasswordSetup();
  } else if (session && !passwordSetupShown) {
    await enterApp(session.user);
  } else {
    $('#auth-view').classList.remove('hidden');
  }
}
async function enterApp(user) {
  const [{data,error},{data:active,error:activeError}] = await Promise.all([
    db.from('perfiles').select('id,nombre,apellido,correo,rol_id,activo,estado,roles(nombre,codigo)').eq('id', user.id).maybeSingle(),
    db.rpc('erp_usuario_activo')
  ]);
  if (activeError) { toast(activeError.message, true); showAuthPanel('login'); return; }
  if (error || !data || !data.rol_id || !data.activo || data.estado !== 'ACTIVO' || active !== true) {
    await db.auth.signOut();
    $('#app-view').classList.add('hidden');
    $('#auth-view').classList.remove('hidden');
    showAuthPanel('login');
    toast(error?.message || 'Esta cuenta no tiene un rol ERP activo.', true);
    return;
  }
  const permissionsResult = await db.rpc('erp_mis_permisos');
  if (permissionsResult.error) {
    toast(permissionsResult.error.message, true);
    showAuthPanel('login');
    return;
  }
  state.profile = data;
  state.permissions = new Set((permissionsResult.data || []).map(row => row.codigo));
  updateNavigationPermissions();
  $('#auth-view').classList.add('hidden'); $('#app-view').classList.remove('hidden');
  $('#user-mini').innerHTML = `<strong>${esc(state.profile.nombre || 'Usuario')}</strong><small>${esc(state.profile.roles?.nombre || 'Sesión activa')}</small>`;
  await render();
}
const navigationPermissions = {
  products:['productos.ver'], 'product-images':['productos.ver','productos.editar'],
  categories:['categorias.ver'], brands:['marcas.ver'], suppliers:['proveedores.ver'],
  units:['unidades.ver'], offers:['productos.ver'], ecommerce:['productos.ver'],
  'ecommerce-orders':['reservas.ver'], 'ecommerce-invoices':['reportes.ver'],
  inventory:['existencias.ver'], inbound:['entradas.ver'], transfers:['transferencias.ver'],
  counts:['conteos.ver'], adjustments:['existencias.ajustar'], kardex:['movimientos.ver'],
  replenishment:['existencias.ver'], 'purchase-orders':['compras.ver'],
  valuation:['valoracion.ver'], reservations:['reservas.ver'], returns:['salidas.ver'],
  outbound:['salidas.ver'], labels:['productos.ver'], 'stock-alerts':['alertas.ver'],
  reports:['reportes.ver'], 'data-tools':['productos.importar','productos.exportar'],
  movements:['movimientos.ver'], locations:['ubicaciones.ver'], users:['usuarios.ver'],
  audit:['auditoria.ver'], settings:['configuracion.ver']
};
const createPermissions = {
  products:'productos.crear', categories:'categorias.crear', brands:'marcas.crear',
  suppliers:'proveedores.crear', units:'unidades.crear', offers:'productos.editar',
  inventory:'existencias.ajustar', inbound:'entradas.crear',
  transfers:'transferencias.crear', counts:'conteos.crear',
  adjustments:'existencias.ajustar', 'purchase-orders':'compras.crear',
  returns:'salidas.crear', locations:'ubicaciones.crear'
};
function updateNavigationPermissions() {
  document.querySelectorAll('#navigation [data-page]').forEach(button => {
    const required = navigationPermissions[button.dataset.page];
    const permitted = !required || (button.dataset.page === 'product-images'
      ? required.every(code => state.permissions.has(code))
      : required.some(code => state.permissions.has(code)));
    button.classList.toggle('hidden', !permitted);
  });
  if (state.page !== 'dashboard' &&
      document.querySelector(`#navigation [data-page="${state.page}"]`)?.classList.contains('hidden')) {
    state.page = 'dashboard';
  }
}
async function verifyCurrentAccess() {
  if (!state.profile) return;
  const [{data:active,error},{data:profile,error:profileError}] = await Promise.all([
    db.rpc('erp_usuario_activo'),
    db.from('perfiles').select('rol_id,roles(nombre,codigo)').eq('id',state.profile.id).maybeSingle()
  ]);
  if (error || profileError) { toast(error?.message || profileError?.message, true); return; }
  if (active !== true || !profile?.rol_id) {
    state.profile = null;
    state.permissions = new Set();
    await db.auth.signOut();
    $('#app-view').classList.add('hidden');
    $('#auth-view').classList.remove('hidden');
    toast('Tu perfil ya no tiene acceso activo.', true);
    return;
  }
  const permissionsResult = await db.rpc('erp_mis_permisos');
  if (permissionsResult.error) { toast(permissionsResult.error.message, true); return; }
  state.profile = {...state.profile,...profile};
  state.permissions = new Set((permissionsResult.data || []).map(row => row.codigo));
  const previousPage = state.page;
  updateNavigationPermissions();
  if (state.page !== previousPage) await render();
}
document.addEventListener('visibilitychange', () => {
  if (!document.hidden) void verifyCurrentAccess();
});
async function render() {
  state.renderVersion++;
  const view = captureView();
  const page = state.page;
  $('#page-title').textContent = ({dashboard:'Resumen',products:'Productos','product-images':'Imágenes de productos',categories:'Categorías',brands:'Marcas',suppliers:'Proveedores',units:'Unidades de medida',offers:'Ofertas',ecommerce:'E-commerce','ecommerce-orders':'Pedidos e-commerce',inventory:'Existencias',inbound:'Entradas',transfers:'Transferencias',counts:'Conteos físicos',adjustments:'Ajustes autorizados',kardex:'Kardex',replenishment:'Reabastecimiento','purchase-orders':'Órdenes de compra',valuation:'Valorización',reservations:'Reservas',returns:'Devoluciones',outbound:'Salidas',labels:'Etiquetas físicas','stock-alerts':'Alertas',reports:'Reportes','data-tools':'Importar y exportar',movements:'Movimientos',locations:'Ubicaciones',users:'Usuarios y roles',audit:'Auditoría',settings:'Configuración'})[page];
  $('#crumb').textContent = ['products','product-images','categories','brands','suppliers','units','offers','ecommerce'].includes(page) ? 'CATÁLOGO' : ['ecommerce-orders','inventory','inbound','transfers','counts','adjustments','kardex','replenishment','purchase-orders','valuation','reservations','returns','outbound','labels','stock-alerts','reports','data-tools','movements','locations'].includes(page) ? 'OPERACIÓN' : 'SISTEMA';
  $('#new-button').textContent = ({products:'+ Nuevo producto',categories:'+ Nueva categoría',brands:'+ Nueva marca',suppliers:'+ Nuevo proveedor',units:'+ Nueva unidad',offers:'+ Nueva oferta',inventory:'+ Solicitar ajuste',inbound:'+ Registrar entrada',transfers:'+ Nueva transferencia',counts:'+ Nuevo conteo',adjustments:'+ Solicitar ajuste','purchase-orders':'+ Nueva orden',returns:'+ Registrar devolución',locations:'+ Nueva ubicación'})[page] || '+ Nuevo';
  $('#new-button').style.visibility = ['products','categories','brands','suppliers','units','offers','inventory','inbound','transfers','counts','adjustments','purchase-orders','returns','locations'].includes(page) ? 'visible' : 'hidden';
  if (createPermissions[page] && !state.permissions.has(createPermissions[page])) {
    $('#new-button').style.visibility = 'hidden';
  }
  $('#content').innerHTML = '<div class="panel"><p class="muted">Cargando información…</p></div>';
  try { if (page === 'dashboard') await dashboard(); else if (page === 'products') await products(); else if (page === 'product-images') await productImages(); else if (page === 'offers') await offers(); else if (page === 'ecommerce') await ecommerceProducts(); else if (page === 'ecommerce-orders') await ecommerceOrders(); else if (page === 'suppliers') await suppliers(); else if (page === 'categories' || page === 'brands' || page === 'units' || page === 'locations') await simpleList(page); else if (page === 'inventory') await inventory(); else if (page === 'inbound') await inbound(); else if (page === 'transfers') await transfers(); else if (page === 'counts') await counts(); else if (page === 'adjustments') await adjustments(); else if (page === 'kardex') await kardex(); else if (page === 'replenishment') await replenishment(); else if (page === 'purchase-orders') await purchaseOrders(); else if (page === 'valuation') await valuation(); else if (page === 'reservations') await reservations(); else if (page === 'returns') await returns(); else if (page === 'outbound') await outbound(); else if (page === 'labels') await labels(); else if (page === 'stock-alerts') await stockAlerts(); else if (page === 'reports') await reports(); else if (page === 'data-tools') await dataTools(); else if (page === 'audit') await audit(); else if (page === 'settings') await settings(); else if (page === 'movements') await movements(); else await users(); }
  catch (e) { if (!isCurrentView(view)) return; $('#content').innerHTML = `<div class="panel"><h3>No fue posible cargar este módulo</h3><p class="muted">${esc(e.message)}</p></div>`; }
}
async function dashboard() { const view=captureView();
  const [p,e,m] = await Promise.all([db.from('productos').select('id',{count:'exact',head:true}).eq('activo',true), db.from('existencias').select('stock_disponible,stock_minimo,productos(nombre,sku),ubicaciones(nombre)').eq('activo',true), db.from('movimientos').select('id',{count:'exact',head:true}).gte('fecha_movimiento',new Date(Date.now()-864e5*30).toISOString())]);
  if (p.error) throw p.error; if (e.error) throw e.error;
  const rows=e.data||[], low=rows.filter(x=>Number(x.stock_disponible)<=Number(x.stock_minimo));
  if(!isCurrentView(view))return; $('#content').innerHTML=`<div class="stats"><div class="stat"><p>PRODUCTOS ACTIVOS</p><h3>${p.count||0}</h3><span>En catálogo</span></div><div class="stat"><p>UNIDADES DISPONIBLES</p><h3>${qty(rows.reduce((a,x)=>a+Number(x.stock_disponible||0),0))}</h3><span>En todas las ubicaciones</span></div><div class="stat"><p>POR REABASTECER</p><h3>${low.length}</h3><span class="${low.length?'warn':''}">Revisar niveles mínimos</span></div><div class="stat"><p>MOVIMIENTOS (30 DÍAS)</p><h3>${m.count||0}</h3><span>Actividad registrada</span></div></div><div class="grid-2"><section class="panel"><div class="panel-head"><h3>Productos con stock bajo</h3><button class="link" data-go="inventory">Ver existencias</button></div><div class="low-list">${low.length?low.slice(0,6).map(x=>`<div class="low-item"><div><strong>${esc(x.productos?.nombre||'Producto')}</strong><div class="sub-cell">${esc(x.ubicaciones?.nombre||'Ubicación')} · ${esc(x.productos?.sku||'')}</div></div><span class="badge warn">${qty(x.stock_disponible)} / mín. ${qty(x.stock_minimo)}</span></div>`).join(''):'<p class="muted">Todo el inventario está sobre el mínimo configurado.</p>'}</div></section><section class="panel"><div class="panel-head"><h3>Conexiones</h3></div><div class="low-list"><div class="low-item"><div><strong>POS</strong><div class="sub-cell">Listo para consumir stock central</div></div><span class="badge ok">API</span></div><div class="low-item"><div><strong>E-commerce</strong><div class="sub-cell">Stock disponible y catálogo publicable</div></div><span class="badge ok">API</span></div><div class="low-item"><div><strong>Seguridad</strong><div class="sub-cell">Acceso protegido por RLS y permisos</div></div><span class="badge ok">ACTIVO</span></div></div></section></div>`;
}
function table(headers, body) { return `<div class="table-wrap"><table class="data-table"><thead><tr>${headers.map(x=>`<th>${x}</th>`).join('')}</tr></thead><tbody>${body||'<tr><td colspan="99" class="muted">No hay registros todavía.</td></tr>'}</tbody></table></div>`; }
async function catalogPermission(code) {
  const {data,error}=await db.rpc('tiene_permiso',{p_permiso_codigo:code});
  if(error)throw error;
  return data===true;
}
function offerDisplayState(offer,now=Date.now()) {
  if(!offer.activo)return {label:'INACTIVA',className:'off'};
  if(new Date(offer.fecha_inicio).getTime()>now)return {label:'PROGRAMADA',className:'off'};
  if(offer.fecha_fin&&new Date(offer.fecha_fin).getTime()<now)return {label:'VENCIDA',className:'off'};
  return {label:'ACTIVA',className:'ok'};
}
function catalogPayload(page,form) {
  const get=name=>String(form.get(name)??'').trim();
  const check=name=>form.has(name);
  const nombre=get('nombre');
  if(!nombre)throw new Error('El nombre es obligatorio.');
  if(page==='categories') {
    const slug=get('slug'),orden=get('orden');
    if(!slug)throw new Error('El slug es obligatorio.');
    if(!/^\d+$/.test(orden)||Number(orden)>2147483647)throw new Error('El orden debe ser un entero entre 0 y 2,147,483,647.');
    return {nombre,slug,descripcion:get('descripcion')||null,categoria_padre_id:get('categoria_padre_id')||null,orden:Number(orden),activo:check('activo'),visible_pos:check('visible_pos'),visible_ecommerce:check('visible_ecommerce'),destacada:check('destacada')};
  }
  if(page==='brands') {
    const slug=get('slug'),orden=get('orden');
    if(!slug)throw new Error('El slug es obligatorio.');
    if(!/^\d+$/.test(orden)||Number(orden)>2147483647)throw new Error('El orden debe ser un entero entre 0 y 2,147,483,647.');
    return {nombre,slug,descripcion:get('descripcion')||null,pais_origen:get('pais_origen')||null,orden:Number(orden),activo:check('activo'),destacada:check('destacada')};
  }
  if(page==='units') {
    const abreviatura=get('abreviatura'),tipo=get('tipo'),decimales=get('decimales_permitidos'),factor=get('factor_base');
    if(!abreviatura||!tipo)throw new Error('Abreviatura y tipo son obligatorios.');
    if(!/^\d+$/.test(decimales)||Number(decimales)>6)throw new Error('Los decimales permitidos deben estar entre 0 y 6.');
    if(!/^(?:\d+)(?:\.\d+)?$/.test(factor)||!Number.isFinite(Number(factor))||!(Number(factor)>0))throw new Error('El factor base debe ser mayor que cero.');
    return {nombre,abreviatura,tipo,decimales_permitidos:Number(decimales),factor_base:Number(factor),permite_fraccion:check('permite_fraccion'),activo:check('activo')};
  }
  throw new Error('Catálogo desconocido.');
}
async function openCatalogForm(page,id=null) {
  const config={categories:{table:'categorias',title:'categoría'},brands:{table:'marcas',title:'marca'},units:{table:'unidades_medida',title:'unidad de medida'}}[page];
  if(!config)return;
  const view=captureView();
  try {
    const [recordResult,categories]=await Promise.all([
      id?db.from(config.table).select('*').eq('id',id).single():Promise.resolve({data:null,error:null}),
      page==='categories'?fetchAllRows(()=>db.from('categorias').select('id,nombre,categoria_padre_id,activo',{count:'exact'}).order('id')):Promise.resolve([])
    ]);
    if(recordResult.error)throw recordResult.error;
    if(!isCurrentView(view))return;
    const record=recordResult.data;
    const text=(label,name,required=false)=>`<label>${label}<input name="${name}" value="${esc(record?.[name]??'')}" ${required?'required':''}></label>`;
    const num=(label,name,defaultValue,step,min)=>`<label>${label}<input name="${name}" type="number" value="${esc(record?.[name]??defaultValue)}" min="${min}" step="${step}" required></label>`;
    const checkbox=(label,name,defaultValue)=>`<label><input style="width:auto" type="checkbox" name="${name}" ${record?record[name]?'checked':'':defaultValue?'checked':''}> ${label}</label>`;
    const description=`<label class="wide">Descripción<textarea name="descripcion">${esc(record?.descripcion??'')}</textarea></label>`;
    let fields='';
    if(page==='categories') {
      const excluded=new Set(id?[id]:[]);
      for(let changed=true;changed;){changed=false;for(const category of categories)if(category.categoria_padre_id&&excluded.has(category.categoria_padre_id)&&!excluded.has(category.id)){excluded.add(category.id);changed=true;}}
      const parents=categories.filter(category=>!excluded.has(category.id)&&(category.activo||category.id===record?.categoria_padre_id));
      fields=text('Nombre','nombre',true)+text('Slug','slug',true)+`<label>Categoría padre<select name="categoria_padre_id"><option value="">Ninguna</option>${parents.map(category=>`<option value="${esc(category.id)}" ${record?.categoria_padre_id===category.id?'selected':''}>${esc(category.nombre)}</option>`).join('')}</select></label>`+num('Orden','orden',0,1,0)+description+checkbox('Activa','activo',true)+checkbox('Visible en POS','visible_pos',true)+checkbox('Visible en e-commerce','visible_ecommerce',true)+checkbox('Destacada','destacada',false);
    } else if(page==='brands') {
      fields=text('Nombre','nombre',true)+text('Slug','slug',true)+text('País de origen','pais_origen')+num('Orden','orden',0,1,0)+description+checkbox('Activa','activo',true)+checkbox('Destacada','destacada',false);
    } else {
      fields=text('Nombre','nombre',true)+text('Abreviatura','abreviatura',true)+text('Tipo','tipo',true)+num('Decimales permitidos','decimales_permitidos',0,1,0)+num('Factor base','factor_base',1,'any',0)+checkbox('Permite fracción','permite_fraccion',false)+checkbox('Activa','activo',true);
    }
    $('#modal-title').textContent=id?`Editar ${config.title}`:`Nueva ${config.title}`;
    $('#modal-form').innerHTML=fields+`<div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">${id?'Guardar cambios':'Crear'}</button></div>`;
    $('#modal').showModal();
    $('#modal-form').onsubmit=event=>saveCatalog(event,page,id);
  } catch(error) {if(isCurrentView(view))toast(error.message,true);}
}
async function saveCatalog(event,page,id=null) {
  event.preventDefault();
  let payload;
  try {payload=catalogPayload(page,new FormData(event.target));}
  catch(error){toast(error.message,true);return;}
  const tableName={categories:'categorias',brands:'marcas',units:'unidades_medida'}[page];
  const button=event.submitter,label=button.textContent;
  button.disabled=true;button.textContent='Guardando…';
  try {
    const request=id?db.from(tableName).update(payload,{count:'exact'}).eq('id',id):db.from(tableName).insert(payload);
    const {error,count}=await request;
    if(error)throw error;
    if(id&&count!==1)throw new Error('No se actualizó el registro. Revisa tus permisos y vuelve a intentarlo.');
    $('#modal').close();toast(id?'Catálogo actualizado.':'Catálogo creado.');await render();
  } catch(error) {button.disabled=false;button.textContent=label;toast(error.message,true);}
}
async function products() {
  await renderPagedList({ page:'products', placeholder:'Buscar por nombre, SKU o código',
    query:(search,offset,size) => {
      let query=db.from('productos').select('*,categorias(nombre),marcas(nombre),unidades_medida(abreviatura)',{count:'exact'});
      const filter=searchOr(['nombre','sku','codigo_barras'],search); if(filter)query=query.or(filter);
      return query.order('fecha_creacion',{ascending:false}).order('id').range(offset,offset+size-1);
    },
    onRows:rows=>{state.products=rows;},
    headers:['PRODUCTO','CATEGORÍA','PRECIO BASE','CANALES','ESTADO',''],
    rowHtml:x=>`<tr><td class="name-cell">${esc(x.nombre)}<div class="sub-cell">${esc(x.sku)}${x.codigo_barras?' · '+esc(x.codigo_barras):''}</div></td><td>${esc(x.categorias?.nombre||'—')}</td><td>${money(x.precio_base)}</td><td>${x.disponible_pos?'<span class="badge ok">POS</span> ':''}${x.publicado_ecommerce?'<span class="badge ok">WEB</span>':''}</td><td><span class="badge ${x.activo?'ok':'off'}">${x.activo?'ACTIVO':'INACTIVO'}</span></td><td>${state.permissions.has('productos.editar') ? '<button class="link" data-edit-product="' + x.id + '">Editar</button>' : ''}</td></tr>`
  });
}
async function offers() {
  const view=captureView();
  const canEdit=await catalogPermission('productos.editar');
  if(!isCurrentView(view))return;
  $('#new-button').style.visibility=canEdit?'visible':'hidden';
  await renderPagedList({
    page:'offers',placeholder:'Buscar por nombre de oferta',
    query:(search,offset,size)=>{
      let query=db.from('ofertas_producto').select('*,productos(nombre,sku)',{count:'exact'});
      const filter=searchOr(['nombre'],search);if(filter)query=query.or(filter);
      return query.order('fecha_inicio',{ascending:false}).order('id').range(offset,offset+size-1);
    },
    headers:['PRODUCTO','OFERTA','VIGENCIA','CANALES','ESTADO',...(canEdit?['']:[])],
    rowHtml:offer=>{
      const status=offerDisplayState(offer);
      const start=new Date(offer.fecha_inicio).toLocaleString('es-GT',{dateStyle:'short',timeStyle:'short'});
      const end=offer.fecha_fin?new Date(offer.fecha_fin).toLocaleString('es-GT',{dateStyle:'short',timeStyle:'short'}):'sin fin';
      return `<tr><td class="name-cell">${esc(offer.productos?.nombre||'Producto eliminado')}<div class="sub-cell">${esc(offer.productos?.sku||'')}</div></td><td><strong>${qty(offer.oferta_porcentaje)}%</strong><div class="sub-cell">${esc(offer.nombre)}</div></td><td>${esc(start)} — ${esc(end)}</td><td>${offer.aplica_pos?'<span class="badge ok">POS</span> ':''}${offer.aplica_ecommerce?'<span class="badge ok">WEB</span>':''}</td><td><span class="badge ${status.className}">${status.label}</span></td>${canEdit?`<td><button type="button" class="link" data-edit-offer="${esc(offer.id)}">Editar</button></td>`:''}</tr>`;
    },
    note:'Cada fila corresponde a un producto. Edita una oferta por producto.'
  });
  if(!isCurrentView(view))return;
  if(canEdit){
    $('#content .toolbar').insertAdjacentHTML('beforeend','<button type="button" class="primary" id="inline-new-offer">+ Nueva oferta</button>');
    $('#inline-new-offer').onclick=openOfferCreate;
  }
  $('#content').onclick=event=>{const edit=event.target.closest('[data-edit-offer]');if(edit&&canEdit)openOfferEdit(edit.dataset.editOffer);};
}
async function simpleList(page) {
  const config={categories:{table:'categorias',title:'Categoría',cols:['nombre','slug','activo'],order:'orden',search:['nombre','slug']},brands:{table:'marcas',title:'Marca',cols:['nombre','slug','activo'],order:'orden',search:['nombre','slug']},units:{table:'unidades_medida',title:'Unidad de medida',cols:['nombre','abreviatura','tipo','permite_fraccion','activo'],order:'nombre',search:['nombre','abreviatura','tipo']},locations:{table:'ubicaciones',title:'Ubicación',cols:['nombre','codigo','tipo','activo'],order:'orden',search:['nombre','codigo','tipo']}}[page];
  const view=captureView();
  const permissionPrefix={categories:'categorias',brands:'marcas',units:'unidades'}[page];
  const [canEdit,canCreate]=permissionPrefix?await Promise.all([catalogPermission(`${permissionPrefix}.editar`),catalogPermission(`${permissionPrefix}.crear`)]):[false,true];
  if(!isCurrentView(view))return;
  if(permissionPrefix)$('#new-button').style.visibility=canCreate?'visible':'hidden';
  await renderPagedList({page,placeholder:`Buscar ${config.title.toLowerCase()}…`,
    query:(search,offset,size)=>{let query=db.from(config.table).select('*',{count:'exact'});const filter=searchOr(config.search,search);if(filter)query=query.or(filter);return query.order(config.order).order('id').range(offset,offset+size-1);},
    headers:[...config.cols.map(c=>c.toUpperCase().replaceAll('_',' ')),...(canEdit?['']:[])],
    rowHtml:x=>`<tr>${config.cols.map(c=>`<td class="${c==='nombre'?'name-cell':''}">${c==='activo'?`<span class="badge ${x[c]?'ok':'off'}">${x[c]?'ACTIVO':'INACTIVO'}</span>`:c==='permite_fraccion'?`<span class="badge ${x[c]?'ok':'off'}">${x[c]?'SÍ':'NO'}</span>`:esc(x[c]??'—')}</td>`).join('')}${canEdit?`<td><button type="button" class="link" data-edit-catalog="${esc(x.id)}">Editar</button></td>`:''}</tr>`
  });
  if(!isCurrentView(view))return;
  $('#content').onclick=event=>{const edit=event.target.closest('[data-edit-catalog]');if(edit&&canEdit)openCatalogForm(page,edit.dataset.editCatalog);};
}
async function movements() { const view=captureView();  const {data,error}=await db.from('movimientos').select('*,productos(nombre,sku),ubicaciones(nombre)').order('fecha_movimiento',{ascending:false}).limit(150);if(error)throw error;if(!isCurrentView(view))return; $('#content').innerHTML=`<div class="panel"><div class="panel-head"><h3>Historial de movimientos</h3><span class="muted">Últimos 150 registros</span></div>${table(['FECHA','PRODUCTO','UBICACIÓN','TIPO','CANTIDAD','STOCK FINAL','ORIGEN'],data.map(x=>`<tr><td>${new Date(x.fecha_movimiento).toLocaleString('es-GT',{dateStyle:'short',timeStyle:'short'})}</td><td class="name-cell">${esc(x.productos?.nombre||'—')}<div class="sub-cell">${esc(x.productos?.sku||'')}</div></td><td>${esc(x.ubicaciones?.nombre||'—')}</td><td><span class="badge off">${esc(x.tipo_movimiento)}</span></td><td>${qty(x.cantidad)}</td><td>${qty(x.stock_posterior)}</td><td>${esc(x.origen||'—')}</td></tr>`).join(''))}</div>`; }
function users(){$('#content').innerHTML=`<section class="panel"><h3>Usuarios y roles</h3><p class="muted">La administración de usuarios está protegida por los permisos <code>usuarios.*</code>, <code>roles.*</code> y <code>permisos.*</code> definidos en tu base de datos.</p><p class="muted">Este módulo se conecta a <strong>perfiles</strong>, <strong>roles</strong>, <strong>rol_permisos</strong> y <strong>usuario_permisos</strong>. Para crear cuentas de autenticación se requiere una función segura del servidor; no se expone ese privilegio en el navegador.</p></section>`;}
function filterRows(query){query=query.toLowerCase();document.querySelectorAll('.data-table tbody tr').forEach(row=>row.style.display=row.textContent.toLowerCase().includes(query)?'':'none');}
function field(label,name,type='text',opts={}){return `<label class="${opts.wide?'wide':''}">${label}<${type==='textarea'?'textarea':'input'} name="${name}" ${type==='textarea'?'':'type="'+type+'"'} ${opts.required?'required':''} ${opts.value!==undefined?'value="'+esc(opts.value)+'"':''} ${opts.step?'step="'+opts.step+'"':''}></${type==='textarea'?'textarea':'input'}></label>`;}
function offerDateInput(value){
  if(!value)return '';
  const date=new Date(value),pad=n=>String(n).padStart(2,'0');
  return `${date.getFullYear()}-${pad(date.getMonth()+1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}
function offerFields(offer=null){
  const name=esc(offer?.nombre??''),percentage=esc(offer?.oferta_porcentaje??'');
  return `<label>Nombre de la oferta<input name='nombre' value='${name}' required></label><label>Porcentaje de descuento<input name='oferta_porcentaje' type='number' min='0.01' max='100' step='0.01' value='${percentage}' required></label><label>Inicio<input name='fecha_inicio' type='datetime-local' value='${esc(offerDateInput(offer?.fecha_inicio))}' required></label><label>Fin (opcional)<input name='fecha_fin' type='datetime-local' value='${esc(offerDateInput(offer?.fecha_fin))}'></label><label><input style='width:auto' type='checkbox' name='activo' ${offer&&!offer.activo?'':'checked'}> Activa</label><label><input style='width:auto' type='checkbox' name='aplica_pos' ${offer&&!offer.aplica_pos?'':'checked'}> Aplicar en POS</label><label><input style='width:auto' type='checkbox' name='aplica_ecommerce' ${offer&&!offer.aplica_ecommerce?'':'checked'}> Aplicar en e-commerce</label>`;
}
function offerPayload(form){
  const nombre=String(form.get('nombre')??'').trim(),raw=String(form.get('oferta_porcentaje')??'').trim();
  if(!nombre)throw new Error('El nombre de la oferta es obligatorio.');
  if(!/^(?:\d+)(?:\.\d+)?$/.test(raw)||!(Number(raw)>0&&Number(raw)<=100))throw new Error('El descuento debe ser mayor que 0 y hasta 100.');
  const startText=String(form.get('fecha_inicio')??''),endText=String(form.get('fecha_fin')??'');
  const start=new Date(startText),end=endText?new Date(endText):null;
  if(!startText||!Number.isFinite(start.getTime())||(end&&!Number.isFinite(end.getTime())))throw new Error('Escribe fechas válidas.');
  if(end&&end.getTime()<=start.getTime())throw new Error('El fin debe ser posterior al inicio.');
  const aplica_pos=form.has('aplica_pos'),aplica_ecommerce=form.has('aplica_ecommerce');
  if(!aplica_pos&&!aplica_ecommerce)throw new Error('Selecciona al menos un canal.');
  return {nombre,oferta_porcentaje:Number(raw),fecha_inicio:start.toISOString(),fecha_fin:end?.toISOString()||null,activo:form.has('activo'),aplica_pos,aplica_ecommerce};
}
async function openOfferCreate(){
  const view=captureView();
  try {
    const items=await fetchAllRows(()=>db.from('productos').select('id,nombre,sku',{count:'exact'}).eq('activo',true).eq('descontinuado',false).order('nombre').order('id'));
    if(!isCurrentView(view))return;
    if(!items.length){toast('No hay productos activos disponibles para ofertas.',true);return;}
    $('#modal-title').textContent='Nueva oferta';
    $('#modal-form').innerHTML=`${offerFields()}<div class='wide'><label>Buscar productos<input id='offer-product-filter' type='search' placeholder='Nombre o SKU'></label><div class='panel-head'><strong>Productos incluidos</strong><button type='button' class='link' id='select-all-products'>Seleccionar visibles</button></div><div id='offer-products' style='max-height:220px;overflow:auto;border:1px solid #d8e1df;border-radius:8px;padding:.3rem .7rem'>${items.map(item=>`<label style='display:block;padding:.45rem 0;border-bottom:1px solid #eef2f1;font-weight:500'><input style='width:auto;margin:0 .5rem 0 0' type='checkbox' name='producto_ids' value='${esc(item.id)}'>${esc(item.nombre)} <small class='muted'>${esc(item.sku)}</small></label>`).join('')}</div></div><div class='form-actions'><button type='button' class='secondary' data-close>Cancelar</button><button class='primary'>Crear oferta</button></div>`;
    $('#modal').showModal();
    $('#offer-product-filter').oninput=event=>{
      const query=event.target.value.trim().toLocaleLowerCase('es');
      document.querySelectorAll('#offer-products label').forEach(label=>{label.style.display=label.textContent.toLocaleLowerCase('es').includes(query)?'':'none';});
    };
    $('#select-all-products').onclick=()=>document.querySelectorAll('#offer-products label').forEach(label=>{if(label.style.display!=='none')label.querySelector('input').checked=true;});
    $('#modal-form').onsubmit=event=>saveOffer(event);
  }catch(error){if(isCurrentView(view))toast(error.message,true);}
}
async function openOfferEdit(id){
  const view=captureView();
  try {
    const {data:offer,error}=await db.from('ofertas_producto').select('*,productos(nombre,sku)').eq('id',id).single();
    if(error)throw error;
    if(!isCurrentView(view))return;
    $('#modal-title').textContent='Editar oferta';
    $('#modal-form').innerHTML=`<p class='wide muted'>Producto: ${esc(offer.productos?.nombre||'—')} (${esc(offer.productos?.sku||'')}). Esta edición afecta solo esta fila.</p>${offerFields(offer)}<div class='form-actions'><button type='button' class='secondary' data-close>Cancelar</button><button class='primary'>Guardar cambios</button></div>`;
    $('#modal').showModal();
    $('#modal-form').onsubmit=event=>saveOffer(event,id,offer.producto_id);
  }catch(error){if(isCurrentView(view))toast(error.message,true);}
}
async function ensureOfferDoesNotOverlap(productIds,payload,editingId=null){
  if(!payload.activo||!payload.aplica_ecommerce)return;
  const startsAt=new Date(payload.fecha_inicio).getTime();
  const endsAt=payload.fecha_fin?new Date(payload.fecha_fin).getTime():Infinity;
  if(endsAt<Date.now())return;
  for(let i=0;i<productIds.length;i+=100){
    const group=productIds.slice(i,i+100);
    const existing=await fetchAllRows(()=>db.from('ofertas_producto').select('id,producto_id,fecha_inicio,fecha_fin,productos(nombre,sku)',{count:'exact'}).in('producto_id',group).eq('activo',true).eq('aplica_ecommerce',true).order('id'));
    const conflict=existing.find(offer=>{
      if(offer.id===editingId)return false;
      const previousStart=new Date(offer.fecha_inicio).getTime();
      const previousEnd=offer.fecha_fin?new Date(offer.fecha_fin).getTime():Infinity;
      return previousEnd>=Date.now()&&startsAt<=previousEnd&&previousStart<=endsAt;
    });
    if(conflict)throw new Error(`El producto ${conflict.productos?.sku||conflict.producto_id} ya tiene una oferta de e-commerce que coincide en fechas. Ajusta la vigencia o desactiva la otra oferta.`);
  }
}
async function saveOffer(event,editingId=null,productId=null){
  event.preventDefault();
  const form=new FormData(event.target);
  const productIds=editingId?[productId]:[...new Set(form.getAll('producto_ids'))];
  if(!productIds.length||productIds.some(id=>!id)){toast('Selecciona al menos un producto.',true);return;}
  let payload;
  try {payload=offerPayload(form);} catch(error){toast(error.message,true);return;}
  const button=event.submitter,label=button.textContent;
  button.disabled=true;button.textContent=editingId?'Guardando…':'Creando…';
  try {
    await ensureOfferDoesNotOverlap(productIds,payload,editingId);
    const request=editingId?db.from('ofertas_producto').update(payload,{count:'exact'}).eq('id',editingId):db.from('ofertas_producto').insert(productIds.map(producto_id=>({producto_id,...payload})));
    const {error,count}=await request;
    if(error)throw error;
    if(editingId&&count!==1)throw new Error('No se actualizó la oferta. Revisa tus permisos y vuelve a intentarlo.');
    $('#modal').close();
    toast(editingId?'Oferta actualizada.':`Oferta creada para ${productIds.length} producto${productIds.length===1?'':'s'}.`);
    await render();
  }catch(error){button.disabled=false;button.textContent=label;toast(error.message,true);}
}
async function openCreateCore() { const kind=state.page; if(kind==='offers')return openOfferCreate(); if(['categories','brands','units'].includes(kind))return openCatalogForm(kind); if(!['products','categories','brands','units','locations'].includes(kind))return; const forms={products:{title:'Nuevo producto',fields:field('Nombre','nombre','text',{required:true})+field('Nombre corto','nombre_corto')+field('SKU','sku','text',{required:true})+field('Código interno','codigo_interno')+field('Código de barras','codigo_barras')+field('Precio base','precio_base','number',{required:true,step:'0.01'})+`<label>Categoría principal<select id="parent-category-select"></select></label><label>Subcategoría<select name="categoria_id" required id="category-select"></select><small class="field-help">Si no aplica una subcategoría, se usará la categoría principal.</small></label>`+`<label>Marca<select name="marca_id" id="brand-select"><option value="">Sin marca</option></select></label>`+`<label>Unidad de medida<select name="unidad_medida_id" required id="unit-select"></select></label>`+field('Modelo','modelo')+field('Presentación','presentacion')+`<label>Peso<input name="peso" type="number" min="0" step="any"></label><label>Unidad de peso<input name="unidad_peso" placeholder="Ej. g, kg"></label><div class="wide"><strong>Dimensiones</strong><small class="field-help">Ingresa ancho, alto y profundidad en la misma unidad.</small></div><label>Ancho<input name="ancho" type="number" min="0" step="any"></label><label>Alto<input name="alto" type="number" min="0" step="any"></label><label>Profundidad<input name="profundidad" type="number" min="0" step="any"></label><label>Unidad de dimensiones<input name="unidad_dimensiones" placeholder="Ej. cm, mm, m"></label>`+field('Tamaño','tamano')+field('Material','material')+field('Contenido','contenido')+field('Piezas por paquete','piezas_por_paquete','number',{step:'1'})+`<label class="wide">Imágenes del producto<input type="file" id="product-images" name="product_images" accept="image/*" multiple><small class="field-help">Puedes seleccionar varias imágenes. La primera quedará como imagen principal.</small></label>`+field('Descripción corta','descripcion_corta','textarea',{wide:true})+field('Descripción completa','descripcion_larga','textarea',{wide:true})},categories:{title:'Nueva categoría',fields:field('Nombre','nombre','text',{required:true})+field('Slug','slug','text',{required:true})+field('Descripción','descripcion','textarea',{wide:true})},brands:{title:'Nueva marca',fields:field('Nombre','nombre','text',{required:true})+field('Slug','slug','text',{required:true})+field('Descripción','descripcion','textarea',{wide:true})},units:{title:'Nueva unidad de medida',fields:field('Nombre','nombre','text',{required:true})+field('Abreviatura','abreviatura','text',{required:true})+field('Tipo','tipo','text',{required:true})+field('Decimales permitidos','decimales_permitidos','number',{required:true,value:0,step:'1'})+field('Factor base','factor_base','number',{required:true,value:1,step:'0.01'})+`<label>¿Permite fracción?<select name="permite_fraccion"><option value="false">No</option><option value="true">Sí</option></select></label>`},locations:{title:'Nueva ubicación',fields:field('Nombre','nombre','text',{required:true})+field('Código','codigo','text',{required:true})+field('Tipo','tipo','text',{required:true})+field('Dirección','direccion','textarea',{wide:true})}}[kind]; $('#modal-title').textContent=forms.title; $('#modal-form').innerHTML=forms.fields+`<div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Guardar</button></div>`; if(kind==='products'){const [c,u,b]=await Promise.all([db.from('categorias').select('id,nombre,categoria_padre_id').eq('activo',true).order('nombre'),db.from('unidades_medida').select('id,nombre,abreviatura').eq('activo',true).order('nombre'),db.from('marcas').select('id,nombre').eq('activo',true).order('nombre')]); if(c.error||u.error||b.error){toast('No se pudieron cargar las listas del producto.',true);return}const categories=c.data||[],parents=categories.filter(x=>!x.categoria_padre_id),parentSelect=$('#parent-category-select'),childSelect=$('#category-select');parentSelect.innerHTML=parents.map(x=>`<option value="${x.id}">${esc(x.nombre)}</option>`).join('');const loadSubcategories=()=>{const parentId=parentSelect.value,children=categories.filter(x=>x.categoria_padre_id===parentId);childSelect.innerHTML=`<option value="${parentId}">Sin subcategoría (usar categoría principal)</option>`+children.map(x=>`<option value="${x.id}">${esc(x.nombre)}</option>`).join('');};parentSelect.onchange=loadSubcategories;loadSubcategories();$('#unit-select').innerHTML=u.data.map(x=>`<option value="${x.id}">${esc(x.nombre)} (${esc(x.abreviatura)})</option>`).join('');$('#brand-select').innerHTML='<option value="">Sin marca</option>'+b.data.map(x=>`<option value="${x.id}">${esc(x.nombre)}</option>`).join('');} $('#modal').showModal(); $('#modal-form').onsubmit=e=>save(e,kind); }
async function openProductEdit(id) {
  const { data: product, error } = await db.from('productos').select('*').eq('id', id).single();
  if (error) { toast(error.message, true); return; }
  await openCreate();
  $('#modal-title').textContent = 'Editar producto';
  $('#modal-form').insertAdjacentHTML('afterbegin', `<input type="hidden" name="product_id" value="${product.id}">`);
  const parentSelect=$('#parent-category-select');
  if(parentSelect&&product.categoria_id){
    const {data:category}=await db.from('categorias').select('categoria_padre_id').eq('id',product.categoria_id).maybeSingle();
    parentSelect.value=category?.categoria_padre_id||product.categoria_id;
    parentSelect.dispatchEvent(new Event('change'));
  }
  Object.entries(product).forEach(([name, value]) => {
    const input = $(`#modal-form [name="${name}"]`);
    if (input && value !== null) {
      input.value = name === 'palabras_clave' && Array.isArray(value) ? value.join(', ') : value;
      if (name === 'palabras_clave' && Array.isArray(value)) {
        input.keywordSnapshot = { text: input.value, values: [...value] };
      }
    }
  });
  $('#modal-form .form-actions .primary').textContent = 'Guardar cambios';
}
async function imageRpc(name, args) {
  const {data,error}=await db.rpc(name,args);
  if(error) throw error;
  return data;
}
async function finishProductImageDelete(imageId, prepared=null) {
  const image=prepared||await imageRpc('erp_preparar_borrado_imagen_producto',{p_imagen_id:imageId});
  const {error}=await db.storage.from(image.storage_bucket).remove([image.storage_path]);
  if(error) throw new Error(`No se pudo borrar el archivo: ${error.message}`);
  await imageRpc('erp_confirmar_borrado_imagen_producto',{p_imagen_id:imageId});
}
async function uploadProductImages(productId, files) {
  const result={uploaded:[],failed:[]};
  for(const file of files) {
    const cleanName=(file.name.replace(/[^a-zA-Z0-9._-]/g,'_').slice(0,180)||'imagen');
    const path=`${productId}/${crypto.randomUUID()}-${cleanName}`;
    let imageId=null,uploaded=false;
    try {
      const publicUrl=db.storage.from(PRODUCT_IMAGE_BUCKET).getPublicUrl(path).data.publicUrl;
      imageId=await imageRpc('erp_reservar_imagen_producto',{
        p_producto_id:productId,p_storage_path:path,p_nombre_archivo:file.name.slice(0,255),
        p_mime_type:file.type,p_tamano_bytes:file.size,p_url_publica:publicUrl
      });
      const {error}=await db.storage.from(PRODUCT_IMAGE_BUCKET).upload(path,file,{contentType:file.type,upsert:false});
      if(error) throw error;
      uploaded=true;
      await imageRpc('erp_confirmar_carga_imagen_producto',{p_imagen_id:imageId});
      result.uploaded.push(file.name);
    } catch(error) {
      let detail=error.message||String(error);
      if(imageId && !uploaded) {
        try { await finishProductImageDelete(imageId); }
        catch(cleanupError) { detail+=`. La limpieza quedó pendiente: ${cleanupError.message}`; }
      } else if(imageId) detail+='; quedó pendiente para completar desde Imágenes de productos';
      result.failed.push({name:file.name,message:detail});
    }
  }
  return result;
}
function imageUploadFeedback(result,productSaved=false) {
  const lead=productSaved?'Producto guardado. ':'';
  if(!result.failed.length) return `${lead}${result.uploaded.length} imagen${result.uploaded.length===1?'':'es'} cargada${result.uploaded.length===1?'':'s'}.`;
  const failures=result.failed.map(x=>`${x.name}: ${x.message}`).join(' · ');
  return `${lead}${result.uploaded.length} cargadas; ${result.failed.length} pendientes/con error. ${failures}`;
}
$('#login-form').onsubmit=async e=>{e.preventDefault();const btn=e.submitter;btn.disabled=true;btn.textContent='Ingresando…';const {data,error}=await db.auth.signInWithPassword({email:$('#email').value,password:$('#password').value});btn.disabled=false;btn.innerHTML='Iniciar sesión <span>→</span>';if(error){toast(error.message,true);return}await enterApp(data.user)};
$('#navigation').onclick=e=>{const b=e.target.closest('[data-page]');if(!b)return;state.page=b.dataset.page;document.querySelectorAll('.nav-link').forEach(x=>x.classList.toggle('active',x===b));$('.sidebar').classList.remove('open');render();};
$('#new-button').onclick=openCreate; $('#refresh').onclick=render; $('#logout').onclick=async()=>{await db.auth.signOut();location.reload()}; $('#mobile-menu').onclick=()=>$('.sidebar').classList.toggle('open'); document.addEventListener('click',e=>{if(e.target.matches('[data-close]'))$('#modal').close();if(e.target.matches('[data-go]')){state.page=e.target.dataset.go;render();}const edit=e.target.closest('[data-edit-product]');if(edit)openProductEdit(edit.dataset.editProduct);});
db.auth.onAuthStateChange((event,session)=>{
  if(event==='PASSWORD_RECOVERY' && session){if(typeof showPasswordSetup==='function')showPasswordSetup();return;}
  if(!session){
    if(typeof showAuthPanel==='function')showAuthPanel('login');
    else {$('#app-view').classList.add('hidden');$('#auth-view').classList.remove('hidden');}
  }
});
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',initialize,{once:true});else initialize();

// Devoluciones: cada registro valida la venta original y reingresa el producto al inventario.
async function returns() { const view=captureView();
  const { data, error } = await db.from('devoluciones_venta').select('*,productos(nombre,sku),ubicaciones(nombre,codigo)').order('fecha_devolucion',{ascending:false}).limit(200);
  if (error) throw error;
  const rows = data || [];
  if(!isCurrentView(view))return; $('#content').innerHTML = `<section class="panel"><div class="panel-head"><div><h3>Devoluciones de venta</h3><p class="muted">El reingreso se permite únicamente contra una venta original y nunca supera lo vendido.</p></div><button class="primary" id="inline-new-return">+ Registrar devolución</button></div><div class="toolbar"><div class="search"><input id="filter" placeholder="Buscar referencia, producto, ubicación o motivo…" /></div><p class="muted">Últimas 200 devoluciones</p></div>${table(['FECHA','CANAL','VENTA ORIGINAL','PRODUCTO','UBICACIÓN','CANTIDAD','MOTIVO'],rows.map(x=>`<tr><td>${new Date(x.fecha_devolucion).toLocaleString('es-GT',{dateStyle:'short',timeStyle:'short'})}</td><td><span class="badge ${x.canal==='POS'?'ok':'off'}">${esc(x.canal)}</span></td><td>${esc(x.referencia_venta)}</td><td class="name-cell">${esc(x.productos?.nombre||'—')}<div class="sub-cell">${esc(x.productos?.sku||'')}</div></td><td>${esc(x.ubicaciones?.nombre||'—')}<div class="sub-cell">${esc(x.ubicaciones?.codigo||'')}</div></td><td><strong>${qty(x.cantidad)}</strong></td><td>${esc(x.motivo)}</td></tr>`).join(''))}</section>`;
  $('#filter').oninput = e => filterRows(e.target.value);
  $('#inline-new-return').onclick = openReturnCreate;
}

async function openReturnCreate() {
  const view=captureView();
  try {
    const [products,locations]=await Promise.all([
      fetchAllRows(()=>db.from('productos').select('id,nombre,sku',{count:'exact'}).eq('activo',true).order('nombre').order('id')),
      fetchAllRows(()=>db.from('ubicaciones').select('id,nombre,codigo',{count:'exact'}).eq('activo',true).eq('permite_inventario',true).order('nombre').order('id'))
    ]);
    if(!isCurrentView(view))return;
    if(!products.length||!locations.length){toast('Necesitas productos y ubicaciones de inventario activas.',true);return;}
    $('#modal-title').textContent='Registrar devolución';
    $('#modal-form').innerHTML=`<label>Canal<select name="canal"><option value="POS">POS</option><option value="ECOMMERCE">E-commerce</option></select></label><label>Referencia de venta original<input name="referencia_venta" required placeholder="Ej. POS-000123 o WEB-000123" /></label><label>Producto<select name="producto_id" required>${products.map(x=>`<option value="${x.id}">${esc(x.nombre)} (${esc(x.sku)})</option>`).join('')}</select></label><label>Ubicación<select name="ubicacion_id" required>${locations.map(x=>`<option value="${x.id}">${esc(x.nombre)} (${esc(x.codigo)})</option>`).join('')}</select></label><label>Cantidad devuelta<input name="cantidad" type="number" min="0.01" step="0.01" required /></label><label>Motivo<input name="motivo" required placeholder="Ej. producto defectuoso" /></label><label class="wide">Observaciones<textarea name="observaciones" rows="3" placeholder="Detalle opcional"></textarea></label><p class="muted wide">La venta debe existir con la misma referencia, producto y ubicación. El sistema impide devolver más unidades de las vendidas.</p><div class="form-actions wide"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Registrar devolución</button></div>`;
    $('#modal').showModal();$('#modal-form').onsubmit=saveReturn;
  }catch(error){if(isCurrentView(view))toast(error.message,true);}
}
async function saveReturn(event) {
  event.preventDefault();
  const button = event.submitter;
  button.disabled = true;
  button.textContent = 'Registrando…';
  const form = new FormData(event.target);
  const { data, error } = await db.rpc('registrar_devolucion_venta', {
    p_canal: form.get('canal'), p_referencia_venta: form.get('referencia_venta').trim(),
    p_producto_id: form.get('producto_id'), p_ubicacion_id: form.get('ubicacion_id'),
    p_cantidad: Number(form.get('cantidad')), p_motivo: form.get('motivo').trim(),
    p_observaciones: form.get('observaciones').trim() || null
  });
  if (error) { button.disabled = false; button.textContent = 'Registrar devolución'; toast(error.message,true); return; }
  $('#modal').close();
  toast(`Devolución registrada. Referencia: ${data?.referencia_devolucion || 'generada'}.`);
  await render();
}

async function outbound() { const view=captureView();
  const salesOrigins = ['POS','ECOMMERCE','E_COMMERCE','E-COMMERCE'];
  const { data, error } = await db.from('movimientos').select('*,productos(nombre,sku),ubicaciones(nombre,codigo)').eq('tipo_movimiento','SALIDA').in('origen',salesOrigins).order('fecha_movimiento',{ascending:false}).limit(200);
  if (error) throw error;
  const rows = data || [];
  const channel = origin => String(origin).toUpperCase() === 'POS' ? 'POS' : 'E-COMMERCE';
  if(!isCurrentView(view))return; $('#content').innerHTML = `<section class="panel"><div class="panel-head"><div><h3>Ventas que descontaron inventario</h3><p class="muted">Cada salida corresponde a producto que salió físicamente por una venta en POS o e-commerce.</p></div><span class="badge off">${rows.length} SALIDAS</span></div><div class="toolbar"><div class="search"><input id="filter" placeholder="Buscar producto, ubicación o referencia…" /></div><p class="muted">Últimos 200 movimientos de venta</p></div>${table(['FECHA','PRODUCTO','UBICACIÓN','CANAL','CANTIDAD','REFERENCIA','STOCK FINAL'],rows.map(x=>`<tr><td>${new Date(x.fecha_movimiento).toLocaleString('es-GT',{dateStyle:'short',timeStyle:'short'})}</td><td class="name-cell">${esc(x.productos?.nombre||'—')}<div class="sub-cell">${esc(x.productos?.sku||'')}</div></td><td>${esc(x.ubicaciones?.nombre||'—')}<div class="sub-cell">${esc(x.ubicaciones?.codigo||'')}</div></td><td><span class="badge ${channel(x.origen)==='POS'?'ok':'off'}">${channel(x.origen)}</span></td><td><strong>${qty(Math.abs(Number(x.cantidad||0)))}</strong></td><td>${esc(x.referencia_numero||x.referencia_tipo||'—')}</td><td>${qty(x.stock_posterior)}</td></tr>`).join(''))}</section>`;
  $('#filter').oninput = e => filterRows(e.target.value);
}

async function inbound() { const view=captureView();
  const { data, error } = await db.from('movimientos').select('*,productos(nombre,sku),ubicaciones(nombre,codigo)').eq('tipo_movimiento','ENTRADA').in('origen',['COMPRA','DEVOLUCION','AJUSTE']).order('fecha_movimiento',{ascending:false}).limit(200);
  if (error) throw error;
  const rows = data || [];
  const labels = { COMPRA:'COMPRA', DEVOLUCION:'DEVOLUCIÓN', AJUSTE:'AJUSTE +' };
  if(!isCurrentView(view))return; $('#content').innerHTML = `<section class="panel"><div class="panel-head"><div><h3>Entradas de inventario</h3><p class="muted">Registra compras, devoluciones y ajustes positivos que aumentan stock.</p></div><button class="primary" id="inline-new-inbound">+ Registrar entrada</button></div><div class="toolbar"><div class="search"><input id="filter" placeholder="Buscar producto, ubicación o referencia…" /></div><p class="muted">Últimas 200 entradas</p></div>${table(['FECHA','PRODUCTO','UBICACIÓN','TIPO','CANTIDAD','REFERENCIA','STOCK FINAL'],rows.map(x=>`<tr><td>${new Date(x.fecha_movimiento).toLocaleString('es-GT',{dateStyle:'short',timeStyle:'short'})}</td><td class="name-cell">${esc(x.productos?.nombre||'—')}<div class="sub-cell">${esc(x.productos?.sku||'')}</div></td><td>${esc(x.ubicaciones?.nombre||'—')}<div class="sub-cell">${esc(x.ubicaciones?.codigo||'')}</div></td><td><span class="badge ok">${labels[x.origen]||esc(x.origen||'ENTRADA')}</span></td><td><strong>${qty(Math.abs(Number(x.cantidad||0)))}</strong></td><td>${esc(x.referencia_numero||x.referencia_tipo||'—')}</td><td>${qty(x.stock_posterior)}</td></tr>`).join(''))}</section>`;
  $('#filter').oninput = e => filterRows(e.target.value);
  $('#inline-new-inbound').onclick = openInboundCreate;
}

async function transfers() { const view=captureView();
  const { data, error } = await db.from('movimientos').select('*,productos(nombre,sku),ubicaciones(nombre,codigo)').eq('origen','TRANSFERENCIA').order('fecha_movimiento',{ascending:false}).limit(200);
  if (error) throw error;
  const rows=data||[];
  if(!isCurrentView(view))return; $('#content').innerHTML=`<section class="panel"><div class="panel-head"><div><h3>Transferencias entre ubicaciones</h3><p class="muted">Cada transferencia genera una salida en origen y una entrada en destino con la misma referencia.</p></div><button class="primary" id="inline-new-transfer">+ Nueva transferencia</button></div><div class="toolbar"><div class="search"><input id="filter" placeholder="Buscar producto, ubicación o referencia…" /></div><p class="muted">Últimos 200 movimientos de transferencia</p></div>${table(['FECHA','REFERENCIA','PRODUCTO','UBICACIÓN','MOVIMIENTO','CANTIDAD','STOCK FINAL'],rows.map(x=>`<tr><td>${new Date(x.fecha_movimiento).toLocaleString('es-GT',{dateStyle:'short',timeStyle:'short'})}</td><td>${esc(x.referencia_numero||'—')}</td><td class="name-cell">${esc(x.productos?.nombre||'—')}<div class="sub-cell">${esc(x.productos?.sku||'')}</div></td><td>${esc(x.ubicaciones?.nombre||'—')}<div class="sub-cell">${esc(x.ubicaciones?.codigo||'')}</div></td><td><span class="badge ${x.tipo_movimiento==='SALIDA'?'off':'ok'}">${esc(x.tipo_movimiento)}</span></td><td><strong>${qty(Math.abs(Number(x.cantidad||0)))}</strong></td><td>${qty(x.stock_posterior)}</td></tr>`).join(''))}</section>`;
  $('#filter').oninput=e=>filterRows(e.target.value);
  $('#inline-new-transfer').onclick=openTransferCreate;
}

async function counts() { const view=captureView();
  const { data, error } = await db.from('conteos_inventario').select('*,productos(nombre,sku),ubicaciones(nombre,codigo)').order('fecha_conteo',{ascending:false}).limit(200);
  if (error) throw error;
  const rows=data||[];
  if(!isCurrentView(view))return; $('#content').innerHTML=`<section class="panel"><div class="panel-head"><div><h3>Conteos físicos e inventario cíclico</h3><p class="muted">Compara el saldo del sistema con lo contado y aplica la diferencia de forma auditable.</p></div><button class="primary" id="inline-new-count">+ Nuevo conteo</button></div><div class="toolbar"><div class="search"><input id="filter" placeholder="Buscar producto, ubicación o referencia…" /></div><p class="muted">Últimos 200 conteos aplicados</p></div>${table(['FECHA','PRODUCTO','UBICACIÓN','SISTEMA','CONTADO','DIFERENCIA','ESTADO'],rows.map(x=>`<tr><td>${new Date(x.fecha_conteo).toLocaleString('es-GT',{dateStyle:'short',timeStyle:'short'})}</td><td class="name-cell">${esc(x.productos?.nombre||'—')}<div class="sub-cell">${esc(x.productos?.sku||'')}</div></td><td>${esc(x.ubicaciones?.nombre||'—')}<div class="sub-cell">${esc(x.ubicaciones?.codigo||'')}</div></td><td>${qty(x.stock_sistema)}</td><td><strong>${qty(x.stock_contado)}</strong></td><td><span class="badge ${Number(x.diferencia)===0?'ok':Number(x.diferencia)>0?'off':'warn'}">${Number(x.diferencia)>0?'+':''}${qty(x.diferencia)}</span></td><td><span class="badge ok">${esc(x.estado)}</span></td></tr>`).join(''))}</section>`;
  $('#filter').oninput=e=>filterRows(e.target.value);$('#inline-new-count').onclick=openCountCreate;
}

async function adjustments() { const view=captureView();
  const {data,error}=await db.from('ajustes_inventario').select('*,productos(nombre,sku),ubicaciones(nombre,codigo)').order('fecha_solicitud',{ascending:false}).limit(200);
  if(error) throw error;
  const rows=data||[];
  if(!isCurrentView(view))return; $('#content').innerHTML=`<section class="panel"><div class="panel-head"><div><h3>Solicitudes de ajuste</h3><p class="muted">Un usuario solicita el ajuste y otro usuario debe aprobarlo o rechazarlo.</p></div><button class="primary" id="inline-new-adjustment">+ Solicitar ajuste</button></div><div class="toolbar"><div class="search"><input id="filter" placeholder="Buscar producto, ubicación o motivo…" /></div><p class="muted">${rows.filter(x=>x.estado==='PENDIENTE').length} pendientes de autorización</p></div>${table(['FECHA','PRODUCTO','UBICACIÓN','TIPO','CANTIDAD','MOTIVO','ESTADO','ACCIÓN'],rows.map(x=>`<tr><td>${new Date(x.fecha_solicitud).toLocaleString('es-GT',{dateStyle:'short',timeStyle:'short'})}</td><td class="name-cell">${esc(x.productos?.nombre||'—')}<div class="sub-cell">${esc(x.productos?.sku||'')}</div></td><td>${esc(x.ubicaciones?.nombre||'—')}<div class="sub-cell">${esc(x.ubicaciones?.codigo||'')}</div></td><td><span class="badge ${x.tipo==='SALIDA'?'off':'ok'}">${esc(x.tipo)}</span></td><td>${qty(x.cantidad)}</td><td>${esc(x.motivo)}</td><td><span class="badge ${x.estado==='PENDIENTE'?'warn':x.estado==='APROBADO'?'ok':'danger-status'}">${esc(x.estado)}</span></td><td>${x.estado==='PENDIENTE'?`<button class="link" data-adjustment-approve="${x.id}">Aprobar</button> <button class="link danger-link" data-adjustment-reject="${x.id}">Rechazar</button>`:'—'}</td></tr>`).join(''))}</section>`;
  $('#filter').oninput=e=>filterRows(e.target.value);$('#inline-new-adjustment').onclick=openAdjustmentRequest;
}

function kardexLocalDate(date) {
  const parts=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Guatemala',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(date);
  const part=name=>parts.find(x=>x.type===name).value;
  return `${part('year')}-${part('month')}-${part('day')}`;
}
function kardexBoundaries(from,to) {
  const valid=value=>/^\d{4}-\d{2}-\d{2}$/.test(value)&&!Number.isNaN(Date.parse(value+'T00:00:00Z'))&&new Date(value+'T00:00:00Z').toISOString().slice(0,10)===value;
  if(!valid(from)||!valid(to)||from>to)throw new Error('Selecciona fechas válidas; Desde no puede superar Hasta.');
  const next=new Date(to+'T00:00:00Z');next.setUTCDate(next.getUTCDate()+1);
  return {from:from+'T00:00:00-06:00',to:next.toISOString().slice(0,10)+'T00:00:00-06:00'};
}
function kardexMovementDelta(row) {
  if(row.tipo_movimiento==='RESERVA')return 0;
  if(row.tipo_movimiento==='ENTRADA')return Math.abs(Number(row.cantidad||0));
  if(row.tipo_movimiento==='SALIDA')return -Math.abs(Number(row.cantidad||0));
  if(row.stock_anterior!=null&&row.stock_posterior!=null)return Number(row.stock_posterior)-Number(row.stock_anterior);
  return Number(row.cantidad||0);
}
async function kardex() {
  const view=captureView();
  const [products,locations]=await Promise.all([
    fetchAllRows(()=>db.from('productos').select('id,nombre,sku',{count:'exact'}).eq('activo',true).order('nombre').order('id')),
    fetchAllRows(()=>db.from('ubicaciones').select('id,nombre,codigo',{count:'exact'}).eq('activo',true).order('nombre').order('id'))
  ]);
  if(!isCurrentView(view))return;
  const dateFrom=new Date();dateFrom.setDate(dateFrom.getDate()-30);
  $('#content').innerHTML=`<section class="panel"><div class="panel-head"><div><h3>Kardex de inventario</h3><p class="muted">Saldos físicos por producto y ubicación. El resumen incluye todos los movimientos del período.</p></div></div><form id="kardex-filter" class="form-grid"><label>Producto<select name="producto_id" required>${products.map(x=>`<option value="${x.id}">${esc(x.nombre)} (${esc(x.sku)})</option>`).join('')}</select></label><label>Ubicación<select name="ubicacion_id"><option value="">Todas las ubicaciones permitidas</option>${locations.map(x=>`<option value="${x.id}">${esc(x.nombre)} (${esc(x.codigo)})</option>`).join('')}</select></label><label>Desde<input name="fecha_desde" type="date" value="${kardexLocalDate(dateFrom)}" required></label><label>Hasta<input name="fecha_hasta" type="date" value="${kardexLocalDate(new Date())}" required></label><div class="form-actions"><button class="primary" ${products.length?'':'disabled'}>Consultar kardex</button></div></form><div id="kardex-results"><p class="muted">${products.length?'Selecciona los filtros y consulta el Kardex.':'No hay productos activos disponibles.'}</p></div></section>`;
  $('#kardex-filter').onsubmit=queryKardex;
}
let kardexRequest=0;
async function queryKardex(event) {
  event.preventDefault();
  const view=captureView(),request=++kardexRequest,form=new FormData(event.target),productId=form.get('producto_id'),locationId=form.get('ubicacion_id')||null;
  if(!productId){toast('Selecciona un producto.',true);return;}
  let bounds;
  try{bounds=kardexBoundaries(form.get('fecha_desde'),form.get('fecha_hasta'));}catch(error){toast(error.message,true);return;}
  const button=event.submitter;if(button)button.disabled=true;
  $('#kardex-results').innerHTML='<p class="muted" role="status">Consultando saldos y movimientos…</p>';
  try{
    const {data:summary,error}=await db.rpc('erp_resumen_kardex',{p_producto_id:productId,p_ubicacion_id:locationId,p_fecha_desde:bounds.from,p_fecha_hasta:bounds.to});
    if(!isCurrentView(view)||request!==kardexRequest)return;
    if(error)throw error;
    if(!summary)throw new Error('No se recibió el resumen de Kardex.');
    $('#kardex-results').innerHTML=`<div class="stats kardex-stats"><div class="stat"><p>SALDO INICIAL</p><h3>${qty(summary.saldo_inicial)}</h3><span>Stock físico al inicio</span></div><div class="stat"><p>ENTRADAS</p><h3>${qty(summary.entradas)}</h3><span>Período completo</span></div><div class="stat"><p>SALIDAS</p><h3>${qty(summary.salidas)}</h3><span>Período completo</span></div><div class="stat"><p>MOVIMIENTOS</p><h3>${qty(summary.movimientos)}</h3><span>Registros del período</span></div><div class="stat"><p>SALDO FINAL</p><h3>${qty(summary.saldo_final)}</h3><span>Stock físico al finalizar</span></div></div><div class="panel" style="margin-top:1rem"><div id="kardex-detail"></div><div class="panel-head"><button type="button" class="secondary" id="kardex-prev">Anterior</button><span class="muted" id="kardex-page" aria-live="polite"></span><button type="button" class="secondary" id="kardex-next">Siguiente</button></div></div>`;
    let page=0,detailRequest=0;const size=50;
    const loadDetail=async()=>{
      const mine=++detailRequest;
      if(!isCurrentView(view)||request!==kardexRequest)return;
      $('#kardex-prev').disabled=$('#kardex-next').disabled=true;
      $('#kardex-detail').innerHTML='<p class="muted">Cargando movimientos…</p>';
      try{
        const {data,error,count}=await readCompletePage((offset,limit)=>{
          let query=db.from('movimientos').select('*,productos(nombre,sku),ubicaciones(nombre,codigo)',{count:'exact'}).eq('producto_id',productId).gte('fecha_movimiento',bounds.from).lt('fecha_movimiento',bounds.to);
          if(locationId)query=query.eq('ubicacion_id',locationId);
          return query.order('fecha_movimiento').order('id').range(offset,offset+limit-1);
        },page*size,size);
        if(!isCurrentView(view)||request!==kardexRequest||mine!==detailRequest)return;
        if(error)throw error;
        $('#kardex-detail').innerHTML=table(['FECHA','UBICACIÓN','TIPO','ORIGEN','REFERENCIA','ENTRADA','SALIDA','SALDO ANTERIOR','SALDO FINAL','OBSERVACIONES'],(data||[]).map(x=>{const delta=kardexMovementDelta(x);return `<tr><td>${new Date(x.fecha_movimiento).toLocaleString('es-GT',{timeZone:'America/Guatemala',dateStyle:'short',timeStyle:'short'})}</td><td>${esc(x.ubicaciones?.nombre||'—')}<div class="sub-cell">${esc(x.ubicaciones?.codigo||'')}</div></td><td><span class="badge ${delta<0?'off':'ok'}">${esc(x.tipo_movimiento)}</span></td><td>${esc(x.origen||'—')}</td><td>${esc(x.referencia_numero||'—')}</td><td>${delta>0?qty(delta):'—'}</td><td>${delta<0?qty(Math.abs(delta)):'—'}</td><td>${qty(x.stock_anterior)}</td><td><strong>${qty(x.stock_posterior)}</strong></td><td>${esc(x.observaciones||'—')}</td></tr>`;}).join(''));
        $('#kardex-page').textContent=`Página ${page+1} · ${count||0} movimientos`;
        $('#kardex-prev').disabled=page===0;$('#kardex-next').disabled=(page+1)*size>=Number(count||0);
      }catch(error){if(isCurrentView(view)&&request===kardexRequest&&mine===detailRequest){$('#kardex-detail').innerHTML=`<p role="alert">${esc(error.message)}</p><button class="secondary" type="button" id="kardex-retry">Reintentar</button>`;$('#kardex-retry').onclick=loadDetail;}}
    };
    $('#kardex-prev').onclick=()=>{if(page>0){page--;loadDetail();}};$('#kardex-next').onclick=()=>{page++;loadDetail();};
    await loadDetail();
  }catch(error){if(isCurrentView(view)&&request===kardexRequest)$('#kardex-results').innerHTML=`<p role="alert">${esc(error.message)}</p>`;}
  finally{if(button&&isCurrentView(view)&&request===kardexRequest)button.disabled=false;}
}
let replenishmentRows = [];
function replenishmentPriority(row) {
  const available=Number(row.stock_disponible||0),minimum=Number(row.stock_minimo||0);
  if(available<=0)return {label:'URGENTE',style:'danger-status'};
  if(available<=minimum)return {label:'CRÍTICO',style:'warn'};
  return {label:'REORDEN',style:'off'};
}
function renderReplenishment() {
  const supplierId=$('#replenishment-supplier')?.value||'';
  const rows=replenishmentRows.filter(row=>!supplierId||row.productos?.proveedores?.id===supplierId);
  const total=rows.reduce((sum,row)=>sum+Math.max(Number(row.stock_maximo||0)-Number(row.stock_disponible||0),0),0);
  $('#replenishment-results').innerHTML=`<div class="stats kardex-stats"><div class="stat"><p>PRODUCTOS A REABASTECER</p><h3>${rows.length}</h3><span>Según mínimo o reorden</span></div><div class="stat"><p>UNIDADES SUGERIDAS</p><h3>${qty(total)}</h3><span>Para llegar al máximo</span></div></div><div class="panel" style="margin-top:1rem">${table(['PRIORIDAD','PRODUCTO','PROVEEDOR','UBICACIÓN','DISPONIBLE','MÍNIMO','REORDEN','MÁXIMO','SUGERIDO'],rows.map(row=>{const priority=replenishmentPriority(row),suggested=Math.max(Number(row.stock_maximo||0)-Number(row.stock_disponible||0),0);return `<tr><td><span class="badge ${priority.style}">${priority.label}</span></td><td class="name-cell">${esc(row.productos?.nombre||'—')}<div class="sub-cell">${esc(row.productos?.sku||'')}</div></td><td>${esc(row.productos?.proveedores?.nombre||'Sin proveedor')}</td><td>${esc(row.ubicaciones?.nombre||'—')}<div class="sub-cell">${esc(row.ubicaciones?.codigo||'')}</div></td><td><strong>${qty(row.stock_disponible)}</strong></td><td>${qty(row.stock_minimo)}</td><td>${qty(row.punto_reorden)}</td><td>${qty(row.stock_maximo)}</td><td><strong>${qty(suggested)}</strong></td></tr>`}).join(''))}</div>`;
}
async function replenishment() { const view=captureView();
  const {data,error}=await db.from('existencias').select('stock_disponible,stock_minimo,stock_maximo,punto_reorden,productos(nombre,sku,proveedores(id,nombre)),ubicaciones(nombre,codigo)').eq('activo',true).order('stock_disponible');
  if(error)throw error;
  replenishmentRows=(data||[]).filter(row=>{const available=Number(row.stock_disponible||0),minimum=Number(row.stock_minimo||0),maximum=Number(row.stock_maximo||0),reorder=Number(row.punto_reorden||0);return maximum>0&&available<maximum&&available<=(reorder>0?reorder:minimum);});
  const suppliers=[...new Map(replenishmentRows.map(row=>[row.productos?.proveedores?.id,row.productos?.proveedores]).filter(([id])=>id)).values()].sort((a,b)=>a.nombre.localeCompare(b.nombre));
  if(!isCurrentView(view))return; $('#content').innerHTML=`<section class="panel"><div class="panel-head"><div><h3>Sugerencias de reabastecimiento</h3><p class="muted">Se incluyen productos con disponible igual o menor al punto de reorden; si no existe, se utiliza el mínimo. La sugerencia lleva el stock al máximo configurado.</p></div></div><div class="toolbar"><label class="image-product-picker">Filtrar por proveedor<select id="replenishment-supplier"><option value="">Todos los proveedores</option>${suppliers.map(x=>`<option value="${x.id}">${esc(x.nombre)}</option>`).join('')}</select></label><p class="muted">Los productos sin máximo configurado no pueden recibir una sugerencia automática.</p></div><div id="replenishment-results"></div></section>`;
  $('#replenishment-supplier').onchange=renderReplenishment;renderReplenishment();
}

async function purchaseOrders() {
  const view=captureView();
  const createPermission=await db.rpc('tiene_permiso',{p_permiso_codigo:'compras.crear'});
  if(createPermission.error)throw createPermission.error;
  if(!isCurrentView(view))return;
  $('#new-button').style.visibility=createPermission.data===true?'visible':'hidden';
  await renderPagedList({
    page:'purchase-orders',
    placeholder:'Buscar número de orden',
    note:'Confirma la orden y registra cada recepción parcial con su costo real.',
    query:(search,offset,size)=>{
      let query=db.from('ordenes_compra').select('id,numero,estado,fecha_creacion,fecha_esperada,proveedores(nombre),ordenes_compra_detalle(id,cantidad_solicitada,cantidad_recibida)',{count:'exact'});
      if(search)query=query.ilike('numero',`%${search.replace(/[%_]/g,'\\$&')}%`);
      return query.order('fecha_creacion',{ascending:false}).order('id').range(offset,offset+size-1);
    },
    headers:['NÚMERO','PROVEEDOR','CREADA','ENTREGA ESPERADA','PENDIENTE','ESTADO',''],
    rowHtml:order=>{
      const pending=(order.ordenes_compra_detalle||[]).reduce((sum,line)=>sum+Math.max(0,Number(line.cantidad_solicitada)-Number(line.cantidad_recibida)),0);
      return `<tr><td class="name-cell">${esc(order.numero)}</td><td>${esc(order.proveedores?.nombre||'—')}</td><td>${new Date(order.fecha_creacion).toLocaleDateString('es-GT')}</td><td>${order.fecha_esperada?new Date(`${order.fecha_esperada}T00:00:00`).toLocaleDateString('es-GT'):'—'}</td><td>${qty(pending)}</td><td><span class="badge ${order.estado==='BORRADOR'?'off':order.estado==='RECIBIDA'?'ok':'warn'}">${esc(order.estado)}</span></td><td><button type="button" class="link" data-purchase-detail="${esc(order.id)}">Ver / recibir</button></td></tr>`;
    }
  });
}

let reservationRows = [];
function renderReservations() {
  const state=$('#reservation-state-filter')?.value||'';
  const rows=reservationRows.filter(x=>!state||x.estado===state);
  const active=rows.filter(x=>x.estado==='ACTIVA');
  const expiring=active.filter(x=>x.fecha_expiracion&&new Date(x.fecha_expiracion).getTime()<=Date.now()+60*60*1000);
  $('#reservations-results').innerHTML=`<div class="stats kardex-stats"><div class="stat"><p>RESERVAS ACTIVAS</p><h3>${active.length}</h3><span>${qty(active.reduce((sum,x)=>sum+Number(x.cantidad||0),0))} unidades retenidas</span></div><div class="stat"><p>POR EXPIRAR</p><h3>${expiring.length}</h3><span>Dentro de la próxima hora</span></div></div><div class="panel" style="margin-top:1rem">${table(['PRODUCTO','UBICACIÓN','CANTIDAD','ORIGEN','REFERENCIA','RESERVADA','EXPIRACIÓN','ESTADO'],rows.map(x=>`<tr><td class="name-cell">${esc(x.productos?.nombre||'—')}<div class="sub-cell">${esc(x.productos?.sku||'')}</div></td><td>${esc(x.ubicaciones?.nombre||'—')}<div class="sub-cell">${esc(x.ubicaciones?.codigo||'')}</div></td><td><strong>${qty(x.cantidad)}</strong></td><td>${esc(x.origen||'—')}</td><td>${esc(x.referencia_numero||'—')}</td><td>${new Date(x.fecha_reserva).toLocaleString('es-GT',{dateStyle:'short',timeStyle:'short'})}</td><td>${x.fecha_expiracion?new Date(x.fecha_expiracion).toLocaleString('es-GT',{dateStyle:'short',timeStyle:'short'}):'—'}</td><td><span class="badge ${x.estado==='ACTIVA'?'warn':x.estado==='CONSUMIDA'?'ok':'off'}">${esc(x.estado)}</span></td></tr>`).join(''))}</div>`;
}
async function reservations() { const view=captureView();
  const {data,error}=await db.from('reservas').select('*,productos(nombre,sku),ubicaciones(nombre,codigo)').order('fecha_reserva',{ascending:false}).limit(300);
  if(error)throw error;
  reservationRows=data||[];
  if(!isCurrentView(view))return; $('#content').innerHTML=`<section class="panel"><div class="panel-head"><div><h3>Reservas de inventario</h3><p class="muted">Unidades retenidas para pedidos pendientes. Al pagar se consumen; al cancelar o expirar se liberan.</p></div></div><div class="toolbar"><label class="image-product-picker">Estado<select id="reservation-state-filter"><option value="">Todos los estados</option><option value="ACTIVA">Activas</option><option value="CONSUMIDA">Consumidas</option><option value="LIBERADA">Liberadas</option><option value="EXPIRADA">Expiradas</option></select></label><div class="search"><input id="filter" placeholder="Buscar producto, ubicación o referencia…" /></div></div><div id="reservations-results"></div></section>`;
  $('#reservation-state-filter').onchange=renderReservations;renderReservations();$('#filter').oninput=e=>filterRows(e.target.value);
}
async function openPurchaseOrder() {
  const view=captureView();
  let suppliers,products;
  try{
    [suppliers,products]=await Promise.all([
      fetchAllRows(()=>db.from('proveedores').select('id,nombre',{count:'exact'}).eq('activo',true).order('nombre').order('id')),
      fetchAllRows(()=>db.from('productos').select('id,nombre,sku,costo_ultimo',{count:'exact'}).eq('activo',true).eq('es_comprable',true).eq('controla_inventario',true).order('nombre').order('id'))
    ]);
  }catch(error){toast(error.message,true);return;}
  if(!isCurrentView(view))return;
  if(!suppliers.length||!products.length){toast('Necesitas al menos un proveedor y un producto comprable.',true);return;}
  const productOptions=products.map(x=>`<option value="${x.id}" data-cost="${Number(x.costo_ultimo||0)}">${esc(x.nombre)} (${esc(x.sku)})</option>`).join('');
  const line=()=>`<div class="purchase-order-line" data-order-line><label>Producto<select name="producto_id" required>${productOptions}</select></label><label>Cantidad<input name="cantidad" type="number" min="0.01" step="0.01" required></label><label>Costo estimado<input name="precio_estimado" type="number" min="0" step="0.0001" value="${Number(products[0].costo_ultimo||0)}"></label><button type="button" class="link danger-link" data-remove-order-line>Quitar</button></div>`;
  $('#modal-title').textContent='Nueva orden de compra';
  $('#modal-form').innerHTML=`<label>Proveedor<select name="proveedor_id" required>${suppliers.map(x=>`<option value="${x.id}">${esc(x.nombre)}</option>`).join('')}</select></label><label>Entrega esperada<input name="fecha_esperada" type="date"></label><label class="wide">Observaciones<textarea name="observaciones" placeholder="Condiciones, referencia o notas para proveedor"></textarea></label><div class="wide"><div class="panel-head"><label>Artículos</label><button type="button" class="link" id="add-order-line">+ Agregar artículo</button></div><div id="purchase-order-lines">${line()}</div></div><div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Crear orden</button></div>`;
  $('#modal').showModal();$('#add-order-line').onclick=()=>$('#purchase-order-lines').insertAdjacentHTML('beforeend',line());
  $('#purchase-order-lines').onchange=event=>{if(event.target.matches('[name="producto_id"]')){const line=event.target.closest('[data-order-line]');line.querySelector('[name="precio_estimado"]').value=event.target.selectedOptions[0].dataset.cost||0;}};
  $('#modal-form').onsubmit=savePurchaseOrder;
}
async function savePurchaseOrder(event) {
  event.preventDefault();const button=event.submitter,form=new FormData(event.target),items=Array.from(document.querySelectorAll('[data-order-line]')).map(line=>({producto_id:line.querySelector('[name="producto_id"]').value,cantidad:Number(line.querySelector('[name="cantidad"]').value),precio_estimado:line.querySelector('[name="precio_estimado"]').value===''?null:Number(line.querySelector('[name="precio_estimado"]').value)}));
  if(!items.length||items.some(x=>!Number.isFinite(x.cantidad)||!(x.cantidad>0)||x.precio_estimado!==null&&(!Number.isFinite(x.precio_estimado)||x.precio_estimado<0))||new Set(items.map(x=>x.producto_id)).size!==items.length){toast('Revisa cantidades, costos y productos repetidos.',true);return;}
  button.disabled=true;button.textContent='Creando…';
  try{const {data,error}=await db.rpc('crear_orden_compra',{p_proveedor_id:form.get('proveedor_id'),p_fecha_esperada:form.get('fecha_esperada')||null,p_observaciones:form.get('observaciones')||null,p_items:items});if(error)throw error;$('#modal').close();toast(`Orden ${data?.numero||'de compra'} creada como borrador.`);render();}
  catch(error){toast(error.message,true);button.disabled=false;button.textContent='Crear orden';}
}
async function openPurchaseOrderDetail(id) {
  const view=captureView();
  try {
    const [orderResult,lines,receipts,locations,confirmPermission,receivePermission]=await Promise.all([
      db.from('ordenes_compra').select('id,numero,estado,fecha_esperada,observaciones,proveedores(nombre)').eq('id',id).single(),
      fetchAllRows(()=>db.from('ordenes_compra_detalle').select('id,producto_id,cantidad_solicitada,cantidad_recibida,precio_estimado,productos(nombre,sku,costo_ultimo)',{count:'exact'}).eq('orden_compra_id',id).order('id')),
      fetchAllRows(()=>db.from('recepciones_compra').select('id,documento,fecha_recepcion,ubicacion_id,resultado',{count:'exact'}).eq('orden_compra_id',id).order('fecha_recepcion',{ascending:false}).order('id')),
      fetchAllRows(()=>db.from('ubicaciones').select('id,nombre,codigo',{count:'exact'}).eq('activo',true).eq('permite_recepcion',true).eq('permite_inventario',true).order('nombre').order('id')),
      db.rpc('tiene_permiso',{p_permiso_codigo:'compras.confirmar'}),
      db.rpc('tiene_permiso',{p_permiso_codigo:'compras.recibir'})
    ]);
    if(!isCurrentView(view))return;
    for(const result of [orderResult,confirmPermission,receivePermission])if(result.error)throw result.error;
    const order=orderResult.data;
    if(!order)throw new Error('No se encontró la orden de compra.');
    const pending=lines.filter(line=>Number(line.cantidad_solicitada)>Number(line.cantidad_recibida));
    const canConfirm=confirmPermission.data===true&&order.estado==='BORRADOR';
    const canReceive=receivePermission.data===true&&['ENVIADA','PARCIAL'].includes(order.estado)&&pending.length>0;
    const history=receipts.length?table(['DOCUMENTO','FECHA','UBICACIÓN','LÍNEAS'],receipts.map(receipt=>`<tr><td>${esc(receipt.documento)}</td><td>${new Date(receipt.fecha_recepcion).toLocaleString('es-GT')}</td><td>${esc(locations.find(location=>location.id===receipt.ubicacion_id)?.nombre||'Ubicación autorizada')}</td><td>${qty(receipt.resultado?.lineas||0)}</td></tr>`).join('')):'<p class="muted">Aún no hay recepciones registradas.</p>';
    $('#modal-title').textContent=`Orden ${order.numero}`;
    $('#modal-form').innerHTML=`<div class="wide"><p><strong>${esc(order.proveedores?.nombre||'Proveedor')}</strong> · Estado: ${esc(order.estado)}</p>${order.observaciones?`<p class="muted">${esc(order.observaciones)}</p>`:''}<h3>Artículos solicitados</h3>${table(['PRODUCTO','SOLICITADO','RECIBIDO','PENDIENTE','COSTO EST.'],lines.map(line=>`<tr><td>${esc(line.productos?.nombre||line.producto_id)}<div class="sub-cell">${esc(line.productos?.sku||'')}</div></td><td>${qty(line.cantidad_solicitada)}</td><td>${qty(line.cantidad_recibida)}</td><td><strong>${qty(Math.max(0,Number(line.cantidad_solicitada)-Number(line.cantidad_recibida)))}</strong></td><td>${line.precio_estimado==null?'—':money(line.precio_estimado)}</td></tr>`).join(''))}<h3>Recepciones anteriores</h3>${history}</div>${canReceive&&locations.length?`<div class="wide"><h3>Registrar recepción</h3><p class="muted">Ingresa sólo las cantidades entregadas y el costo unitario real. Cada recepción actualiza existencias y promedio en una operación completa.</p></div><input type="hidden" name="recepcion_id" value="${crypto.randomUUID()}"><label>Ubicación<select name="ubicacion_id" required>${locations.map(location=>`<option value="${esc(location.id)}">${esc(location.nombre)} (${esc(location.codigo)})</option>`).join('')}</select></label><label>Documento del proveedor<input name="documento" maxlength="120" required placeholder="Factura o remisión"></label><label class="wide">Observaciones<textarea name="observaciones" maxlength="2000"></textarea></label><div class="wide"><h3>Cantidades recibidas</h3>${pending.map(line=>{const remaining=Number(line.cantidad_solicitada)-Number(line.cantidad_recibida);return `<div class="purchase-order-line" data-reception-line data-detail-id="${esc(line.id)}" data-pending="${remaining}"><strong>${esc(line.productos?.nombre||line.producto_id)}</strong><label>Cantidad (máx. ${qty(remaining)})<input name="cantidad" type="number" min="0" max="${remaining}" step="0.01" value="0" required></label><label>Costo unitario real<input name="costo_unitario" type="number" min="0" step="0.0001" value="${Number(line.precio_estimado??line.productos?.costo_ultimo??0)}" required></label></div>`}).join('')}</div>`:canReceive?'<p class="wide" role="alert">No hay ubicaciones de recepción disponibles para tu usuario.</p>':''}<div class="form-actions"><button type="button" class="secondary" data-close>Cerrar</button>${canConfirm?'<button type="button" class="secondary" id="confirm-purchase-order">Marcar como enviada</button>':''}${canReceive&&locations.length?'<button class="primary">Registrar recepción</button>':''}</div>`;
    $('#modal-form').onsubmit=canReceive&&locations.length?event=>savePurchaseReception(event,order):event=>event.preventDefault();
    if(canConfirm)$('#confirm-purchase-order').onclick=async()=>{const button=$('#confirm-purchase-order');button.disabled=true;try{const result=await db.rpc('erp_confirmar_orden_compra',{p_orden_id:order.id});if(result.error)throw result.error;$('#modal').close();toast('Orden marcada como enviada. Ya puede registrarse la recepción.');render();}catch(error){toast(error.message,true);button.disabled=false;}};
    if(!$('#modal').open)$('#modal').showModal();
  }catch(error){if(isCurrentView(view))toast(error.message,true);}
}

async function savePurchaseReception(event,order) {
  event.preventDefault();
  const button=event.submitter,form=new FormData(event.target);
  const selected=Array.from($('#modal-form').querySelectorAll('[data-reception-line]')).map(line=>({
    detalle_id:line.dataset.detailId,
    cantidad:Number(line.querySelector('[name="cantidad"]').value),
    costo_unitario:Number(line.querySelector('[name="costo_unitario"]').value),
    pendiente:Number(line.dataset.pending)
  }));
  if(selected.some(line=>!Number.isFinite(line.cantidad)||line.cantidad<0||line.cantidad>line.pendiente||!Number.isFinite(line.costo_unitario)||line.costo_unitario<0)){
    toast('Revisa cantidades pendientes y costos unitarios.',true);return;
  }
  const items=selected.filter(line=>line.cantidad>0).map(({detalle_id,cantidad,costo_unitario})=>({detalle_id,cantidad,costo_unitario}));
  if(!items.length){toast('Ingresa al menos una cantidad recibida.',true);return;}
  button.disabled=true;button.textContent='Registrando…';
  try{
    const result=await db.rpc('erp_recibir_orden_compra',{
      p_recepcion_id:form.get('recepcion_id'),p_orden_id:order.id,
      p_ubicacion_id:form.get('ubicacion_id'),p_documento:String(form.get('documento')||'').trim(),
      p_observaciones:String(form.get('observaciones')||'').trim()||null,p_items:items
    });
    if(result.error)throw result.error;
    $('#modal').close();toast(`Recepción registrada. Orden ${result.data?.estado==='RECIBIDA'?'completa':'parcial'}.`);render();
  }catch(error){toast(error.message,true);button.disabled=false;button.textContent='Registrar recepción';}
}
document.addEventListener('click',e=>{const remove=e.target.closest('[data-remove-order-line]');if(remove){const lines=document.querySelectorAll('[data-order-line]');if(lines.length>1)remove.closest('[data-order-line]').remove();else toast('La orden debe incluir al menos un artículo.',true);}const detail=e.target.closest('[data-purchase-detail]');if(detail&&state.page==='purchase-orders')openPurchaseOrderDetail(detail.dataset.purchaseDetail);});
document.querySelector('#new-button').addEventListener('click',()=>{if(state.page==='purchase-orders')openPurchaseOrder();});
async function openAdjustmentRequest() {
  const [productsResult,locationsResult]=await Promise.all([db.from('productos').select('id,nombre,sku').eq('activo',true).eq('controla_inventario',true).order('nombre'),db.from('ubicaciones').select('id,nombre,codigo').eq('activo',true).eq('permite_inventario',true).order('nombre')]);
  if(productsResult.error||locationsResult.error){toast(productsResult.error?.message||locationsResult.error?.message,true);return;}
  const products=productsResult.data||[],locations=locationsResult.data||[];if(!products.length||!locations.length){toast('Necesitas productos inventariables y ubicaciones activas.',true);return;}
  $('#modal-title').textContent='Solicitar ajuste de inventario';
  $('#modal-form').innerHTML=`<label>Producto<select name="producto_id" required>${products.map(x=>`<option value="${x.id}">${esc(x.nombre)} (${esc(x.sku)})</option>`).join('')}</select></label><label>Ubicación<select name="ubicacion_id" required>${locations.map(x=>`<option value="${x.id}">${esc(x.nombre)} (${esc(x.codigo)})</option>`).join('')}</select></label><label>Tipo<select name="tipo" required><option value="ENTRADA">Entrada / aumentar stock</option><option value="SALIDA">Salida / reducir stock</option></select></label><label>Cantidad<input name="cantidad" type="number" min="0.01" step="0.01" required></label><label class="wide">Motivo<input name="motivo" required placeholder="Ej. daño, merma, corrección de registro"></label><label class="wide">Observaciones<textarea name="observaciones" placeholder="Detalle y evidencia del ajuste"></textarea></label><p class="wide muted" style="margin:0;font-size:.76rem">El stock no cambiará hasta que otro usuario autorice esta solicitud.</p><div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Enviar solicitud</button></div>`;
  $('#modal').showModal();$('#modal-form').onsubmit=saveAdjustmentRequest;
}
async function saveAdjustmentRequest(event) {
  event.preventDefault();const button=event.submitter,form=new FormData(event.target),quantity=Number(form.get('cantidad'));
  if(!(quantity>0)){toast('Ingresa una cantidad mayor que cero.',true);return;}button.disabled=true;button.textContent='Enviando…';
  const {error}=await db.rpc('solicitar_ajuste_inventario',{p_producto_id:form.get('producto_id'),p_ubicacion_id:form.get('ubicacion_id'),p_tipo:form.get('tipo'),p_cantidad:quantity,p_motivo:form.get('motivo'),p_observaciones:form.get('observaciones')||null});
  if(error){button.disabled=false;button.textContent='Enviar solicitud';toast(error.message,true);return;}$('#modal').close();toast('Solicitud enviada para autorización.');state.page='adjustments';render();
}
async function processAdjustment(id, approve) {
  const comment=window.prompt(approve?'Comentario de autorización (opcional):':'Motivo de rechazo (opcional):','');
  if(comment===null)return;
  const {data,error}=await db.rpc('autorizar_ajuste_inventario',{p_ajuste_id:id,p_aprobar:approve,p_comentario:comment||null});
  if(error){toast(error.message,true);return;}toast(`Ajuste ${String(data?.estado||'procesado').toLowerCase()}.`);render();
}
document.addEventListener('click',e=>{const approve=e.target.closest('[data-adjustment-approve]'),reject=e.target.closest('[data-adjustment-reject]');if(approve)processAdjustment(approve.dataset.adjustmentApprove,true);if(reject)processAdjustment(reject.dataset.adjustmentReject,false);});
document.querySelector('#new-button').addEventListener('click',()=>{if(state.page==='adjustments')openAdjustmentRequest();});
async function openCountCreate() {
  const {data,error}=await db.from('existencias').select('id,producto_id,ubicacion_id,stock_fisico,productos(nombre,sku),ubicaciones(nombre,codigo)').eq('activo',true).order('stock_fisico');
  if(error){toast(error.message,true);return;}
  const records=data||[];if(!records.length){toast('No hay existencias activas para contar.',true);return;}
  $('#modal-title').textContent='Registrar conteo físico';
  $('#modal-form').innerHTML=`<label class="wide">Producto y ubicación<select name="existencia_id" id="count-existence" required>${records.map(x=>`<option value="${x.id}">${esc(x.productos?.nombre||'Producto')} (${esc(x.productos?.sku||'')}) · ${esc(x.ubicaciones?.nombre||'Ubicación')}</option>`).join('')}</select><small id="system-count-stock" class="field-help"></small></label><label>Stock contado físicamente<input name="stock_contado" type="number" min="0" step="0.01" required></label><label>Observaciones<textarea name="observaciones" placeholder="Motivo de diferencia, responsable o referencia"></textarea></label><p class="wide muted" style="margin:0;font-size:.76rem">Al guardar, se registra el conteo y se ajusta el inventario si hay diferencia. No se aceptan conteos negativos.</p><div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Aplicar conteo</button></div>`;
  const updateSystemStock=()=>{const record=records.find(x=>x.id===$('#count-existence').value);$('#system-count-stock').textContent=`Stock físico registrado en sistema: ${qty(record?.stock_fisico)}.`;};
  $('#count-existence').onchange=updateSystemStock;updateSystemStock();$('#modal').showModal();
  $('#modal-form').onsubmit=event=>saveCount(event,records);
}
async function saveCount(event, records) {
  event.preventDefault();const button=event.submitter,form=new FormData(event.target),record=records.find(x=>x.id===form.get('existencia_id')),counted=Number(form.get('stock_contado'));
  if(!record||counted<0){toast('Ingresa un conteo válido.',true);return;}
  button.disabled=true;button.textContent='Aplicando…';
  const {data,error}=await db.rpc('registrar_conteo_inventario',{p_producto_id:record.producto_id,p_ubicacion_id:record.ubicacion_id,p_stock_contado:counted,p_observaciones:form.get('observaciones')||null});
  if(error){button.disabled=false;button.textContent='Aplicar conteo';toast(error.message,true);return;}
  $('#modal').close();toast(`Conteo aplicado. Diferencia: ${data?.diferencia===undefined?'—':qty(data.diferencia)}.`);render();
}
document.querySelector('#new-button').addEventListener('click',()=>{if(state.page==='counts')openCountCreate();});
async function openTransferCreate() {
  const [productsResult,locationsResult]=await Promise.all([
    db.from('productos').select('id,nombre,sku').eq('activo',true).eq('controla_inventario',true).order('nombre'),
    db.from('ubicaciones').select('id,nombre,codigo').eq('activo',true).eq('permite_transferencia',true).order('nombre')
  ]);
  if(productsResult.error||locationsResult.error){toast(productsResult.error?.message||locationsResult.error?.message,true);return;}
  const products=productsResult.data||[],locations=locationsResult.data||[];
  if(!products.length||locations.length<2){toast('Necesitas un producto inventariable y al menos dos ubicaciones con transferencias habilitadas.',true);return;}
  $('#modal-title').textContent='Nueva transferencia';
  $('#modal-form').innerHTML=`<label>Producto<select name="producto_id" required>${products.map(x=>`<option value="${x.id}">${esc(x.nombre)} (${esc(x.sku)})</option>`).join('')}</select></label><label>Cantidad<input name="cantidad" type="number" min="0.01" step="0.01" required></label><label>Ubicación origen<select name="ubicacion_origen_id" required>${locations.map(x=>`<option value="${x.id}">${esc(x.nombre)} (${esc(x.codigo)})</option>`).join('')}</select></label><label>Ubicación destino<select name="ubicacion_destino_id" required>${locations.map((x,index)=>`<option value="${x.id}" ${index===1?'selected':''}>${esc(x.nombre)} (${esc(x.codigo)})</option>`).join('')}</select></label><label class="wide">Referencia (opcional)<input name="referencia_numero" placeholder="Ej. TRF-001; se genera una si se deja vacío"></label><label class="wide">Observaciones<textarea name="observaciones" placeholder="Motivo o detalle de la transferencia"></textarea></label><p class="wide muted" style="margin:0;font-size:.76rem">La operación es atómica: se descuenta del origen y se agrega al destino, o no se realiza ningún cambio.</p><div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Transferir</button></div>`;
  $('#modal').showModal();$('#modal-form').onsubmit=saveTransfer;
}
async function saveTransfer(event) {
  event.preventDefault();const button=event.submitter,form=new FormData(event.target),quantity=Number(form.get('cantidad'));
  if(!(quantity>0)){toast('Ingresa una cantidad mayor que cero.',true);return;}
  if(form.get('ubicacion_origen_id')===form.get('ubicacion_destino_id')){toast('El origen y destino deben ser distintos.',true);return;}
  button.disabled=true;button.textContent='Transfiriendo…';
  const {data,error}=await db.rpc('erp_transferir_inventario',{p_producto_id:form.get('producto_id'),p_ubicacion_origen_id:form.get('ubicacion_origen_id'),p_ubicacion_destino_id:form.get('ubicacion_destino_id'),p_cantidad:quantity,p_referencia_numero:form.get('referencia_numero')||null,p_observaciones:form.get('observaciones')||null});
  if(error){button.disabled=false;button.textContent='Transferir';toast(error.message,true);return;}
  $('#modal').close();toast(`Transferencia completada${data?.referencia_numero?`: ${data.referencia_numero}`:''}.`);render();
}
document.querySelector('#new-button').addEventListener('click',()=>{if(state.page==='transfers')openTransferCreate();});
async function openInboundCreate() {
  const [productsResult,locationsResult] = await Promise.all([
    db.from('productos').select('id,nombre,sku').eq('activo',true).eq('controla_inventario',true).order('nombre'),
    db.from('ubicaciones').select('id,nombre,codigo').eq('activo',true).eq('permite_recepcion',true).order('nombre')
  ]);
  if (productsResult.error || locationsResult.error) { toast(productsResult.error?.message || locationsResult.error?.message,true); return; }
  const products=productsResult.data||[], locations=locationsResult.data||[];
  if (!products.length || !locations.length) { toast('Necesitas un producto inventariable y una ubicación que permita recepción.',true); return; }
  $('#modal-title').textContent='Registrar entrada';
  $('#modal-form').innerHTML=`<label>Producto<select name="producto_id" required>${products.map(x=>`<option value="${x.id}">${esc(x.nombre)} (${esc(x.sku)})</option>`).join('')}</select></label><label>Ubicación<select name="ubicacion_id" required>${locations.map(x=>`<option value="${x.id}">${esc(x.nombre)} (${esc(x.codigo)})</option>`).join('')}</select></label><label>Tipo de entrada<select name="origen" required><option value="COMPRA">Compra / recepción de proveedor</option><option value="DEVOLUCION">Devolución de cliente</option><option value="AJUSTE">Ajuste positivo</option></select></label><label>Cantidad<input name="cantidad" type="number" min="0.01" step="0.01" required></label><label class="wide">Referencia / documento<input name="referencia_numero" placeholder="Ej. OC-001, factura o devolución"></label><label class="wide">Observaciones<textarea name="observaciones" placeholder="Detalle de la entrada"></textarea></label><div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Registrar entrada</button></div>`;
  $('#modal').showModal();
  $('#modal-form').onsubmit = saveInbound;
}
async function saveInbound(event) {
  event.preventDefault(); const button=event.submitter,form=new FormData(event.target),quantity=Number(form.get('cantidad'));
  if (!(quantity>0)) { toast('Ingresa una cantidad mayor que cero.',true);return; }
  button.disabled=true;button.textContent='Registrando…';
  const { data, error }=await db.rpc('registrar_movimiento_inventario',{p_producto_id:form.get('producto_id'),p_ubicacion_id:form.get('ubicacion_id'),p_cantidad:quantity,p_tipo_movimiento:'ENTRADA',p_origen:form.get('origen'),p_referencia_tipo:'entrada_inventario',p_referencia_numero:form.get('referencia_numero')||null,p_observaciones:form.get('observaciones')||null});
  if(error){button.disabled=false;button.textContent='Registrar entrada';toast(error.message,true);return;}
  $('#modal').close();toast(`Entrada registrada. Disponible: ${qty(data.stock_disponible)}.`);render();
}
document.querySelector('#new-button').addEventListener('click', () => { if (state.page === 'inbound') openInboundCreate(); });

async function openMaxStock(existenciaId, productName) {
  const { data, error } = await db.from('existencias').select('stock_maximo,stock_minimo,stock_disponible,ubicaciones(nombre)').eq('id',existenciaId).single();
  if (error) { toast(error.message, true); return; }
  $('#modal-title').textContent = 'Configurar niveles de stock';
  $('#modal-form').innerHTML = `<p class="wide muted" style="margin:0">${esc(productName)} · ${esc(data.ubicaciones?.nombre||'Ubicación')}<br>Disponible actual: <strong>${qty(data.stock_disponible)}</strong>.</p>${field('Stock mínimo','stock_minimo','number',{required:true,value:data.stock_minimo??0,step:'0.01'})}${field('Stock máximo','stock_maximo','number',{required:true,value:data.stock_maximo??'',step:'0.01'})}<p class="wide muted" style="margin:0;font-size:.76rem">El estado será BAJO cuando el disponible sea igual o menor al mínimo. Las alertas también se activan al 40% o menos del máximo.</p><div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Guardar niveles</button></div>`;
  $('#modal').showModal();
  $('#modal-form').onsubmit = async event => {
    event.preventDefault();
    const button=event.submitter, form=new FormData(event.target), minimum=Number(form.get('stock_minimo')), maximum=Number(form.get('stock_maximo'));
    if (minimum < 0 || !(maximum > 0) || minimum > maximum) { toast('El mínimo debe ser 0 o mayor y no puede superar el máximo.',true); return; }
    button.disabled=true; button.textContent='Guardando…';
    const { error:updateError } = await db.from('existencias').update({stock_minimo:minimum,stock_maximo:maximum}).eq('id',existenciaId);
    if (updateError) { button.disabled=false;button.textContent='Guardar niveles';toast(updateError.message,true);return; }
    $('#modal').close();toast('Stock mínimo y máximo actualizados.');render();
  };
}

let labelProducts = [], labelLocations = [];
async function labels() { const view=captureView();
  const [productsResult, locationsResult] = await Promise.all([
    db.from('productos').select('id,nombre,sku,codigo_barras,codigo_interno,precio_base').eq('activo',true).order('nombre'),
    db.from('ubicaciones').select('id,nombre,codigo').eq('activo',true).order('nombre')
  ]);
  if (productsResult.error || locationsResult.error) throw (productsResult.error || locationsResult.error);
  labelProducts = productsResult.data || []; labelLocations = locationsResult.data || [];
  if(!isCurrentView(view))return; $('#content').innerHTML = `<section class="panel"><div class="panel-head"><div><h3>Generar etiquetas de producto</h3><p class="muted">Incluye identificación del artículo, precio, ubicación, código de barras y QR para impresión física.</p></div></div><form id="labels-form" class="form-grid"><label>Producto<select name="producto_id" required>${labelProducts.map(x=>`<option value="${x.id}">${esc(x.nombre)} · ${esc(x.sku)}</option>`).join('')}</select></label><label>Ubicación<select name="ubicacion_id" required>${labelLocations.map(x=>`<option value="${x.id}">${esc(x.nombre)} (${esc(x.codigo)})</option>`).join('')}</select></label><label>Cantidad de etiquetas<input name="cantidad" type="number" min="1" max="200" value="1" required></label><div class="label-options wide"><strong>Información a incluir</strong><label><input type="checkbox" name="incluir_nombre" checked> Nombre</label><label><input type="checkbox" name="incluir_sku" checked> SKU</label><label><input type="checkbox" name="incluir_barras" checked> Código de barras</label><label><input type="checkbox" name="incluir_interno" checked> Código interno</label><label><input type="checkbox" name="incluir_precio" checked> Precio</label><label><input type="checkbox" name="incluir_ubicacion" checked> Ubicación</label><label><input type="checkbox" name="incluir_qr" checked> QR</label></div><div class="form-actions"><button class="primary">Generar vista previa</button></div></form><div id="label-preview-host"></div></section>`;
  $('#labels-form').onsubmit = generateLabelPreview;
}
function labelOption(form, name) { return form.get(name) === 'on'; }
function generateLabelPreview(event) {
  event.preventDefault();
  const form = new FormData(event.target), product=labelProducts.find(x=>x.id===form.get('producto_id')), location=labelLocations.find(x=>x.id===form.get('ubicacion_id'));
  if (!product || !location) return;
  const options={name:labelOption(form,'incluir_nombre'),sku:labelOption(form,'incluir_sku'),barcode:labelOption(form,'incluir_barras'),internal:labelOption(form,'incluir_interno'),price:labelOption(form,'incluir_precio'),location:labelOption(form,'incluir_ubicacion'),qr:labelOption(form,'incluir_qr')};
  const barcodeValue=product.codigo_barras || product.sku || product.codigo_interno || product.id;
  const qrValue=`SM|${product.id}|${product.sku}|${location.id}`;
  const preview=`<div class="label-preview-card" id="label-preview"><div class="label-copy"><strong>${options.name?esc(product.nombre):''}</strong>${options.sku?`<span>SKU: ${esc(product.sku)}</span>`:''}${options.internal&&product.codigo_interno?`<span>Int.: ${esc(product.codigo_interno)}</span>`:''}${options.price?`<b>${money(product.precio_base)}</b>`:''}${options.location?`<span>Ubicación: ${esc(location.nombre)} (${esc(location.codigo)})</span>`:''}${options.barcode?'<svg id="generated-barcode"></svg>':''}</div>${options.qr?'<div class="qr-zone"><div id="generated-qr"></div></div>':''}</div>`;
  $('#label-preview-host').innerHTML=`<div class="panel label-preview-panel"><div class="panel-head"><div><h3>Vista previa</h3><p class="muted">${Number(form.get('cantidad'))} etiqueta${Number(form.get('cantidad'))===1?'':'s'} lista${Number(form.get('cantidad'))===1?'':'s'} para imprimir.</p></div><button type="button" class="primary" id="print-labels">Imprimir etiquetas</button></div>${preview}</div>`;
  if (options.barcode && window.JsBarcode) window.JsBarcode('#generated-barcode', barcodeValue, {format:'CODE128',displayValue:true,fontSize:11,height:38,margin:2});
  if (options.qr && window.QRCode) new window.QRCode(document.getElementById('generated-qr'), {text:qrValue,width:72,height:72,correctLevel:window.QRCode.CorrectLevel.M});
  $('#print-labels').onclick = () => printLabels(Number(form.get('cantidad')));
}
function printLabels(quantity) {
  const preview=$('#label-preview'); if (!preview) return;
  const popup=window.open('','_blank','width=900,height=700'); if (!popup) { toast('Permite las ventanas emergentes para imprimir.',true); return; }
  const copies=Array.from({length:quantity},()=>`<article class="label">${preview.innerHTML}</article>`).join('');
  popup.document.write(`<!doctype html><html><head><title>Etiquetas</title><style>body{font-family:Arial,sans-serif;margin:12mm;display:flex;gap:4mm;flex-wrap:wrap}.label{width:58mm;height:38mm;border:1px solid #222;padding:3mm;display:flex;justify-content:space-between;box-sizing:border-box;overflow:hidden}.label-copy{display:flex;flex-direction:column;gap:1mm;font-size:8pt;max-width:38mm}.label-copy strong{font-size:10pt}.label-copy b{font-size:11pt}.label svg{width:38mm;height:13mm}.qr-zone{display:grid;place-items:center}.qr-zone img,.qr-zone table{width:18mm!important;height:18mm!important}@media print{body{margin:0}.label{break-inside:avoid}}</style></head><body>${copies}</body></html>`);
  popup.document.close(); popup.focus(); popup.print();
}

async function suppliers() { const view=captureView();
  const { data, error } = await db.from('proveedores').select('*').order('nombre');
  if (error) throw error;
  const rows = data || [];
  if(!isCurrentView(view))return; $('#content').innerHTML = `<div class="toolbar"><div class="search"><input id="filter" placeholder="Buscar proveedor, NIT o contacto…" /></div><p class="muted">${rows.length} proveedores</p></div>${table(['PROVEEDOR','NIT','CONTACTO','TELÉFONO','CORREO','ESTADO',''],rows.map(x=>`<tr><td class="name-cell">${esc(x.nombre)}</td><td>${esc(x.nit||'—')}</td><td>${esc(x.contacto_nombre||'—')}</td><td>${esc(x.telefono||'—')}</td><td>${esc(x.correo||'—')}</td><td><span class="badge ${x.activo?'ok':'off'}">${x.activo?'ACTIVO':'INACTIVO'}</span></td><td><button class="link" data-supplier-history="${x.id}">Historial</button> <button class="link" data-supplier-edit="${x.id}">Editar</button>${x.activo?` <button class="link danger-link" data-supplier-disable="${x.id}">Desactivar</button>`:''}</td></tr>`).join(''))}`;
  $('#filter').oninput = e => filterRows(e.target.value);
}

async function openSupplierEdit(id) {
  const {data:supplier,error}=await db.from('proveedores').select('*').eq('id',id).single();if(error){toast(error.message,true);return;}
  $('#modal-title').textContent='Editar proveedor';
  $('#modal-form').innerHTML=`<input type="hidden" name="id" value="${supplier.id}">${field('Nombre o razón social','nombre','text',{required:true,value:supplier.nombre})}${field('NIT','nit','text',{value:supplier.nit||''})}${field('Nombre de contacto','contacto_nombre','text',{value:supplier.contacto_nombre||''})}${field('Teléfono','telefono','tel',{value:supplier.telefono||''})}${field('Correo electrónico','correo','email',{value:supplier.correo||''})}${field('Dirección','direccion','textarea',{wide:true})}<div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Guardar cambios</button></div>`;
  $('#modal-form [name="direccion"]').value=supplier.direccion||'';$('#modal').showModal();
  $('#modal-form').onsubmit=async event=>{event.preventDefault();const button=event.submitter,form=new FormData(event.target),supplierId=form.get('id');form.delete('id');const body=Object.fromEntries(form);Object.keys(body).forEach(key=>{if(body[key]==='')body[key]=null;});button.disabled=true;button.textContent='Guardando…';const {error:updateError}=await db.from('proveedores').update(body).eq('id',supplierId);if(updateError){button.disabled=false;button.textContent='Guardar cambios';toast(updateError.message,true);return;}$('#modal').close();toast('Proveedor actualizado.');render();};
}
async function showSupplierHistory(id) {
  const [supplierResult,productsResult,ordersResult]=await Promise.all([db.from('proveedores').select('nombre,nit').eq('id',id).single(),db.from('productos').select('nombre,sku,activo').eq('proveedor_id',id).order('nombre'),db.from('ordenes_compra').select('numero,estado,fecha_creacion,fecha_esperada').eq('proveedor_id',id).order('fecha_creacion',{ascending:false}).limit(20)]);
  if(supplierResult.error||productsResult.error||ordersResult.error){toast(supplierResult.error?.message||productsResult.error?.message||ordersResult.error?.message,true);return;}
  const supplier=supplierResult.data,products=productsResult.data||[],orders=ordersResult.data||[];
  $('#modal-title').textContent=`Historial: ${supplier.nombre}`;
  $('#modal-form').innerHTML=`<div class="wide"><p class="muted">NIT: ${esc(supplier.nit||'—')} · ${products.length} producto(s) vinculado(s)</p><h3 style="font:600 1rem Outfit">Productos vinculados</h3>${table(['PRODUCTO','SKU','ESTADO'],products.map(x=>`<tr><td>${esc(x.nombre)}</td><td>${esc(x.sku)}</td><td>${x.activo?'ACTIVO':'INACTIVO'}</td></tr>`).join(''))}<h3 style="font:600 1rem Outfit;margin-top:1rem">Últimas órdenes de compra</h3>${table(['NÚMERO','CREADA','ENTREGA','ESTADO'],orders.map(x=>`<tr><td>${esc(x.numero)}</td><td>${new Date(x.fecha_creacion).toLocaleDateString('es-GT')}</td><td>${x.fecha_esperada||'—'}</td><td>${esc(x.estado)}</td></tr>`).join(''))}</div><div class="form-actions"><button type="button" class="primary" data-close>Cerrar</button></div>`;
  $('#modal').showModal();
}
async function disableSupplier(id) {
  if(!confirm('¿Desactivar este proveedor? Su historial y productos vinculados se conservarán.'))return;
  const {error}=await db.from('proveedores').update({activo:false}).eq('id',id);if(error){toast(error.message,true);return;}toast('Proveedor desactivado.');render();
}
document.addEventListener('click',e=>{const edit=e.target.closest('[data-supplier-edit]'),history=e.target.closest('[data-supplier-history]'),disable=e.target.closest('[data-supplier-disable]');if(edit)openSupplierEdit(edit.dataset.supplierEdit);if(history)showSupplierHistory(history.dataset.supplierHistory);if(disable)disableSupplier(disable.dataset.supplierDisable);});

let alertInventoryRows = [];
function stockAlertState(row) {
  const available = Number(row.stock_disponible || 0);
  const minimum = Number(row.stock_minimo || 0);
  const maximum = Number(row.stock_maximo || 0);
  if (available <= 0) return { label:'SIN STOCK', style:'danger-status' };
  if (available <= minimum || (maximum > 0 && available <= maximum * .4)) return { label:'STOCK BAJO', style:'warn' };
  return { label:'STOCK NORMAL', style:'ok' };
}
function renderStockAlerts() {
  const providerId = $('#alert-provider-filter')?.value || '';
  const rows = alertInventoryRows.filter(row => !providerId || row.productos?.proveedores?.id === providerId);
  const counts = { none:0, low:0, normal:0 };
  rows.forEach(row => { const state=stockAlertState(row).label; if(state==='SIN STOCK')counts.none++; else if(state==='STOCK BAJO')counts.low++; else counts.normal++; });
  $('#stock-alerts-table').innerHTML = `${table(['PRODUCTO','PROVEEDOR','UBICACIÓN','DISPONIBLE','MÍNIMO','MÁXIMO','ESTADO','DISPONIBILIDAD'],rows.map(row=>{const state=stockAlertState(row),available=Number(row.stock_disponible||0)>0;return `<tr><td class="name-cell">${esc(row.productos?.nombre||'—')}<div class="sub-cell">${esc(row.productos?.sku||'')}</div></td><td>${esc(row.productos?.proveedores?.nombre||'Sin proveedor')}</td><td>${esc(row.ubicaciones?.nombre||'—')}</td><td><strong>${qty(row.stock_disponible)}</strong></td><td>${qty(row.stock_minimo)}</td><td>${Number(row.stock_maximo||0)>0?qty(row.stock_maximo):'—'}</td><td><span class="badge ${state.style}">${state.label}</span></td><td><span class="badge ${available?'ok':'danger-status'}">${available?'DISPONIBLE':'NO DISPONIBLE'}</span></td></tr>`}).join(''))}`;
  $('#alert-summary').innerHTML = `<span class="badge danger-status">${counts.none} SIN STOCK</span><span class="badge warn">${counts.low} BAJO</span><span class="badge ok">${counts.normal} NORMAL</span>`;
}
async function stockAlerts() { const view=captureView();
  const { data, error } = await db.from('existencias').select('stock_disponible,stock_minimo,stock_maximo,productos(nombre,sku,proveedores(id,nombre)),ubicaciones(nombre,codigo)').eq('activo',true).order('stock_disponible');
  if (error) throw error;
  alertInventoryRows = data || [];
  const providers = [...new Map(alertInventoryRows.map(row=>[row.productos?.proveedores?.id,row.productos?.proveedores]).filter(([id])=>id)).values()].sort((a,b)=>a.nombre.localeCompare(b.nombre));
  if(!isCurrentView(view))return; $('#content').innerHTML = `<section class="panel"><div class="panel-head"><div><h3>Estado automático de inventario</h3><p class="muted">Sin stock: 0. Stock bajo: igual o menor al mínimo, o al 40% del máximo. Stock normal: por encima de ambos niveles.</p></div><div id="alert-summary" class="alert-summary"></div></div><div class="toolbar"><label class="image-product-picker">Filtrar por proveedor<select id="alert-provider-filter"><option value="">Todos los proveedores</option>${providers.map(p=>`<option value="${p.id}">${esc(p.nombre)}</option>`).join('')}</select></label><div class="search"><input id="filter" placeholder="Buscar producto o ubicación…" /></div></div><div id="stock-alerts-table"></div></section>`;
  $('#alert-provider-filter').onchange = renderStockAlerts;
  renderStockAlerts();
  $('#filter').oninput = e => filterRows(e.target.value);
}
async function openSupplierCreate() {
  $('#modal-title').textContent = 'Nuevo proveedor';
  $('#modal-form').innerHTML = `${field('Nombre o razón social','nombre','text',{required:true})}${field('NIT','nit')}${field('Nombre de contacto','contacto_nombre')}${field('Teléfono','telefono','tel')}${field('Correo electrónico','correo','email')}${field('Dirección','direccion','textarea',{wide:true})}<div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Guardar proveedor</button></div>`;
  $('#modal').showModal();
  $('#modal-form').onsubmit = async e => { e.preventDefault(); const button=e.submitter, body=Object.fromEntries(new FormData(e.target)); Object.keys(body).forEach(key=>{if(body[key]==='')body[key]=null;}); button.disabled=true; button.textContent='Guardando…'; const { error }=await db.from('proveedores').insert({...body,activo:true}); if(error){button.disabled=false;button.textContent='Guardar proveedor';toast(error.message,true);return;} $('#modal').close();toast('Proveedor creado correctamente.');render(); };
}
async function openCreateWithProvider() {
  if (state.page === 'suppliers') return openSupplierCreate();
  await openCreateCore();
  if (state.page !== 'products' || !$('#modal').open || $('#product-provider-select')) return;
  const unit = $('#unit-select'); if (!unit) return;
  unit.closest('label').insertAdjacentHTML('afterend', '<label>Proveedor<select name="proveedor_id" id="product-provider-select"><option value="">Sin proveedor asignado</option></select></label>');
  const { data, error } = await db.from('proveedores').select('id,nombre').eq('activo',true).order('nombre');
  if (error) { toast(`No se pudieron cargar proveedores: ${error.message}`, true); return; }
  $('#product-provider-select').innerHTML = '<option value="">Sin proveedor asignado</option>' + (data || []).map(x=>`<option value="${x.id}">${esc(x.nombre)}</option>`).join('');
};
async function stockAlertsLegacy() {
  const {data,error}=await db.from('existencias').select('*,productos(nombre,sku),ubicaciones(nombre,codigo)').eq('activo',true).gt('stock_maximo',0).order('stock_disponible');
  if(error) throw error;
  const alerts=(data||[]).filter(x=>Number(x.stock_disponible)<=Number(x.stock_maximo)*.4);
  $('#content').innerHTML=`<section class="panel"><div class="panel-head"><div><h3>Productos con nivel bajo</h3><p class="muted">Disponible igual o menor al 40% del stock máximo configurado.</p></div><span class="badge ${alerts.length?'warn':'ok'}">${alerts.length} ALERTA${alerts.length===1?'':'S'}</span></div>${table(['PRODUCTO','UBICACIÓN','DISPONIBLE','MÁXIMO','NIVEL','ACCIÓN'],alerts.map(x=>`<tr><td class="name-cell">${esc(x.productos?.nombre||'—')}<div class="sub-cell">${esc(x.productos?.sku||'')}</div></td><td>${esc(x.ubicaciones?.nombre||'—')}</td><td><strong>${qty(x.stock_disponible)}</strong></td><td>${qty(x.stock_maximo)}</td><td><span class="badge warn">${qty(Number(x.stock_disponible)/Number(x.stock_maximo)*100)}%</span></td><td><button class="link" data-max-stock="${x.id}" data-product-name="${esc(x.productos?.nombre||'Producto')}">Editar máximo</button></td></tr>`).join(''))}</section>`;
}
async function openMaxStockLegacy(id, productName) {
  const {data,error}=await db.from('existencias').select('stock_maximo,stock_disponible,ubicaciones(nombre)').eq('id',id).single();
  if(error){toast(error.message,true);return;}
  $('#modal-title').textContent='Configurar stock máximo';
  $('#modal-form').innerHTML=`<p class="wide muted" style="margin:0">${esc(productName)} · ${esc(data.ubicaciones?.nombre||'Ubicación')}<br>Disponible actual: <strong>${qty(data.stock_disponible)}</strong>. La alerta se activa al 40% o menos.</p>${field('Stock máximo','stock_maximo','number',{required:true,value:data.stock_maximo??'',step:'0.01'})}<div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Guardar máximo</button></div>`;
  $('#modal').showModal();
  $('#modal-form').onsubmit=async e=>{e.preventDefault();const btn=e.submitter,max=Number(new FormData(e.target).get('stock_maximo'));if(!(max>0)){toast('El stock máximo debe ser mayor que cero.',true);return;}btn.disabled=true;btn.textContent='Guardando…';const {error:updateError}=await db.from('existencias').update({stock_maximo:max}).eq('id',id);if(updateError){btn.disabled=false;btn.textContent='Guardar máximo';toast(updateError.message,true);return;}$('#modal').close();toast('Stock máximo actualizado.');render();};
}
document.addEventListener('click',e=>{const button=e.target.closest('[data-max-stock]');if(button)openMaxStock(button.dataset.maxStock,button.dataset.productName);});

// Extiende el producto con datos de presentación y publicación e-commerce.
async function openCreate() {
  await openCreateWithProvider();
  if (state.page !== 'products' || !$('#modal').open || $('#ecommerce-product-fields')) return;
  const price = $('#modal-form [name="precio_base"]');
  if (!price) return;
  price.closest('label').insertAdjacentHTML('afterend', `<div id="ecommerce-product-fields" style="display:contents"><label>Costo último (Q)<input name="costo_ultimo" type="number" min="0" step="any"><small class="field-help">Costo unitario de la última compra. Las recepciones también lo actualizan.</small></label>${field('Color','color')}<label>¿Publicado en e-commerce?<select name="publicado_ecommerce"><option value="false">No</option><option value="true">Sí</option></select></label><label>¿Visible en e-commerce?<select name="visible_ecommerce"><option value="false">No</option><option value="true">Sí</option></select><small class="field-help">Controla si se muestra al público.</small></label></div>`);
  $('#modal-form .form-actions').insertAdjacentHTML('beforebegin', `<div class="wide"><strong>Datos para buscadores</strong></div><label>Slug del producto<input name="slug" maxlength="280" placeholder="cuaderno-cuadriculado"><small class="field-help">Identificador único usado en la URL del producto.</small></label><label>Título SEO<input name="titulo_seo" maxlength="200"></label><label class="wide">Descripción SEO<textarea name="descripcion_seo"></textarea></label><label class="wide">Palabras clave<textarea name="palabras_clave" placeholder="cuaderno, escolar, papelería"></textarea><small class="field-help">Separa las palabras o frases con comas o líneas nuevas.</small></label>`);
};
$('#new-button').onclick = event => state.page === 'returns' ? openReturnCreate() : openCreate(event);

async function ecommerceProducts() {
  const { data, error } = await db.from('productos').select('id,nombre,sku,color,precio_base,publicado_ecommerce,visible_ecommerce,destacado_ecommerce,activo,categorias(nombre)').eq('activo',true).order('nombre');
  if (error) throw error;
  const products = data || [];
  $('#content').innerHTML = `<section class="panel"><div class="panel-head"><div><h3>Catálogo para e-commerce</h3><p class="muted">Marca los productos que deben aparecer como destacados en la tienda.</p></div><span class="badge ok">${products.filter(x=>x.destacado_ecommerce).length} DESTACADOS</span></div><div class="toolbar"><div class="search"><input id="filter" placeholder="Buscar producto…" /></div><p class="muted">${products.length} productos activos</p></div>${table(['PRODUCTO','CATEGORÍA','COLOR','PRECIO','PUBLICADO','VISIBLE','DESTACADO'],products.map(x=>`<tr><td class="name-cell">${esc(x.nombre)}<div class="sub-cell">${esc(x.sku)}</div></td><td>${esc(x.categorias?.nombre||'—')}</td><td>${esc(x.color||'—')}</td><td>${money(x.precio_base)}</td><td><span class="badge ${x.publicado_ecommerce?'ok':'off'}">${x.publicado_ecommerce?'SÍ':'NO'}</span></td><td><span class="badge ${x.visible_ecommerce?'ok':'off'}">${x.visible_ecommerce?'SÍ':'NO'}</span></td><td><label class="toggle-feature"><input type="checkbox" data-feature-product="${x.id}" ${x.destacado_ecommerce?'checked':''}> <span>${x.destacado_ecommerce?'Destacado':'Marcar'}</span></label></td></tr>`).join(''))}</section>`;
  $('#filter').oninput = e => filterRows(e.target.value);
}
document.addEventListener('change', async e => {
  const input = e.target.closest('[data-feature-product]');
  if (!input) return;
  input.disabled = true;
  const { error } = await db.from('productos').update({ destacado_ecommerce: input.checked }).eq('id', input.dataset.featureProduct);
  if (error) { input.checked = !input.checked; toast(error.message, true); }
  else { toast(input.checked ? 'Producto marcado como destacado.' : 'Producto retirado de destacados.'); const text = input.parentElement.querySelector('span'); if (text) text.textContent = input.checked ? 'Destacado' : 'Marcar'; }
  input.disabled = false;
});

async function saveLocation(event) {
  event.preventDefault();
  const submit=event.submitter;
  submit.disabled=true;
  submit.textContent='Guardando…';
  const body=Object.fromEntries(new FormData(event.target));
  for(const key of Object.keys(body)) if(body[key]==='') body[key]=null;
  Object.assign(body,{
    activo:true,permite_inventario:true,permite_venta:false,
    permite_recepcion:true,permite_transferencia:true,orden:0
  });
  const {error}=await db.from('ubicaciones').insert(body);
  if(error){submit.disabled=false;submit.textContent='Guardar';toast(error.message,true);return;}
  $('#modal').close();
  toast('Ubicación creada correctamente.');
  await render();
}

// El guardado del producto conserva explícitamente las opciones del formulario.
async function save(e, kind) {
  if (kind === 'locations') return saveLocation(e);
  if (kind !== 'products') throw new Error('Formulario no admitido.');
  e.preventDefault();
  const submit = e.submitter;
  submit.disabled = true;
  submit.textContent = 'Guardando…';
  const form = new FormData(e.target);
  const productId = form.get('product_id');
  form.delete('product_id');
  const files = Array.from(form.getAll('product_images')).filter(x => x instanceof File && x.size);
  form.delete('product_images');
  const body = Object.fromEntries(form);
  Object.keys(body).forEach(key => { if (body[key] === '') body[key] = null; });
  for (const key of ['slug','titulo_seo','descripcion_seo']) {
    body[key] = String(body[key] ?? '').trim() || null;
  }
  const costText = String(body.costo_ultimo ?? '').trim();
  body.costo_ultimo = costText === '' ? null : Number(costText);
  if (body.costo_ultimo !== null && (!Number.isFinite(body.costo_ultimo) || body.costo_ultimo < 0)) {
    submit.disabled=false;submit.textContent=productId?'Guardar cambios':'Guardar';
    toast('El costo último debe ser un número igual o mayor que cero.',true);return;
  }
  if ((body.slug?.length || 0) > 280 || (body.titulo_seo?.length || 0) > 200) {
    submit.disabled=false;submit.textContent=productId?'Guardar cambios':'Guardar';
    toast('El slug admite hasta 280 caracteres y el título SEO hasta 200.',true);return;
  }
  const keywords = [...new Set(String(body.palabras_clave ?? '').split(/[,\r\n]+/).map(value => value.trim()).filter(Boolean))];
  const keywordInput = e.target.querySelector?.('[name="palabras_clave"]');
  const snapshot = keywordInput?.keywordSnapshot;
  // Conservar frases históricas con comas o líneas si no se editó este campo.
  body.palabras_clave = snapshot && keywordInput.value === snapshot.text
    ? [...snapshot.values] : keywords.length ? keywords : null;
  body.precio_base = Number(body.precio_base);
  body.piezas_por_paquete = body.piezas_por_paquete === null ? null : Number(body.piezas_por_paquete);
  for (const key of ['peso','ancho','alto','profundidad']) {
    body[key]=body[key]==null?null:Number(body[key]);
    if(body[key]!==null&&(!Number.isFinite(body[key])||body[key]<0)){
      submit.disabled=false;submit.textContent='Guardar';toast('El peso y las dimensiones deben ser números iguales o mayores que cero.',true);return;
    }
  }
  ['publicado_ecommerce', 'visible_ecommerce'].forEach(key => { body[key] = body[key] === 'true'; });
  if (!productId) Object.assign(body, { activo:true, es_vendible:true, es_comprable:true, controla_inventario:true, disponible_pos:true, destacado_ecommerce:false });
  const request = productId ? db.from('productos').update(body).eq('id', productId) : db.from('productos').insert(body);
  const { data, error } = await request.select('id').single();
  if (error) {
    submit.disabled = false; submit.textContent = productId ? 'Guardar cambios' : 'Guardar';
    toast(error.code === '23505' && error.message.includes('productos_slug_unique')
      ? 'Este slug ya está usado por otro producto.' : error.message, true);
    return;
  }
  const images=files.length?await uploadProductImages(data.id,files):null;
  $('#modal').close();
  if(images?.failed.length) toast(imageUploadFeedback(images,true),true);
  else toast(images?imageUploadFeedback(images,true):productId?'Producto actualizado correctamente.':'Producto creado correctamente.');
  render();
};

let managedProductImages = [];
let pendingProductImages = [];
async function productImages() {
  const { data, error } = await db.from('productos').select('id,nombre,sku').eq('activo',true).order('nombre');
  if (error) throw error;
  const products = data || [];
  $('#content').innerHTML = `<section class="panel"><div class="panel-head"><div><h3>Administrar imágenes</h3><p class="muted">Define la imagen principal y el orden que usarán POS y e-commerce.</p></div></div><div class="toolbar"><label class="image-product-picker">Producto<select id="image-product-select">${products.map(x=>`<option value="${x.id}">${esc(x.nombre)} (${esc(x.sku)})</option>`).join('')}</select></label></div><div id="product-images-manager">${products.length?'Cargando imágenes…':'<p class="muted">No hay productos activos.</p>'}</div></section>`;
  if (!products.length) return;
  $('#image-product-select').onchange = e => loadProductImages(e.target.value);
  await loadProductImages(products[0].id);
}
async function loadProductImages(productId) {
  const host = $('#product-images-manager'); if (!host) return;
  host.innerHTML = '<p class="muted">Cargando imágenes…</p>';
  const { data, error } = await db.from('producto_imagenes').select('*').eq('producto_id',productId).order('orden');
  if (error) { host.innerHTML=`<p class="muted">${esc(error.message)}</p>`; return; }
  if($('#image-product-select')?.value!==productId) return;
  managedProductImages = (data||[]).filter(image=>image.activo);
  const pendingImages=(data||[]).filter(image=>!image.activo);
  pendingProductImages=pendingImages;
  const cards = managedProductImages.map(image => { const url=image.url_publica || db.storage.from(image.storage_bucket).getPublicUrl(image.storage_path).data.publicUrl; return `<article class="product-image-card" data-image-id="${image.id}"><div class="image-preview"><img src="${esc(url)}" alt="${esc(image.alt_text||image.nombre_archivo||'Imagen de producto')}"></div><div class="image-card-body"><strong>${esc(image.nombre_archivo||'Imagen')}</strong><span class="badge ${image.es_principal?'ok':'off'}">${image.es_principal?'PRINCIPAL':'SECUNDARIA'}</span><label>Posición<input class="image-order" type="number" min="0" step="1" value="${Number(image.orden||0)}" data-image-order="${image.id}"></label><div class="image-actions"><button class="secondary" data-image-first="${image.id}">Primera</button><button class="secondary" data-image-last="${image.id}">Última</button><button class="primary" data-image-primary="${image.id}">Principal</button><button class="link danger-link" data-image-delete="${image.id}">Eliminar</button></div></div></article>`; }).join('');
  const pendingCards=pendingImages.map(image=>`<article class="product-image-card" data-image-id="${image.id}"><div class="image-card-body"><strong>${esc(image.nombre_archivo||'Imagen')}</strong><span class="badge warn">${image.estado_storage==='CARGANDO'?'CARGA PENDIENTE':'BORRADO PENDIENTE'}</span><p class="muted">${image.estado_storage==='CARGANDO'?'Comprueba si el archivo terminó de subir.':'La imagen ya no se muestra; falta limpiar el archivo.'}</p><div class="image-actions">${image.estado_storage==='CARGANDO'?`<button class="secondary" data-image-complete="${image.id}">Completar carga</button><button class="link danger-link" data-image-discard="${image.id}">Descartar</button>`:`<button class="secondary" data-image-retry-delete="${image.id}">Reintentar borrado</button>`}</div></div></article>`).join('');
  host.innerHTML = `<div class="image-upload-bar"><label class="primary upload-label">+ Subir imágenes<input id="more-product-images" type="file" accept="image/*" multiple hidden></label><span class="muted">${managedProductImages.length} imagen${managedProductImages.length===1?'':'es'} · La principal es la portada; el orden organiza la galería.</span></div>${cards ? `<div class="product-images-grid">${cards}</div>` : '<div class="empty"><div>▧</div><h3>Este producto aún no tiene imágenes</h3><p>Sube una o varias imágenes para comenzar.</p></div>'}${pendingCards?`<h3>Operaciones pendientes (${pendingImages.length})</h3><div class="product-images-grid">${pendingCards}</div>`:''}`;
  $('#more-product-images').onchange = e => addProductImages(productId, Array.from(e.target.files));
}
async function addProductImages(productId, files) {
  if(!files.length)return;
  const result=await uploadProductImages(productId,files);
  toast(imageUploadFeedback(result),!!result.failed.length);
  await loadProductImages(productId);
}
function currentImageIds(){return managedProductImages.map(image=>image.id);}
async function organizeProductImages(imageIds,productId,primaryId=null) {
  try {
    await imageRpc('erp_organizar_imagenes_producto',{
      p_producto_id:productId,p_imagen_ids:imageIds,p_principal_id:primaryId
    });
    await loadProductImages(productId);
    return true;
  } catch(error) {
    toast(error.message,true);
    await loadProductImages(productId);
    return false;
  }
}
async function saveProductImageOrder(imageId, order) {
  const position=Number(order),ids=currentImageIds(),index=ids.indexOf(imageId);
  if(!Number.isInteger(position)||position<0) {toast('La posición debe ser un entero igual o mayor que cero.',true);return;}
  if(index<0)return;
  const productId=managedProductImages[index].producto_id;
  ids.splice(index,1);
  ids.splice(Math.min(position,ids.length),0,imageId);
  if(await organizeProductImages(ids,productId))toast('Orden actualizado.');
}
async function moveProductImage(imageId, destination) {
  const ids=currentImageIds(),index=ids.indexOf(imageId);
  if(index<0)return;
  const productId=managedProductImages[index].producto_id;
  ids.splice(index,1);
  if(destination==='first')ids.unshift(imageId);else ids.push(imageId);
  if(await organizeProductImages(ids,productId))toast(destination==='first'?'Imagen movida al primer lugar.':'Imagen movida al último lugar.');
}
async function setProductImagePrimary(imageId) {
  const image=managedProductImages.find(x=>x.id===imageId);
  if(image&&await organizeProductImages(currentImageIds(),image.producto_id,imageId))toast('Imagen principal actualizada.');
}
async function deleteProductImage(imageId,confirmed=false) {
  const image=managedProductImages.find(x=>x.id===imageId)||pendingProductImages.find(x=>x.id===imageId);
  if(!image)return;
  if(!confirmed&&!confirm(`¿Eliminar la imagen “${image.nombre_archivo}”?`))return;
  try {
    await finishProductImageDelete(imageId);
    toast('Imagen eliminada.');
  } catch(error) {
    toast(`La imagen quedó pendiente de limpieza: ${error.message}`,true);
  }
  await loadProductImages(image.producto_id);
}
async function completeProductImage(imageId) {
  const image=pendingProductImages.find(x=>x.id===imageId);
  if(!image)return;
  try { await imageRpc('erp_confirmar_carga_imagen_producto',{p_imagen_id:imageId});toast('Carga completada.'); }
  catch(error){toast(`No se completó “${image.nombre_archivo}”: ${error.message}`,true);}
  await loadProductImages(image.producto_id);
}
document.addEventListener('click', e => {
  const first=e.target.closest('[data-image-first]'),last=e.target.closest('[data-image-last]'),
    primary=e.target.closest('[data-image-primary]'),remove=e.target.closest('[data-image-delete]'),
    complete=e.target.closest('[data-image-complete]'),discard=e.target.closest('[data-image-discard]'),
    retryDelete=e.target.closest('[data-image-retry-delete]');
  if(first)moveProductImage(first.dataset.imageFirst,'first');
  if(last)moveProductImage(last.dataset.imageLast,'last');
  if(primary)setProductImagePrimary(primary.dataset.imagePrimary);
  if(remove)deleteProductImage(remove.dataset.imageDelete);
  if(complete)completeProductImage(complete.dataset.imageComplete);
  if(discard)deleteProductImage(discard.dataset.imageDiscard);
  if(retryDelete)deleteProductImage(retryDelete.dataset.imageRetryDelete,true);
});
document.addEventListener('change', e => { const input=e.target.closest('[data-image-order]'); if(input)saveProductImageOrder(input.dataset.imageOrder,input.value); });

function inventoryStatus(existencia) {
  const available = Number(existencia.stock_disponible || 0);
  const minimum = Number(existencia.stock_minimo || 0);
  const maximum = Number(existencia.stock_maximo || 0);
  if (available <= 0) return { label:'SIN STOCK', style:'danger-status' };
  if (available <= minimum || (maximum > 0 && available <= maximum * .4)) return { label:'BAJO', style:'warn' };
  return { label:'NORMAL', style:'ok' };
}

async function inventory() {
  await renderPagedList({page:'inventory',placeholder:'Buscar producto, SKU o ubicación…',note:'Stock disponible = físico − reservado',
    query:async(search,offset,size)=>{const result=await db.rpc('erp_buscar_existencias',{p_busqueda:search,p_offset:offset,p_limite:size});return {data:result.data?.rows||[],count:result.data?.count||0,error:result.error};},
    headers:['PRODUCTO','UBICACIÓN','FÍSICO','RESERVADO','DISPONIBLE','MÁXIMO','MÍNIMO','NIVEL','ESTADO',''],
    rowHtml:x=>{const max=Number(x.stock_maximo||0),level=max>0?Number(x.stock_disponible||0)/max*100:null,status=inventoryStatus(x);return `<tr><td class="name-cell">${esc(x.productos?.nombre||'—')}<div class="sub-cell">${esc(x.productos?.sku||'')}</div></td><td>${esc(x.ubicaciones?.nombre||'—')}<div class="sub-cell">${esc(x.ubicaciones?.codigo||'')}</div></td><td>${qty(x.stock_fisico)}</td><td>${qty(x.stock_reservado)}</td><td><strong>${qty(x.stock_disponible)}</strong></td><td>${max>0?qty(max):'<span class="muted">Sin definir</span>'}</td><td>${qty(x.stock_minimo)}</td><td>${level===null?'—':qty(level)+'%'}</td><td><span class="badge ${status.style}">${status.label}</span></td><td><button class="link" data-max-stock="${x.id}" data-product-name="${esc(x.productos?.nombre||'Producto')}">Configurar niveles</button></td></tr>`;}
  });
}
