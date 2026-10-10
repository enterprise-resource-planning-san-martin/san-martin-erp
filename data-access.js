/* Lecturas completas y listas paginadas. No cambia permisos: cada consulta usa la sesión/RLS. */
function captureView() { return { page: state.page, version: state.renderVersion || 0 }; }
function isCurrentView(view) { return !!view && view.page === state.page && view.version === (state.renderVersion || 0); }
function searchOr(columns, search) {
  const value = String(search || '').trim();
  if (!value) return '';
  const literal = value.replace(/\\/g, '\\\\').replace(/[%_*]/g, '\\$&').replace(/"/g, '\\"');
  return columns.map(column => `${column}.ilike."%${literal}%"`).join(',');
}
async function fetchAllRows(queryFactory, { batchSize = 500, onProgress } = {}) {
  const rows = [];
  let offset = 0, expected = null;
  const seen = new Set();
  while (true) {
    const { data, error, count } = await queryFactory().range(offset, offset + batchSize - 1);
    if (error) throw error;
    if (!Array.isArray(data)) throw new Error('La consulta no devolvió una lista de registros.');
    if (Number.isInteger(count)) {
      if (expected !== null && expected !== count) throw new Error('Los datos cambiaron durante la descarga. Actualiza y vuelve a exportar.');
      expected = count;
    }
    if (!data.length) {
      if (expected !== null && rows.length !== expected) throw new Error('La descarga quedó incompleta. Vuelve a intentarlo.');
      break;
    }
    for (const row of data) {
      if (row.id != null) {
        if (seen.has(row.id)) throw new Error('Los registros cambiaron durante la descarga. Actualiza y vuelve a exportar.');
        seen.add(row.id);
      }
    }
    rows.push(...data); offset += data.length;
    if (expected !== null && rows.length > expected) throw new Error('El total cambió durante la descarga. Vuelve a exportar.');
    if (onProgress) onProgress(rows.length, expected);
    if (expected !== null && rows.length >= expected) break;
    // Continue even if the server caps each page below batchSize.
  }
  return rows;
}
async function readCompletePage(request, offset, size) {
  const rows = [], seen = new Set();
  let expected = null;
  while (rows.length < size && (expected === null || offset + rows.length < expected)) {
    const result = await request(offset + rows.length, size - rows.length);
    if (result.error) throw result.error;
    if (!Array.isArray(result.data) || !Number.isInteger(result.count) || result.count < 0) throw new Error('No se recibió una página y un total válidos.');
    if (expected !== null && expected !== result.count) throw new Error('Los datos cambiaron durante la consulta. Vuelve a buscar.');
    expected = result.count;
    if (!result.data.length) {
      if (offset + rows.length < expected) throw new Error('La página quedó incompleta. Vuelve a intentarlo.');
      break;
    }
    for (const row of result.data) {
      if (row.id != null && seen.has(row.id)) throw new Error('Los registros cambiaron durante la consulta. Vuelve a buscar.');
      if (row.id != null) seen.add(row.id);
    }
    rows.push(...result.data);
    if (rows.length > size) throw new Error('Se recibió una página de tamaño inesperado.');
  }
  return {data:rows,count:expected || 0,error:null};
}
async function renderPagedList({ page, placeholder = 'Buscar…', query, headers, rowHtml, onRows, note = '', pageSize = 50 }) {
  const view = captureView();
  if (view.page !== page) return;
  const host = $('#content');
  host.innerHTML = `<div class="toolbar"><form id="list-search-form" class="search"><input id="filter" placeholder="${esc(placeholder)}" aria-label="${esc(placeholder)}"><button class="secondary" type="submit">Buscar</button></form>${note ? `<p class="muted">${esc(note)}</p>` : ''}</div><div id="paged-list-results"></div><div class="panel-head"><button class="secondary" id="list-prev">Anterior</button><span class="muted" id="list-page" aria-live="polite"></span><button class="secondary" id="list-next">Siguiente</button></div>`;
  let pageIndex = 0, request = 0, timer, currentSearch = '';
  const load = async () => {
    const mine = ++request;
    const resultHost = $('#paged-list-results'), prev = $('#list-prev'), next = $('#list-next');
    if (!isCurrentView(view) || !resultHost) return;
    prev.disabled = next.disabled = true;
    resultHost.innerHTML = '<p class="muted" role="status">Cargando información…</p>';
    try {
      const querySearch = currentSearch, queryPage = pageIndex;
      const result = await readCompletePage((offset,size)=>query(querySearch,offset,size),queryPage * pageSize,pageSize);
      if (!isCurrentView(view) || mine !== request) return;
      if (result.error) throw result.error;
      const rows = result.data || [], count = Number(result.count || 0);
      if (onRows) onRows(rows);
      resultHost.innerHTML = table(headers, rows.map(rowHtml).join(''));
      $('#list-page').textContent = `Página ${pageIndex + 1} · ${count} registro${count === 1 ? '' : 's'}`;
      prev.disabled = pageIndex === 0;
      next.disabled = (pageIndex + 1) * pageSize >= count;
    } catch (error) {
      if (!isCurrentView(view) || mine !== request) return;
      resultHost.innerHTML = `<p role="alert">${esc(error.message)}</p><button type="button" class="secondary" id="list-retry">Reintentar</button>`;
      $('#list-retry').onclick = load;
      prev.disabled = pageIndex === 0;
    }
  };
  const search = () => { clearTimeout(timer); if (!isCurrentView(view)) return; currentSearch = $('#filter').value.trim(); pageIndex = 0; return load(); };
  $('#list-search-form').onsubmit = event => { event.preventDefault(); search(); };
  $('#filter').oninput = () => { clearTimeout(timer); timer = setTimeout(search, 300); };
  $('#list-prev').onclick = () => { if (pageIndex > 0) { pageIndex--; load(); } };
  $('#list-next').onclick = () => { pageIndex++; load(); };
  await load();
}
