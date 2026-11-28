const { nativeTheme, app, BrowserWindow, WebContentsView, ipcMain, session, Notification, shell, nativeImage } = require('electron');
const path = require('path'), fs = require('fs');
const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
nativeTheme.themeSource = 'light';
app.userAgentFallback = UA; // looks like a normal browser so Apple/Google sign-in pages accept it
app.setName('NeedsMe');
const APP_URL = 'https://support897.github.io/needsme/app/'; // real Needs Me sign-in: Apple, Google, email
const AUTH_PART = 'persist:nm-account';
let win, hubView, authView, views = {}, store = {}, status = {}, queues = {};
let signedIn = false, checking = true, accountMode = false, user = null, prefs = { ask: true, stop: true };
const catalog = JSON.parse(fs.readFileSync(path.join(__dirname, 'catalog.json')));
const file = () => path.join(app.getPath('userData'), 'needsme.json');
const load = () => { try { return JSON.parse(fs.readFileSync(file())); } catch { return {}; } };
const persist = () => { try { fs.writeFileSync(file(), JSON.stringify(store)); } catch (e) { console.error(e); } };
const sleep = (ms) => new Promise(r => setTimeout(r, ms));
const accounts = () => store.accounts || [];
const accOf = (id) => accounts().find(a => a.id === id);
const baseOf = (id) => { const a = accOf(id) || {}; return a.url || (catalog.find(c => c.id === a.ai) || {}).url || 'https://muse.ai/'; };
const send = (ch, d) => { try { hubView.webContents.send(ch, d); } catch {} };

// ---------- one saved login per AI account (own cookie jar) ----------
function viewFor(id, base) {
  if (views[id]) return views[id];
  const v = new WebContentsView({ webPreferences: { partition: 'persist:muse-' + id } });
  const wc = v.webContents;
  wc.setWindowOpenHandler(({ url }) => {
    if (!/^https?:/i.test(url)) { if (/^mailto:/i.test(url)) shell.openExternal(url); return { action: 'deny' }; }
    // Item 6: real pop-up window, same saved login as this AI account, opener kept (sign-in and share pop-ups work).
    return { action: 'allow', overrideBrowserWindowOptions: { width: 900, height: 760, autoHideMenuBar: true, title: 'NeedsMe', backgroundColor: '#FFFFFF' } };
  });
  wc.on('did-create-window', (child) => { child.webContents.setWindowOpenHandler(({ url }) => /^https?:/i.test(url) ? { action: 'allow' } : { action: 'deny' }); });
  wc.loadURL(base || baseOf(id));
  v.setVisible(false); win.contentView.addChildView(v); views[id] = v;
  return v;
}
function hideViews() { for (const v of Object.values(views)) v.setVisible(false); }
ipcMain.handle('viewShow', (_e, { id, rect, href, base }) => {
  if (!signedIn || accountMode) return;
  const v = viewFor(id, base), wc = v.webContents;
  for (const [k, o] of Object.entries(views)) if (k !== id) o.setVisible(false);
  v.setBounds({ x: Math.round(rect.x), y: Math.round(rect.y), width: Math.round(rect.width), height: Math.round(rect.height) });
  v.setVisible(true); win.contentView.addChildView(v);
  if (href) { try { const u = new URL(href, wc.getURL() || base).href; if (u !== wc.getURL()) wc.loadURL(u); } catch {} }
});
ipcMain.handle('viewHide', () => hideViews());
ipcMain.handle('rmAccount', async (_e, id) => {
  if (views[id]) { win.contentView.removeChildView(views[id]); try { views[id].webContents.close(); } catch {} delete views[id]; }
  delete status[id];
  await session.fromPartition('persist:muse-' + id).clearStorageData();
});

