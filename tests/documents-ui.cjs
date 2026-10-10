const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = require('node:path').resolve(__dirname,'..');
const esc = value => String(value ?? '').replace(/[&<>"']/g, char => ({
  '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#039;'
})[char]);
const invoiceContext = vm.createContext({
  document:{baseURI:'https://example.test/erp/'},
  URL, Intl, Date, Number, String, Math, Array,
  esc,
  qty:value=>String(value),
  orderDate:value=>String(value),
  render:async()=>{},
  state:{page:'dashboard'}
});
vm.runInContext(fs.readFileSync(`${source}/ecommerce-invoices.js`,'utf8'), invoiceContext);
const invoice = {
  numero:7,
  fecha_emision:'2026-10-09T12:00:00Z',
  datos:{
    moneda:'GTQ', zona_horaria:'America/Guatemala',
    empresa:{
      empresa_nombre:'Nueva Librería', empresa_nit:'1234567',
      empresa_direccion:'Calle Nueva 1', empresa_telefono:'5555-5555',
      empresa_correo:'nueva@example.com'
    },
    cliente:{nombre:'Cliente'},
    pedido:{numero:'WEB-007',total:25,costo_envio:0,metodo_entrega:'recoger'},
    lineas:[{sku:'SKU-1',cantidad:1,medida:'UND',nombre:'Cuaderno',precio_unitario:25,total_linea:25}]
  }
};
const rendered = invoiceContext.ecommerceInvoiceDocument(invoice);
for(const expected of ['Nueva Librería','1234567','Calle Nueva 1','5555-5555','nueva@example.com','TOTAL (GTQ)','QUETZALES']) {
  assert(rendered.includes(expected), `Comprobante nuevo omitió ${expected}`);
}
assert(!rendered.includes('NIT Empresa: 42299039'));
assert(!rendered.includes('sanmartinlibreriapapeleria@gmail.com'));
const legacy = structuredClone(invoice);
delete legacy.datos.moneda;
legacy.datos.empresa = {empresa_nombre:'Nombre histórico'};
const legacyHtml = invoiceContext.ecommerceInvoiceDocument(legacy);
assert(legacyHtml.includes('Nombre histórico'));
assert(legacyHtml.includes('TOTAL (GTQ)'));
assert(legacyHtml.includes('NIT Empresa: 42299039'));
const malicious = structuredClone(invoice);
malicious.datos.empresa.empresa_nombre = '<img src=x onerror=alert(1)>';
const escaped = invoiceContext.ecommerceInvoiceDocument(malicious);
assert(!escaped.includes('<img src=x onerror=alert(1)>'));
assert(escaped.includes('&lt;img src=x onerror=alert(1)&gt;'));
assert(invoiceContext.ecommerceAmountWords(1,'GTQ').includes('QUETZAL'));
assert(invoiceContext.ecommerceAmountWords(1,'USD').includes('DÓLAR'));

let savedRows;
let editable=true;
const readonlyInputs=[{disabled:false},{disabled:false}];
const elements = {
  '#content':{innerHTML:''},
  '#settings-form [name="empresa_direccion"]':{value:''},
  '#settings-form':{onsubmit:null,querySelectorAll:()=>readonlyInputs}
};
class FormDataMock { get(key) { return key === 'moneda' ? 'USD' : ({empresa_nombre:'Mi Empresa',empresa_nit:'123'}[key] || ''); } }
const settingsContext = vm.createContext({
  db:{
    from:()=>({
      select:async()=>({data:[{clave:'moneda',valor:{valor:'GTQ'}}],error:null}),
      upsert:async rows=>{savedRows=rows;return {error:null};}
    }),
    rpc:async()=>({data:editable,error:null})
  },
  '$':selector=>elements[selector],
  captureView:()=>({page:'settings'}),
  isCurrentView:()=>true,
  field:()=>'<label><input></label>',
  FormData:FormDataMock,
  Date,
  String,
  Object,
  Promise,
  toast:()=>{}
});
vm.runInContext(fs.readFileSync(`${source}/settings.js`,'utf8'), settingsContext);
(async()=>{
  await settingsContext.settings();
  assert(elements['#content'].innerHTML.includes('GTQ — Quetzal guatemalteco'));
  assert(!elements['#content'].innerHTML.includes('option value="USD"'));
  assert.equal(typeof elements['#settings-form'].onsubmit,'function');
  const button={disabled:false,textContent:'Guardar configuración'};
  await settingsContext.saveSettings({preventDefault(){},submitter:button,target:{}});
  assert.equal(savedRows.find(row=>row.clave==='moneda').valor.valor,'GTQ');
  assert.equal(button.disabled,false);
  editable=false;
  elements['#settings-form'].onsubmit=null;
  await settingsContext.settings();
  assert.equal(elements['#settings-form'].onsubmit,null);
  assert(readonlyInputs.every(input=>input.disabled));
  assert(elements['#content'].innerHTML.includes('puede consultar esta configuración, pero no editarla'));
  console.log('PASS H11 UI: documento nuevo e histórico, HTML escapado y configuración GTQ.');
})().catch(error=>{console.error(error);process.exitCode=1;});
