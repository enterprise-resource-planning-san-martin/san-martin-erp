// Administración de perfiles mediante el permiso efectivo de la base de datos.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.117.2';

const ERP_PUBLIC_URL = 'https://enterprise-resource-planning-san-martin.github.io/san-martin-erp/';
const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
};
const respond = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), { status, headers });

type Permission = 'usuarios.crear' | 'usuarios.editar' | 'usuarios.desactivar' | 'roles.asignar';

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers });
  if (request.method !== 'POST') return respond({ error: 'Método no permitido.' }, 405);

  const token = request.headers.get('Authorization')?.match(/^Bearer (.+)$/i)?.[1];
  if (!token) return respond({ error: 'Sesión requerida.' }, 401);

  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !serviceKey) return respond({ error: 'Servicio no configurado.' }, 500);
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: userData, error: authError } = await admin.auth.getUser(token);
  const caller = userData.user;
  if (authError || !caller) return respond({ error: 'Sesión inválida.' }, 401);

  const permitted = async (code: Permission) => {
    const { data, error } = await admin.rpc('usuario_tiene_permiso', {
      p_usuario_id: caller.id,
      p_permiso_codigo: code,
    });
    if (error) throw error;
    return data === true;
  };

  try {
    const body = await request.json();
    if (!body || typeof body !== 'object') return respond({ error: 'Datos inválidos.' }, 400);
    if (body.action !== 'invite' && body.action !== 'update') {
      return respond({ error: 'Acción no admitida.' }, 400);
    }

    const { data: callerProfile, error: callerError } = await admin.from('perfiles')
      .select('rol_id,activo,estado,roles(codigo,activo)')
      .eq('id', caller.id).single();
    if (callerError || !callerProfile?.activo || callerProfile.estado !== 'ACTIVO' ||
        !callerProfile.roles?.activo) {
      return respond({ error: 'El perfil no tiene acceso activo.' }, 403);
    }
    const callerIsAdmin = callerProfile.roles?.codigo === 'ADMINISTRADOR';

    const targetRole = async (id: unknown) => {
      if (typeof id !== 'string' || !/^[0-9a-f-]{36}$/i.test(id)) return null;
      const { data, error } = await admin.from('roles').select('id,codigo,activo')
        .eq('id', id).maybeSingle();
      if (error) throw error;
      return data?.activo ? data : null;
    };

    if (body.action === 'invite') {
      if (!(await permitted('usuarios.crear')) || !(await permitted('roles.asignar'))) {
        return respond({ error: 'No tienes permiso para invitar y asignar un rol.' }, 403);
      }
      const correo = String(body.correo ?? '').trim().toLowerCase();
      const nombre = String(body.nombre ?? '').trim();
      const apellido = String(body.apellido ?? '').trim();
      if (!nombre || nombre.length > 100 || apellido.length > 100 ||
          !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo) || correo.length > 254) {
        return respond({ error: 'Nombre o correo inválido.' }, 400);
      }
      const role = await targetRole(body.rol_id);
      if (!role) return respond({ error: 'El rol no está activo.' }, 400);
      if (role.codigo === 'ADMINISTRADOR' && !callerIsAdmin) {
        return respond({ error: 'Solo un administrador puede asignar ese rol.' }, 403);
      }
      const { data: existing, error: lookupError } = await admin.from('perfiles')
        .select('id').ilike('correo', correo).limit(1).maybeSingle();
      if (lookupError) throw lookupError;
      if (existing) return respond({ error: 'Ese correo ya tiene un perfil.' }, 409);
      const { data, error } = await admin.auth.admin.inviteUserByEmail(correo, {
        data: { nombre, apellido }, redirectTo: ERP_PUBLIC_URL,
      });
      if (error || !data.user) return respond({ error: error?.message || 'No se envió la invitación.' }, 400);
      const { error: profileError } = await admin.from('perfiles').upsert({
        id: data.user.id, nombre, apellido: apellido || null, correo,
        rol_id: role.id, estado: 'ACTIVO', activo: true,
      }, { onConflict: 'id' });
      if (profileError) {
        // La invitación acaba de crear la cuenta: invalidarla si el perfil no quedó configurado.
        const { error: cleanupError } = await admin.auth.admin.deleteUser(data.user.id);
        return respond({
          error: cleanupError
            ? 'La invitación falló al configurar el perfil; requiere revisión administrativa.'
            : 'La invitación falló al configurar el perfil. Vuelve a intentarlo.',
        }, 500);
      }
      return respond({ ok: true });
    }

    if (!(await permitted('usuarios.editar'))) {
      return respond({ error: 'No tienes permiso para editar usuarios.' }, 403);
    }
    const id = body.id;
    if (typeof id !== 'string' || !/^[0-9a-f-]{36}$/i.test(id)) {
      return respond({ error: 'Usuario inválido.' }, 400);
    }
    const { data: current, error: currentError } = await admin.from('perfiles')
      .select('id,rol_id,activo,estado,roles(codigo)')
      .eq('id', id).maybeSingle();
    if (currentError) throw currentError;
    if (!current) return respond({ error: 'Usuario no encontrado.' }, 404);
    if (current.roles?.codigo === 'ADMINISTRADOR' && !callerIsAdmin) {
      return respond({ error: 'Solo un administrador puede editar ese perfil.' }, 403);
    }

    const nombre = String(body.nombre ?? '').trim();
    const apellido = String(body.apellido ?? '').trim();
    const telefono = String(body.telefono ?? '').trim();
    if (!nombre || nombre.length > 100 || apellido.length > 100 || telefono.length > 40) {
      return respond({ error: 'Los datos personales no son válidos.' }, 400);
    }
    const estado = body.estado;
    if (estado !== 'ACTIVO' && estado !== 'INACTIVO') {
      return respond({ error: 'Estado inválido.' }, 400);
    }
    const role = await targetRole(body.rol_id);
    if (!role) return respond({ error: 'El rol no está activo.' }, 400);
    if (role.codigo === 'ADMINISTRADOR' && !callerIsAdmin) {
      return respond({ error: 'Solo un administrador puede asignar ese rol.' }, 403);
    }
    if (role.id !== current.rol_id && !(await permitted('roles.asignar'))) {
      return respond({ error: 'No tienes permiso para cambiar roles.' }, 403);
    }
    if ((estado !== current.estado || (estado === 'ACTIVO') !== current.activo) &&
        !(await permitted('usuarios.desactivar'))) {
      return respond({ error: 'No tienes permiso para cambiar el estado.' }, 403);
    }
    if (id === caller.id && (estado !== 'ACTIVO' || role.id !== current.rol_id)) {
      return respond({ error: 'No puedes desactivar ni cambiar tu propio rol.' }, 400);
    }
    const { error: updateError } = await admin.from('perfiles').update({
      nombre, apellido: apellido || null, telefono: telefono || null,
      rol_id: role.id, estado, activo: estado === 'ACTIVO',
    }).eq('id', id);
    if (updateError) throw updateError;
    return respond({ ok: true });
  } catch (error) {
    return respond({ error: error instanceof Error ? error.message : 'Error inesperado.' }, 500);
  }
});
