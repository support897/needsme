// End-to-end test against the REAL servers (Firebase needs-me-480ea + the NeedsMe bridge) with a throwaway user.
const NM = require('./nm-shared.js');
const KEY = process.env.FBKEY || 'AIzaSyD3pfsSI-NpEPZgZhk4jiqdIZjyfmbkTVs', BR = 'https://billowing-lake-5abc.placenciailse.workers.dev', PROJ = 'needs-me-480ea';
const H = { 'content-type': 'application/json', Referer: 'https://www.needsme.xyz/' };
let pass = 0, fail = 0;
const ok = (c, m) => { (c ? pass++ : fail++); console.log((c ? 'PASS ' : 'FAIL ') + m); };
(async () => {
  const su = await (await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${KEY}`, { method: 'POST', headers: H, body: '{"returnSecureToken":true}' })).json();
  const tok = su.idToken, uid = su.localId; ok(!!tok, 'throwaway user created ' + uid.slice(0, 6));
  const dev = (id, ai, name, at, extra) => Object.assign({ id, ai, aiName: ai, url: 'https://x/', name, desc: '', emoji: '', img: '', color: '', at, del: false }, extra || {});
  const round = (local, device) => NM.syncRound({ fetchFn: fetch, proj: PROJ, uid, token: tok, local, device });
  if (!process.env.SKIP_FS) {
  // 1. "phone" adds ChatGPT; "computer" sees it
  let r = await round([dev('chatgpt-a1', 'chatgpt', 'Work', 1000)], 'phone');
  ok(r.list.length === 1, 'phone saves 1 AI to the shared list');
  r = await round([dev('claude-b1', 'claude', 'Home', 1100)], 'computer');
  ok(r.list.length === 2 && r.list.some((a) => a.id === 'chatgpt-a1'), 'computer sees the phone AI and keeps its own (same list both places)');
  // 2. "web" edits colour + emoji + description + switches; phone sees it
  const edited = dev('chatgpt-a1', 'chatgpt', 'Work', 2000, { color: '#E5484D', emoji: '🦊', desc: 'my writing helper', nf: { done: false, needs: true, msgs: true }, use: { chats: true, needs: false, updates: true } });
  r = await round([edited], 'web');
  r = await round([dev('chatgpt-a1', 'chatgpt', 'Work', 1000)], 'phone');
  const c = r.list.find((a) => a.id === 'chatgpt-a1');
  ok(c && c.color === '#E5484D' && c.emoji === '🦊' && c.desc === 'my writing helper' && c.nf.done === false && c.use.needs === false, 'colour, emoji, description and on/off switches follow the account (newer edit wins)');
  // 3. removal on phone removes everywhere
  r = await round([Object.assign(dev('claude-b1', 'claude', 'Home', 3000), { del: true })], 'phone');
  r = await round([], 'computer');
  ok(NM.live(r.list).length === 1 && NM.live(r.list)[0].id === 'chatgpt-a1', 'removing an AI on one device removes it on the others');
  // 4. another account cannot read this list
  const su2 = await (await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${KEY}`, { method: 'POST', headers: H, body: '{"returnSecureToken":true}' })).json();
  const x = await fetch(`https://firestore.googleapis.com/v1/projects/${PROJ}/databases/(default)/documents/users/${uid}/settings/aiaccounts`, { headers: { Authorization: 'Bearer ' + su2.idToken } });
  ok(x.status === 403 || x.status === 401, 'another user cannot read it (HTTP ' + x.status + ')');
  await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${KEY}`, { method: 'POST', headers: H, body: JSON.stringify({ idToken: su2.idToken }) });
  }
  // 5. bridge: link, MCP, alert event, closed-app push
  const B = (p, o, t) => fetch(BR + p, Object.assign({ headers: { 'content-type': 'application/json', authorization: 'Bearer ' + (t || tok) } }, o));
  const d = await B('/device', { method: 'POST', body: JSON.stringify({ token: 'a'.repeat(64) }) }); ok(d.status === 200, 'phone push token saved on the bridge (' + d.status + ')');
  const t = await (await B('/tokens', { method: 'POST', body: JSON.stringify({ name: 'Polar' }) })).json(); ok(/^nm_/.test(t.token || ''), 'private MCP link made for "Polar"');
  const mcp = (m, p) => B('/mcp', { method: 'POST', body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: m, params: p }) }, t.token).then((x) => x.json());
  const init = await mcp('initialize', { protocolVersion: '2025-03-26', capabilities: {}, clientInfo: { name: 'polar-test', version: '1' } }); ok(!!(init.result && init.result.serverInfo), 'MCP initialize works');
  const tl = await mcp('tools/list', {}); const names = ((tl.result || {}).tools || []).map((z) => z.name); ok(names.includes('report_update') && names.includes('get_my_projects'), 'MCP tools: ' + names.join(','));
  const ru = await mcp('tools/call', { name: 'report_update', arguments: { ai: 'Polar', project: 'E2E test', summary: 'Test finished', needs_you: 'Pick A or B?', chat_url: 'https://polarbrowser.com/' } }); ok(!ru.error, 'report_update (needs_you) accepted');
  const ev = await (await B('/events', {}, t.token)).json(); ok(Array.isArray(ev) && ev.some((e) => e.needs_you === 'Pick A or B?' && e.ai === 'Polar'), 'alert event "Polar needs you: Pick A or B?" is waiting for the apps');
  const d2 = await B('/device', { method: 'POST', body: JSON.stringify({ token: 'b'.repeat(64) }) }); const dj = await d2.json();
  console.log('devices kept after Apple answered:', JSON.stringify(dj));
  // each device keeps its own "last seen" time, so a phone and a computer both get the alert (Android/desktop rule)
  const since = new Date(Date.parse(ev[0].at) - 1000).toISOString();
  const again = await (await B('/events', {}, t.token)).json(); ok(again.filter((e) => e.at > since).length === 1 && again.filter((e) => e.at > new Date().toISOString()).length === 0, 'a second device also sees the alert, and nothing newer is waiting');
  await B('/me', { method: 'DELETE' });
  await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${KEY}`, { method: 'POST', headers: H, body: JSON.stringify({ idToken: tok }) });
  console.log(`\n${pass} passed, ${fail} failed`); process.exit(fail ? 1 : 0);
})().catch((e) => { console.log('ERROR', e); process.exit(2); });
