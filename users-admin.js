// Administración de usuarios. El servidor decide el permiso efectivo en cada acción.
const canManage = code => state.permissions instanceof Set && state.permissions.has(code);

async function invokeManageUsers(body) {
  const { data, error } = await db.functions.invoke('manage-users', { body });
  if (error) {
    let detail;
    try { detail = await error.context?.json(); } catch (_) { /* respuesta sin JSON */ }
    throw new Error(detail?.error || error.message);
  }
  if (!data?.ok) throw new Error(data?.error || 'La operación no fue confirmada.');
  return data;
}

async function users() {
  const [profilesResult, rolesResult, permissionsResult] = await Promise.all([
    db.from('perfiles').select('id,nombre,apellido,correo,telefono,estado,activo,rol_id,roles(nombre,codigo)').order('fecha_creacion', { ascending: false }),
    db.from('roles').select('id,codigo,nombre,descripcion,activo').order('nombre'),
    db.from('permisos').select('id,codigo,modulo,accion,nombre,activo').eq('activo', true).order('modulo')
  ]);
  if (profilesResult.error) throw profilesResult.error;
  if (rolesResult.error) throw rolesResult.error;
  if (permissionsResult.error) throw permissionsResult.error;
  const profiles = profilesResult.data || [];
  const roles = rolesResult.data || [];
  const permissions = permissionsResult.data || [];
  const mayInvite = canManage('usuarios.crear') && canManage('roles.asignar');
  const mayEdit = canManage('usuarios.editar');
  const mayCreateRole = canManage('roles.crear');
  const mayAssignPermissions = canManage('permisos.asignar');

  $('#content').innerHTML = `<section class="panel"><div class="panel-head"><div><h3>Usuarios</h3><p class="muted">Invita usuarios y asigna el rol que define sus permisos dentro del ERP.</p></div>${mayInvite ? '<button class="primary" id="invite-user">+ Invitar usuario</button>' : ''}</div>
    ${table(['USUARIO','CORREO','ROL','ESTADO',''], profiles.map(user => `<tr><td class="name-cell">${esc([user.nombre,user.apellido].filter(Boolean).join(' ') || 'Sin nombre')}<div class="sub-cell">${esc(user.telefono || '')}</div></td><td>${esc(user.correo || '—')}</td><td>${esc(user.roles?.nombre || 'Sin rol')}</td><td><span class="badge ${user.activo ? 'ok' : 'off'}">${esc(user.estado || (user.activo ? 'ACTIVO' : 'INACTIVO'))}</span></td><td>${mayEdit ? `<button class="link" data-edit-user="${esc(user.id)}">Editar</button>` : ''}</td></tr>`).join(''))}</section>
    <div class="grid-2" style="margin-top:1rem"><section class="panel"><div class="panel-head"><h3>Roles</h3>${mayCreateRole ? '<button class="secondary" id="new-role">+ Nuevo rol</button>' : ''}</div>
    ${table(['CÓDIGO','NOMBRE','ESTADO',''], roles.map(role => `<tr><td>${esc(role.codigo)}</td><td class="name-cell">${esc(role.nombre)}<div class="sub-cell">${esc(role.descripcion || '')}</div></td><td><span class="badge ${role.activo ? 'ok' : 'off'}">${role.activo ? 'ACTIVO' : 'INACTIVO'}</span></td><td>${mayAssignPermissions ? `<button class="link" data-role-permissions="${esc(role.id)}">Permisos</button>` : ''}</td></tr>`).join(''))}</section>
    <section class="panel"><div class="panel-head"><h3>Permisos disponibles</h3><span class="badge off">${permissions.length}</span></div>
    ${table(['MÓDULO','ACCIÓN','CÓDIGO'], permissions.map(permission => `<tr><td>${esc(permission.modulo)}</td><td>${esc(permission.accion)}</td><td>${esc(permission.codigo)}</td></tr>`).join(''))}</section></div>`;

  $('#invite-user')?.addEventListener('click', () => openUserInvite(roles));
  $('#new-role')?.addEventListener('click', openRoleCreate);
  document.querySelectorAll('[data-edit-user]').forEach(button =>
    button.addEventListener('click', () => openUserEdit(button.dataset.editUser)));
  document.querySelectorAll('[data-role-permissions]').forEach(button =>
    button.addEventListener('click', () => openRolePermissions(button.dataset.rolePermissions)));
}

