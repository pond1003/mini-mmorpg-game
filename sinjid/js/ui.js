'use strict';
// ================= UI: HUD / MODAL / MENU / NPCS / QUESTS =================
function modal(html){$('#modal-body').innerHTML=html;$('#modal').classList.add('on')}
function closeModal(){$('#modal').classList.remove('on');if(STATE==='world')W.keys={}}
const modalOpen=()=>$('#modal').classList.contains('on');
const menuOpen=()=>$('#menu').classList.contains('on');
const dialogOpen=()=>$('#dialog').classList.contains('on');

function renderHeader(){
  if(!P){$('#hud').innerHTML='';return}
  $('#hud').innerHTML=`<span>🥷 <b>${P.name}</b> <span class="small">${CLS().name}</span></span><span>Lv <b>${P.lvl}</b></span>
  <span>EXP <b>${P.exp}/${expNeed(P.lvl)}</b></span><span class="gold">💰 <b class="gold">${P.gold}</b></span>`;
}
let hudT=0;
function updateHUD(force){
  if(!force&&performance.now()-hudT<200)return;hudT=performance.now();
  fixPlayer();renderHeader();
  const q=MAIN_QUESTS[P.quest.i];
  let qh='';
  if(q&&P.quest.active){qh=`<div class="qt"><b>📜 ${q.title}</b>`+questProgress(q).map(r=>`<div>${ENEMIES[r.s].name} ${r.have}/${r.n}</div>`).join('')+
    (questDone(q)?'<div class="gold">✔ กลับไปรายงานผู้ใหญ่บ้าน</div>':'')+'</div>'}
  else if(q){qh=`<div class="qt"><b>📜 คุยกับผู้ใหญ่บ้านฮิโรชิ</b><div>เพื่อรับภารกิจใหม่</div></div>`}
  $('#whud').innerHTML=`<div class="zone">${MAPS[W.id].name}</div>
    <div class="mbar"><i style="width:${P.hp/maxHP()*100}%;background:var(--hp)"></i><span>HP ${P.hp}/${maxHP()}</span></div>
    <div class="mbar"><i style="width:${P.mp/maxMP()*100}%;background:var(--mp)"></i><span>MP ${P.mp}/${maxMP()}</span></div>
    ${P.sp||P.skp?`<div class="small gold">มีแต้มเหลือ! กด I</div>`:''}${qh}`;
}
const toastQ=[];
function toast(msg,color='#fff'){
  const d=document.createElement('div');d.className='toast';d.style.color=color;d.textContent=msg;$('#toasts').appendChild(d);
  setTimeout(()=>d.classList.add('out'),2600);setTimeout(()=>d.remove(),3200);
}

// ---------- dialog ----------
let dlg=null;
function showDialog(name,lines,after){
  dlg={name,lines,i:0,after};$('#dialog').classList.add('on');W.keys={};drawDialog();
}
function drawDialog(){$('#dialog').innerHTML=`<b>${dlg.name}</b><p>${dlg.lines[dlg.i]}</p><span class="small">[E / Space / คลิก] ต่อไป</span>`}
function advanceDialog(){
  if(!dlg)return;sfx('ui');
  if(++dlg.i<dlg.lines.length){drawDialog();return}
  $('#dialog').classList.remove('on');const a=dlg.after;dlg=null;if(a)a();
}

