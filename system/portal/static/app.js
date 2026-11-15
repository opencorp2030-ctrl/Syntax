import RFB from './vendor/novnc/core/rfb.js';

const $ = (id) => document.getElementById(id);
const wsBase = (location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host;
let currentTab = 'home';
let statusTimer = null;

async function api(path, data) {
  const opt = data === undefined ? {} : {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
  };
  let res;
  try {
    res = await fetch(path, { credentials: 'same-origin', ...opt });
  } catch (e) {
    return { ok: false, error: 'Connexion au Pi impossible.', status: 0 };
  }
  let json = {};
  try { json = await res.json(); } catch (e) { /* réponse vide */ }
  json.status = res.status;
  if (res.status === 401 && path !== '/api/login') showLogin();
  return json;
}

// ---------------------------------------------------------------- connexion
function showLogin() {
  clearInterval(statusTimer);
  closeTerm(); closeScreen();
  $('view-app').hidden = true;
  $('view-login').hidden = false;
  $('login-user').focus();
}

function showApp(user) {
  $('view-login').hidden = true;
  $('view-app').hidden = false;
  $('login-pass').value = $('login-new').value = $('login-new2').value = '';
  $('login-change').hidden = true;
  $('login-error').textContent = '';
  refreshStatus();
  clearInterval(statusTimer);
  statusTimer = setInterval(() => { if (!document.hidden && currentTab === 'home') refreshStatus(); }, 3000);
  selectTab(currentTab);
}

$('login-form').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  const payload = { username: $('login-user').value.trim(), password: $('login-pass').value };
  if (!$('login-change').hidden) {
    if ($('login-new').value !== $('login-new2').value) {
      $('login-error').textContent = 'Les deux mots de passe ne correspondent pas.';
      return;
    }
    payload.new_password = $('login-new').value;
  }
  $('login-error').textContent = '';
  const r = await api('/api/login', payload);
  if (r.ok) { showApp(r.user); return; }
  if (r.must_change) {
    const first = $('login-change').hidden;
    $('login-change').hidden = false;
    $('login-error').textContent = first ? '' : (r.error || '');
    if (first) $('login-new').focus();
    return;
  }
  $('login-error').textContent = r.error || 'Connexion impossible.';
});

$('logout').addEventListener('click', async () => { await api('/api/logout', {}); showLogin(); });

// ------------------------------------------------------------------ onglets
function selectTab(name) {
  currentTab = name;
  for (const b of $('tabs').children) b.classList.toggle('on', b.dataset.tab === name);
  for (const t of ['home', 'screen', 'term', 'net']) $('tab-' + t).hidden = t !== name;
  if (name === 'home') refreshStatus();
  if (name === 'term') openTerm();
  if (name === 'screen') openScreen();
  if (name === 'net') refreshTunnel();
}
$('tabs').addEventListener('click', (ev) => { if (ev.target.dataset.tab) selectTab(ev.target.dataset.tab); });
document.querySelectorAll('[data-go]').forEach((b) => b.addEventListener('click', () => selectTab(b.dataset.go)));

// ------------------------------------------------------------------- aperçu
const gb = (n) => (n / 1073741824).toFixed(1).replace('.', ',') + ' Go';
function meter(id, pct) {
  const el = $(id);
  el.style.width = Math.max(0, Math.min(100, pct)) + '%';
  el.className = pct > 90 ? 'crit' : pct > 75 ? 'warn' : '';
}
function duration(s) {
  const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
  return (d ? d + ' j ' : '') + (h ? h + ' h ' : '') + m + ' min';
}

async function refreshStatus() {
  const s = await api('/api/status');
  if (s.status !== 200) return;
  $('bar-host').textContent = s.hostname;
  document.title = s.hostname + ' — Syntax Connect';
  const cpu = Math.min(100, Math.round(s.load[0] / s.cpus * 100));
  $('s-cpu').textContent = cpu + ' %'; meter('m-cpu', cpu);
  $('s-load').textContent = 'Charge ' + s.load.join(' · ') + ' — ' + s.cpus + ' cœurs';
  if (s.temp === null) { $('s-temp').textContent = '–'; } else {
    $('s-temp').textContent = String(s.temp).replace('.', ',') + ' °C'; meter('m-temp', (s.temp - 30) / 55 * 100);
  }
  const mem = s.mem_total ? s.mem_used / s.mem_total * 100 : 0;
  $('s-mem').textContent = Math.round(mem) + ' %'; meter('m-mem', mem);
  $('s-mem2').textContent = gb(s.mem_used) + ' sur ' + gb(s.mem_total);
  const disk = s.disk_total ? s.disk_used / s.disk_total * 100 : 0;
  $('s-disk').textContent = Math.round(disk) + ' %'; meter('m-disk', disk);
  $('s-disk2').textContent = gb(s.disk_used) + ' sur ' + gb(s.disk_total);
  const rows = [
    ['Machine', s.hostname], ['Modèle', s.model], ['Système', s.os], ['Noyau', s.kernel],
    ['Allumé depuis', duration(s.uptime)], ['Utilisateur', s.user],
    ['Adresses locales', s.ips.map((i) => i.ip + ' (' + i.dev + ')').join(', ') || '–'],
    ['Session graphique', s.screen ? 'Disponible' : 'Non démarrée'],
  ];
  const dl = $('s-info');
  dl.replaceChildren();
  for (const [k, v] of rows) {
    const dt = document.createElement('dt'); dt.textContent = k;
    const dd = document.createElement('dd'); dd.textContent = v;
    dl.append(dt, dd);
  }
  $('headless').checked = !!s.headless;
}