// ---------- type a message into a real AI page and read the answer ----------
async function askPage({ id, base, text, fresh }) {
  const v = viewFor(id, base), wc = v.webContents, b = base || baseOf(id);
  if (fresh || !wc.getURL() || wc.getURL() === 'about:blank') { await wc.loadURL(b).catch(() => {}); await sleep(3500); }
  const body = () => wc.executeJavaScript('document.body.innerText');
  const before = await body();
  wc.focus();
  const found = await wc.executeJavaScript(`(()=>{const el=[...document.querySelectorAll('textarea,[contenteditable="true"],[role="textbox"]')].filter(e=>e.offsetParent).pop();if(!el)return false;el.focus();return true})()`);
  if (!found) throw new Error('Cannot find the message box. Open this AI once and make sure you are logged in.');
  wc.insertText(text); await sleep(500);
  wc.sendInputEvent({ type: 'keyDown', keyCode: 'Return' }); wc.sendInputEvent({ type: 'keyUp', keyCode: 'Return' });
  let last = '', stable = 0; const t0 = Date.now();
  await sleep(3000);
  while (Date.now() - t0 < 5 * 60 * 1000) {
    const now = await body();
    if (now === last && now !== before) stable++; else stable = 0;
    last = now; if (stable >= 4) break; await sleep(2000);
  }
  const tail = text.slice(-40), i = last.lastIndexOf(tail);
  return (i >= 0 ? last.slice(i + tail.length) : last.slice(before.length)).trim() || '(no answer found)';
}
ipcMain.handle('ask', (_e, a) => { // one job at a time per account
  const q = (queues[a.id] || Promise.resolve()).catch(() => {}).then(() => askPage(a));
  queues[a.id] = q;
  return q.then(text => ({ ok: true, text }), err => ({ ok: false, error: err.message }));
});

// ---------- every minute: read each AI page. Needs you? Stopped? Signed out? ----------
const SCAN = `(()=>{
  const out={convos:[],needs:[],signedOut:false};
  const seen=new Set();
  for(const a of document.querySelectorAll('nav a[href], aside a[href]')){const t=(a.innerText||'').trim().split('\\n')[0];if(!t||t.length<3||seen.has(a.href)||/^(new|search|settings|upgrade|home|log ?in|sign ?up)/i.test(t))continue;seen.add(a.href);out.convos.push({title:t.slice(0,80),href:a.href});if(out.convos.length>=40)break}
  const btns=[...document.querySelectorAll('button,[role=button]')].filter(b=>b.offsetParent).map(b=>(b.innerText||'').trim()).filter(Boolean);
  const tail=(document.body.innerText||'').slice(-700);
  const ok=btns.find(b=>/^(approve|allow|allow once|always allow|confirm|accept|yes, proceed)\\b/i.test(b));
  if(ok)out.needs.push({kind:'needs',why:'Waiting for your OK ('+ok+')'});
  const lim=tail.match(/(usage limit|rate limit|limit reached|reached (your|the) (message|usage)|try again later|something went wrong|network error|upgrade to continue|out of (credits|messages)|too many requests)/i);
  if(lim)out.needs.push({kind:'stopped',why:'Stopped: "'+lim[0]+'"'});
  out.tail=tail;
  const LAST=['[data-message-author-role="assistant"]','.font-claude-response','[data-is-streaming]','.font-claude-message','message-content','model-response','[data-testid="bot-message"]','[data-content="ai-message"]','.prose','.markdown'];
  for(const q of LAST){const els=[...document.querySelectorAll(q)].filter(e=>(e.innerText||'').trim());if(els.length){out.last=(els[els.length-1].innerText||'').trim();out.lastN=els.length;break}}
  out.busy=!![...document.querySelectorAll('button,[role=button]')].find(b=>b.offsetParent&&(/^(stop|stop generating|stop response)$/i.test((b.innerText||'').trim())||/^stop/i.test(b.getAttribute('aria-label')||'')));
  const hasBox=document.querySelector('textarea,[contenteditable=true],[role=textbox]');
  if(!hasBox&&btns.some(b=>/^(log ?in|sign ?in|continue with)/i.test(b)))out.signedOut=true;
  return out})()`;
