const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync(require('node:path').resolve(__dirname,'../app.js'),'utf8');

function form(values,checked=[],products=[]) {
  const fields=new Map(Object.entries(values));
  return {get:key=>fields.get(key)??null,has:key=>checked.includes(key),getAll:key=>key==='producto_ids'?products:[]};
}
function harness() {
  const elements=new Map(),updates=[],inserts=[],queryLog=[],perms=new Map();
  const rows={
    categorias:[{id:'parent',nombre:'Padre',categoria_padre_id:null,activo:true},{id:'cat-1',nombre:'Actual',slug:'actual',categoria_padre_id:'parent',orden:3,activo:true,visible_pos:true,visible_ecommerce:false,destacada:false},{id:'child',nombre:'Hija',categoria_padre_id:'cat-1',activo:true},{id:'grandchild',nombre:'Nieta',categoria_padre_id:'child',activo:true}],
    marcas:[],unidades_medida:[],productos:[],ofertas_producto:[]
  };
  const getElement=selector=>{
    if(!elements.has(selector))elements.set(selector,{style:{},classList:{add(){},remove(){},toggle(){}},innerHTML:'',textContent:'',disabled:false,onclick:null,onchange:null,addEventListener(){},insertAdjacentHTML(_position,html){this.innerHTML+=html;},showModal(){this.open=true;},close(){this.open=false;}});
    return elements.get(selector);
  };
  const db={
    auth:{onAuthStateChange(){},getSession:async()=>({data:{session:null}})},
    rpc:async(_name,args)=>({data:perms.get(args.p_permiso_codigo)===true,error:null}),
    from(table){
      const q={table,action:'select',filters:[],selected:'*',select(columns){this.selected=columns;return this;},eq(key,value){this.filters.push([key,value]);return this;},in(key,value){this.filters.push([key,value]);return this;},order(){return this;},range(first,last){queryLog.push({table,first,last});return Promise.resolve({data:[],count:0,error:null});},update(payload){this.action='update';this.payload=payload;return this;},insert(payload){this.action='insert';this.payload=payload;return this;},single(){
        if(this.action==='update'){updates.push({table,payload:this.payload,filters:this.filters});return Promise.resolve({data:{id:this.filters.find(x=>x[0]==='id')?.[1]},error:null});}
        if(this.action==='insert'){inserts.push({table,payload:this.payload});return Promise.resolve({data:{id:'new'},error:null});}
        const id=this.filters.find(x=>x[0]==='id')?.[1];
        return Promise.resolve({data:(rows[table]||[]).find(x=>x.id===id)||null,error:null});
      },then(resolve,reject){
        if(this.action==='insert')inserts.push({table,payload:this.payload});
        if(this.action==='update')updates.push({table,payload:this.payload,filters:this.filters});
        return Promise.resolve({data:null,count:this.action==='update'?1:null,error:null}).then(resolve,reject);
      }};
      return q;
    }
  };
  const context=vm.createContext({
    window:{supabase:{createClient:()=>db}},document:{readyState:'loading',querySelector:getElement,querySelectorAll:()=>[],addEventListener(){}},
    location:{hash:''},URLSearchParams,setTimeout(){},Intl,FormData:class{constructor(target){return target.fakeForm;}},console
  });
  vm.runInContext(source,context,{filename:'app.js'});
  const state=vm.runInContext('state',context);
  let listOptions=null,renderCalls=0,offerRows=[];
  context.captureView=()=>({page:state.page,version:state.renderVersion});
  context.isCurrentView=view=>view.page===state.page&&view.version===state.renderVersion;
  context.renderPagedList=async options=>{listOptions=options;};
  context.searchOr=()=>'';
  context.fetchAllRows=async factory=>{
    const query=factory();
    if(query.table==='ofertas_producto')return offerRows;
    return rows[query.table]||[];
  };
  context.render=async()=>{renderCalls++;};
  return {context,state,rows,updates,inserts,queryLog,perms,getElement,get listOptions(){return listOptions;},get renderCalls(){return renderCalls;},set offerRows(value){offerRows=value;}};
}

function productForm(overrides={}) {
  const fields=new Map(Object.entries({nombre:'Cuaderno',sku:'CU-1',precio_base:'15',
    piezas_por_paquete:'',peso:'',ancho:'',alto:'',profundidad:'',
    publicado_ecommerce:'false',visible_ecommerce:'true',costo_ultimo:'',
    slug:'',titulo_seo:'',descripcion_seo:'',palabras_clave:'',...overrides}));
  fields.getAll=()=>[];
  return fields;
}