$('btn-reboot').addEventListener('click', () => {
  if (confirm('Redémarrer le Pi maintenant ?')) api('/api/power', { action: 'reboot' });
});
$('btn-off').addEventListener('click', () => {
  if (confirm('Éteindre le Pi ? Il faudra le rallumer physiquement.')) api('/api/power', { action: 'poweroff' });
});
$('headless').addEventListener('change', (ev) => api('/api/headless', { enabled: ev.target.checked }));
$('pw-form').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  const r = await api('/api/password', { old: $('pw-old').value, new: $('pw-new').value });
  $('pw-msg').textContent = r.ok ? 'Mot de passe modifié.' : (r.error || 'Échec.');
  if (r.ok) ev.target.reset();
});

// ----------------------------------------------------------------- terminal
let term = null, termFit = null, termWs = null;

function openTerm() {
  if (!term) {
    term = new window.Terminal({
      cursorBlink: true, fontSize: 14, scrollback: 5000,
      fontFamily: 'ui-monospace, "SF Mono", Menlo, "DejaVu Sans Mono", Consolas, monospace',
      theme: { background: '#16161a', foreground: '#e8e8ed', cursor: '#0a84ff' },
    });
    termFit = new window.FitAddon.FitAddon();
    term.loadAddon(termFit);
    term.open($('term-box'));
    term.onData((d) => { if (termWs && termWs.readyState === 1) termWs.send(new TextEncoder().encode(d)); });
    term.onResize(sendTermSize);
    new ResizeObserver(() => { if (currentTab === 'term') termFit.fit(); }).observe($('term-box'));
  }
  termFit.fit();
  term.focus();
  if (!termWs || termWs.readyState > 1) connectTerm();
}

function sendTermSize() {
  if (termWs && termWs.readyState === 1) termWs.send(JSON.stringify({ type: 'resize', cols: term.cols, rows: term.rows }));
}

function connectTerm() {
  $('term-state').textContent = 'Connexion…';
  const ws = new WebSocket(wsBase + '/ws/term');
  ws.binaryType = 'arraybuffer';
  termWs = ws;
  ws.onopen = () => { $('term-state').textContent = 'Connecté'; term.reset(); sendTermSize(); };
  ws.onmessage = (ev) => { if (typeof ev.data !== 'string') term.write(new Uint8Array(ev.data)); };
  ws.onclose = () => {
    if (termWs !== ws) return;
    $('term-state').textContent = 'Session terminée';
    term.write('\r\n\x1b[2m[session terminée — « Nouvelle session » pour relancer]\x1b[0m\r\n');
  };
}

function closeTerm() {
  if (termWs) { const w = termWs; termWs = null; w.close(); }
}
$('term-new').addEventListener('click', () => { closeTerm(); connectTerm(); term.focus(); });

// -------------------------------------------------------------------- écran
let rfb = null;

function openScreen() {
  if (rfb) { rfb.focus(); return; }
  $('screen-state').textContent = 'Connexion…';
  $('screen-msg').textContent = '';
  try {
    rfb = new RFB($('screen-box'), wsBase + '/ws/screen', { wsProtocols: ['binary'] });
  } catch (e) {
    $('screen-msg').textContent = 'Impossible de démarrer le partage d\'écran.';
    return;
  }
  const mine = rfb;
  rfb.scaleViewport = true;
  rfb.resizeSession = false;
  rfb.background = '#111';
  rfb.addEventListener('connect', () => { $('screen-state').textContent = 'Connecté'; mine.focus(); });
  rfb.addEventListener('disconnect', () => {
    if (rfb !== mine) return;
    rfb = null;
    $('screen-state').textContent = 'Déconnecté';
    $('screen-msg').textContent = 'Écran indisponible. Vérifie qu\'une session graphique est ouverte sur le Pi, puis clique sur « Reconnecter ».';
  });
  rfb.addEventListener('securityfailure', () => { $('screen-msg').textContent = 'Connexion à l\'écran refusée.'; });
}