// ---------- quests ----------
function questProgress(q){
  return Object.entries(q.need).map(([s,n])=>{s=+s;
    const have=ENEMIES[s].boss?(P.flags['boss'+s]?1:0):(P.kills[s]||0)-(P.quest.base[s]||0);
    return {s,n,have:Math.min(n,Math.max(0,have))}});
}
const questDone=q=>questProgress(q).every(r=>r.have>=r.n);
function npcMarker(id){
  if(id==='elder'){const q=MAIN_QUESTS[P.quest.i];if(!q)return '';if(!P.quest.active)return '!';return questDone(q)?'?':''}
  if(id==='board'){ensureBounties();return P.bounties.some(bountyDone)?'?':''}
  return '';
}
function questNotes(){
  let h='';const q=MAIN_QUESTS[P.quest.i];
  if(q&&P.quest.active&&questDone(q))h+=`<p class="gold">📜 ภารกิจ "${q.title}" สำเร็จ! กลับไปรายงานผู้ใหญ่บ้าน</p>`;
  if(P.bounties.some(bountyDone))h+=`<p class="gold">📋 มีค่าหัวที่รับรางวัลได้ที่กระดาน</p>`;
  return h;
}
function talkElder(){
  const q=MAIN_QUESTS[P.quest.i],n='ผู้ใหญ่บ้าน ฮิโรชิ';
  if(!q){showDialog(n,['เจ้าคือวีรบุรุษของหมู่บ้านใบไม้!','ไปล่าค่าหัวที่กระดานหรือฝึกฝนต่อได้ตามใจเลย']);return}
  if(!P.quest.active){
    showDialog(n,[...q.talk,`📜 รับภารกิจ: ${q.title}`],()=>{P.quest.active=true;P.quest.base={...P.kills};save();sfx('ui');toast(`📜 รับภารกิจ: ${q.title}`,'#e3b04b');updateHUD(true)});
  } else if(questDone(q)){
    showDialog(n,['ยอดเยี่ยมมาก! เจ้าทำสำเร็จแล้ว','นี่คือรางวัลของเจ้า'],()=>{
      const lines=addLoot({gold:q.reward.gold,items:q.reward.items});const lv=gainExp(q.reward.exp);
      P.quest.i++;P.quest.active=false;save();sfx('coin');
      modal(`<h3 style="color:var(--gold)">ภารกิจสำเร็จ!</h3><p>${q.title}</p><p>EXP +${q.reward.exp}<br>${lines.join('<br>')}</p>
        ${lv?`<p class="gold">⬆ เลเวลอัป! Lv ${P.lvl}</p>`:''}<button class="primary" onclick="closeModal();talkElder()">ตกลง</button>`);
    });
  } else {
    showDialog(n,[`ภารกิจ "${q.title}" ยังไม่สำเร็จ`,questProgress(q).map(r=>`${ENEMIES[r.s].name} ${r.have}/${r.n}`).join(' · ')]);
  }
}

// ---------- bounties ----------
function unlockedStages(){
  const s=[...MAPS.forest.enemies];
  if(P.flags.boss5)s.push(...MAPS.mountain.enemies);
  if(P.flags.boss10)s.push(...MAPS.castle.enemies);
  return s;
}
function genBounty(){
  const ss=unlockedStages(),s=ss[Math.floor(Math.random()*ss.length)],st=enemyStats(s);
  if(Math.random()<.65){const n=3+Math.floor(Math.random()*4);
    return {type:'kill',s,n,base:P.kills[s]||0,gold:Math.round(st.gold*n*.9),exp:Math.round(st.exp*n*.6)}}
  const drops=ENEMIES[s].drops,m=drops[Math.floor(Math.random()*drops.length)].m,n=3+Math.floor(Math.random()*3);
  return {type:'mat',m,n,gold:Math.round(MATS[m].price*n*3),exp:Math.round(st.exp*n*.4)};
}
function ensureBounties(){while(P.bounties.length<3)P.bounties.push(genBounty())}
function bountyHave(b){return b.type==='kill'?Math.min(b.n,(P.kills[b.s]||0)-b.base):Math.min(b.n,P.mats[b.m]||0)}
const bountyDone=b=>bountyHave(b)>=b.n;
function openBoard(){
  ensureBounties();sfx('ui');
  const rows=P.bounties.map((b,i)=>{const done=bountyDone(b);
    const what=b.type==='kill'?`ปราบ ${ENEMIES[b.s].name}`:`ส่งมอบ ${MATS[b.m].icon} ${MATS[b.m].name}`;
    return `<div class="card ${done?'eq':''}" style="text-align:left"><h4>${what} <span class="small">${bountyHave(b)}/${b.n}</span></h4>
      <div class="sub">รางวัล 💰${b.gold} · EXP ${b.exp}</div>
      <button class="${done?'primary':''}" ${done?'':'disabled'} onclick="claimBounty(${i})">รับรางวัล</button>
      <button ${P.gold<20?'disabled':''} onclick="rerollBounty(${i})">เปลี่ยน (💰20)</button></div>`}).join('');
  modal(`<h3>📋 กระดานค่าหัว</h3><p class="small">ทำได้ไม่จำกัด · นับเฉพาะศัตรูที่ปราบหลังติดประกาศ</p><div class="grid1">${rows}</div>
    <button onclick="closeModal()">ปิด</button>`);
}
function claimBounty(i){const b=P.bounties[i];if(!bountyDone(b))return;
  if(b.type==='mat')P.mats[b.m]-=b.n;
  P.gold+=b.gold;const lv=gainExp(b.exp);P.bounties.splice(i,1);ensureBounties();save();sfx('coin');
  toast(`📋 ได้รับ 💰${b.gold} · EXP ${b.exp}${lv?' · เลเวลอัป!':''}`,'#e3b04b');openBoard()}
