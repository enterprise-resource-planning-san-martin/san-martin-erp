// Invitación y recuperación de contraseña para el sitio público del ERP.
const ERP_AUTH_REDIRECT = 'https://enterprise-resource-planning-san-martin.github.io/san-martin-erp/';
let passwordSetupShown = false;

function showAuthPanel(panel) {
  $('#auth-view').classList.remove('hidden');
  $('#app-view').classList.add('hidden');
  $('#login-form').classList.toggle('hidden', panel !== 'login');
  $('#recovery-request-form').classList.toggle('hidden', panel !== 'recovery');
  $('#password-setup-form').classList.toggle('hidden', panel !== 'password');
  $('#forgot-password').classList.toggle('hidden', panel !== 'login');
  $('#back-to-login').classList.toggle('hidden', panel === 'login' || panel === 'password');
  $('#auth-title').textContent = panel === 'password'
    ? (AUTH_CALLBACK_TYPE === 'invite' ? 'Crea tu contraseña' : 'Restablece tu contraseña')
    : panel === 'recovery' ? 'Recuperar acceso' : 'Ingresa a San Martín';
  $('#auth-help').textContent = panel === 'password'
    ? 'Después de guardarla podrás entrar con tu correo.'
    : 'El acceso está protegido por los permisos de tu organización.';
}

function showPasswordSetup() {
  passwordSetupShown = true;
  showAuthPanel('password');
}

document.addEventListener('DOMContentLoaded', () => {
  $('#forgot-password').addEventListener('click', () => showAuthPanel('recovery'));
  $('#back-to-login').addEventListener('click', () => showAuthPanel('login'));
  $('#recovery-request-form').addEventListener('submit', async event => {
    event.preventDefault();
    const button = event.submitter;
    if (button.disabled) return;
    button.disabled = true;
    const email = $('#recovery-email').value.trim();
    const { error } = await db.auth.resetPasswordForEmail(email, { redirectTo: ERP_AUTH_REDIRECT });
    button.disabled = false;
    if (error) { toast(error.message, true); return; }
    showAuthPanel('login');
    toast('Si el correo tiene una cuenta, recibirás un enlace para cambiar tu contraseña.');
  });
  $('#password-setup-form').addEventListener('submit', async event => {
    event.preventDefault();
    const password = $('#new-password').value;
    if (password !== $('#confirm-password').value) {
      toast('Las contraseñas no coinciden.', true); return;
    }
    const button = event.submitter;
    if (button.disabled) return;
    button.disabled = true;
    const { data, error } = await db.auth.updateUser({ password });
    button.disabled = false;
    if (error) { toast(error.message, true); return; }
    passwordSetupShown = false;
    history.replaceState(null, '', location.pathname + location.search);
    $('#new-password').value = '';
    $('#confirm-password').value = '';
    const user = data?.user || (await db.auth.getUser()).data.user;
    if (user) await enterApp(user);
    else {
      showAuthPanel('login');
      toast('Contraseña guardada. Inicia sesión con tu correo.');
    }
  });
});
