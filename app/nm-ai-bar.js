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
    { id: 'polar', name: 'Polar', url: 'https://polarbrowser.com/' },
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
      list = cur; editing = a.id; draft = JSON.parse(JSON.stringify(a)); isNew = a.id; open = true;
    } catch (e) { state = 'Could not save it to your list (' + e.message + ').'; }
    draw();
  }

  let editing = null, draft = null, isNew = null;
  async function saveList(mutate) { // read the newest shared list, change it, write it back (newer change wins on every device)
    const t = await token(user);
    const r0 = await fetch(docUrl(user.uid), { headers: { Authorization: 'Bearer ' + t } });
    let cur = [];
    if (r0.ok) { const f = (await r0.json()).fields || {}; const j = JSON.parse((f.json || {}).stringValue || '{}'); cur = Array.isArray(j) ? j : j.accounts || []; }
    cur = mutate(cur) || cur;
    const body = { fields: { json: { stringValue: JSON.stringify({ v: 1, accounts: cur }) }, updated: { integerValue: String(Date.now()) }, device: { stringValue: 'web' } } };
    const w = await fetch(docUrl(user.uid) + '?updateMask.fieldPaths=json&updateMask.fieldPaths=updated&updateMask.fieldPaths=device', { method: 'PATCH', headers: { Authorization: 'Bearer ' + t, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    if (!w.ok) throw new Error('HTTP ' + w.status);
    list = cur;
  }
  const COLORS = ['#A8C256', '#16120E', '#F0EAE0', '#E5484D', '#F5A524', '#F2D14B', '#3E63DD', '#8E4EC6', '#12A594', '#E93D82'];
  function editor(a) {
    const d = draft, nf = d.nf || {}, use = d.use || {};
    const sw = (g, k, label, o) => `<label class="nmb-sw"><input type="checkbox" data-sw="${g}.${k}" ${o[k] !== false ? 'checked' : ''}> ${label}</label>`;
    return `<div class="nmb-ed">
      <div class="nmb-lab">${isNew === a.id ? 'Make it yours:' : 'Edit'} ${esc(title(a))}</div>
      <input class="nmb-in" data-f="name" placeholder="Name (like Work)" value="${esc(d.name || '')}">
      <input class="nmb-in" data-f="emoji" placeholder="Emoji" maxlength="4" value="${esc(d.emoji || '')}">
      <textarea class="nmb-in" data-f="desc" maxlength="300" placeholder="What is this AI for?">${esc(d.desc || '')}</textarea>
      <div class="nmb-cols">${COLORS.map((c) => `<button class="nmb-c${d.color === c ? ' on' : ''}" data-col="${c}" style="background:${c}" aria-label="color ${c}"></button>`).join('')}<button class="nmb-c" data-col="" aria-label="no color">x</button></div>
      <label class="nmb-btn2">Upload a picture<input type="file" accept="image/*" data-img hidden></label>${d.img ? ' <button class="nmb-btn2" data-noimg>Remove picture</button>' : ''}
      <div class="nmb-lab">Tell me when</div>
      ${sw('nf', 'done', 'It finishes or replies', nf)}${sw('nf', 'needs', 'It needs me', nf)}${sw('nf', 'msgs', 'A new message comes', nf)}
      <div class="nmb-lab">Use it in NeedsMe</div>
      ${sw('use', 'chats', 'Pull its chats and projects', use)}${sw('use', 'needs', 'Find what needs me', use)}${sw('use', 'updates', 'Show its updates', use)}
      <div class="nmb-row2"><button class="nmb-btn2 pri" data-save>Save</button><button class="nmb-btn2" data-cancel>Cancel</button><button class="nmb-btn2 del" data-del>Remove</button></div>
    </div>`;
  }
  function pickImage(file, cb) {
    const r = new FileReader();
    r.onload = () => { const im = new Image(); im.onload = () => { const c = document.createElement('canvas'); c.width = c.height = 96; const x = c.getContext('2d'); const s = Math.max(96 / im.width, 96 / im.height); x.drawImage(im, (96 - im.width * s) / 2, (96 - im.height * s) / 2, im.width * s, im.height * s); cb(c.toDataURL('image/jpeg', 0.6)); }; im.src = r.result; };
    r.readAsDataURL(file);
  }

  const BRIDGE = 'https://billowing-lake-5abc.placenciailse.workers.dev';
  let mcpName = 'Polar', mcpToken = '', mcpNote = '';
  function mcpPrompt(t) { return `Connect to my NeedsMe. It is my own private link. Add it as an MCP server (or custom connector) with these details:\nURL: ${BRIDGE}/mcp\nHeader: Authorization: Bearer ${t}\nRules for you:\n1. Call get_my_projects first, and use my exact project names.\n2. After every reply where something changed, call report_update (project, summary, todos_new, todos_done, needs_you, finished, chat_url = the web link to this chat).\n3. Use needs_you only when you cannot go on without my answer.\n4. To bring in another AI, call post_message and write @name (for example @gemini).\n5. Never share this token with anyone. If you cannot add MCP servers, tell me, and I will give you the paste-block rule instead.`; }
  async function makeMcp() {
    if (!user) { mcpNote = 'Sign in first.'; return draw(); }
    try {
      const r = await fetch(BRIDGE + '/tokens', { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + (await token(user)) }, body: JSON.stringify({ name: mcpName || 'My AI' }) });
      const j = await r.json(); if (!r.ok || !j.token) throw new Error(j.error || 'HTTP ' + r.status);
      mcpToken = j.token; mcpNote = 'Link made. Copy the prompt and paste it into ' + (mcpName || 'your AI') + '.';
    } catch (e) { mcpNote = 'Could not make a link (' + e.message + ').'; }
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
        ${live.length ? live.map((a, i) => editing === a.id ? editor(a) : `<div class="nmb-line"><a class="nmb-row" role="menuitem" href="${esc(a.url || '#')}" target="_blank" rel="noopener">${dot(a)}<span><b>${esc(title(a))}</b>${a.desc ? `<small>${esc(a.desc)}</small>` : ''}</span></a><button class="nmb-edit" data-edit="${esc(a.id)}">Edit</button></div>`).join('') : `<p class="nmb-note">None yet. Log in to an AI below, or on your phone or computer. It shows here too.</p>`}
        <div class="nmb-lab">Not logged in yet</div>
        ${rest.map((m, i) => `<button class="nmb-row" role="menuitem" data-add="${i}"><span class="nmb-dot">${esc(m.name[0])}</span><span><b>${esc(m.name)}</b><small>Open and add to my list</small></span></button>`).join('')}
        <details class="nmb-about"><summary>Connect Polar and other AIs (MCP)</summary>
          <p>Make your own private link. Paste it into Polar, Claude, ChatGPT or any AI that takes an MCP link. When it needs you or finishes, you get an alert on your phone and computers, even with the app closed.</p>
          <input class="nmb-in" data-mcpname placeholder="Name this AI (like Polar)" value="${esc(mcpName)}">
          <button class="nmb-btn2 pri" data-mcpmake>Make a link</button>
          ${mcpToken ? `<textarea class="nmb-in" readonly rows="5" data-mcpbox>${esc(mcpPrompt(mcpToken))}</textarea><button class="nmb-btn2" data-mcpcopy>Copy prompt for my AI</button>` : ''}
          ${mcpNote ? `<p class="nmb-note">${esc(mcpNote)}</p>` : ''}
        </details>
        <details class="nmb-about"><summary>One AI or a workforce? What is MCP?</summary>
          <p><b>One AI</b> is one helper. You ask, it does one job.</p>
          <p><b>An AI workforce</b> is a team of AIs. Each has its own job. They pass work along, and they tell you when they are stuck.</p>
          <p>In NeedsMe, <b>Your AIs</b> is each helper by itself. <b>Your workforce</b> is all of them together: who is busy, who needs you, and what each one finished.</p>
          <p><b>MCP</b> is a plug that lets an AI use another app. You paste a link into the AI. These take your own link: Claude, ChatGPT (web), Grok, Perplexity (Pro), Mistral, Gemini (limited), Cursor, VS Code, Claude Code, Codex CLI and Gemini CLI. Meta AI and DeepSeek do not. Polar is in your AI list: add it and open it like any other AI.</p>
        </details>
        <p class="nmb-note">Same list on your phone, the web and every computer. Each device signs in to each AI once.</p>
      </div>` : '');
    root.querySelector('.nmb-btn').onclick = () => { open = !open; draw(); if (open) load(); };
    root.querySelectorAll('[data-edit]').forEach((b) => (b.onclick = (e) => { e.preventDefault(); const a = list.find((x) => x.id === b.dataset.edit); editing = a.id; draft = JSON.parse(JSON.stringify(a)); draw(); }));
    const ed = root.querySelector('.nmb-ed');
    if (ed) {
      ed.querySelectorAll('[data-f]').forEach((i) => (i.oninput = () => { draft[i.dataset.f] = i.value; }));
      ed.querySelectorAll('[data-col]').forEach((b) => (b.onclick = () => { draft.color = b.dataset.col; draw(); }));
      ed.querySelectorAll('[data-sw]').forEach((i) => (i.onchange = () => { const [g, k] = i.dataset.sw.split('.'); draft[g] = draft[g] || {}; draft[g][k] = i.checked; }));
      const f = ed.querySelector('[data-img]'); if (f) f.onchange = () => f.files[0] && pickImage(f.files[0], (u) => { draft.img = u; draw(); });
      const ni = ed.querySelector('[data-noimg]'); if (ni) ni.onclick = () => { draft.img = ''; draw(); };
      ed.querySelector('[data-cancel]').onclick = () => { editing = null; isNew = null; draw(); };
      ed.querySelector('[data-save]').onclick = async () => { try { const d = Object.assign({}, draft, { at: Date.now(), del: false }); await saveList((c) => c.map((x) => (x.id === d.id ? d : x))); state = ''; } catch (e) { state = 'Could not save (' + e.message + ').'; } editing = null; isNew = null; draw(); };
      ed.querySelector('[data-del]').onclick = async () => { try { await saveList((c) => c.map((x) => (x.id === draft.id ? Object.assign({}, x, { del: true, at: Date.now() }) : x))); } catch (e) { state = 'Could not remove (' + e.message + ').'; } editing = null; isNew = null; draw(); };
    }
    const mn = root.querySelector('[data-mcpname]'); if (mn) mn.oninput = () => { mcpName = mn.value; };
    const mm = root.querySelector('[data-mcpmake]'); if (mm) mm.onclick = makeMcp;
    const mc = root.querySelector('[data-mcpcopy]'); if (mc) mc.onclick = async () => { try { await navigator.clipboard.writeText(mcpPrompt(mcpToken)); mcpNote = 'Copied.'; } catch { root.querySelector('[data-mcpbox]').select(); mcpNote = 'Select all and copy.'; } draw(); };
    root.querySelectorAll('details.nmb-about').forEach((d) => { if (d.querySelector('[data-mcpname]') && (mcpToken || mcpNote)) d.open = true; });
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
  .nmb-line{display:flex;align-items:center}.nmb-line .nmb-row{flex:1}.nmb-edit{background:none;border:1px solid #E5DED2;border-radius:8px;padding:4px 8px;cursor:pointer;font:inherit;font-size:12px}
  .nmb-ed{padding:4px 6px}.nmb-in{display:block;width:100%;box-sizing:border-box;margin:4px 0;padding:7px;border:1px solid #E5DED2;border-radius:8px;font:inherit}
  .nmb-cols{display:flex;flex-wrap:wrap;gap:6px;margin:6px 0}.nmb-c{width:24px;height:24px;border-radius:50%;border:2px solid #E5DED2;cursor:pointer;font-size:11px}.nmb-c.on{border-color:#16120E}
  .nmb-btn2{display:inline-block;background:#F0EAE0;border:0;border-radius:8px;padding:6px 10px;margin:3px 3px 3px 0;cursor:pointer;font:inherit;font-size:13px}.nmb-btn2.pri{background:#16120E;color:#F0EAE0}.nmb-btn2.del{color:#B3261E}
  .nmb-sw{display:block;margin:3px 8px;font-size:13px}.nmb-row2{margin-top:8px}.nmb-about{margin:8px;font-size:12.5px;color:#6B6252}.nmb-about summary{cursor:pointer;font-weight:600;color:#16120E}
  .nmb-note{font-size:12.5px;color:#6B6252;margin:6px 8px}
  @media (max-width:520px){.nmb-menu{width:calc(100vw - 24px)}}`;
  const root = document.createElement('div'); root.id = 'nm-ai-bar';
  document.addEventListener('click', (e) => { if (open && !e.composedPath().includes(root)) { open = false; draw(); } });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && open) { open = false; draw(); } });
  const start = () => { document.head.appendChild(css); document.body.appendChild(root); draw(); load(); };
  if (document.body) start(); else document.addEventListener('DOMContentLoaded', start);
})();
