/* NeedsMe for Mac, part 1: data, helpers, sidebar */
const KIND={Chat:'chat',Agent:'agent',Coding:'code',Research:'research',Builder:'build',Images:'image',Video:'video',Music:'music',Voice:'voice',Any:'plus'};
const COLS=['#A8C256','#D98C7A','#7FA7BF','#D9B26A','#A58BC9','#6FB5A3'];
let S={accounts:[],projects:[],chats:[],msgs:{},notes:[],updates:[],log:{answers:[]},settings:{theme:'light',col:false,goal:3,ask:true,stop:true,sent:true}},CAT=[],ST={},USER=null,INFO={};
let screen='today',curPr=null,curCh=null,curNote=null,openAcc=null,openHref='',nfold='All Notes',tab='Tasks',insTab='week',uMode='time',cpf='All',showArchP=false,showArchC=false,draft='',TYPING={},REPLY={},busyOpen=false,toastT=null;
const $=s=>document.querySelector(s),uid=()=>Math.random().toString(36).slice(2,10);
const esc=s=>String(s==null?'':s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const muted='color:var(--soft)';
let saveT=null;function save(now){clearTimeout(saveT);const f=()=>hub.save(S);if(now)return f();saveT=setTimeout(f,350)}
const cat=id=>CAT.find(c=>c.id===id)||{id,name:id,group:'Chat',url:''};
const acc=id=>S.accounts.find(a=>a.id===id);
const platOf=a=>cat(a.ai);
const multi=a=>S.accounts.filter(x=>x.ai===a.ai).length>1;
const kindOf=a=>KIND[platOf(a).group]||'chat';
const pName=a=>a.ai==='custom'?(a.label||'AI'):platOf(a).name;
const disp=a=>a?(a.ai==='custom'?a.label:(multi(a)?pName(a)+' · '+a.label:pName(a))):'Removed AI';
const handle=a=>(a?(multi(a)?pName(a)+a.label:pName(a)):'x').replace(/[^A-Za-z0-9]/g,'');
const baseOf=a=>a.url||platOf(a).url;
function syncNames(){S.accounts.forEach(a=>{a.disp=disp(a)})}
const plats=()=>{const m=[];S.accounts.forEach(a=>{let p=m.find(x=>x.ai===a.ai);if(!p){p={ai:a.ai,n:pName(a),k:kindOf(a),accs:[]};m.push(p)}p.accs.push(a)});return m};
const chip=id=>{const a=acc(id);return `<span class=chip>${ic(a?kindOf(a):'chat')}${esc(disp(a))}</span>`};
const toast=t=>{let e=$('.toast');if(e)e.remove();e=document.createElement('div');e.className='toast';e.textContent=t;document.body.appendChild(e);clearTimeout(toastT);toastT=setTimeout(()=>e.remove(),2600)};
const D=86400000,startDay=t=>{const d=new Date(t);d.setHours(0,0,0,0);return d.getTime()};
function ago(t){const s=(Date.now()-t)/1000;if(s<60)return 'just now';if(s<3600)return Math.round(s/60)+' min ago';if(s<86400)return Math.round(s/3600)+' h ago';return new Date(t).toLocaleDateString(undefined,{day:'numeric',month:'short'})}
const clock=t=>new Date(t).toLocaleTimeString([],{hour:'numeric',minute:'2-digit'});
const whenTxt=t=>{const d=new Date(t),n=startDay(Date.now()),x=startDay(t),dd=(x-n)/D;return (dd===0?'Today':dd===1?'Tomorrow':d.toLocaleDateString(undefined,{weekday:'short',day:'numeric',month:'short'}))+' '+clock(t)};
const toLocalInput=t=>{const d=new Date(t-new Date(t).getTimezoneOffset()*60000);return d.toISOString().slice(0,16)};
function addUpdate(accId,where,text,kind){S.updates.unshift({id:uid(),at:Date.now(),acc:accId,where:where||'',text:String(text).slice(0,400),kind:kind||'note'});S.updates=S.updates.slice(0,300);save()}
/* progress maths */
const pr=id=>S.projects.find(p=>p.id===id);
const prAll=p=>(p.tasks||[]).length,prDone=p=>(p.tasks||[]).filter(t=>t.done).length;
const allDone=()=>S.projects.flatMap(p=>(p.tasks||[]).filter(t=>t.done&&t.doneAt).map(t=>({...t,proj:p})));
function ring(p,sz=54,r=22){const a=prAll(p),d=prDone(p),pc=a?Math.round(d/a*100):null,C=2*Math.PI*r,h=sz/2;return `<div class=ring style="width:${sz}px;height:${sz}px"><svg width=${sz} height=${sz}><circle cx=${h} cy=${h} r=${r} fill=none stroke="var(--line)" stroke-width=3.5 /><circle cx=${h} cy=${h} r=${r} fill=none stroke="${p.c||'var(--acc)'}" stroke-width=3.5 stroke-linecap=round stroke-dasharray="${C}" stroke-dashoffset="${pc==null?C:C*(1-pc/100)}"/></svg><span>${pc==null?'–':pc+'%'}</span></div>`}
/* popups, modals (native AI view is hidden while they are open) */
let POPF=[];
function popup(e,items){e.stopPropagation();closePop(true);POPF=items;const r=e.currentTarget.getBoundingClientRect();const d=document.createElement('div');d.className='pop';d.id='pop';d.innerHTML=items.map((it,i)=>it==='-'?'<hr>':it.h?`<small>${esc(it.h)}</small>`:`<div class="${it.red?'red':''}" onclick="POPF[${i}].f();closePop()">${it.i?ic(it.i,'s'):''}${esc(it.t)}${it.on?`<span style="margin-left:auto" class=pin>${ic('check','s')}</span>`:''}</div>`).join('');document.body.appendChild(d);d.style.left=Math.max(8,Math.min(r.left,innerWidth-240))+'px';d.style.top=(r.bottom+6)+'px';if(screen==='open')hub.viewHide()}
function closePop(keep){const d=$('#pop');if(d)d.remove();if(!keep&&screen==='open'&&!$('#modal'))setTimeout(syncView,0)}
document.addEventListener('click',()=>closePop());
function showModal(html){let m=$('#modal');if(!m){m=document.createElement('div');m.id='modal';m.className='modal';document.body.appendChild(m)}m.innerHTML=`<div class=mbox>${html}</div>`;m.onclick=e=>{if(e.target===m)hideModal()};if(screen==='open')hub.viewHide()}
function hideModal(){const m=$('#modal');if(m)m.remove();if(screen==='open')syncView()}
/* sidebar */
function dotCls(p){let c='';p.accs.forEach(a=>{((ST[a.id]||{}).items||[]).forEach(i=>{if(i.kind==='stopped'||i.kind==='needs')c='w';else if(i.kind==='login'&&c!=='w')c='a'})});return c}
const needItems=()=>S.accounts.flatMap(a=>((ST[a.id]||{}).items||[]).map(i=>({a,i})));
const unreadTotal=()=>S.chats.filter(c=>!c.arch).reduce((n,c)=>n+(c.unread||0),0);
const NAV=[['today','Today','today'],['projects','Projects','projects'],['chats','Chats','chat'],['updates','Updates','updates'],['notes','Notes','notes'],['schedule','Schedule','schedule'],['insights','Insights','insights']];
function sb(){const col=S.settings.col,cnt={today:needItems().length,chats:unreadTotal()};
 return `<div class=brand><img src="assets/mark.svg"><span>NeedsMe</span></div><div class=cbtn onclick="S.settings.col=!S.settings.col;save();render()" title="${col?'Expand':'Collapse'} sidebar">${ic('panel','s')}</div>`
 +NAV.map(([k,t,i])=>`<div class="nav ${screen===k?'on':''}" onclick="go('${k}')" title="${t}">${ic(i)}<span class=t>${t}</span>${cnt[k]?`<span class=n>${cnt[k]}</span>`:''}</div>`).join('')
 +`<div class=lab>Your AIs</div>`+(plats().map(p=>{const cur=screen==='open'&&openAcc&&p.accs.some(a=>a.id===openAcc);const first=p.accs.find(a=>a.id===openAcc)||p.accs[0];const d=dotCls(p);
  return `<div class="plat ${cur?'on':''}" onclick="openAI('${first.id}')" title="${esc(p.n)}"><div class=dot>${av(first)}<b class="${d}"></b></div><div class=meta>${esc(p.n)}<small>${p.accs.length>1?esc(first.label)+' · '+p.accs.length+' accounts':esc(first.label)}</small></div></div>`+(p.accs.length>1?`<div class=sub2>${p.accs.map(a=>`<div class="${cur&&a.id===openAcc?'on':''}" onclick="openAI('${a.id}')"><i></i>${esc(a.label)}</div>`).join('')}</div>`:'')}).join('')||`<div style="padding:4px 12px;font-size:12.5px;color:var(--faint)">None yet</div>`)
 +`<div class="nav ${screen==='connect'?'on':''}" onclick="go('connect')" style="margin-top:6px" title="Connect an AI">${ic('plus')}<span class=t>Connect an AI</span></div><div class=sp></div><div class="nav ${screen==='settings'?'on':''}" onclick="go('settings')" title="Settings">${ic('settings')}<span class=t>Settings</span></div><div class=nav onclick="helpPop(event)" title="Help & feedback">${ic('help')}<span class=t>Help & feedback</span></div>`}
function helpPop(e){popup(e,[{i:'bug',t:'Report a bug',f:()=>feedback('bug')},{i:'heart',t:'Send feedback',f:()=>feedback('feedback')},{i:'shield',t:'Privacy policy',f:()=>hub.openExternal('https://support897.github.io/needsme/privacy.html')}])}
function feedback(kind){const bug=kind==='bug';showModal(`<h3>${bug?'Report a bug':'Send feedback'}</h3><p style="${muted};margin-bottom:12px">${bug?'Tell us what happened and which AI you were using.':'Tell us what you love or what would make NeedsMe better.'}</p><textarea class=t id=fbt placeholder="${bug?'What went wrong?':'Your thoughts…'}"></textarea><div class=row style="justify-content:flex-end"><button class="btn g" onclick="hideModal()">Cancel</button><button class="btn a" onclick="sendFb('${kind}')">Open email to send</button></div><p class=foot>This opens your email app with the message ready. Nothing is sent until you press send there.</p>`)}
function sendFb(kind){const t=($('#fbt')||{}).value||'';if(!t.trim())return;const sub=(kind==='bug'?'NeedsMe Mac bug: ':'NeedsMe Mac feedback: ')+t.trim().slice(0,50);const body=t.trim()+'\n\n---\nNeedsMe for Mac '+(INFO.version||'')+' · Electron '+(INFO.electron||'')+' · '+(USER&&USER.email||'');hub.openExternal('mailto:hello@needsme.xyz?subject='+encodeURIComponent(sub)+'&body='+encodeURIComponent(body));hideModal();toast('Your email app opened.')}
