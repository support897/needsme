/* NeedsMe shared AI list: one list per Needs Me account, the same on phone, web and every computer.
   Stored in Firestore users/{uid}/settings/aiaccounts as { json: "<string>", updated: <ms> }.
   json = { v: 1, accounts: [ SharedAccount ] }
   SharedAccount = { id, ai, aiName, url, name, desc, emoji, img, color, nf:{done,needs,msgs}, use:{chats,needs,updates}, at, del }
   - at: last change time (ms). The newer copy of an account wins.
   - del: true means "removed". Kept so a removal on one device removes it everywhere.
   AI website logins (cookies, passwords) are never part of it: each device signs in to each AI once. */
(function (root) {
  const DOC = 'aiaccounts';
  const IMG_MAX = 60000; // keep the whole list far below Firestore's 1 MB document limit

  function clean(a) {
    const b = (x, d) => (typeof x === 'boolean' ? x : d);
    const nf = a.nf || {}, use = a.use || {};
    let color = String(a.color || '');
    if (color && !/^#[0-9A-Fa-f]{6}$/.test(color)) color = '';
    const img = typeof a.img === 'string' && a.img.startsWith('data:image/') && a.img.length <= IMG_MAX ? a.img : '';
    return {
      id: String(a.id || ''), ai: String(a.ai || ''), aiName: String(a.aiName || ''), url: String(a.url || ''),
      name: String(a.name || ''), desc: String(a.desc || '').slice(0, 300), emoji: String(a.emoji || ''), img, color,
      nf: { done: b(nf.done, true), needs: b(nf.needs, true), msgs: b(nf.msgs, true) },
      use: { chats: b(use.chats, true), needs: b(use.needs, true), updates: b(use.updates, true) },
      at: Number(a.at) || 0, del: !!a.del,
    };
  }

  /** Merge two lists by id. For the same id the newer `at` wins; a tie keeps the first list's copy. */
  function merge(mine, theirs) {
    const out = new Map();
    for (const a of (mine || []).map(clean)) if (a.id) out.set(a.id, a);
    for (const a of (theirs || []).map(clean)) {
      if (!a.id) continue;
      const m = out.get(a.id);
      if (!m || a.at > m.at) out.set(a.id, a);
    }
    return [...out.values()];
  }

  const live = (list) => (list || []).filter((a) => !a.del);
  // Equal when every id has the same change time and removed flag, so small shape differences between apps never cause a write loop.
  const key = (l) => (l || []).map(clean).map((a) => a.id + '|' + a.at + '|' + (a.del ? 1 : 0)).sort().join(',');
  const same = (x, y) => key(x) === key(y);
  const parse = (json) => { try { const j = JSON.parse(json || '{}'); return Array.isArray(j) ? j : (j.accounts || []); } catch { return []; } };
  const encode = (list) => JSON.stringify({ v: 1, accounts: (list || []).map(clean) });

  /* ---- desktop (Mac and Windows) account shape <-> shared ---- */
  function fromDesktop(a, catalog, at) {
    const c = (catalog || []).find((x) => x.id === a.ai) || {};
    return clean({ id: a.id, ai: a.ai, aiName: a.ai === 'custom' ? (a.label || 'AI') : (c.name || a.ai), url: a.url || c.url || '',
      name: a.label || '', desc: a.desc, emoji: a.emoji, img: a.img, color: a.color, nf: a.nf, use: a.use, at: a.at || at || 0 });
  }
  function toDesktop(s, old) {
    const a = Object.assign({}, old || {}, { id: s.id, ai: s.ai, label: s.name || (s.ai.startsWith('custom') ? s.aiName : 'Main'),
      desc: s.desc || undefined, emoji: s.emoji || undefined, img: s.img || undefined, color: s.color || undefined,
      nf: s.nf, use: s.use, at: s.at });
    if (s.ai.startsWith('custom')) { a.ai = 'custom'; a.label = s.name || s.aiName; }
    if (a.ai === 'custom' || s.url) a.url = s.url || a.url;
    if (!old) a.setup = false;
    return a;
  }

  /* ---- Android legacy list (settings/android) -> shared, used once to bring old saved AIs in ---- */
  function fromAndroidLegacy(x, at) {
    const col = Number(x.color) || 0, nf = Number(x.nf == null ? 7 : x.nf);
    return clean({ id: x.id, ai: String(x.aiId || '').startsWith('custom-') ? 'custom' : x.aiId, aiName: x.aiName, url: x.url, name: x.nickname, desc: x.note, emoji: x.emoji,
      color: col ? '#' + col.toString(16).padStart(6, '0').toUpperCase() : '',
      nf: { done: !!(nf & 1), needs: !!(nf & 2), msgs: !!(nf & 4) }, at: at || 1 });
  }

  /* ---- Firestore REST ---- */
  const base = (proj, uid, doc) => `https://firestore.googleapis.com/v1/projects/${proj}/databases/(default)/documents/users/${uid}/settings/${doc}`;
  async function readDoc(fetchFn, proj, uid, token, doc) {
    const r = await fetchFn(base(proj, uid, doc), { headers: { Authorization: 'Bearer ' + token } });
    if (r.status === 404) return null;
    if (!r.ok) throw new Error('read ' + doc + ' ' + r.status);
    const f = (await r.json()).fields || {};
    return { json: (f.json || {}).stringValue || '', updated: +((f.updated || {}).integerValue || 0) };
  }
  async function writeShared(fetchFn, proj, uid, token, list, device) {
    const body = { fields: { json: { stringValue: encode(list) }, updated: { integerValue: String(Date.now()) }, device: { stringValue: device || 'unknown' } } };
    const r = await fetchFn(base(proj, uid, DOC) + '?updateMask.fieldPaths=json&updateMask.fieldPaths=updated&updateMask.fieldPaths=device',
      { method: 'PATCH', headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    if (!r.ok) throw new Error('write ' + DOC + ' ' + r.status);
  }

  /** One sync round. `local` is this device's list in shared shape. Returns { list, pushed }.
      The first time the shared list is missing, old per-device lists (Android, desktop) are merged in, so nothing she saved is lost. */
  async function syncRound({ fetchFn, proj, uid, token, local, device, legacyDesktop }) {
    const remote = await readDoc(fetchFn, proj, uid, token, DOC);
    let theirs = remote ? parse(remote.json) : [];
    if (!remote) {
      const and = await readDoc(fetchFn, proj, uid, token, 'android').catch(() => null);
      if (and) theirs = merge(theirs, parse(and.json).map((x) => fromAndroidLegacy(x, 1)));
      if (legacyDesktop) {
        const desk = await readDoc(fetchFn, proj, uid, token, 'desktop').catch(() => null);
        if (desk) { try { theirs = merge(theirs, (JSON.parse(desk.json).accounts || []).map((a) => legacyDesktop(a))); } catch {} }
      }
    }
    const list = merge(local, theirs);
    const pushed = !remote || !same(list, theirs);
    if (pushed) await writeShared(fetchFn, proj, uid, token, list, device);
    return { list, pushed };
  }

  const api = { DOC, clean, merge, live, same, parse, encode, fromDesktop, toDesktop, fromAndroidLegacy, readDoc, writeShared, syncRound };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.NMShared = api;
})(typeof self !== 'undefined' ? self : this);
