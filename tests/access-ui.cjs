const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = require('node:path').resolve(__dirname,'..');
const edge = fs.readFileSync(source + '/supabase/functions/manage-users/index.ts', 'utf8');
const js = edge
  .replace(/^import \{ createClient \} from .*;$/m, "const { createClient } = require('supabase');")
  .replace(/^type Permission = .*;$/m, '')
  .replace(': Record<string, unknown>', '')
  .replace(': Permission', '')
  .replace(': unknown', '');
const callerId = '11111111-1111-4111-8111-111111111111';
const targetId = '22222222-2222-4222-8222-222222222222';
const adminRole = '33333333-3333-4333-8333-333333333333';
const staffRole = '44444444-4444-4444-8444-444444444444';

async function invoke(body, changes = {}) {
  const log = { invites: [], upserts: [], updates: [], deletes: [] };
  const config = {
    permissions: ['usuarios.crear','usuarios.editar','usuarios.desactivar','roles.asignar'],
    active: true, callerRole: 'ADMINISTRADOR', targetRole: staffRole,
    upsertError: null, existingEmail: false, ...changes
  };
  const role = id => id === adminRole
    ? { id, codigo: 'ADMINISTRADOR', activo: true }
    : id === staffRole ? { id, codigo: 'OPERADOR_INVENTARIO', activo: true } : null;
  const admin = {
    auth: {
      getUser: async () => ({ data: { user: { id: callerId } }, error: null }),
      admin: {
        inviteUserByEmail: async (email, options) => {
          log.invites.push({ email, options });
          return { data: { user: { id: targetId } }, error: null };
        },
        deleteUser: async id => { log.deletes.push(id); return { error: null }; }
      }
    },
    rpc: async (_name, args) => ({
      data: config.permissions.includes(args.p_permiso_codigo), error: null
    }),
    from: table => {
      const q = {
        key: null,
        select() { return this; },
        eq(_field, value) { this.key = value; return this; },
        ilike() { this.emailLookup = true; return this; },
        limit() { return this; },
        async single() {
          if (table === 'perfiles') return { data: {
            rol_id: config.callerRole === 'ADMINISTRADOR' ? adminRole : staffRole,
            activo: config.active, estado: config.active ? 'ACTIVO' : 'INACTIVO',
            roles: { codigo: config.callerRole, activo: true }
          }, error: null };
          throw Error('unexpected single ' + table);
        },
        async maybeSingle() {
          if (table === 'roles') return { data: role(this.key), error: null };
          if (table === 'perfiles' && this.emailLookup) {
            return { data: config.existingEmail ? { id: targetId } : null, error: null };
          }
          if (table === 'perfiles') return { data: {
            id: targetId, rol_id: config.targetRole, activo: true, estado: 'ACTIVO',
            roles: { codigo: config.targetRole === adminRole ? 'ADMINISTRADOR' : 'OPERADOR_INVENTARIO' }
          }, error: null };
          throw Error('unexpected maybeSingle ' + table);
        },
        async upsert(row) {
          log.upserts.push(row);
          return { error: config.upsertError };
        },
        update(row) {
          log.updates.push(row);
          return { eq: async () => ({ error: null }) };
        }
      };
      return q;
    }
  };
  let handler;
  vm.runInNewContext(js, {
    require: () => ({ createClient: () => admin }),
    exports: {}, Deno: { env: { get: key => key === 'SUPABASE_URL' ? 'https://example.supabase.co' : 'secret' },
      serve: fn => { handler = fn; } },
    Request, Response, JSON, String, Error
  });
  const request = new Request('https://example.supabase.co/functions/v1/manage-users', {
    method: 'POST', headers: { Authorization: 'Bearer valid' },
    body: JSON.stringify(body)
  });
  const result = await handler(request);
  return { status: result.status, body: await result.json(), log };
}

(async () => {
  const invitation = {
    action: 'invite', nombre: 'Ana', apellido: 'López', correo: ' ANA@example.com ',
    rol_id: staffRole
  };
  let result = await invoke(invitation);
  assert.equal(result.status, 200);
  assert.equal(result.log.invites[0].email, 'ana@example.com');
  assert.equal(result.log.invites[0].options.redirectTo,
    'https://enterprise-resource-planning-san-martin.github.io/san-martin-erp/');
  assert.equal(result.log.upserts[0].rol_id, staffRole);

  result = await invoke(invitation, { permissions: ['usuarios.crear'] });
  assert.equal(result.status, 403);
  assert.equal(result.log.invites.length, 0);

  result = await invoke({ ...invitation, rol_id: adminRole }, {
    callerRole: 'OPERADOR_INVENTARIO'
  });
  assert.equal(result.status, 403);
  assert.equal(result.log.invites.length, 0);

  result = await invoke(invitation, { active: false });
  assert.equal(result.status, 403);
  assert.equal(result.log.invites.length, 0);

  result = await invoke(invitation, { existingEmail: true });
  assert.equal(result.status, 409);
  assert.equal(result.log.invites.length, 0);

  result = await invoke(invitation, { upsertError: { message: 'failed' } });
  assert.equal(result.status, 500);
  assert.deepEqual(result.log.deletes, [targetId]);

  const edit = {
    action: 'update', id: targetId, nombre: 'Ana', apellido: 'López',
    telefono: '55555555', rol_id: adminRole, estado: 'ACTIVO'
  };
  result = await invoke(edit, { permissions: ['usuarios.editar'] });
  assert.equal(result.status, 403);
  assert.equal(result.log.updates.length, 0);

  result = await invoke({ ...edit, rol_id: staffRole });
  assert.equal(result.status, 200);
  assert.equal(result.log.updates[0].nombre, 'Ana');
  assert.equal(result.log.updates[0].activo, true);

  console.log('PASS H13 Edge: invitación, autorización efectiva, rol, inactivo, compensación y edición.');
})().catch(error => { console.error(error); process.exitCode = 1; });