function rerollBounty(i){if(P.gold<20)return;P.gold-=20;P.bounties[i]=genBounty();save();openBoard()}

// ---------- NPC actions ----------
function npcAction(id){
  W.keys={};
  switch(id){
    case 'merchant':showDialog('พ่อค้า โทคิจิ',['ยินดีต้อนรับ! ของดีราคาถูกทั้งนั้น'],()=>openShop('buy'));break;
    case 'smith':showDialog('ช่างตีดาบ กันเท็ตสึ',['อาวุธดีต้องผ่านไฟและค้อนนับพันครั้ง','เอาวัตถุดิบมา ข้าจะตีให้คมกว่าเดิม'],()=>openForge());break;
    case 'inn':openInn();break;
    case 'master':showDialog('อาจารย์นินจา ไรเดน',['วิถีนินจาคือการฝึกฝนไม่สิ้นสุด','จะเรียนวิชาใหม่ หรือจะล้างพลังเพื่อเริ่มฝึกใหม่?'],()=>openMaster());break;
    case 'elder':talkElder();break;
    case 'board':openBoard();break;
  }
}
function openInn(){
  const cost=5+P.lvl*3;sfx('ui');
  modal(`<h3>🏮 โรงเตี๊ยม โอฮานะ</h3><p>"พักผ่อนสักคืนไหมคะ? ค่าห้อง ${cost} ทองค่ะ"</p>
    <p class="small">ฟื้น HP/MP เต็ม และบันทึกเกม</p>
    <button class="primary" ${P.gold<cost?'disabled':''} onclick="rest(${cost})">พักผ่อน (💰${cost})</button> <button onclick="closeModal()">ไว้ก่อน</button>`);
}
function rest(cost){P.gold-=cost;P.hp=maxHP();P.mp=maxMP();save();sfx('heal');
  modal(`<h3>😴 หลับสบาย...</h3><p>HP/MP ฟื้นเต็มแล้ว · บันทึกเกมแล้ว</p><button class="primary" onclick="closeModal()">ออกเดินทาง</button>`)}
function openMaster(){
  const used=freeSpent(),cost=50*P.lvl;
  modal(`<h3>🥷 อาจารย์ไรเดน</h3><p>แต้มสถานะ ${P.sp} · แต้มสกิล ${P.skp}</p>
    <button class="primary" onclick="closeModal();openMenu('skills')">เรียนวิชา (สกิล)</button>
    <button onclick="closeModal();openMenu('stats')">อัปค่าสถานะ</button>
    <p class="small" style="margin-top:14px">ล้างแต้มสถานะทั้งหมด (คืน ${used} แต้ม) ราคา 💰${cost}</p>
    <button ${P.gold<cost||!used?'disabled':''} onclick="respec(${cost})">ล้างแต้มสถานะ</button> <button onclick="closeModal()">ปิด</button>`);
}
function classStats(){const C=CLS(),o={...C.base};for(const [k,n] of Object.entries(C.grow))o[k]+=n*(P.lvl-1);return o}
function freeSpent(){const o=classStats();return ['str','agi','int','vit'].reduce((a,k)=>a+Math.max(0,P[k]-o[k]),0)}
function respec(cost){const n=freeSpent();P.gold-=cost;P.sp+=n;Object.assign(P,classStats());fixPlayer();save();sfx('magic');openMaster()}

