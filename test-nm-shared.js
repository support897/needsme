const assert = require('assert'), S = require('./nm-shared.js');
const cat = [{ id: 'chatgpt', name: 'ChatGPT', url: 'https://chatgpt.com/' }, { id: 'claude', name: 'Claude', url: 'https://claude.ai/' }];
// phone has ChatGPT Work; computer has Claude Main -> both see both
const phone = [S.fromAndroidLegacy({ id: 'p1', aiId: 'chatgpt', aiName: 'ChatGPT', url: 'https://chatgpt.com/', nickname: 'Work', color: 0x3E7BFA, nf: 5 }, 100)];
const desk = [S.fromDesktop({ id: 'd1', ai: 'claude', label: 'Main', color: '#A8C256', desc: 'my coding AI', at: 200 }, cat)];
let m = S.merge(phone, desk); assert.deepStrictEqual(m.map(a => a.id).sort(), ['d1', 'p1']);
assert.strictEqual(m.find(a => a.id === 'p1').color, '#3E7BFA'); assert.deepStrictEqual(m.find(a => a.id === 'p1').nf, { done: true, needs: false, msgs: true });
// newer edit wins
const edited = Object.assign({}, desk[0], { name: 'Home', at: 300 }); m = S.merge(m, [edited]); assert.strictEqual(m.find(a => a.id === 'd1').name, 'Home');
// older edit loses
m = S.merge(m, [Object.assign({}, desk[0], { name: 'Old', at: 50 })]); assert.strictEqual(m.find(a => a.id === 'd1').name, 'Home');
// removal spreads, and live() hides it
m = S.merge(m, [{ id: 'p1', del: true, at: 400 }]); assert.deepStrictEqual(S.live(m).map(a => a.id), ['d1']);
// desktop shape round trip
const back = S.toDesktop(m.find(a => a.id === 'd1'), null); assert.strictEqual(back.label, 'Home'); assert.strictEqual(back.ai, 'claude'); assert.strictEqual(back.setup, false);
// custom Android AI -> desktop custom with link
const c = S.toDesktop(S.clean({ id: 'c1', ai: 'custom', aiName: 'MyBot', url: 'https://bot.example.com', at: 1 }), null); assert.strictEqual(c.ai, 'custom'); assert.strictEqual(c.url, 'https://bot.example.com');
// big image is dropped from the shared copy, small kept
assert.strictEqual(S.clean({ id: 'x', img: 'data:image/jpeg;base64,' + 'a'.repeat(70000) }).img, '');
assert.ok(S.clean({ id: 'x', img: 'data:image/jpeg;base64,abc' }).img);
console.log('nm-shared: all 10 checks pass');
