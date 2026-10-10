const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const base = require('node:path').resolve(__dirname,'..') + '/';
const source = fs.readFileSync(base + 'data-access.js', 'utf8') + '\n' + fs.readFileSync(base + 'data-tools.js', 'utf8');

function harness(initialProducts = [], cap = 137) {
  const tables = {
    categorias: [{id:'cat-1',slug:'papeleria'}],
    unidades_medida: [{id:'unit-1',abreviatura:'UND'}],
    marcas: [{id:'brand-1',slug:'marca'}],
    productos: initialProducts,
    existencias: []
  };
  const inserts = [], messages = [], downloads = [], elements = new Map();
  const element = selector => {
    if (selector === '#confirm-product-import' && !element('#import-preview').innerHTML.includes('id="confirm-product-import"')) return null;
    if (!elements.has(selector)) elements.set(selector, {innerHTML:'',textContent:'',disabled:false,value:'',onclick:null,onchange:null});
    return elements.get(selector);
  };
  const db = {from(table) {
    const query = {
      select(columns, options) { this.columns = columns; this.options = options; return this; },
      order() { return this; },
      range(first, last) {
        const values = tables[table] || [];
        return Promise.resolve({data:values.slice(first, Math.min(last + 1, first + cap)),count:values.length,error:null});
      },
      insert(records) { inserts.push(records); return Promise.resolve({error:null}); }
    };
    return query;
  }};
  const context = vm.createContext({
    db, state:{page:'data-tools',renderVersion:1},
    $:element, esc:text => String(text).replace(/[&<>"']/g, value => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[value])),
    toast:(message,error) => messages.push({message,error}),
    document:{querySelector:selector => element(selector),querySelectorAll:() => [],createElement:() => ({click(){}})},
    URL:{createObjectURL(blob){downloads.push(blob);return 'blob:test';},revokeObjectURL(){}},
    Blob, setTimeout(){}, clearTimeout(){}, console
  });
  vm.runInContext(source, context, {filename:'data-tools.js'});
  return {context,tables,inserts,messages,downloads,element};
}

test('rechaza precio vacío y permite cero explícito con detalle por fila', async () => {
  const h = harness();
  const csv = 'nombre,sku,categoria_slug,unidad_abreviatura,precio_base\nVacío,A,papeleria,UND,\nCero,B,papeleria,UND,0';
  const plan = await h.context.prepareProductCsv(csv);
  assert.equal(plan.records.length, 1);
  assert.equal(plan.records[0].precio_base, 0);
  assert.equal(plan.issues.length, 1);
  assert.equal(plan.issues[0].line, 2);
  assert.match(plan.issues[0].message, /precio_base vacío/);
  await h.context.dataTools();
  await h.context.importProductCsv({name:'productos.csv',text:async()=>csv});
  assert.equal(h.inserts.length, 0);
  assert.match(h.element('#import-preview').innerHTML, /Fila 2: precio_base vacío/);
  assert.ok(!h.element('#import-preview').innerHTML.includes('id="confirm-product-import"'));
});

test('identifica SKU repetido en archivo y SKU existente sin guardar', async () => {
  const h = harness([{id:'prod-1',sku:'EN-DB'}]);
  const csv = 'nombre,sku,categoria_slug,unidad_abreviatura,precio_base\nUno,EN-DB,papeleria,UND,1\nDos,nuevo,papeleria,UND,2\nTres,NUEVO,papeleria,UND,3';
  const plan = await h.context.prepareProductCsv(csv);
  assert.equal(plan.records.length, 1);
  assert.equal(plan.issues.length, 2);
  assert.match(plan.issues.find(x=>x.line===2).message,/ya existe/);
  assert.match(plan.issues.find(x=>x.line===4).message,/repetido en la fila 3/);
  assert.equal(h.inserts.length, 0);
});

test('exportación completa con límite de 137 filas mantiene formato reimportable', async () => {
  const products = Array.from({length:1201},(_,i)=>({
    id:`prod-${String(i).padStart(5,'0')}`,nombre:`Producto ${i}`,sku:`SKU-${i}`,
    precio_base:i===0?0:'10.50',categoria_id:'cat-1',marca_id:i%2?'brand-1':null,
    unidad_medida_id:'unit-1',categorias:{slug:'papeleria'},marcas:i%2?{slug:'marca'}:null,
    unidades_medida:{abreviatura:'UND'},color:'Azul',descripcion_corta:'Descripción',
    activo:true,es_vendible:true,es_comprable:true,controla_inventario:true,
    disponible_pos:true,publicado_ecommerce:false,visible_ecommerce:false
  }));
  const h = harness(products);
  await h.context.exportCsv('productos');
  assert.equal(h.downloads.length, 1);
  const csv = await h.downloads[0].text();
  const parsed = h.context.readCsv(csv);
  assert.equal(parsed.length, 1202);
  assert.deepEqual(Array.from(parsed[0].cells), Array.from(vm.runInContext('PRODUCT_CSV_COLUMNS',h.context)));
  assert.equal(parsed[1].cells[2], 'papeleria');
  assert.equal(parsed[1].cells[3], 'UND');
  assert.equal(parsed[1].cells[4], '0');
  h.tables.productos = [];
  const plan = await h.context.prepareProductCsv(csv);
  assert.equal(plan.issues.length, 0);
  assert.equal(plan.records.length, 1201);
  assert.equal(plan.records[0].precio_base, 0);
  await h.context.dataTools();
  await h.context.importProductCsv({name:'productos.csv',text:async()=>csv});
  assert.equal(h.inserts.length, 0, 'vista previa no debe insertar');
  assert.match(h.element('#import-preview').innerHTML, /Importar 1201 producto/);
  await h.context.confirmProductCsvImport();
  assert.equal(h.inserts.length, 1, 'toda la carga se envía en una petición');
  assert.equal(h.inserts[0].length, 1201);
});

test('CSV conserva comas, comillas y líneas; informa comilla sin cierre', () => {
  const h = harness();
  const parsed = h.context.readCsv('nombre,sku\r\n"Nombre, con\r\nsalto",A\r\n"Dijo ""hola""",B');
  assert.equal(parsed[1].line, 2);
  assert.equal(parsed[2].line, 4);
  assert.equal(parsed[1].cells[0], 'Nombre, con\nsalto');
  assert.equal(parsed[2].cells[0], 'Dijo "hola"');
  assert.throws(() => h.context.readCsv('nombre,sku\n"Roto,A'), /Fila 2: falta cerrar/);
});