test('crear producto presenta costo, palabras clave, SEO y slug con límites correctos',async()=>{
  const h=harness();h.state.page='products';
  h.context.openCreateWithProvider=async()=>{h.getElement('#modal').open=true;};
  h.context.document.querySelector=selector=>selector==='#ecommerce-product-fields'?null:h.getElement(selector);
  const priceLabel={innerHTML:'',insertAdjacentHTML(_position,html){this.innerHTML+=html;}};
  h.getElement('#modal-form [name="precio_base"]').closest=()=>priceLabel;
  await h.context.openCreate();
  const html=priceLabel.innerHTML+h.getElement('#modal-form .form-actions').innerHTML;
  for(const name of ['costo_ultimo','palabras_clave','descripcion_seo','titulo_seo','slug'])assert.match(html,new RegExp(`name="${name}"`));
  assert.match(html,/name="costo_ultimo"[^>]*min="0"/);
  assert.match(html,/name="slug"[^>]*maxlength="280"/);
  assert.match(html,/name="titulo_seo"[^>]*maxlength="200"/);
});

test('editar producto precarga el costo y la lista de palabras clave sin perder SEO',async()=>{
  const h=harness();h.context.openCreate=async()=>{};
  h.rows.productos=[{id:'product-1',costo_ultimo:8.125,slug:'cuaderno',titulo_seo:'Cuaderno escolar',
    descripcion_seo:'Descripción',palabras_clave:['cuaderno','útiles escolares']}];
  await h.context.openProductEdit('product-1');
  assert.equal(h.getElement('#modal-form [name="costo_ultimo"]').value,8.125);
  assert.equal(h.getElement('#modal-form [name="palabras_clave"]').value,'cuaderno, útiles escolares');
  assert.equal(h.getElement('#modal-form [name="titulo_seo"]').value,'Cuaderno escolar');
  assert.equal(h.getElement('#modal-form [name="slug"]').value,'cuaderno');
});

test('guardar producto envía costo numérico y palabras clave como array a Supabase',async()=>{
  const h=harness();
  await h.context.save({preventDefault(){},submitter:{},target:{fakeForm:productForm({
    costo_ultimo:'8.125',slug:' cuaderno ',titulo_seo:' Cuaderno escolar ',
    descripcion_seo:' Para el colegio ',palabras_clave:'cuaderno, útiles escolares\ncuaderno, , papelería'
  })}},'products');
  const body=h.inserts[0].payload;
  assert.equal(body.costo_ultimo,8.125);
  assert.deepEqual([...body.palabras_clave],['cuaderno','útiles escolares','papelería']);
  assert.equal(body.slug,'cuaderno');assert.equal(body.titulo_seo,'Cuaderno escolar');
  assert.equal(body.descripcion_seo,'Para el colegio');
});

test('editar otro dato conserva palabras clave históricas con comas, líneas o duplicados',async()=>{
  const h=harness();h.context.openCreate=async()=>{};
  const original=['papel, cartón','escolar\noficina','papel, cartón'];
  h.rows.productos=[{id:'product-1',palabras_clave:original}];
  await h.context.openProductEdit('product-1');
  const input=h.getElement('#modal-form [name="palabras_clave"]');
  const target={fakeForm:productForm({product_id:'product-1',palabras_clave:input.value}),
    querySelector:()=>input};
  await h.context.save({preventDefault(){},submitter:{},target},'products');
  assert.deepEqual([...h.updates[0].payload.palabras_clave],original);
  input.value='nuevo, escolar';target.fakeForm=productForm({product_id:'product-1',palabras_clave:input.value});
  await h.context.save({preventDefault(){},submitter:{},target},'products');
  assert.deepEqual([...h.updates[1].payload.palabras_clave],['nuevo','escolar']);
});

test('los campos opcionales vacíos se guardan como null y el costo cero se conserva',async()=>{
  for(const cost of ['', '0']){
    const h=harness();
    await h.context.save({preventDefault(){},submitter:{},target:{fakeForm:productForm({costo_ultimo:cost,
      product_id:'product-1',slug:'  ',titulo_seo:' ',descripcion_seo:' ',palabras_clave:',\n '
    })}},'products');
    const body=h.updates[0].payload;
    assert.equal(body.costo_ultimo,cost===''?null:0);
    for(const name of ['slug','titulo_seo','descripcion_seo','palabras_clave'])assert.equal(body[name],null);
    assert.deepEqual(h.updates[0].filters,[['id','product-1']]);
  }
});

test('costo inválido y SEO demasiado largo se rechazan antes de escribir',async()=>{
  for(const values of [{costo_ultimo:'-1'},{costo_ultimo:'Infinity'},{costo_ultimo:'texto'},
    {slug:'s'.repeat(281)},{titulo_seo:'t'.repeat(201)}]){
    const h=harness(),submitter={};
    await h.context.save({preventDefault(){},submitter,target:{fakeForm:productForm(values)}},'products');
    assert.equal(h.inserts.length,0);assert.equal(h.updates.length,0);
    assert.equal(submitter.disabled,false);
  }
});

test('el listado de categorías muestra edición sólo con permiso',async()=>{
  const h=harness();h.state.page='categories';
  await h.context.simpleList('categories');
  assert.ok(!h.listOptions.rowHtml(h.rows.categorias[1]).includes('data-edit-catalog'));
  assert.equal(h.getElement('#new-button').style.visibility,'hidden');
  h.perms.set('categorias.editar',true);h.perms.set('categorias.crear',true);
  await h.context.simpleList('categories');
  assert.match(h.listOptions.rowHtml(h.rows.categorias[1]),/data-edit-catalog="cat-1"/);
  assert.equal(h.getElement('#new-button').style.visibility,'visible');
});