function notify(title, body, id, url) {
  if (!Notification.isSupported() || !body) return;
  const n = new Notification({ title, body: String(body).slice(0, 1000) });
  n.on('click', () => { win.show(); send('navigate', { id, url }); });
  n.show();
}
async function scanOne(a) {
  const v = views[a.id]; if (!v) return;
  const wc = v.webContents; if (wc.isLoading()) return;
  let r; try { r = await wc.executeJavaScript(SCAN); } catch { return; }
  const prev = status[a.id] || { keys: [], dismissed: {} }, url = wc.getURL();
  // Item 5: title = which AI and which account, body = the AI's exact words.
  const c = catalog.find(x => x.id === a.ai) || {}, aiName = a.ai === 'custom' ? (a.label || 'AI') : (c.name || a.ai || 'AI');
  const name = a.ai === 'custom' || !a.label ? aiName : aiName + ' \u00b7 ' + a.label;
  const nf = a.nf || {}, use = a.use || {};
  if (use.chats === false) r.convos = [];
  if (use.needs === false) r.needs = []; const dismissed = prev.tail === r.tail ? prev.dismissed : {};
  let items = r.signedOut ? [{ kind: 'login', why: 'Signed out. Tap to log in.' }] : [];
  items.push(...r.needs);
  const lines = (r.tail || '').split('\n').map(s => s.trim()).filter(Boolean);
  const lastQ = lines.slice(-4).reverse().find(l => /\?\s*$/.test(l) && l.length > 8);
  if (!r.signedOut && !r.busy && lastQ && prev.tail === r.tail) items.push({ kind: 'question', why: lastQ.slice(0, 300) }); // idle for 2 checks + ends with "?"
  items = items.filter(i => !dismissed[i.why]).map(i => ({ ...i, url, at: (prev.items || []).find(p => p.why === i.why)?.at || Date.now() }));
  for (const i of items) if (!prev.keys.includes(i.why)) {
    if (use.needs === false) continue;
    if (i.kind === 'question' && prefs.ask && nf.needs !== false) notify(name, r.last || i.why, a.id, url);
    else if (i.kind !== 'question' && prefs.stop && nf.needs !== false) notify(name, i.why, a.id, url);
  }
  // A new reply = the AI's last message changed and it is not typing any more. One alert per reply, with its exact text.
  if (!r.signedOut && prev.last !== undefined && !r.busy && r.last && r.last !== prev.last && r.last !== prev.notified) {
    const asked = items.some(i => i.kind === 'question');
    if (!asked && ((prev.busy && nf.done !== false) || (!prev.busy && nf.msgs !== false && !win.isFocused()))) { notify(name, r.last, a.id, url); r.notified = r.last; }
    if (r.last !== prev.last && r.last !== prev.loggedLast && use.updates !== false) { send('aiupdate', { id: a.id, text: r.last.slice(0, 400) }); r.loggedLast = r.last; }
  }
  status[a.id] = { busy: r.busy, keys: items.map(i => i.why), items, convos: r.convos, tail: r.tail, last: r.last || prev.last || '', notified: r.notified || prev.notified, loggedLast: r.loggedLast || prev.loggedLast, dismissed };
  send('status');
}
async function scanAll() { for (const a of accounts()) await scanOne(a); }
ipcMain.handle('status', () => status);
ipcMain.handle('rescan', () => scanAll());
ipcMain.handle('dismiss', (_e, { id, why }) => { const s = status[id]; if (!s) return; s.dismissed[why] = true; s.items = s.items.filter(i => i.why !== why); s.keys = s.items.map(i => i.why); send('status'); });
ipcMain.handle('reply', async (_e, { id, base, url, text }) => { // answer a question straight from the Needs Me card
  const wc = viewFor(id, base).webContents;
  if (url && url !== wc.getURL()) { await wc.loadURL(url).catch(() => {}); await sleep(2500); }
  wc.focus();
  const ok = await wc.executeJavaScript(`(()=>{const el=[...document.querySelectorAll('textarea,[contenteditable="true"],[role="textbox"]')].filter(e=>e.offsetParent).pop();if(!el)return false;el.focus();return true})()`);
  if (!ok) return { ok: false, error: 'Cannot find the message box. Open the chat and make sure you are logged in.' };
  wc.insertText(text); await sleep(300);
  wc.sendInputEvent({ type: 'keyDown', keyCode: 'Return' }); wc.sendInputEvent({ type: 'keyUp', keyCode: 'Return' });
  const s = status[id]; if (s) { const q = s.items.find(i => i.kind === 'question'); if (q) s.dismissed[q.why] = true; s.items = s.items.filter(i => i.kind !== 'question'); s.keys = s.items.map(i => i.why); send('status'); }
  return { ok: true };
});


