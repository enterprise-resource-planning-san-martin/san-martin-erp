/* Los precios, ventas y pedidos existentes están contabilizados en GTQ. */
const ERP_TRANSACTION_CURRENCY = 'GTQ';
const ERP_SETTING_KEYS = [
  'empresa_nombre', 'empresa_nit', 'empresa_correo', 'empresa_telefono',
  'empresa_direccion', 'moneda', 'zona_horaria'
];

async function settings() {
  const view = captureView();
  const [{ data, error }, editPermission] = await Promise.all([
    db.from('configuracion_erp').select('clave,valor'),
    db.rpc('tiene_permiso', { p_permiso_codigo:'configuracion.editar' })
  ]);
  if (error) throw error;
  if (editPermission.error) throw editPermission.error;
  if (!isCurrentView(view)) return;

  const canEdit = editPermission.data === true;
  const values = Object.fromEntries((data || []).map(row => [row.clave, row.valor?.valor ?? '']));
  const previousCurrency = values.moneda && values.moneda !== ERP_TRANSACTION_CURRENCY;
  $('#content').innerHTML = `
    <section class="panel">
      <div class="panel-head"><div><h3>Configuración general</h3>
        <p class="muted">Estos datos se copian al comprobante cuando se confirma un pago. Los comprobantes ya emitidos conservan su instantánea.</p>
      </div></div>
      <form id="settings-form" class="form-grid">
        ${field('Nombre de la empresa','empresa_nombre','text',{value:values.empresa_nombre || ''})}
        ${field('NIT','empresa_nit','text',{value:values.empresa_nit || ''})}
        ${field('Correo institucional','empresa_correo','email',{value:values.empresa_correo || ''})}
        ${field('Teléfono','empresa_telefono','tel',{value:values.empresa_telefono || ''})}
        <label>Moneda de precios, ventas y comprobantes
          <input value="GTQ — Quetzal guatemalteco" readonly aria-describedby="erp-currency-note">
          <input type="hidden" name="moneda" value="GTQ">
          <small id="erp-currency-note" class="field-help">El ERP registra importes en GTQ. Para operar en USD se necesita registrar moneda y conversión en cada transacción.</small>
        </label>
        <label>Zona horaria<select name="zona_horaria"><option value="America/Guatemala">America/Guatemala</option></select></label>
        ${field('Dirección','empresa_direccion','textarea',{wide:true})}
        ${previousCurrency ? '<p class="wide" role="alert">La preferencia de moneda guardada no se aplica a los importes existentes; al guardar se corregirá a GTQ.</p>' : ''}
        ${canEdit ? '<div class="form-actions"><button class="primary">Guardar configuración</button></div>' : '<p class="wide muted">Tu usuario puede consultar esta configuración, pero no editarla.</p>'}
      </form>
    </section>`;
  $('#settings-form [name="empresa_direccion"]').value = values.empresa_direccion || '';
  if (canEdit) $('#settings-form').onsubmit = saveSettings;
  else $('#settings-form').querySelectorAll('input, textarea, select').forEach(input => { input.disabled = true; });
}

async function saveSettings(event) {
  event.preventDefault();
  const button = event.submitter;
  const form = new FormData(event.target);
  const rows = ERP_SETTING_KEYS.map(clave => ({
    clave,
    valor: { valor: clave === 'moneda' ? ERP_TRANSACTION_CURRENCY : String(form.get(clave) || '').trim() },
    fecha_actualizacion: new Date().toISOString()
  }));
  button.disabled = true;
  button.textContent = 'Guardando…';
  try {
    const { error } = await db.from('configuracion_erp').upsert(rows, { onConflict:'clave' });
    if (error) throw error;
    toast('Configuración guardada. Los cambios se aplicarán a los próximos comprobantes.');
  } catch (error) {
    toast(error.message, true);
  } finally {
    button.disabled = false;
    button.textContent = 'Guardar configuración';
  }
}
