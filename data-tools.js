// Formato común para plantilla, exportación e importación de productos nuevos.
const PRODUCT_CSV_COLUMNS = ['nombre','sku','categoria_slug','unidad_abreviatura','precio_base','marca_slug','color','descripcion_corta','activo','es_vendible','es_comprable','controla_inventario','disponible_pos','publicado_ecommerce','visible_ecommerce'];
const PRODUCT_CSV_REQUIRED = ['nombre','sku','categoria_slug','unidad_abreviatura','precio_base'];
const PRODUCT_CSV_FLAGS = {activo:true,es_vendible:true,es_comprable:true,controla_inventario:true,disponible_pos:true,publicado_ecommerce:false,visible_ecommerce:false};
let pendingProductCsv = null, productCsvRequest = 0;

function csvValue(value) { const text=String(value ?? ''); return /[",\r\n]/.test(text) ? `"${text.replace(/"/g,'""')}"` : text; }
function downloadCsv(filename, headers, rows) {
  const content=[headers.map(csvValue).join(','),...rows.map(row=>row.map(csvValue).join(','))].join('\r\n');
  const url=URL.createObjectURL(new Blob(['\ufeff'+content],{type:'text/csv;charset=utf-8'}));
  const link=document.createElement('a'); link.href=url; link.download=filename; link.click();
  setTimeout(()=>URL.revokeObjectURL(url),1000);
}
// Conserva el número de línea de cada registro para errores claros, incluso con celdas multilínea.
function readCsv(source) {
  const input=String(source ?? '').replace(/^\ufeff/,'');
  const rows=[]; let cells=[],value='',quoted=false,afterQuote=false,line=1,rowLine=1;
  const finishCell=()=>{cells.push(value.trim());value='';afterQuote=false;};
  const finishRow=()=>{finishCell();if(cells.some(cell=>cell!==''))rows.push({line:rowLine,cells});cells=[];rowLine=line+1;};
  for(let i=0;i<input.length;i++){
    const char=input[i],next=input[i+1];
    if(quoted){
      if(char==='"'&&next==='"'){value+='"';i++;}
      else if(char==='"'){quoted=false;afterQuote=true;}
      else if(char==='\r'||char==='\n'){if(char==='\r'&&next==='\n')i++;value+='\n';line++;}
      else value+=char;
      continue;
    }
    if(char===','){finishCell();continue;}
    if(char==='\r'||char==='\n'){finishRow();if(char==='\r'&&next==='\n')i++;line++;continue;}
    if(char==='"'){
      if(afterQuote||value.trim()!=='')throw new Error(`Fila ${rowLine}: comillas en una posición inválida.`);
      value='';quoted=true;continue;
    }
    if(afterQuote){if(char===' '||char==='\t')continue;throw new Error(`Fila ${rowLine}: hay texto después de cerrar una celda entre comillas.`);}
    value+=char;
  }
  if(quoted)throw new Error(`Fila ${rowLine}: falta cerrar una celda entre comillas.`);
  if(value!==''||cells.length||afterQuote)finishRow();
  return rows;
}
function csvKey(value){return String(value ?? '').trim().toLocaleLowerCase('es');}
function csvFlag(text,fallback){
  if(text==='')return fallback;
  if(['true','1','sí','si','yes'].includes(csvKey(text)))return true;
  if(['false','0','no'].includes(csvKey(text)))return false;
  return null;
}
function productCsvRow(product){return PRODUCT_CSV_COLUMNS.map(column=>{
  if(column==='categoria_slug')return product.categorias?.slug||'';
  if(column==='unidad_abreviatura')return product.unidades_medida?.abreviatura||'';
  if(column==='marca_slug')return product.marcas?.slug||'';
  return product[column]??'';
});}
async function exportCsv(kind) {
  const settings={
    categorias:{table:'categorias',file:'categorias.csv',columns:['nombre','slug','descripcion','activo']},
    marcas:{table:'marcas',file:'marcas.csv',columns:['nombre','slug','descripcion','pais_origen','activo']}
  }[kind];
  const button=document.querySelector('[data-export="'+kind+'"]'),label=button?.textContent;
  if(button){button.disabled=true;button.textContent='Preparando descarga…';}
  try{
    const progress=count=>{if(button)button.textContent=count+' registros leídos…';};
    if(kind==='existencias'){
      const data=await fetchAllRows(()=>db.from('existencias').select('id,stock_fisico,stock_reservado,stock_disponible,stock_minimo,stock_maximo,productos(nombre,sku),ubicaciones(nombre,codigo)',{count:'exact'}).order('id'),{onProgress:progress});
      downloadCsv('existencias.csv',['producto','sku','ubicacion','codigo_ubicacion','stock_fisico','stock_reservado','stock_disponible','stock_minimo','stock_maximo'],data.map(x=>[x.productos?.nombre,x.productos?.sku,x.ubicaciones?.nombre,x.ubicaciones?.codigo,x.stock_fisico,x.stock_reservado,x.stock_disponible,x.stock_minimo,x.stock_maximo]));
      toast(data.length+' existencias exportadas.');return;
    }
    if(kind==='productos'){
      const productColumns=`id,marca_id,${PRODUCT_CSV_COLUMNS.filter(column=>!['categoria_slug','unidad_abreviatura','marca_slug'].includes(column)).join(',')},categorias(slug),marcas(slug),unidades_medida(abreviatura)`;
      const data=await fetchAllRows(()=>db.from('productos').select(productColumns,{count:'exact'}).order('id'),{onProgress:progress});
      const inaccessible=data.find(row=>!row.categorias?.slug||!row.unidades_medida?.abreviatura||(row.marca_id&&!row.marcas?.slug));
      if(inaccessible)throw new Error(`No se pueden leer los catálogos del producto ${inaccessible.sku}; revisa tus permisos antes de exportar.`);
      downloadCsv('productos.csv',PRODUCT_CSV_COLUMNS,data.map(productCsvRow));
      toast(data.length+' productos exportados.');return;
    }
    if(!settings)throw new Error('Exportación desconocida.');
    const data=await fetchAllRows(()=>db.from(settings.table).select(['id',...settings.columns].join(','),{count:'exact'}).order('id'),{onProgress:progress});
    downloadCsv(settings.file,settings.columns,data.map(x=>settings.columns.map(column=>x[column])));
    toast(data.length+' registros exportados.');
  }catch(error){toast('No se descargó el archivo: '+error.message,true);}
  finally{if(button){button.disabled=false;button.textContent=label;}}
}
function downloadProductTemplate(){downloadCsv('plantilla_productos.csv',PRODUCT_CSV_COLUMNS,[['Producto ejemplo','EJEMPLO-001','papeleria','UND','10.00','','Azul','Descripción opcional',true,true,true,true,true,false,false]]);}
async function prepareProductCsv(text){
  const parsed=readCsv(text);
  if(!parsed.length)return {records:[],preview:[],issues:[{line:1,message:'El archivo está vacío.'}],total:0};
  const headers=parsed[0].cells.map(csvKey);
  const missing=PRODUCT_CSV_REQUIRED.filter(column=>!headers.includes(column));
  const repeated=headers.filter((column,index)=>column&&headers.indexOf(column)!==index);
  const headerIssues=[];
  if(missing.length)headerIssues.push({line:1,message:`Faltan columnas obligatorias: ${missing.join(', ')}.`});
  if(repeated.length)headerIssues.push({line:1,message:`Columnas repetidas: ${[...new Set(repeated)].join(', ')}.`});
  if(headerIssues.length)return {records:[],preview:[],issues:headerIssues,total:parsed.length-1};
  const brandColumn=headers.indexOf('marca_slug');
  const needsBrands=brandColumn>=0&&parsed.slice(1).some(row=>row.cells[brandColumn]?.trim());
  const [categories,units,brands,products]=await Promise.all([
    fetchAllRows(()=>db.from('categorias').select('id,slug',{count:'exact'}).order('id')),
    fetchAllRows(()=>db.from('unidades_medida').select('id,abreviatura',{count:'exact'}).order('id')),
    needsBrands?fetchAllRows(()=>db.from('marcas').select('id,slug',{count:'exact'}).order('id')):Promise.resolve([]),
    fetchAllRows(()=>db.from('productos').select('id,sku',{count:'exact'}).order('id'))
  ]);
  const categoriesBySlug=new Map(categories.map(row=>[csvKey(row.slug),row.id]));
  const unitsByAbbreviation=new Map(units.map(row=>[csvKey(row.abreviatura),row.id]));
  const brandsBySlug=new Map(brands.map(row=>[csvKey(row.slug),row.id]));
  const existingSkus=new Set(products.map(row=>csvKey(row.sku)));
  const fileSkus=new Map(),records=[],issues=[],preview=[];
  if(parsed.length===1)issues.push({line:2,message:'El archivo no contiene productos.'});
  for(const row of parsed.slice(1)){
    const rowIssues=[];
    const cell=column=>row.cells[headers.indexOf(column)]?.trim()||'';
    if(row.cells.length!==headers.length)rowIssues.push(`se esperaban ${headers.length} columnas y se encontraron ${row.cells.length}`);
    const nombre=cell('nombre'),sku=cell('sku'),categorySlug=cell('categoria_slug');
    const unitAbbreviation=cell('unidad_abreviatura'),brandSlug=cell('marca_slug');
    const priceText=cell('precio_base');
    if(!nombre)rowIssues.push('nombre vacío');
    if(!sku)rowIssues.push('SKU vacío');
    if(!categorySlug)rowIssues.push('categoria_slug vacío');
    else if(!categoriesBySlug.has(csvKey(categorySlug)))rowIssues.push(`categoría ${categorySlug} no encontrada`);
    if(!unitAbbreviation)rowIssues.push('unidad_abreviatura vacía');
    else if(!unitsByAbbreviation.has(csvKey(unitAbbreviation)))rowIssues.push(`unidad ${unitAbbreviation} no encontrada`);
    if(brandSlug&&!brandsBySlug.has(csvKey(brandSlug)))rowIssues.push(`marca ${brandSlug} no encontrada`);
    if(!priceText)rowIssues.push('precio_base vacío');
    else if(!/^(?:\d+)(?:\.\d+)?$/.test(priceText)||!Number.isFinite(Number(priceText)))rowIssues.push('precio_base debe ser un número no negativo con punto decimal');
    const skuKey=csvKey(sku);
    if(skuKey){
      if(fileSkus.has(skuKey))rowIssues.push(`SKU ${sku} repetido en la fila ${fileSkus.get(skuKey)}`);
      else fileSkus.set(skuKey,row.line);
      if(existingSkus.has(skuKey))rowIssues.push(`SKU ${sku} ya existe en productos`);
    }
    const flags={};
    for(const [column,fallback] of Object.entries(PRODUCT_CSV_FLAGS)){
      const flag=csvFlag(headers.includes(column)?cell(column):'',fallback);
      if(flag===null)rowIssues.push(`${column} debe ser verdadero o falso`);
      else flags[column]=flag;
    }
    preview.push({line:row.line,nombre,sku,categorySlug,unitAbbreviation,priceText,valid:!rowIssues.length});
    if(rowIssues.length){issues.push({line:row.line,message:rowIssues.join('; ')+'.'});continue;}
    records.push({nombre,sku,categoria_id:categoriesBySlug.get(csvKey(categorySlug)),unidad_medida_id:unitsByAbbreviation.get(csvKey(unitAbbreviation)),marca_id:brandSlug?brandsBySlug.get(csvKey(brandSlug)):null,precio_base:Number(priceText),color:cell('color')||null,descripcion_corta:cell('descripcion_corta')||null,...flags});
  }
  return {records,preview,issues,total:parsed.length-1};
}
function showProductCsvPreview(fileName,plan){
  const host=$('#import-preview');if(!host)return;
  const badRows=new Set(plan.issues.map(issue=>issue.line));
  const previewRows=plan.preview.slice(0,10).map(row=>`<tr><td>${row.line}</td><td>${esc(row.sku)}</td><td>${esc(row.nombre)}</td><td>${esc(row.categorySlug)}</td><td>${esc(row.unitAbbreviation)}</td><td>${esc(row.priceText)}</td><td>${row.valid?'Lista':'Error'}</td></tr>`).join('');
  host.innerHTML=`<h4>Vista previa: ${esc(fileName)}</h4><p class="muted">${plan.total} fila(s), ${badRows.size} con error. ${plan.issues.length?'Corrige el archivo y vuelve a seleccionarlo; no se ha guardado ningún producto.':'Revisa los datos antes de importarlos.'}</p>${previewRows?`<div style="overflow:auto"><table><thead><tr><th>Fila</th><th>SKU</th><th>Producto</th><th>Categoría</th><th>Unidad</th><th>Precio</th><th>Estado</th></tr></thead><tbody>${previewRows}</tbody></table></div>${plan.preview.length>10?`<p class="muted">Se muestran 10 de ${plan.preview.length} filas.</p>`:''}`:''}${plan.issues.length?`<div role="alert"><strong>Errores por fila</strong><div style="max-height:220px;overflow:auto"><ul>${plan.issues.map(issue=>`<li>Fila ${issue.line}: ${esc(issue.message)}</li>`).join('')}</ul></div></div>`:`<button type="button" class="primary" id="confirm-product-import">Importar ${plan.records.length} producto(s)</button>`}`;
  const confirm=$('#confirm-product-import');if(confirm)confirm.onclick=confirmProductCsvImport;
}
async function importProductCsv(file,view=captureView()){
  const request=++productCsvRequest;pendingProductCsv=null;
  const feedback=$('#import-feedback'),preview=$('#import-preview');
  if(feedback)feedback.textContent=`Leyendo ${file.name}…`;
  if(preview)preview.innerHTML='';
  try{
    const plan=await prepareProductCsv(await file.text());
    if(!isCurrentView(view)||request!==productCsvRequest)return;
    pendingProductCsv=plan.issues.length||!plan.records.length?null:{plan,view};
    feedback.textContent=plan.issues.length?'Corrige los errores indicados y vuelve a seleccionar el CSV.':'Archivo validado. Confirma la importación.';
    showProductCsvPreview(file.name,plan);
  }catch(error){
    if(!isCurrentView(view)||request!==productCsvRequest)return;
    feedback.textContent=`No se pudo leer el CSV: ${error.message}`;
    toast(feedback.textContent,true);
  }
}
async function confirmProductCsvImport(){
  const pending=pendingProductCsv;
  if(!pending||!isCurrentView(pending.view))return;
  const button=$('#confirm-product-import');
  if(button){button.disabled=true;button.textContent='Importando…';}
  pendingProductCsv=null;
  try{
    // Un solo INSERT: si falla una fila, Postgres revierte todo el lote.
    const {error}=await db.from('productos').insert(pending.plan.records);
    if(error)throw error;
    if(!isCurrentView(pending.view))return;
    await dataTools();
    $('#import-feedback').textContent=`${pending.plan.records.length} producto(s) importados correctamente.`;
    toast($('#import-feedback').textContent);
  }catch(error){
    if(!isCurrentView(pending.view))return;
    const message=error.code==='23505'?'Un SKU ya existe en la base. Selecciona el CSV otra vez para actualizar la vista previa.':`No se importó ningún producto: ${error.message}`;
    $('#import-feedback').textContent=message;
    if(button)button.textContent='Selecciona el CSV de nuevo';
    toast(message,true);
  }
}
async function dataTools() {
  productCsvRequest++;pendingProductCsv=null;
  const view=captureView();
  $('#content').innerHTML=`<section class="panel"><div class="panel-head"><div><h3>Exportar información</h3><p class="muted">Descarga datos CSV según los permisos de tu usuario.</p></div></div><div class="grid-2"><section class="panel"><h3>Catálogos</h3><div class="form-actions"><button class="secondary" data-export="categorias">Categorías CSV</button><button class="secondary" data-export="marcas">Marcas CSV</button><button class="secondary" data-export="productos">Productos CSV</button></div></section><section class="panel"><h3>Existencias</h3><p class="muted">Stock por producto y ubicación.</p><button class="secondary" data-export="existencias">Existencias CSV</button></section></div></section><section class="panel" style="margin-top:1rem"><div class="panel-head"><div><h3>Importar productos</h3><p class="muted">Carga productos nuevos. La plantilla y la exportación de productos comparten columnas.</p></div><button class="secondary" id="download-product-template">Descargar plantilla</button></div><p class="muted">Obligatorias: nombre, sku, categoria_slug, unidad_abreviatura y precio_base. El precio usa punto decimal; 0 es válido si lo escribes explícitamente. Se valida todo el archivo antes de guardar.</p><label class="primary upload-label" style="display:inline-flex;cursor:pointer">Seleccionar CSV<input id="product-import-file" type="file" accept=".csv,text/csv" hidden></label><p id="import-feedback" class="muted" role="status"></p><div id="import-preview" aria-live="polite"></div></section>`;
  document.querySelectorAll('[data-export]').forEach(button=>button.onclick=()=>exportCsv(button.dataset.export));
  $('#download-product-template').onclick=downloadProductTemplate;
  $('#product-import-file').onchange=event=>{const file=event.target.files[0];event.target.value='';if(file)importProductCsv(file,view);};
}