function closeScreen() {
  if (rfb) { const r = rfb; rfb = null; r.disconnect(); }
}
$('screen-reconnect').addEventListener('click', () => { closeScreen(); setTimeout(openScreen, 200); });
$('screen-cad').addEventListener('click', () => { if (rfb) rfb.sendCtrlAltDel(); });
$('screen-full').addEventListener('click', () => {
  const el = $('screen-box');
  if (document.fullscreenElement) document.exitFullscreen(); else if (el.requestFullscreen) el.requestFullscreen();
});
$('screen-paste').addEventListener('click', async () => {
  if (!rfb) return;
  try {
    rfb.clipboardPasteFrom(await navigator.clipboard.readText());
    $('screen-state').textContent = 'Presse-papiers envoyé — colle avec Ctrl+V sur le Pi';
  } catch (e) {
    $('screen-state').textContent = 'Accès au presse-papiers refusé par le navigateur';
  }
});

// ------------------------------------------------------------ accès Internet
let tunnelPoll = null;

function actionButton(label, fn, cls) {
  const b = document.createElement('button');
  b.textContent = label; if (cls) b.className = cls;
  b.addEventListener('click', async () => { b.disabled = true; await fn(); refreshTunnel(); });
  return b;
}

async function refreshTunnel() {
  const t = await api('/api/tunnel');
  if (t.status !== 200) return;
  const badge = $('net-badge'), sum = $('net-summary'), acts = $('net-actions');
  acts.replaceChildren();
  $('tok-target').textContent = 'http://localhost:' + t.port;
  badge.className = 'badge';
  if (!t.installed) {
    badge.textContent = 'Indisponible'; sum.textContent = 'cloudflared n\'est pas installé sur ce système.';
  } else if (t.mode === 'none') {
    badge.textContent = 'Non configuré';
    sum.textContent = 'Ce Pi n\'est accessible que sur ton réseau local. Choisis une méthode ci-dessous pour y accéder de partout.';
  } else if (t.active) {
    badge.textContent = 'Actif'; badge.classList.add('ok');
    sum.textContent = t.hostname ? 'Ton Pi est accessible à l\'adresse https://' + t.hostname
      : 'Tunnel connecté. L\'adresse publique est celle définie dans ton tableau de bord Cloudflare.';
    acts.append(actionButton('Suspendre', () => api('/api/tunnel/disable', {})),
      actionButton('Supprimer la configuration', () => api('/api/tunnel/disable', { reset: true }), 'danger'));
  } else {
    badge.textContent = t.enabled ? 'En attente' : 'Suspendu'; badge.classList.add('warn');
    sum.textContent = t.blocked_default_password
      ? 'Le tunnel reste bloqué tant qu\'un compte utilise le mot de passe d\'usine.'
      : (t.enabled ? 'Le tunnel démarre ou n\'arrive pas à joindre Cloudflare (état : ' + t.state + ').' : 'Le tunnel est configuré mais désactivé.');
    acts.append(actionButton(t.enabled ? 'Relancer' : 'Activer', () => api('/api/tunnel/enable', {}), 'primary'),
      actionButton('Supprimer la configuration', () => api('/api/tunnel/disable', { reset: true }), 'danger'));
  }
  $('cf-state').textContent = t.login.done ? '✓ Autorisation reçue.' : (t.login.running ? 'En attente de ton autorisation…' : '');
  clearTimeout(tunnelPoll);
  if (currentTab === 'net' && (t.login.running || (t.enabled && !t.active))) tunnelPoll = setTimeout(refreshTunnel, 3000);
}

$('cf-start').addEventListener('click', async () => {
  $('cf-link').textContent = 'Demande en cours…';
  const r = await api('/api/tunnel/login/start', {});
  const box = $('cf-link');
  box.replaceChildren();
  if (r.ok && /^https:\/\/dash\.cloudflare\.com\//.test(r.url)) {
    const a = document.createElement('a');
    a.href = r.url; a.target = '_blank'; a.rel = 'noopener noreferrer'; a.textContent = 'Ouvrir la page d\'autorisation Cloudflare';
    box.append(a);
  } else {
    box.textContent = r.error || 'Échec.';
  }
  refreshTunnel();
});
$('cf-finish').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  $('cf-msg').textContent = 'Création du tunnel…';
  const r = await api('/api/tunnel/login/finish', { hostname: $('cf-host').value });
  $('cf-msg').textContent = r.ok ? r.message : (r.error || 'Échec.');
  refreshTunnel();
});
$('tok-form').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  const r = await api('/api/tunnel/token', { token: $('tok').value });
  $('tok-msg').textContent = r.ok ? r.message : (r.error || 'Échec.');
  if (r.ok) $('tok').value = '';
  refreshTunnel();
});

// ---------------------------------------------------------------- démarrage
(async () => {
  const s = await api('/api/session');
  if (s.hostname) $('login-host').textContent = 'Connexion à « ' + s.hostname + ' »';
  if (s.user) showApp(s.user); else showLogin();
})();
