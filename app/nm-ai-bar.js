/* NeedsMe "Your AIs" bar (web). Items 2, 9, 10, 13, 14.
   One small button at the top. Tap it: a drop-down (not full screen) with
   "Already logged in" (the same AI list as her phone and computers) and "Not logged in yet".
   The list is the shared one: Firestore users/{uid}/settings/aiaccounts (same shape as the apps' nm-shared.js). */
(function () {
  if (!/(^|\.)needsme\.xyz$|vercel\.app$|^localhost$|^127\.0\.0\.1$/.test(location.hostname)) return; // not inside the desktop/phone sign-in page
  const PROJ = 'needs-me-480ea';
  const MAIN = [
    { id: 'chatgpt', name: 'ChatGPT', url: 'https://chatgpt.com/' },
    { id: 'claude', name: 'Claude', url: 'https://claude.ai/' },
    { id: 'gemini', name: 'Gemini', url: 'https://gemini.google.com/app' },
    { id: 'copilot', name: 'Copilot', url: 'https://copilot.microsoft.com/' },
    { id: 'perplexity', name: 'Perplexity', url: 'https://www.perplexity.ai/' },
    { id: 'grok', name: 'Grok', url: 'https://grok.com/' },
  ];
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  let list = [], state = 'Loading your AIs…', open = false, user = null;

  async function authUser() {
    try {
      const dbs = indexedDB.databases ? await indexedDB.databases() : [{ name: 'firebaseLocalStorageDb' }];
      if (!dbs.some((d) => d.name === 'firebaseLocalStorageDb')) return null;
      return await new Promise((res) => {
        const q = indexedDB.open('firebaseLocalStorageDb');
        q.onerror = () => res(null);
        q.onsuccess = () => {
          try {
            const g = q.result.transaction('firebaseLocalStorage').objectStore('firebaseLocalStorage').getAll();
            g.onsuccess = () => { const u = g.result.find((x) => String(x.fbase_key).startsWith('firebase:authUser')); res(u && u.value && u.value.stsTokenManager ? u.value : null); };
            g.onerror = () => res(null);
          } catch { res(null); }
        };
      });
    } catch { return null; }
  }
  let tok = null;
  async function token(u) {
    const m = u.stsTokenManager;
    if (tok && tok.exp > Date.now() + 60000) return tok.t;
    if (m.expirationTime > Date.now() + 60000) { tok = { t: m.accessToken, exp: m.expirationTime }; return tok.t; }
    const r = await fetch('https://securetoken.googleapis.com/v1/token?key=' + u.apiKey, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: 'grant_type=refresh_token&refresh_token=' + encodeURIComponent(m.refreshToken) });
    const j = await r.json(); if (!j.id_token) throw new Error('sign-in expired');
    tok = { t: j.id_token, exp: Date.now() + (+j.expires_in || 3600) * 1000 }; return tok.t;
  }
  const docUrl = (uid) => `https://firestore.googleapis.com/v1/projects/${PROJ}/databases/(default)/documents/users/${uid}/settings/aiaccounts`;
  async function load() {
    user = await authUser();
    if (!user) { list = []; state = 'Sign in to see your AIs.'; return draw(); }
    try {
      const r = await fetch(docUrl(user.uid), { headers: { Authorization: 'Bearer ' + (await token(user)) } });
      if (r.status === 404) { list = []; state = ''; return draw(); }
      if (r.status === 429) { state = 'Your AI list could not load: the Needs Me server is over its daily limit. It works again after the reset.'; return draw(); }
      if (!r.ok) throw new Error('HTTP ' + r.status);
      const f = (await r.json()).fields || {};
      const j = JSON.parse((f.json || {}).stringValue || '{}');
      list = (Array.isArray(j) ? j : j.accounts || []); state = '';
    } catch (e) { state = 'Your AI list could not load (' + e.message + ').'; }
    draw();
  }
  async function addToList(ai) { // "log in" on the web = open the AI's site; this also puts it on her list everywhere
    window.open(ai.url, '_blank', 'noopener');
    if (!user) return;
    try {
      const now = Date.now();
      const a = { id: Math.random().toString(36).slice(2, 10), ai: ai.id, aiName: ai.name, url: ai.url, name: '', desc: '', emoji: '', img: '', color: '', nf: { done: true, needs: true, msgs: true }, use: { chats: true, needs: true, updates: true }, at: now, del: false };
      const t = await token(user);
      const r0 = await fetch(docUrl(user.uid), { headers: { Authorization: 'Bearer ' + t } });
      let cur = [];
      if (r0.ok) { const f = (await r0.json()).fields || {}; const j = JSON.parse((f.json || {}).stringValue || '{}'); cur = Array.isArray(j) ? j : j.accounts || []; }
      cur.push(a);
      const body = { fields: { json: { stringValue: JSON.stringify({ v: 1, accounts: cur }) }, updated: { integerValue: String(now) }, device: { stringValue: 'web' } } };
      const w = await fetch(docUrl(user.uid) + '?updateMask.fieldPaths=json&updateMask.fieldPaths=updated&updateMask.fieldPaths=device', { method: 'PATCH', headers: { Authorization: 'Bearer ' + t, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
      if (!w.ok) throw new Error('HTTP ' + w.status);
      list = cur;
    } catch (e) { state = 'Could not save it to your list (' + e.message + ').'; }
    draw();
  }
  function dot(a) {
    const bg = a.color || '#F0EAE0';
    const inner = a.img ? `<img src="${esc(a.img)}" alt="">` : esc(a.emoji || (a.aiName || a.ai || '?').slice(0, 1).toUpperCase());
    return `<span class="nmb-dot" style="background:${esc(bg)}">${inner}</span>`;
  }
  const title = (a) => (a.name && a.name !== 'Main' ? (a.aiName || a.ai) + ' · ' + a.name : (a.aiName || a.ai));
  function draw() {
    const live = list.filter((a) => !a.del);
    const rest = MAIN.filter((m) => !live.some((a) => a.ai === m.id));
    root.innerHTML = `<button class="nmb-btn" aria-expanded="${open}" aria-haspopup="true">Your AIs${live.length ? ' (' + live.length + ')' : ''} <span aria-hidden="true">▾</span></button>` +
      (open ? `<div class="nmb-menu" role="menu">
        ${state ? `<p class="nmb-note">${esc(state)}</p>` : ''}
        <div class="nmb-lab">Already logged in</div>
        ${live.length ? live.map((a, i) => `<a class="nmb-row" role="menuitem" href="${esc(a.url || '#')}" target="_blank" rel="noopener">${dot(a)}<span><b>${esc(title(a))}</b>${a.desc ? `<small>${esc(a.desc)}</small>` : ''}</span></a>`).join('') : `<p class="nmb-note">None yet. Log in to an AI below, or on your phone or computer. It shows here too.</p>`}
        <div class="nmb-lab">Not logged in yet</div>
        ${rest.map((m, i) => `<button class="nmb-row" role="menuitem" data-add="${i}"><span class="nmb-dot">${esc(m.name[0])}</span><span><b>${esc(m.name)}</b><small>Open and add to my list</small></span></button>`).join('')}
        <p class="nmb-note">Same list on your phone, the web and every computer. Each device signs in to each AI once.</p>
      </div>` : '');
    root.querySelector('.nmb-btn').onclick = () => { open = !open; draw(); if (open) load(); };
    root.querySelectorAll('[data-add]').forEach((b) => (b.onclick = () => addToList(rest[+b.dataset.add])));
  }
  const css = document.createElement('style');
  css.textContent = `#nm-ai-bar{position:fixed;top:12px;left:50%;transform:translateX(-50%);z-index:2147483000;font:14px/1.35 system-ui,-apple-system,Segoe UI,sans-serif}
  .nmb-btn{background:#16120E;color:#F0EAE0;border:0;border-radius:999px;padding:8px 14px;font-weight:600;cursor:pointer;box-shadow:0 2px 8px rgba(0,0,0,.15)}
  .nmb-menu{position:absolute;left:50%;transform:translateX(-50%);top:42px;width:300px;max-height:min(70vh,520px);overflow:auto;background:#fff;color:#16120E;border:1px solid #E5DED2;border-radius:14px;padding:8px;box-shadow:0 10px 30px rgba(0,0,0,.18)}
  .nmb-lab{font-size:12px;color:#6B6252;margin:10px 8px 4px}
  .nmb-row{display:flex;gap:10px;align-items:center;width:100%;text-align:left;background:none;border:0;padding:8px;border-radius:10px;color:inherit;text-decoration:none;cursor:pointer;font:inherit}
  .nmb-row:hover,.nmb-row:focus{background:#F0EAE0;outline:none}
  .nmb-row small{display:block;color:#6B6252;font-size:12px}
  .nmb-dot{flex:none;width:30px;height:30px;border-radius:50%;display:grid;place-items:center;overflow:hidden;background:#F0EAE0;font-weight:700}
  .nmb-dot img{width:100%;height:100%;object-fit:cover}
  .nmb-note{font-size:12.5px;color:#6B6252;margin:6px 8px}
  @media (max-width:520px){.nmb-menu{width:calc(100vw - 24px)}}`;
  const root = document.createElement('div'); root.id = 'nm-ai-bar';
  document.addEventListener('click', (e) => { if (open && !e.composedPath().includes(root)) { open = false; draw(); } });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && open) { open = false; draw(); } });
  const start = () => { document.head.appendChild(css); document.body.appendChild(root); draw(); load(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);
})();
