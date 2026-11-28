const { contextBridge, ipcRenderer: R } = require('electron');
const inv = (c) => (a) => R.invoke(c, a);
contextBridge.exposeInMainWorld('hub', {
  state: inv('state'), save: inv('save'), catalog: inv('catalog'), status: inv('status'), user: inv('user'),
  ask: inv('ask'), reply: inv('reply'), dismiss: inv('dismiss'), rescan: inv('rescan'),
  viewShow: inv('viewShow'), viewHide: inv('viewHide'), removeAccount: inv('rmAccount'),
  account: inv('account'), accountBack: inv('accountBack'), logout: inv('logout'),
  notify: inv('notify'), openExternal: inv('openExternal'), prefs: inv('prefs'), info: inv('info'),
  syncState: inv('syncState'), syncNow: inv('syncNow'), checkinsGet: inv('checkinsGet'), checkinsSet: inv('checkinsSet'),
  on: (ch, fn) => R.on(ch, (_e, d) => fn(d)),
});