test('edición de categoría precarga datos y evita asignar un descendiente como padre',async()=>{
  const h=harness();h.state.page='categories';
  await h.context.openCatalogForm('categories','cat-1');
  const html=h.getElement('#modal-form').innerHTML;
  assert.match(html,/value="Actual"/);
  assert.match(html,/option value="parent" selected/);
  assert.ok(!html.includes('option value="child"'));
  assert.ok(!html.includes('option value="grandchild"'));
  assert.equal(h.getElement('#modal').open,true);
});

test('guardar categoría actualiza sólo campos editables y conserva estado desactivado',async()=>{
  const h=harness();h.state.page='categories';
  const submitter={textContent:'Guardar cambios',disabled:false};
  const fakeForm=form({nombre:'  Papelería  ',slug:'papeleria',descripcion:'Texto',orden:'4',categoria_padre_id:''},['visible_pos']);
  await h.context.saveCatalog({preventDefault(){},target:{fakeForm},submitter},'categories','cat-1');
  assert.equal(h.updates.length,1);
  assert.equal(h.inserts.length,0);
  assert.equal(h.updates[0].table,'categorias');
  assert.equal(h.updates[0].payload.nombre,'Papelería');
  assert.equal(h.updates[0].payload.activo,false);
  assert.equal(h.updates[0].payload.visible_pos,true);
  assert.equal(h.updates[0].payload.categoria_padre_id,null);
  assert.equal(h.renderCalls,1);
});

test('valida unidades y vigencia de ofertas antes de guardar',()=>{
  const h=harness();
  assert.throws(()=>h.context.catalogPayload('units',form({nombre:'Unidad',abreviatura:'UND',tipo:'CANTIDAD',decimales_permitidos:'7',factor_base:'1'},['activo'])),/entre 0 y 6/);
  assert.throws(()=>h.context.catalogPayload('units',form({nombre:'Unidad',abreviatura:'UND',tipo:'CANTIDAD',decimales_permitidos:'0',factor_base:'0'},['activo'])),/mayor que cero/);
  assert.throws(()=>h.context.offerPayload(form({nombre:'Oferta',oferta_porcentaje:'',fecha_inicio:'2030-01-01T10:00',fecha_fin:''},['activo','aplica_ecommerce'])),/descuento/);
  assert.throws(()=>h.context.offerPayload(form({nombre:'Oferta',oferta_porcentaje:'15',fecha_inicio:'2030-01-02T10:00',fecha_fin:'2030-01-01T10:00'},['activo','aplica_ecommerce'])),/posterior/);
  assert.throws(()=>h.context.offerPayload(form({nombre:'Oferta',oferta_porcentaje:'15',fecha_inicio:'2030-01-01T10:00',fecha_fin:''},['activo'])),/al menos un canal/);
});

test('editar oferta afecta una fila; oferta superpuesta bloquea una nueva carga',async()=>{
  const h=harness();h.state.page='offers';
  h.offerRows=[{id:'old',producto_id:'p-1',fecha_inicio:'2030-01-01T00:00:00Z',fecha_fin:'2030-02-01T00:00:00Z',productos:{sku:'SKU-1'}}];
  const submitter={textContent:'Crear oferta',disabled:false};
  const fakeForm=form({nombre:'Nueva',oferta_porcentaje:'10',fecha_inicio:'2030-01-10T10:00',fecha_fin:'2030-01-20T10:00'},['activo','aplica_ecommerce'],['p-1']);
  await h.context.saveOffer({preventDefault(){},target:{fakeForm},submitter});
  assert.equal(h.inserts.length,0);
  assert.match(h.getElement('#toast').textContent,/ya tiene una oferta/);
  const editSubmit={textContent:'Guardar cambios',disabled:false};
  await h.context.saveOffer({preventDefault(){},target:{fakeForm},submitter:editSubmit},'old','p-1');
  assert.equal(h.updates.length,1);
  assert.equal(h.updates[0].table,'ofertas_producto');
  assert.deepEqual(Array.from(h.updates[0].filters[0]),['id','old']);
  assert.equal(h.inserts.length,0);
});

test('ofertas usa lista paginada y acción de editar con permiso',async()=>{
  const h=harness();h.state.page='offers';h.perms.set('productos.editar',true);
  await h.context.offers();
  const html=h.listOptions.rowHtml({id:'offer-1',nombre:'Descuento',oferta_porcentaje:10,fecha_inicio:'2030-01-01T00:00:00Z',fecha_fin:null,activo:true,aplica_pos:true,aplica_ecommerce:true,productos:{nombre:'Cuaderno',sku:'SKU-1'}});
  assert.match(html,/data-edit-offer="offer-1"/);
  h.listOptions.query('',100,50);
  assert.deepEqual(h.queryLog[0],{table:'ofertas_producto',first:100,last:149});
});