// ---------- Google sign-in through the user's real browser, back via needsme:// ----------
const crypto = require('crypto');
let pendingNonce = null, pendingAt = 0;
function startGoogle() {
  pendingNonce = crypto.randomBytes(24).toString('hex'); pendingAt = Date.now();
  shell.openExternal('https://support897.github.io/needsme/desktop-signin.html?state=' + pendingNonce);
}
async function finishGoogle(link) {
  try {
    const u = new URL(link);
    const st = u.searchParams.get('state'), blob = u.hash.slice(1);
    if (!pendingNonce || st !== pendingNonce || Date.now() - pendingAt > 10 * 60 * 1000 || !blob) return; // wrong or old: ignore
    pendingNonce = null;
    const val = JSON.parse(Buffer.from(blob.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8'));
    if (!val.uid || !val.stsTokenManager || !val.apiKey) return;
    await authView.webContents.executeJavaScript(`(async()=>{const v=${JSON.stringify(val)};
      await new Promise((res,rej)=>{const q=indexedDB.open('firebaseLocalStorageDb');
        q.onupgradeneeded=()=>q.result.createObjectStore('firebaseLocalStorage',{keyPath:'fbase_key'});
        q.onerror=()=>rej(q.error);
        q.onsuccess=()=>{const t=q.result.transaction('firebaseLocalStorage','readwrite');
          t.objectStore('firebaseLocalStorage').put({fbase_key:'firebase:authUser:'+v.apiKey+':[DEFAULT]',value:v});
          t.oncomplete=res;t.onerror=()=>rej(t.error)}})})()`);
    authView.webContents.loadURL(APP_URL);
    if (win) { if (win.isMinimized()) win.restore(); win.show(); win.focus(); }
  } catch {}
}
app.setAsDefaultProtocolClient('needsme');
app.on('open-url', (e, link) => { e.preventDefault(); finishGoogle(link); });

// ---------- Needs Me account (Apple / Google / email), saved on this Mac until log out ----------
function makeAuth() {
  authView = new WebContentsView({ webPreferences: { partition: AUTH_PART } });
  const wc = authView.webContents;
  wc.setWindowOpenHandler(({ url }) => {
    if (/providerId=google\.com|accounts\.google\.com/.test(url)) { startGoogle(); return { action: 'deny' }; } // Google blocks embedded browsers: use the real browser
    return { action: 'allow', overrideBrowserWindowOptions: { width: 520, height: 720, autoHideMenuBar: true } };
  });
  authView.setBackgroundColor('#FFFFFF');
  wc.on('dom-ready',()=>wc.executeJavaScript("document.documentElement.style.colorScheme='light'").catch(()=>{}));
  wc.loadURL(APP_URL); win.contentView.addChildView(authView);
  wc.on('did-finish-load', checkUser);
}
async function readUser() {
  try {
    return await authView.webContents.executeJavaScript(`(async()=>{
      const dbs=await indexedDB.databases(); if(!dbs.some(d=>d.name==='firebaseLocalStorageDb')) return null;
      return await new Promise(r=>{const q=indexedDB.open('firebaseLocalStorageDb');q.onerror=()=>r(null);q.onsuccess=()=>{try{
        const g=q.result.transaction('firebaseLocalStorage').objectStore('firebaseLocalStorage').getAll();
        g.onsuccess=()=>{const u=g.result.find(x=>String(x.fbase_key).startsWith('firebase:authUser'));r(u&&u.value?{email:u.value.email||'',name:u.value.displayName||''}:null)};
        g.onerror=()=>r(null)}catch(e){r(null)}}})})()`);
  } catch { return null; }
}
async function checkUser() {
  if (!authView) return;
  const u = await readUser(); checking = false;
  const was = signedIn; signedIn = !!u; user = u;
  if (!signedIn) accountMode = false;
  applyGate();
  if (was !== signedIn) { send('user', user); if (signedIn) setTimeout(syncNow, 1500); }
}
function applyGate() {
  if (!win || !authView) return;
  const [w, h] = win.getContentSize();
  if (checking) { authView.setVisible(false); hubView.setVisible(false); hideViews(); return; }
  if (!signedIn) { hideViews(); hubView.setVisible(false); authView.setVisible(true); authView.setBounds({ x: 0, y: 0, width: w, height: h }); win.contentView.addChildView(authView); return; }
  if (accountMode) {
    hideViews(); authView.setVisible(true); authView.setBounds({ x: 0, y: 44, width: w, height: h - 44 });
    hubView.setVisible(true); hubView.setBounds({ x: 0, y: 0, width: w, height: 44 });
    win.contentView.addChildView(authView); win.contentView.addChildView(hubView); send('mode', 'account'); return;
  }
  authView.setVisible(false); hubView.setVisible(true); hubView.setBounds({ x: 0, y: 0, width: w, height: h }); send('mode', 'hub');
}
ipcMain.handle('user', () => user);
ipcMain.handle('account', () => { accountMode = true; applyGate(); });
ipcMain.handle('accountBack', async () => { accountMode = false; await checkUser(); applyGate(); });
ipcMain.handle('logout', async () => {
  await session.fromPartition(AUTH_PART).clearStorageData();
  accountMode = false; signedIn = false; user = null; authView.webContents.loadURL(APP_URL); applyGate(); send('user', null);
});


// ---------- cloud sync: same Needs Me account on every device (Firestore, users/{uid}/settings/desktop) ----------
const FB_KEY = 'AIzaSyD3pfsSI-NpEPZgZhk4jiqdIZjyfmbkTVs', FB_PROJ = 'needs-me-480ea';
let syncInfo = { state: 'waiting', at: 0, msg: 'Waiting for sign in' }, pushT = null, syncing = false, tok = null;
const setSync = (state, msg) => { syncInfo = { state, at: Date.now(), msg }; send('syncstate', syncInfo); };
async function readAuthRaw() {
  try {
    return await authView.webContents.executeJavaScript(`(async()=>{
      const dbs=await indexedDB.databases(); if(!dbs.some(d=>d.name==='firebaseLocalStorageDb')) return null;
      return await new Promise(r=>{const q=indexedDB.open('firebaseLocalStorageDb');q.onerror=()=>r(null);q.onsuccess=()=>{try{
        const g=q.result.transaction('firebaseLocalStorage').objectStore('firebaseLocalStorage').getAll();
        g.onsuccess=()=>{const u=g.result.find(x=>String(x.fbase_key).startsWith('firebase:authUser'));const v=u&&u.value;r(v&&v.stsTokenManager?{uid:v.uid,rt:v.stsTokenManager.refreshToken,at:v.stsTokenManager.accessToken,exp:v.stsTokenManager.expirationTime}:null)};
        g.onerror=()=>r(null)}catch(e){r(null)}}})})()`);
  } catch { return null; }
}
async function idToken() {
  if (tok && tok.exp > Date.now() + 60000) return tok;
  const a = await readAuthRaw(); if (!a) return null;
  if (a.exp > Date.now() + 60000) return (tok = { uid: a.uid, token: a.at, exp: a.exp });
  const r = await fetch('https://securetoken.googleapis.com/v1/token?key=' + FB_KEY, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: 'grant_type=refresh_token&refresh_token=' + encodeURIComponent(a.rt) });
  const j = await r.json(); if (!j.id_token) return null;
  return (tok = { uid: a.uid, token: j.id_token, exp: Date.now() + (+j.expires_in || 3600) * 1000 });
}
const docUrl = (uid) => `https://firestore.googleapis.com/v1/projects/${FB_PROJ}/databases/(default)/documents/users/${uid}/settings/desktop`;
function syncable() { const s = { ...store }; delete s._at; return s; }
async function pull(t) {
  const r = await fetch(docUrl(t.uid), { headers: { Authorization: 'Bearer ' + t.token } });
  if (r.status === 404) return null;
  if (!r.ok) throw new Error('read ' + r.status);
  const d = await r.json(), f = d.fields || {};
  return { at: +((f.updated || {}).integerValue || 0), json: (f.json || {}).stringValue || '' };
}
async function push(t) {
  const body = JSON.stringify(syncable());
  if (body.length > 900000) throw new Error('too big');
  const r = await fetch(docUrl(t.uid), { method: 'PATCH', headers: { Authorization: 'Bearer ' + t.token, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: { json: { stringValue: body }, updated: { integerValue: String(store._at || Date.now()) }, device: { stringValue: process.platform } } }) });
  if (!r.ok) throw new Error('write ' + r.status);
}
async function syncNow() {
  if (syncing || !signedIn) return; syncing = true;
  try {
    const t = await idToken(); if (!t) { setSync('waiting', 'Waiting for sign in'); return; }
    const remote = await pull(t), mine = store._at || 0;
    if (remote && remote.json && remote.at > mine) {
      const s = JSON.parse(remote.json); s._at = remote.at; store = s; persist(); setSync('ok', 'Synced');
      try { hubView.webContents.reload(); } catch {}
    } else if (!remote || mine > remote.at || (mine && !remote.at)) {
      if (!mine) store._at = Date.now();
      await push(t); setSync('ok', 'Synced');
    } else setSync('ok', 'Synced');
    await sharedSync(t);
  } catch (e) { setSync('error', 'Not synced: ' + (e.message || e)); }
  finally { syncing = false; }
}
// ---------- shared AI list: the same AIs on phone, web and every computer (users/{uid}/settings/aiaccounts) ----------
const NMS = require('./nm-shared.js');
let sharedBusy = false;
async function sharedSync(t) {
  if (sharedBusy) return; sharedBusy = true;
  try {
    const gone = store.goneAcc || {};
    const local = accounts().map(a => NMS.fromDesktop(a, catalog, a.at || 1)).concat(Object.entries(gone).map(([id, at]) => ({ id, del: true, at })));
    const { list } = await NMS.syncRound({ fetchFn: fetch, proj: FB_PROJ, uid: t.uid, token: t.token, local, device: process.platform, legacyDesktop: null });
    let changed = false; const next = [];
    for (const s of list) {
      const mine = accOf(s.id);
      if (s.del) { if (mine) { changed = true; gone[s.id] = s.at; try { await session.fromPartition('persist:muse-' + s.id).clearStorageData(); } catch {} } continue; }
      if (!mine) { next.push(NMS.toDesktop(s, null)); changed = true; continue; }
      if ((s.at || 0) > (mine.at || 0)) { next.push(NMS.toDesktop(s, mine)); changed = true; } else next.push(mine);
    }
    if (changed) {
      store.accounts = next; store.goneAcc = gone; store._at = Date.now(); persist();
      try { hubView.webContents.reload(); } catch {}
      await push(t).catch(() => {});
    }
  } finally { sharedBusy = false; }
}
function pushSoon() { clearTimeout(pushT); pushT = setTimeout(syncNow, 4000); }
ipcMain.handle('syncState', () => syncInfo);
ipcMain.handle('syncNow', () => syncNow());

