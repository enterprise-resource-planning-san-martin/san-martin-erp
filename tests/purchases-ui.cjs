const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');

const source=fs.readFileSync(require('node:path').resolve(__dirname,'../app.js'),'utf8');
const start=source.indexOf('async function savePurchaseReception(');
const end=source.indexOf('\ndocument.addEventListener(',start);
assert(start>=0&&end>start);
let lines=[
  {dataset:{detailId:'line-1',pending:'3'},querySelector:name=>({value:name.includes('cantidad')?'2':'8.5'})},
  {dataset:{detailId:'line-2',pending:'4'},querySelector:name=>({value:name.includes('cantidad')?'0':'12'})}
];
const button={disabled:false,textContent:'Registrar recepción'};
const form={};
const values={recepcion_id:'receipt-1',ubicacion_id:'location-1',documento:' FACT-007 ',observaciones:' Parcial '};
let sent=null,closed=0,rendered=0,errors=[];
class FormDataMock{get(key){return values[key]??'';}}
const context=vm.createContext({
  '$':name=>name==='#modal-form'?{querySelectorAll:()=>lines}:name==='#modal'?{close:()=>closed++}:null,
  FormData:FormDataMock,
  db:{rpc:async(name,args)=>{sent={name,args};return {data:{estado:'PARCIAL'},error:null};}},
  toast:(message,isError)=>{if(isError)errors.push(message);},
  render:()=>{rendered++;},
  Number,Array,String,FormData:FormDataMock
});
vm.runInContext(source.slice(start,end),context);
const event=()=>({preventDefault(){},submitter:button,target:form});
(async()=>{
  await context.savePurchaseReception(event(),{id:'order-1'});
  assert.equal(sent.name,'erp_recibir_orden_compra');
  assert.equal(sent.args.p_recepcion_id,'receipt-1');
  assert.equal(sent.args.p_documento,'FACT-007');
  assert.equal(sent.args.p_observaciones,'Parcial');
  assert.equal(sent.args.p_items.length,1);
  assert.equal(sent.args.p_items[0].cantidad,2);
  assert.equal(sent.args.p_items[0].costo_unitario,8.5);
  assert.equal(closed,1);
  assert.equal(rendered,1);

  sent=null;lines=[{dataset:{detailId:'line-1',pending:'3'},querySelector:name=>({value:name.includes('cantidad')?'4':'8'})}];
  await context.savePurchaseReception(event(),{id:'order-1'});
  assert.equal(sent,null);
  assert(errors.some(message=>message.includes('Revisa cantidades')));
  console.log('PASS compras UI: recepción parcial, documento normalizado y exceso local rechazado.');
})().catch(error=>{console.error(error);process.exitCode=1;});