async function openUserInvite(roles) {
  if (!canManage('usuarios.crear') || !canManage('roles.asignar')) return;
  $('#modal-title').textContent = 'Invitar usuario';
  $('#modal-form').innerHTML = `${field('Nombre','nombre','text',{required:true})}${field('Apellido','apellido')}${field('Correo electrónico','correo','email',{required:true})}
    <label>Rol<select name="rol_id" required>${roles.filter(x => x.activo && (x.codigo !== 'ADMINISTRADOR' || state.profile?.roles?.codigo === 'ADMINISTRADOR')).map(x => `<option value="${esc(x.id)}">${esc(x.nombre)}</option>`).join('')}</select></label>
    <p class="wide muted">El usuario recibirá un correo para configurar su contraseña en el ERP.</p>
    <div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Enviar invitación</button></div>`;
  $('#modal').showModal();
  $('#modal-form').onsubmit = async event => {
    event.preventDefault();
    const button = event.submitter;
    if (button.disabled) return;
    const form = new FormData(event.target);
    button.disabled = true;
    button.textContent = 'Enviando…';
    try {
      await invokeManageUsers({
        action: 'invite', nombre: form.get('nombre'), apellido: form.get('apellido'),
        correo: form.get('correo'), rol_id: form.get('rol_id')
      });
      $('#modal').close();
      toast('Invitación enviada.');
      await render();
    } catch (error) {
      toast(error.message, true);
    } finally {
      button.disabled = false;
      button.textContent = 'Enviar invitación';
    }
  };
}

async function openUserEdit(id) {
  if (!canManage('usuarios.editar')) return;
  const [userResult, rolesResult] = await Promise.all([
    db.from('perfiles').select('id,nombre,apellido,telefono,rol_id,estado,activo').eq('id', id).single(),
    db.from('roles').select('id,nombre,codigo').eq('activo', true).order('nombre')
  ]);
  if (userResult.error || rolesResult.error) {
    toast(userResult.error?.message || rolesResult.error?.message, true); return;
  }
  const user = userResult.data;
  const roles = (rolesResult.data || []).filter(x =>
    x.codigo !== 'ADMINISTRADOR' || state.profile?.roles?.codigo === 'ADMINISTRADOR');
  const mayAssign = canManage('roles.asignar') && id !== state.profile?.id;
  const mayToggle = canManage('usuarios.desactivar') && id !== state.profile?.id;
  $('#modal-title').textContent = 'Editar usuario';
  $('#modal-form').innerHTML = `${field('Nombre','nombre','text',{required:true,value:user.nombre || ''})}${field('Apellido','apellido','text',{value:user.apellido || ''})}${field('Teléfono','telefono','tel',{value:user.telefono || ''})}
    <label>Rol<select name="rol_id" ${mayAssign ? '' : 'disabled'}>${roles.map(x => `<option value="${esc(x.id)}" ${x.id === user.rol_id ? 'selected' : ''}>${esc(x.nombre)}</option>`).join('')}</select></label>
    <label>Estado<select name="estado" ${mayToggle ? '' : 'disabled'}><option value="ACTIVO" ${user.estado === 'ACTIVO' ? 'selected' : ''}>Activo</option><option value="INACTIVO" ${user.estado === 'INACTIVO' ? 'selected' : ''}>Inactivo</option></select></label>
    <div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Guardar</button></div>`;
  $('#modal').showModal();
  $('#modal-form').onsubmit = async event => {
    event.preventDefault();
    const button = event.submitter;
    if (button.disabled) return;
    const form = new FormData(event.target);
    button.disabled = true;
    try {
      await invokeManageUsers({
        action: 'update', id, nombre: form.get('nombre'), apellido: form.get('apellido'),
        telefono: form.get('telefono'), rol_id: mayAssign ? form.get('rol_id') : user.rol_id,
        estado: mayToggle ? form.get('estado') : user.estado
      });
      $('#modal').close();
      toast('Usuario actualizado.');
      await render();
    } catch (error) {
      toast(error.message, true);
    } finally {
      button.disabled = false;
    }
  };
}