// ---------- shop ----------
function openShop(tab){
  const tabs=`<div class="tabs" style="justify-content:center">${[['buy','ยา/ไอเทม'],['gear','อุปกรณ์'],['sell','ขายวัตถุดิบ']].map(([t,n])=>
    `<button class="${t===tab?'on':''}" onclick="openShop('${t}')">${n}</button>`).join('')}</div>`;
  let h='';
  if(tab==='buy'){
    h=Object.entries(ITEMS).map(([id,it])=>`<div class="row"><span>${it.name} <span class="small">มี ${P.inv[id]||0} · ${it.desc}</span></span>
      <span><button ${P.gold<it.price?'disabled':''} onclick="buyItem('${id}',1)">💰${it.price}</button>
      <button ${P.gold<it.price*5?'disabled':''} onclick="buyItem('${id}',5)">×5</button></span></div>`).join('');
  } else if(tab==='gear'){
    for(const slot of ['weapon','throw','charm','armor']){
      h+=`<h4 style="font-weight:400;margin:10px 0 4px;text-align:left">${SLOTNAME[slot]}</h4>`;
      for(const [id,g] of Object.entries(GEAR)){if(g.slot!==slot||!g.price)continue;const own=P.owned.includes(id);
        h+=`<div class="row"><span>${g.name} <span class="small">${gearDesc(id)}</span></span>
          <button ${own||P.gold<g.price?'disabled':''} onclick="buyGear('${id}')">${own?'มีแล้ว':'💰'+g.price}</button></div>`}}
  } else {
    const ms=Object.entries(MATS).filter(([id])=>P.mats[id]>0);
    h=ms.length?ms.map(([id,m])=>`<div class="row"><span>${m.icon} ${m.name} ×${P.mats[id]}</span>
      <span><button onclick="sellMat('${id}',1)">ขาย 💰${m.price}</button> <button onclick="sellMat('${id}',${P.mats[id]})">ขายทั้งหมด</button></span></div>`).join('')
      :'<p class="small">ไม่มีวัตถุดิบ — ได้จากการปราบศัตรู</p>';
    h+='<p class="small">เก็บวัตถุดิบไว้ตีอาวุธหรือส่งค่าหัวก็ได้นะ</p>';
  }
  modal(`<h3>🏪 ร้านค้าโทคิจิ <span class="gold" style="font-size:15px">💰${P.gold}</span></h3>${tabs}<div class="scroll">${h}</div>
    <button onclick="closeModal()">ปิด</button>`);
  $('#modal-body').dataset.shop=tab;
}
function buyItem(id,n){const it=ITEMS[id];if(P.gold<it.price*n)return;P.gold-=it.price*n;P.inv[id]=(P.inv[id]||0)+n;save();sfx('coin');openShop('buy')}
function buyGear(id){const g=GEAR[id];if(P.gold<g.price||P.owned.includes(id))return;P.gold-=g.price;P.owned.push(id);P.eq[g.slot]=id;fixPlayer();save();sfx('coin');
  toast(`สวมใส่ ${g.name} แล้ว`,'#e3b04b');openShop('gear')}
function sellMat(id,n){n=Math.min(n,P.mats[id]||0);P.mats[id]-=n;P.gold+=MATS[id].price*n;save();sfx('coin');openShop('sell')}
function gearDesc(id){
  const g=GEAR[id],s=gstat(id);
  if(g.slot==='weapon')return `พลังดาบ +${s.atk}`;
  if(g.slot==='throw')return `พลังปา +${s.atk}`;
  if(g.slot==='charm')return `พลังเวท +${s.atk} · MP +${s.mp}`;
  return `ป้องกัน +${s.def} · HP +${s.hp}`;
}

