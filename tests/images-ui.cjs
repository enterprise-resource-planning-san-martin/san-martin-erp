const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=fs.readFileSync(require('node:path').resolve(__dirname,'../app.js'),'utf8');
function extractFunction(name){
  const match=new RegExp(`(?:async )?function ${name}\\(`).exec(source);
  assert.ok(match,`Falta ${name}`);
  const start=match.index,body=source.indexOf('{',start);
  let depth=0,end=body;
  for(;end<source.length;end++){
    if(source[end]==='{')depth++;
    if(source[end]==='}'&&--depth===0){end++;break;}
  }
  return source.slice(start,end);
}
const logic=['imageRpc','finishProductImageDelete','uploadProductImages','imageUploadFeedback'].map(extractFunction).join('\n');
const product='20000000-0000-0000-0000-000000000001';
const modes=['success','reserve-fails','upload-fails','confirm-fails','remove-fails'];
async function scenario(mode){
  const calls=[];
  const mock={
    rpc:async(name,args)=>{
      calls.push({name,args});
      if(mode==='reserve-fails'&&name==='erp_reservar_imagen_producto')return {data:null,error:{message:'permiso rechazado'}};
      if(mode==='confirm-fails'&&name==='erp_confirmar_carga_imagen_producto')return {data:null,error:{message:'sin confirmación'}};
      return {data:name==='erp_reservar_imagen_producto'?'50000000-0000-0000-0000-000000000001':{
        storage_bucket:'productos',storage_path:args.p_storage_path||`${product}/archivo.png`
      },error:null};
    },
    storage:{from:()=>({
      getPublicUrl:path=>({data:{publicUrl:`https://beasfybalepkdlomzazf.supabase.co/storage/v1/object/public/productos/${path}`}}),
      upload:async()=>{calls.push({name:'upload'});return {error:['upload-fails','remove-fails'].includes(mode)?{message:'falló Storage'}:null};},
      remove:async()=>{calls.push({name:'remove'});return {error:mode==='remove-fails'?{message:'falló borrado'}:null};}
    })}
  };
  const context=vm.createContext({db:mock,PRODUCT_IMAGE_BUCKET:'productos',crypto:{randomUUID:()=> 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'}});
  vm.runInContext(logic,context);
  const result=await vm.runInContext('uploadProductImages',context)(product,[{name:'foto.png',type:'image/png',size:11}]);
  return {calls,result};
}
(async()=>{
  let run=await scenario('success');
  assert.deepEqual([...run.result.uploaded],['foto.png']);
  assert.deepEqual(run.calls.map(x=>x.name),['erp_reservar_imagen_producto','upload','erp_confirmar_carga_imagen_producto']);
  run=await scenario('reserve-fails');
  assert.equal(run.result.failed.length,1);
  assert.deepEqual(run.calls.map(x=>x.name),['erp_reservar_imagen_producto']);
  run=await scenario('upload-fails');
  assert.equal(run.result.failed.length,1);
  assert.deepEqual(run.calls.map(x=>x.name),['erp_reservar_imagen_producto','upload','erp_preparar_borrado_imagen_producto','remove','erp_confirmar_borrado_imagen_producto']);
  run=await scenario('confirm-fails');
  assert.equal(run.result.failed.length,1);
  assert.match(run.result.failed[0].message,/pendiente/);
  assert.deepEqual(run.calls.map(x=>x.name),['erp_reservar_imagen_producto','upload','erp_confirmar_carga_imagen_producto']);
  run=await scenario('remove-fails');
  assert.match(run.result.failed[0].message,/limpieza quedó pendiente/);
  assert.deepEqual(run.calls.map(x=>x.name),['erp_reservar_imagen_producto','upload','erp_preparar_borrado_imagen_producto','remove']);
  console.log('H12 interfaz: éxito y fallos de reserva, carga, confirmación y limpieza: OK');
})().catch(error=>{console.error(error);process.exitCode=1;});