ipcMain.handle('state', () => store);
ipcMain.handle('save', (_e, s) => {
  const prev = JSON.stringify({ ...store, _at: 0 }), next = JSON.stringify({ ...s, _at: 0 });
  const at = store._at || 0, old = accounts(), now = Date.now();
  const gone = Object.assign({}, store.goneAcc || {});
  for (const a of (s.accounts || [])) { const o = old.find(x => x.id === a.id); const k = (x) => JSON.stringify(Object.assign({}, x, { at: 0, disp: 0, setup: 0 })); a.at = !o ? now : (k(o) !== k(a) ? now : (o.at || a.at || 1)); delete gone[a.id]; }
  for (const o of old) if (!(s.accounts || []).some(a => a.id === o.id)) gone[o.id] = now;
  s.goneAcc = gone;
  store = s; store._at = prev === next ? at : Date.now(); persist();
  if (prev !== next) pushSoon();
});
ipcMain.handle('catalog', () => catalog);
ipcMain.handle('notify', (_e, { title, body, id, url }) => notify(title, body, id, url));
ipcMain.handle('openExternal', (_e, u) => { if (/^(https:|mailto:)/.test(u)) shell.openExternal(u); });
ipcMain.handle('prefs', (_e, p) => { prefs = { ...prefs, ...p }; });