async function openRoleCreate() {
  if (!canManage('roles.crear')) return;
  $('#modal-title').textContent = 'Nuevo rol';
  $('#modal-form').innerHTML = `${field('Código','codigo','text',{required:true,placeholder:'ej. BODEGA'})}${field('Nombre','nombre','text',{required:true})}${field('Descripción','descripcion','textarea',{wide:true})}<div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Crear rol</button></div>`;
  $('#modal').showModal();
  $('#modal-form').onsubmit = async event => {
    event.preventDefault();
    const button = event.submitter;
    const body = Object.fromEntries(new FormData(event.target));
    body.codigo = body.codigo.toUpperCase().replace(/\s+/g,'_');
    body.activo = true;
    button.disabled = true;
    const { error } = await db.from('roles').insert(body);
    if (error) { button.disabled = false; toast(error.message, true); return; }
    $('#modal').close();
    toast('Rol creado.');
    await render();
  };
}

async function openRolePermissions(roleId) {
  if (!canManage('permisos.asignar')) return;
  const view = captureView();
  try {
    const [roleResult, permissionsResult, assignedResult] = await Promise.all([
      db.from('roles').select('nombre').eq('id', roleId).single(),
      fetchAllRows(() => db.from('permisos').select('id,codigo,modulo,accion', { count:'exact' }).eq('activo', true).order('id')),
      fetchAllRows(() => db.from('rol_permisos').select('permiso_id', { count:'exact' }).eq('rol_id', roleId).order('permiso_id'))
    ]);
    if (!isCurrentView(view)) return;
    if (roleResult.error) throw roleResult.error;
    const assigned = new Set(assignedResult.map(row => row.permiso_id));
    $('#modal-title').textContent = `Permisos: ${roleResult.data.nombre}`;
    $('#modal-form').innerHTML = `<div class="wide">${permissionsResult.map(row => `<label style="display:flex;gap:.6rem;align-items:center;margin:.45rem 0"><input type="checkbox" name="permiso_id" value="${esc(row.id)}" ${assigned.has(row.id) ? 'checked' : ''}> <span><strong>${esc(row.codigo)}</strong><small class="field-help">${esc(row.modulo)} · ${esc(row.accion)}</small></span></label>`).join('')}</div><div class="form-actions"><button type="button" class="secondary" data-close>Cancelar</button><button class="primary">Guardar permisos</button></div>`;
    $('#modal').showModal();
    $('#modal-form').onsubmit = async event => {
      event.preventDefault();
      const button = event.submitter;
      if (button.disabled) return;
      const selected = [...new Set(new FormData(event.target).getAll('permiso_id'))];
      button.disabled = true;
      button.textContent = 'Guardando…';
      try {
        const { error } = await db.rpc('erp_guardar_permisos_rol', {
          p_rol_id: roleId, p_permiso_ids: selected
        });
        if (error) throw error;
        $('#modal').close();
        toast('Permisos actualizados.');
        if (state.page === 'users') await render();
      } catch (error) {
        toast(error.message || 'No se pudieron guardar los permisos.', true);
      } finally {
        button.disabled = false;
        button.textContent = 'Guardar permisos';
      }
    };
  } catch (error) {
    if (isCurrentView(view)) toast(error.message || 'No se pudieron cargar los permisos.', true);
  }
}