// ---------- forge ----------
function forgeReq(id){
  const u=P.up[id]||0,g=GEAR[id];if(u>=10)return null;
  const m={};
  if(u<3)m.scrap_iron=u+1;
  else if(u<6){m.scrap_iron=2;m[g.slot==='charm'?'herb':'wolf_pelt']=u-1}
  else if(u<8){m.tengu_feather=u-4;m.oni_horn=1}
  else{m.shadow_shard=u-6;m.oni_horn=2}
  return {u,gold:Math.round((30+(g.price||40)*.3)*(u+1)*(1+u*.15)),mats:m,chance:[100,100,100,95,90,85,75,65,55,45][u]};
}
function canForge(r){return r&&P.gold>=r.gold&&Object.entries(r.mats).every(([k,n])=>(P.mats[k]||0)>=n)}
function openForge(msg=''){
  let h='';
  for(const slot of ['weapon','throw','charm','armor']){
    const id=P.eq[slot],r=forgeReq(id);
    h+=`<div class="card" style="text-align:left"><h4>${SLOTNAME[slot]}: ${gname(id)}</h4><div class="sub">${gearDesc(id)}`;
    if(r){const nx={...P.up};P.up[id]=r.u+1;const after=gearDesc(id);P.up=nx;
      h+=` → <span class="gold">${after}</span><br>ต้องใช้ 💰${r.gold} · `+Object.entries(r.mats).map(([k,n])=>
        `<span style="color:${(P.mats[k]||0)>=n?'#9be37a':'#ff8f80'}">${MATS[k].icon}${MATS[k].name} ${P.mats[k]||0}/${n}</span>`).join(' · ')+
        `<br>โอกาสสำเร็จ ${r.chance}%</div><button ${canForge(r)?'':'disabled'} onclick="doForge('${id}')">ตีเหล็ก +${r.u+1}</button>`;}
    else h+=`<br><span class="gold">ตีถึงขีดสุด +10 แล้ว!</span></div>`;
    h+='</div>';
  }
  modal(`<h3>⚒ โรงตีดาบกันเท็ตสึ <span class="gold" style="font-size:15px">💰${P.gold}</span></h3>
    <p class="small">ตีเสริมอุปกรณ์ที่สวมใส่อยู่ · ถ้าล้มเหลวจะเสียทองและวัตถุดิบ แต่ระดับไม่ลด</p>${msg}<div class="grid1 scroll">${h}</div>
    <button onclick="closeModal()">ปิด</button>`);
}
function doForge(id){
  const r=forgeReq(id);if(!canForge(r))return;
  P.gold-=r.gold;for(const [k,n] of Object.entries(r.mats))P.mats[k]-=n;
  let msg;
  if(Math.random()*100<r.chance){P.up[id]=r.u+1;fixPlayer();sfx('level');msg=`<p class="gold">✨ สำเร็จ! ${gname(id)}</p>`}
  else{sfx('lose');msg=`<p style="color:var(--red)">💥 ล้มเหลว... อุปกรณ์ยังคงเป็น +${r.u}</p>`}
  save();openForge(msg);
}