// ---------- alerts from the NeedsMe bridge: AIs (Polar, Claude, ChatGPT...) report "needs you" / "finished" through their MCP link ----------
const BRIDGE = 'https://billowing-lake-5abc.placenciailse.workers.dev';
const brFile = () => path.join(app.getPath('userData'), 'bridge.json');
let br = {}; try { br = JSON.parse(require('fs').readFileSync(brFile(), 'utf8')); } catch {}
const brSave = () => { try { require('fs').writeFileSync(brFile(), JSON.stringify(br)); } catch {} };
async function bridgePoll() {
  try {
    if (!signedIn) return;
    if (!br.t) {
      const t = await idToken(); if (!t) return;
      const r = await fetch(BRIDGE + '/tokens', { method: 'POST', headers: { authorization: 'Bearer ' + t.token, 'content-type': 'application/json' }, body: JSON.stringify({ name: 'NeedsMe ' + (process.platform === 'darwin' ? 'Mac' : 'Windows') }) });
      if (!r.ok) return; br = { t: (await r.json()).token, since: new Date().toISOString() }; brSave();
    }
    const r = await fetch(BRIDGE + '/events', { headers: { authorization: 'Bearer ' + br.t } });
    if (r.status === 401) { br = {}; brSave(); return; }
    if (!r.ok) return;
    const ev = await r.json(); if (!Array.isArray(ev)) return;
    let newest = br.since || new Date().toISOString();
    for (const e of ev) {
      if (!(e.at > br.since)) continue;
      const ai = e.ai || 'An AI';
      if (e.needs_you) notify(ai + ' needs you', e.needs_you, '', e.chat_url || '');
      else if (e.finished) notify(ai + ' finished', e.summary || e.project || 'A job is done', '', e.chat_url || '');
      if (e.at > newest) newest = e.at;
    }
    if (newest !== br.since) { br.since = newest; brSave(); }
  } catch {}
}
ipcMain.handle('info', () => ({ version: app.getVersion(), electron: process.versions.electron, user }));

app.whenReady().then(() => {
  store = load();
  try { if (process.platform === 'darwin') app.dock.setIcon(nativeImage.createFromPath(path.join(__dirname, 'build/icon.png'))); } catch {}
  win = new BrowserWindow({ width: 1320, height: 860, minWidth: 980, minHeight: 620, title: 'NeedsMe', backgroundColor: '#FFFFFF', titleBarStyle: 'hiddenInset', trafficLightPosition: { x: 18, y: 18 } });
  hubView = new WebContentsView({ webPreferences: { preload: path.join(__dirname, 'preload.js'), backgroundThrottling: false } });
  win.contentView.addChildView(hubView);
  hubView.webContents.loadFile('index.html');
  makeAuth();
  win.on('resize', applyGate);
  hubView.webContents.once('did-finish-load', () => { for (const a of accounts()) viewFor(a.id); });
  setInterval(checkUser, 3000); setInterval(() => { if (win && (win.isFocused() || Date.now() % 300000 < 60000)) syncNow(); }, 60000); setTimeout(syncNow, 8000); setInterval(scanAll, 60000); setInterval(bridgePoll, 20000); setTimeout(bridgePoll, 10000); setTimeout(scanAll, 20000);
});
app.on('window-all-closed', () => app.quit());
