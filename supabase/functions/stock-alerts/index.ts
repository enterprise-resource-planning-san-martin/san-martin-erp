// H07. Secrets: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY,
// RESEND_API_KEY, ALERT_EMAIL_TO, ALERT_EMAIL_FROM. Optional job: ALERT_DISPATCH_SECRET.
// Resend idempotency (24h): https://resend.com/docs/dashboard/emails/idempotency-keys
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.117.2';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-alert-dispatch-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (body: unknown, status = 200) => Response.json(body, { status, headers: corsHeaders });
const errorMessage = (error: unknown) => error instanceof Error ? error.message : String(error);
// Dependency injection keeps offline regressions separate from actual dispatch.
export function createAlertHandler({ createClient: clientFactory = createClient,
  env = (key: string) => Deno.env.get(key), fetch: sendRequest = fetch,
  newId = () => crypto.randomUUID() } = {}) {
  return async (request: Request) => {
    if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
    if (request.method !== 'POST') return json({ error: 'Usa POST para despachar alertas.' }, 405);
    try {
      const url = env('SUPABASE_URL'), anonKey = env('SUPABASE_ANON_KEY'), serviceKey = env('SUPABASE_SERVICE_ROLE_KEY');
      if (!url || !anonKey || !serviceKey) return json({ error: 'Falta configuración de Supabase.' }, 500);
      const jobSecret = env('ALERT_DISPATCH_SECRET');
      const suppliedSecret = request.headers.get('x-alert-dispatch-secret');
      const trustedJob = !!jobSecret && suppliedSecret === jobSecret;
      const authorization = request.headers.get('Authorization') || '';
      if (!trustedJob && !/^Bearer\s+\S+$/i.test(authorization)) return json({ error: 'Sesión requerida.' }, 401);
      if (suppliedSecret && !trustedJob) return json({ error: 'Credencial de despacho inválida.' }, 401);
      const admin = clientFactory(url, serviceKey, { auth: { persistSession: false } });
      const caller = trustedJob ? admin : clientFactory(url, anonKey, {
        global: { headers: { Authorization: authorization } }, auth: { persistSession: false },
      });
      if (!trustedJob) {
        const token = authorization.replace(/^Bearer\s+/i, '');
        const { data, error } = await caller.auth.getUser(token);
        if (error || !data?.user) return json({ error: 'Sesión inválida.' }, 401);
        const active = await caller.rpc('erp_usuario_activo');
        if (active.error) return json({ error: active.error.message }, 500);
        if (active.data !== true) return json({ error: 'El usuario está inactivo.' }, 403);
      }
      const queue = await caller.rpc('generar_alertas_inventario');
      if (queue.error) return json({ error: queue.error.message }, queue.error.code === '42501' ? 403 : 500);
      const recipients = (env('ALERT_EMAIL_TO') || '').split(',').map(value => value.trim()).filter(Boolean);
      const resendKey = env('RESEND_API_KEY');
      // Preserve the deployed sender fallback; a verified sender remains recommended.
      const sender = env('ALERT_EMAIL_FROM') || 'Inventario <onboarding@resend.dev>';
      if (!recipients.length || recipients.length > 50 || !resendKey) {
        return json({ error: 'Alertas generadas; faltan o son inválidos RESEND_API_KEY o ALERT_EMAIL_TO.' }, 500);
      }
      const batchId = newId();
      // Five bounded 20s requests fit within the usual Edge execution window.
      const claimed = await caller.rpc('erp_reclamar_alertas', { p_lote: batchId, p_limite: 5 });
      if (claimed.error) return json({ error: claimed.error.message }, claimed.error.code === '42501' ? 403 : 500);
      const ids: string[] = claimed.data?.ids || [];
      const blocked = Number(claimed.data?.blocked || 0);
      let sent = 0, skipped = 0;
      const errors: { alert_id: string; message: string }[] = [];
      for (const alertId of ids) {
        let emailId: string | null = null;
        try {
          const prepared = await admin.rpc('erp_preparar_envio_alerta', {
            p_alerta_id: alertId, p_lote: batchId, p_remitente: sender, p_destinatarios: recipients,
          });
          if (prepared.error) throw new Error(prepared.error.message);
          if (!prepared.data) { skipped++; continue; }
          const response = await sendRequest('https://api.resend.com/emails', {
            method: 'POST', headers: { Authorization: `Bearer ${resendKey}`, 'Content-Type': 'application/json',
              'Idempotency-Key': `inventory-alert/${alertId}` },
            body: JSON.stringify(prepared.data), signal: AbortSignal.timeout(20000),
          });
          if (!response.ok) throw new Error(`Proveedor de correo (${response.status}): ${(await response.text()).slice(0,500)}`);
          const result = await response.json();
          if (!result.id) throw new Error('El proveedor no devolvió una referencia de envío.');
          emailId = result.id;
          const completed = await admin.rpc('erp_finalizar_envio_alerta', {
            p_alerta_id: alertId, p_lote: batchId, p_email_id: emailId, p_error: null,
          });
          if (completed.error || completed.data !== true) throw new Error(completed.error?.message || 'No se pudo confirmar el envío en la cola.');
          sent++;
        } catch (error) {
          let message = errorMessage(error);
          const released = await admin.rpc('erp_finalizar_envio_alerta', {
            p_alerta_id: alertId, p_lote: batchId, p_email_id: emailId, p_error: emailId ? null : message,
          });
          if (released.error || released.data !== true) message += ` Cola pendiente: ${released.error?.message || 'la reserva cambió'}.`;
          else if (emailId) { sent++; continue; }
          errors.push({ alert_id: alertId, message });
        }
      }
      const result = { sent, skipped, failed: errors.length, blocked, errors };
      if (blocked) return json({ ...result, error: `${blocked} alerta(s) requieren conciliación manual del envío; venció la ventana segura de reintento.` }, 409);
      if (errors.length) return json({ ...result, error: 'No se completaron todos los envíos.', message: errors[0].message }, 502);
      return json(result);
    } catch (error) { return json({ error: errorMessage(error) }, 500); }
  };
}
Deno.serve(createAlertHandler());