// ---------- menu (I) ----------
let menuTab='stats';
function openMenu(tab){if(tab)menuTab=tab;$('#menu').classList.add('on');W.keys={};renderMenu();sfx('ui')}
function closeMenu(){$('#menu').classList.remove('on');$('#bagtip').style.display='none';updateHUD(true)}
function renderMenu(){
  renderHeader();
  const tabs=[['stats','สถานะ'],['skills','สกิล'],['bag','กระเป๋า'],['quests','ภารกิจ'],['beast','สมุดศัตรู'],['sys','ระบบ']];
  let h=`<div class="tabs">${tabs.map(([t,n])=>`<button class="${menuTab===t?'on':''}" onclick="menuTab='${t}';renderMenu()">${n}</button>`).join('')}
    <button style="margin-left:auto" onclick="closeMenu()">✕ ปิด (I/Esc)</button></div>`;
  fixPlayer();
  if(menuTab==='stats'){
    const stat=(k,label,info)=>`<div class="row"><span>${label} <b>${P[k]}</b><br><span class="small">${info}</span></span>
      <span><button ${P.sp<1?'disabled':''} onclick="addStat('${k}',1)">+1</button> <button ${P.sp<5?'disabled':''} onclick="addStat('${k}',5)">+5</button></span></div>`;
    h+=`<div class="statgrid"><div>
      <h3>ค่าสถานะ <span class="gold">(แต้มเหลือ ${P.sp})</span></h3><p class="small">สาย ${CLS().name} (${CLS().en}) · ทุกเลเวลได้ ${Object.entries(CLS().grow).map(([k,n])=>k.toUpperCase()+' +'+n).join(', ')} อัตโนมัติ + แต้มอิสระ 1</p>
      ${stat('str','💪 STR พลัง','เพิ่มพลังโจมตีดาบ')}
      ${stat('agi','💨 AGI ความไว','เพิ่มพลังปา คริติคอล และการหลบ')}
      ${stat('int','🔮 INT ปัญญา','เพิ่มพลังเวท MP และการฟื้นฟู')}
      ${stat('vit','❤ VIT ร่างกาย','เพิ่ม HP และพลังป้องกัน')}
    </div><div><h3>ค่าต่อสู้</h3>
      ${[['HP',`${P.hp}/${maxHP()}`],['MP',`${P.mp}/${maxMP()}`],['พลังดาบ',Math.round(meleePow())],['พลังปา',Math.round(rangedPow())],
        ['พลังเวท',Math.round(magicPow())],['ป้องกัน',pDef()],['คริติคอล',critChance().toFixed(1)+'%'],['ชนะทั้งหมด',P.wins]]
        .map(([a,b])=>`<div class="row"><span>${a}</span><b>${b}</b></div>`).join('')}
    </div></div>`;
  }
  else if(menuTab==='skills'){
    h+=`<h3>สกิล <span class="gold">(แต้มสกิลเหลือ ${P.skp})</span> <span class="small">· ได้ 1 แต้มทุกเลเวล</span></h3>`;
    for(const tree of ['katana','shuriken','ninjutsu']){
      h+=`<h4>${TREES[tree]}</h4><div class="grid">`;
      for(const [id,s] of Object.entries(SKILLS)){if(s.tree!==tree)continue;
        const lv=P.skills[id]||0,can=P.skp>0&&P.lvl>=s.req&&lv<s.max;
        h+=`<div class="card ${lv?'eq':''}"><h4>${s.name} <span class="small">Lv ${lv}/${s.max}</span></h4>
          <div class="sub">${s.desc(Math.max(1,lv))}<br>MP ${s.mp} · ต้องการ Lv ${s.req}</div>
          <button ${can?'':'disabled'} onclick="learn('${id}')">${lv?'อัปเกรด':'เรียนรู้'}</button></div>`}
      h+='</div>';
    }
  }
  else if(menuTab==='bag'){h+=bagHTML()}
  else if(menuTab==='quests'){
    const q=MAIN_QUESTS[P.quest.i];
    h+='<h3>📜 ภารกิจหลัก</h3>';
    if(!q)h+='<p class="gold">ทำภารกิจหลักครบทั้งหมดแล้ว!</p>';
    else if(!P.quest.active)h+=`<p>คุยกับผู้ใหญ่บ้านฮิโรชิ (บ้านบนขวาของหมู่บ้าน) เพื่อรับภารกิจ "${q.title}"</p>`;
    else h+=`<div class="card"><h4>${q.title}</h4><div class="sub">${q.talk.join(' ')}</div>`+
      questProgress(q).map(r=>`<div class="row"><span>${ENEMIES[r.s].name}</span><b>${r.have}/${r.n}</b></div>`).join('')+
      `<div class="small">รางวัล 💰${q.reward.gold} · EXP ${q.reward.exp}</div></div>`;
    h+=`<p class="small">ภารกิจหลักที่ทำสำเร็จ ${P.quest.i}/${MAIN_QUESTS.length}</p><h3>📋 ค่าหัว</h3>`;
    ensureBounties();
    h+=P.bounties.map(b=>`<div class="row"><span>${b.type==='kill'?'ปราบ '+ENEMIES[b.s].name:'ส่งมอบ '+MATS[b.m].name}</span><b>${bountyHave(b)}/${b.n}</b></div>`).join('');
    h+='<p class="small">รับรางวัลค่าหัวได้ที่กระดานกลางหมู่บ้าน</p>';
  }
  else if(menuTab==='beast'){
    h+='<h3>📖 สมุดบันทึกศัตรู</h3><div class="grid">';
    for(let s=1;s<ENEMIES.length;s++){const e=ENEMIES[s],k=P.kills[s]||0,st=enemyStats(s);
      const zone=Object.values(MAPS).find(m=>m.enemies&&m.enemies.includes(s)||m.boss===s);
      h+=`<div class="card"><h4>${e.boss?'👹 ':''}${k?e.name:'???'}</h4><div class="sub">${k?`HP ${st.hp} · ATK ${st.atk} · DEF ${st.def}<br>ดรอป: ${e.drops.map(d=>MATS[d.m].icon+MATS[d.m].name).join(', ')}<br>`:''}
        พื้นที่: ${zone?zone.name:'-'} · ปราบแล้ว ${k}</div></div>`}
    h+='</div>';
  }
  else if(menuTab==='sys'){
    h+=`<h3>ระบบ</h3>
      <div class="row"><span>เสียงประกอบ</span><button onclick="P.sound=!P.sound;save();renderMenu()">${P.sound?'🔊 เปิด':'🔇 ปิด'}</button></div>
      <div class="row"><span>แผนที่ย่อ (M)</span><button onclick="P.minimap=!P.minimap;save();renderMenu()">${P.minimap?'เปิด':'ปิด'}</button></div>
      <div class="row"><span>บันทึกเกม (บันทึกอัตโนมัติเมื่อเปลี่ยนพื้นที่/จบการต่อสู้)</span><button onclick="save();toast('บันทึกแล้ว','#9be37a')">บันทึก</button></div>
      <div class="row"><span>ลบเซฟและเริ่มใหม่</span><button onclick="if(confirm('ลบเซฟและเริ่มใหม่?')){try{localStorage.removeItem(SAVE_KEY)}catch(e){};location.reload()}">ลบเซฟ</button></div>
      <h3>ปุ่มควบคุม</h3><p class="small">WASD / ลูกศร = เดิน · Shift = วิ่ง · E / Space = คุย/เปิดหีบ · I / Tab = เมนู · M = แผนที่ย่อ · Esc = ปิด<br>
      ในการต่อสู้: 1-8 = ใช้สกิล/ไอเทม · Q / E = เปลี่ยนหมวด · R = โอกิ</p>`;
  }
  $('#menu').innerHTML=h;
  if(menuTab==='bag')bindBag();
}
function addStat(k,n){n=Math.min(n,P.sp);if(n<1)return;P[k]+=n;P.sp-=n;if(k==='vit')P.hp+=n*10;if(k==='int')P.mp+=n*5;save();renderMenu()}
function learn(id){const s=SKILLS[id],lv=P.skills[id]||0;if(P.skp<1||P.lvl<s.req||lv>=s.max)return;
  P.skills[id]=lv+1;P.skp--;save();sfx('magic');renderMenu()}
function equip(id){P.eq[GEAR[id].slot]=id;fixPlayer();save();renderMenu()}
function useMapItem(id){const it=ITEMS[id];if(!(P.inv[id]>0)||it.battle)return;P.inv[id]--;
  if(it.hp)P.hp=Math.min(maxHP(),P.hp+it.hp);if(it.mp)P.mp=Math.min(maxMP(),P.mp+it.mp);sfx('heal');save();renderMenu()}
