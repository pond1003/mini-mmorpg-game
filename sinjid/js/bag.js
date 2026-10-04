'use strict';
// ================= MMORPG-STYLE INVENTORY (grid bag + paper doll + tooltips) =================
const BAG_SLOTS = 36;
let bagFilter = 'all', bagSel = null;

// ---------- rarity ----------
const RARITY = [
  {name:'ธรรมดา',col:'#a8a8a8'},{name:'ดี',col:'#5fd35f'},{name:'หายาก',col:'#4a9bff'},
  {name:'มหากาพย์',col:'#c070ff'},{name:'ตำนาน',col:'#ff9d2e'}];
const ITEM_RAR = {potion:0,ether:0,hipotion:1,bomb:1,smoke:1,elixir:3};
const MAT_RAR = {herb:0,scrap_iron:0,wolf_pelt:0,tengu_feather:1,shadow_shard:2,oni_horn:2};
function rarity(e){
  if(e.t==='gear'){const p=GEAR[e.id].price;return p===0?0:p<200?1:p<700?2:p<2000?3:4}
  return e.t==='item'?ITEM_RAR[e.id]||0:MAT_RAR[e.id]||0;
}

// ---------- icons (drawn once, cached as data URLs) ----------
const ICON_CACHE = {};
const ICON_ART = {
  // weapons: blade tint by tier
  wood_katana:{k:'katana',blade:'#b08a5a',hilt:'#5a3a22'}, steel_katana:{k:'katana',blade:'#dde2ea',hilt:'#2a1c1c'},
  kage_blade:{k:'katana',blade:'#9ab0ff',hilt:'#1c1c3a',glow:'#7a8cff'}, dragon_fang:{k:'katana',blade:'#ffd27a',hilt:'#7a1a1a',glow:'#ff9d2e'},
  muramasa:{k:'katana',blade:'#ff6a6a',hilt:'#1a0a0a',glow:'#ff2020'},
  iron_star:{k:'star',col:'#b8bcc4'}, steel_kunai:{k:'kunai',col:'#dde2ea'}, venom_star:{k:'star',col:'#7bd35a',glow:'#5aff3a'},
  phoenix_star:{k:'star',col:'#ff9d2e',glow:'#ff5a1a'},
  paper_charm:{k:'ofuda'}, jade_charm:{k:'beads',col:'#3fae6a'}, spirit_scroll:{k:'scroll'}, dragon_orb:{k:'orb',col:'#c070ff'},
  cloth:{k:'armor',col:'#2a2a2e'}, leather:{k:'armor',col:'#8a5a32'}, chain:{k:'armor',col:'#9a9aa2',rings:1},
  shadow_garb:{k:'armor',col:'#26263a',trim:'#c8382c'}, oni_armor:{k:'armor',col:'#8b1a1a',trim:'#d4af37',plates:1},
  potion:{k:'bottle',col:'#5fd35f'}, hipotion:{k:'bottle',col:'#ffcf40',big:1}, ether:{k:'bottle',col:'#4aa8ff'},
  elixir:{k:'bottle',col:'#ff6ad5',big:1,glow:'#ff9ae8'}, bomb:{k:'bomb',col:'#2a2a2e'}, smoke:{k:'bomb',col:'#9a9aa2',smoke:1},
  herb:{k:'leaf'}, scrap_iron:{k:'gear'}, wolf_pelt:{k:'pelt'}, tengu_feather:{k:'feather'}, shadow_shard:{k:'crystal'}, oni_horn:{k:'horn'},
};
function iconURL(id){
  if(ICON_CACHE[id])return ICON_CACHE[id];
  const cv2=document.createElement('canvas');cv2.width=cv2.height=64;const c=cv2.getContext('2d'),a=ICON_ART[id]||{k:'orb',col:'#888888'};
  c.lineJoin=c.lineCap='round';
  if(a.glow){c.shadowColor=a.glow;c.shadowBlur=12}
  switch(a.k){
    case 'katana':{c.translate(32,32);c.rotate(-Math.PI/4);
      c.beginPath();c.moveTo(-6,-3);c.quadraticCurveTo(10,-7,27,-1);c.lineTo(-6,3);c.closePath();ink(c,grad(c,0,-6,0,3,a.blade),2);
      c.shadowBlur=0;c.beginPath();c.ellipse(-8,0,2.5,6,0,0,7);ink(c,shade('#c9a227',0),1.6);
      c.beginPath();c.rect(-26,-3,17,6);ink(c,grad(c,0,-3,0,3,a.hilt),1.8);
      c.strokeStyle='rgba(255,255,255,.35)';c.lineWidth=1;for(let i=-24;i<-10;i+=4){c.beginPath();c.moveTo(i,-3);c.lineTo(i+2,3);c.stroke()}break}
    case 'star':{c.translate(32,32);c.beginPath();for(let i=0;i<8;i++){const r=i%2?6:22,an=i*Math.PI/4+Math.PI/8;c.lineTo(Math.cos(an)*r,Math.sin(an)*r)}c.closePath();
      ink(c,grad(c,-20,-20,20,20,a.col),2.2);c.shadowBlur=0;blob(c,0,0,4,4,'#3a3a40',1.6);break}
    case 'kunai':{c.translate(32,32);c.rotate(-Math.PI/4);c.beginPath();c.moveTo(26,0);c.lineTo(4,-7);c.lineTo(0,0);c.lineTo(4,7);c.closePath();ink(c,grad(c,0,-7,0,7,a.col),2);
      c.beginPath();c.rect(-18,-2.5,18,5);ink(c,shade('#3a2a2a',0),1.6);c.beginPath();c.arc(-23,0,5,0,7);c.lineWidth=2.5;c.strokeStyle=OUT;c.stroke();break}
    case 'ofuda':{c.translate(32,32);c.rotate(.15);c.beginPath();c.rect(-11,-24,22,48);ink(c,grad(c,-11,0,11,0,'#efe2c4'),2);
      c.fillStyle='#c8382c';c.fillRect(-6,-18,12,3);c.fillRect(-2,-14,4,22);c.fillRect(-7,-2,14,3);c.fillRect(-5,12,10,3);break}
    case 'beads':{for(let i=0;i<10;i++){const an=i/10*Math.PI*2;blob(c,32+Math.cos(an)*17,32+Math.sin(an)*17,6,6,a.col,1.6)}blob(c,32,52,5,7,'#c9a227',1.6);break}
    case 'scroll':{c.beginPath();c.rect(14,20,36,24);ink(c,grad(c,0,20,0,44,'#e8d8a8'),2);capsule(c,12,18,12,46,5,5,'#6b3a1a',2);capsule(c,52,18,52,46,5,5,'#6b3a1a',2);
      c.fillStyle='#2a2a6a';for(let i=0;i<4;i++)c.fillRect(20+i*7,25,3,14);break}
    case 'orb':{const g=c.createRadialGradient(26,24,3,32,32,22);g.addColorStop(0,'#ffffff');g.addColorStop(.3,a.col);g.addColorStop(1,hexShade(a.col,-.6));
      c.beginPath();c.arc(32,32,20,0,7);ink(c,g,2.2);c.shadowBlur=0;c.beginPath();c.ellipse(32,52,14,4,0,0,7);ink(c,shade('#c9a227',0),1.6);break}
    case 'armor':{c.beginPath();c.moveTo(18,12);c.lineTo(27,16);c.quadraticCurveTo(32,21,37,16);c.lineTo(46,12);c.lineTo(56,22);c.lineTo(49,30);c.lineTo(46,27);
      c.lineTo(46,54);c.lineTo(18,54);c.lineTo(18,27);c.lineTo(15,30);c.lineTo(8,22);c.closePath();ink(c,grad(c,8,12,56,54,a.col),2.2);
      if(a.trim){c.strokeStyle=a.trim;c.lineWidth=3;c.beginPath();c.moveTo(27,16);c.lineTo(32,40);c.lineTo(37,16);c.stroke();c.fillStyle=a.trim;c.fillRect(18,44,28,4)}
      if(a.rings){c.strokeStyle='rgba(0,0,0,.35)';c.lineWidth=1;for(let y=24;y<54;y+=5)for(let x=20;x<46;x+=5){c.beginPath();c.arc(x,y,2,0,7);c.stroke()}}
      if(a.plates){c.strokeStyle='rgba(0,0,0,.5)';c.lineWidth=1.5;for(let y=30;y<54;y+=7){c.beginPath();c.moveTo(18,y);c.lineTo(46,y);c.stroke()}}
      break}
    case 'bottle':{const s=a.big?1.1:1;c.translate(32,34);c.scale(s,s);
      c.beginPath();c.moveTo(-6,-20);c.lineTo(-6,-10);c.quadraticCurveTo(-18,-6,-17,8);c.quadraticCurveTo(-16,20,0,20);c.quadraticCurveTo(16,20,17,8);c.quadraticCurveTo(18,-6,6,-10);c.lineTo(6,-20);c.closePath();
      ink(c,'rgba(220,235,245,.35)',2.2);c.shadowBlur=0;
      c.save();c.clip();const g=c.createLinearGradient(0,-2,0,20);g.addColorStop(0,hexShade(a.col,.3));g.addColorStop(1,hexShade(a.col,-.35));c.fillStyle=g;c.fillRect(-20,-2,40,24);c.restore();
      c.beginPath();c.rect(-7,-25,14,6);ink(c,shade('#8a5a32',0),1.8);c.fillStyle='rgba(255,255,255,.55)';c.beginPath();c.ellipse(-9,2,2.5,6,.3,0,7);c.fill();break}
    case 'bomb':{blob(c,30,36,18,18,a.col,2.2);c.fillStyle='rgba(255,255,255,.35)';c.beginPath();c.ellipse(23,29,5,3,-.6,0,7);c.fill();
      c.strokeStyle=OUT;c.lineWidth=3;c.beginPath();c.moveTo(40,22);c.quadraticCurveTo(48,12,52,14);c.stroke();
      if(a.smoke){c.fillStyle='rgba(200,200,210,.8)';for(const [x,y,r] of [[50,12,6],[56,8,4],[45,7,4]]){c.beginPath();c.arc(x,y,r,0,7);c.fill()}}
      else{c.fillStyle='#ffcf40';c.beginPath();c.arc(53,13,4,0,7);c.fill();c.fillStyle='#ff5a1a';c.beginPath();c.arc(53,13,2,0,7);c.fill()}break}
    case 'leaf':{c.translate(32,34);c.rotate(-.6);for(const [r,s] of [[0,1],[.7,.75],[-.7,.75]]){c.save();c.rotate(r);c.scale(s,s);
      c.beginPath();c.moveTo(0,22);c.quadraticCurveTo(-16,0,0,-24);c.quadraticCurveTo(16,0,0,22);ink(c,grad(c,-12,0,12,0,'#5fae3a'),2);
      c.strokeStyle='rgba(0,0,0,.35)';c.lineWidth=1.2;c.beginPath();c.moveTo(0,20);c.lineTo(0,-20);c.stroke();c.restore()}break}
    case 'gear':{c.translate(32,32);c.beginPath();for(let i=0;i<16;i++){const r=i%2?15:21,an=i*Math.PI/8;c.lineTo(Math.cos(an)*r,Math.sin(an)*r)}c.closePath();
      ink(c,grad(c,-20,-20,20,20,'#8a8a92'),2.2);c.beginPath();c.arc(0,0,6,0,7);ink(c,shade('#2a2a2e',0),2);
      c.fillStyle='rgba(140,80,40,.5)';c.beginPath();c.arc(9,8,5,0,7);c.fill();break}
    case 'pelt':{c.beginPath();c.moveTo(14,18);c.quadraticCurveTo(32,10,50,18);c.lineTo(54,30);c.quadraticCurveTo(50,40,52,50);c.quadraticCurveTo(32,56,12,50);c.quadraticCurveTo(14,40,10,30);c.closePath();
      ink(c,grad(c,10,10,54,54,'#8a8a90'),2.2);c.strokeStyle='rgba(0,0,0,.3)';c.lineWidth=1.2;for(let i=0;i<6;i++){c.beginPath();c.moveTo(18+i*6,24);c.lineTo(16+i*6,44);c.stroke()}break}
    case 'feather':{c.translate(32,32);c.rotate(.7);c.beginPath();c.moveTo(0,26);c.quadraticCurveTo(-14,0,0,-26);c.quadraticCurveTo(14,0,0,26);ink(c,grad(c,-12,-20,12,20,'#2a2a30'),2);
      c.strokeStyle='#c8382c';c.lineWidth=2;c.beginPath();c.moveTo(0,28);c.lineTo(0,-22);c.stroke();
      c.strokeStyle='rgba(255,255,255,.2)';c.lineWidth=1;for(let y=-16;y<18;y+=5){c.beginPath();c.moveTo(0,y);c.lineTo(-8,y-5);c.moveTo(0,y);c.lineTo(8,y-5);c.stroke()}break}
    case 'crystal':{c.shadowColor='#b56cff';c.shadowBlur=10;c.beginPath();c.moveTo(32,6);c.lineTo(46,26);c.lineTo(40,56);c.lineTo(24,56);c.lineTo(18,26);c.closePath();
      ink(c,grad(c,18,6,46,56,'#8a4ad0'),2.2);c.shadowBlur=0;c.strokeStyle='rgba(255,255,255,.4)';c.lineWidth=1.5;c.beginPath();c.moveTo(32,6);c.lineTo(30,56);c.moveTo(18,26);c.lineTo(46,26);c.stroke();break}
    case 'horn':{c.beginPath();c.moveTo(18,54);c.quadraticCurveTo(14,30,30,16);c.quadraticCurveTo(40,8,50,8);c.quadraticCurveTo(38,20,36,32);c.quadraticCurveTo(34,44,36,54);c.closePath();
      ink(c,grad(c,14,8,50,54,'#efe2c2'),2.2);c.strokeStyle='rgba(0,0,0,.3)';c.lineWidth=1.4;for(let i=0;i<4;i++){c.beginPath();c.moveTo(18+i*2,48-i*9);c.lineTo(35-i,46-i*9);c.stroke()}break}
  }
  return ICON_CACHE[id]=cv2.toDataURL();
}

// ---------- entries ----------
function bagEntries(){
  const eqd=new Set(Object.values(P.eq)),e=[];
  if(bagFilter==='all'||bagFilter==='gear')for(const id of P.owned)if(!eqd.has(id))e.push({t:'gear',id,n:1});
  if(bagFilter==='all'||bagFilter==='item')for(const id in ITEMS)if(P.inv[id]>0)e.push({t:'item',id,n:P.inv[id]});
  if(bagFilter==='all'||bagFilter==='mat')for(const id in MATS)if(P.mats[id]>0)e.push({t:'mat',id,n:P.mats[id]});
  return e;
}
const entryName=e=>e.t==='gear'?gname(e.id):e.t==='item'?ITEMS[e.id].name:MATS[e.id].name;
const entryKey=e=>e.t+':'+e.id;

function gearLines(id){
  const g=GEAR[id],s=gstat(id),L=[];
  if(g.slot==='weapon')L.push(['พลังดาบ',s.atk]);
  if(g.slot==='throw')L.push(['พลังปา',s.atk]);
  if(g.slot==='charm'){L.push(['พลังเวท',s.atk]);L.push(['MP',s.mp])}
  if(g.slot==='armor'){L.push(['ป้องกัน',s.def]);L.push(['HP',s.hp])}
  return L;
}
function tipHTML(e,equipped){
  const r=RARITY[rarity(e)];
  let h=`<div class="tname" style="color:${r.col}">${entryName(e)}</div><div class="ttype">${r.name} · `;
  if(e.t==='gear'){
    const g=GEAR[e.id];h+=`${SLOTNAME[g.slot]}${equipped?' · <span class="gold">สวมใส่อยู่</span>':''}</div>`;
    const cur=gearLines(P.eq[g.slot]),mine=gearLines(e.id);
    h+=mine.map(([k,v],i)=>{const d=v-cur[i][1];
      return `<div class="tline">${k} +${v}${!equipped&&d?` <span style="color:${d>0?'#5fd35f':'#ff6a5a'}">(${d>0?'▲':'▼'}${Math.abs(d)})</span>`:''}</div>`}).join('');
    if(P.up[e.id])h+=`<div class="tline gold">ตีเสริม +${P.up[e.id]}</div>`;
    h+=`<div class="tfoot">${equipped?'ตีเสริมได้ที่ช่างตีดาบ':'ดับเบิลคลิก / คลิกขวา / ลากไปช่องอุปกรณ์ = สวมใส่'}</div>`;
    if(g.price)h+=`<div class="tprice">มูลค่า 💰${g.price}</div>`;
  } else if(e.t==='item'){
    const it=ITEMS[e.id];h+=`ไอเทม</div><div class="tline">${it.desc}</div>`;
    h+=`<div class="tfoot">${it.battle?'ใช้ได้ในการต่อสู้เท่านั้น':'ดับเบิลคลิก / คลิกขวา = ใช้'}</div><div class="tprice">ราคา 💰${it.price} · มี ${e.n}</div>`;
  } else {
    const m=MATS[e.id];h+=`วัตถุดิบ</div><div class="tline">ใช้ตีเสริมอุปกรณ์ หรือส่งค่าหัว</div>
      <div class="tline small">ดรอปจาก: ${ENEMIES.filter(x=>x&&x.drops.some(d=>d.m===e.id)).map(x=>x.name).join(', ')}</div>
      <div class="tprice">ขายได้ 💰${m.price} / ชิ้น · มี ${e.n}</div>`;
  }
  return h;
}
function slotHTML(e,i){
  if(!e)return `<div class="slot empty"></div>`;
  const r=rarity(e),sel=bagSel===entryKey(e);
  return `<div class="slot r${r}${sel?' sel':''}" data-i="${i}" draggable="${e.t==='gear'}"><img src="${iconURL(e.id)}" alt="">
    ${e.n>1?`<span class="cnt">${e.n}</span>`:''}${e.t==='gear'&&P.up[e.id]?`<span class="up">+${P.up[e.id]}</span>`:''}</div>`;
}
function eqSlotHTML(slot){
  const id=P.eq[slot],e={t:'gear',id,n:1};
  return `<div class="eqslot"><div class="slot r${rarity(e)}" data-eq="${slot}"><img src="${iconURL(id)}" alt="">${P.up[id]?`<span class="up">+${P.up[id]}</span>`:''}</div>
    <span>${SLOTNAME[slot]}</span></div>`;
}

function bagHTML(){
  const list=bagEntries(),n=Math.max(BAG_SLOTS,Math.ceil(list.length/6)*6);
  const filters=[['all','ทั้งหมด'],['gear','อุปกรณ์'],['item','ไอเทม'],['mat','วัตถุดิบ']];
  const sel=list.find(e=>entryKey(e)===bagSel);
  return `<div class="bag">
    <div class="doll panel">
      <div class="dolltitle">${P.name} <span class="small">Lv ${P.lvl} · ${CLS().name}</span></div>
      <div class="dollbody">
        <div class="eqcol">${eqSlotHTML('weapon')}${eqSlotHTML('throw')}</div>
        <canvas id="dollcv" width="170" height="230"></canvas>
        <div class="eqcol">${eqSlotHTML('charm')}${eqSlotHTML('armor')}</div>
      </div>
      <div class="dollstats">
        <span>❤ HP <b>${P.hp}/${maxHP()}</b></span><span>🔷 MP <b>${P.mp}/${maxMP()}</b></span>
        <span>⚔ ดาบ <b>${Math.round(meleePow())}</b></span><span>✴ ปา <b>${Math.round(rangedPow())}</b></span>
        <span>🔥 เวท <b>${Math.round(magicPow())}</b></span><span>🛡 ป้องกัน <b>${pDef()}</b></span>
      </div>
    </div>
    <div class="bagside panel">
      <div class="bagtop"><div class="tabs">${filters.map(([k,v])=>`<button class="${bagFilter===k?'on':''}" onclick="bagFilter='${k}';bagSel=null;renderMenu()">${v}</button>`).join('')}</div>
        <span class="gold">💰 ${P.gold}</span></div>
      <div class="bagmain"><div class="baggrid">${Array.from({length:n},(_,i)=>slotHTML(list[i],i)).join('')}</div>
        <div id="bagdetail">${sel?detailHTML(sel):'<span class="small">คลิกที่ไอเทมเพื่อดูรายละเอียด<br><br>ดับเบิลคลิก / คลิกขวา = ใช้หรือสวมใส่<br>ลากอุปกรณ์ไปวางที่ช่องข้างตัวละครได้</span>'}</div></div>
      <div class="bagfoot small">${list.length}/${n} ช่อง</div>
    </div>
  </div>`;
}
function detailHTML(e){
  let btn='';
  if(e.t==='gear')btn=`<button class="primary" onclick="bagPrimary('${e.t}','${e.id}')">สวมใส่</button>`;
  else if(e.t==='item'&&!ITEMS[e.id].battle)btn=`<button class="primary" onclick="bagPrimary('${e.t}','${e.id}')">ใช้</button>`;
  return `<div class="ddetail"><img src="${iconURL(e.id)}" alt=""><div>${tipHTML(e,false)}</div>${btn}</div>`;
}

function bagPrimary(t,id){
  if(t==='gear'){equip(id);sfx('ui');toast(`สวมใส่ ${gname(id)}`,'#e3b04b');bagSel=null}
  else if(t==='item'){if(ITEMS[id].battle){toast('ใช้ได้ในการต่อสู้เท่านั้น','#ff8f80');return}
    if(ITEMS[id].hp&&P.hp>=maxHP()&&!ITEMS[id].mp){toast('HP เต็มอยู่แล้ว','#aaa');return}
    useMapItem(id);toast(`ใช้ ${ITEMS[id].name}`,'#9be37a')}
  renderMenu();
}

// ---------- events ----------
function bindBag(){
  const tip=$('#bagtip'),list=bagEntries();
  const show=(html,ev)=>{tip.innerHTML=html;tip.style.display='block';moveTip(ev)};
  const moveTip=ev=>{const w=tip.offsetWidth,h=tip.offsetHeight;let x=ev.clientX+16,y=ev.clientY+16;
    if(x+w>innerWidth-8)x=ev.clientX-w-16;if(y+h>innerHeight-8)y=innerHeight-h-8;tip.style.left=x+'px';tip.style.top=y+'px'};
  const hide=()=>{tip.style.display='none'};
  document.querySelectorAll('.baggrid .slot[data-i]').forEach(el=>{
    const e=list[+el.dataset.i];
    el.onmouseenter=ev=>show(tipHTML(e,false),ev);el.onmousemove=moveTip;el.onmouseleave=hide;
    el.onclick=()=>{bagSel=entryKey(e);sfx('ui');hide();renderMenu()};
    el.ondblclick=()=>{hide();bagPrimary(e.t,e.id)};
    el.oncontextmenu=ev=>{ev.preventDefault();hide();bagPrimary(e.t,e.id)};
    el.ondragstart=ev=>{hide();ev.dataTransfer.setData('text/plain',e.id);document.querySelectorAll(`[data-eq="${GEAR[e.id].slot}"]`).forEach(s=>s.classList.add('drop'))};
    el.ondragend=()=>document.querySelectorAll('.drop').forEach(s=>s.classList.remove('drop'));
  });
  document.querySelectorAll('[data-eq]').forEach(el=>{
    const slot=el.dataset.eq;
    el.onmouseenter=ev=>show(tipHTML({t:'gear',id:P.eq[slot],n:1},true),ev);el.onmousemove=moveTip;el.onmouseleave=hide;
    el.ondragover=ev=>ev.preventDefault();
    el.ondrop=ev=>{ev.preventDefault();const id=ev.dataTransfer.getData('text/plain');
      if(GEAR[id]&&GEAR[id].slot===slot)bagPrimary('gear',id);else toast(`ใส่ได้เฉพาะ${SLOTNAME[slot]}`,'#ff8f80')};
  });
  hide();
}
function drawDoll(){
  const el=$('#dollcv');if(!el)return;const c=el.getContext('2d');
  c.clearRect(0,0,170,230);const g=c.createRadialGradient(85,170,10,85,150,120);g.addColorStop(0,'#3a2e28');g.addColorStop(1,'rgba(0,0,0,0)');
  c.fillStyle=g;c.fillRect(0,0,170,230);
  c.save();c.translate(80,218);c.fillStyle='rgba(0,0,0,.45)';c.beginPath();c.ellipse(0,2,36,6,0,0,7);c.fill();
  c.scale(1.12,1.12);drawBody(c,{look:playerLook(),flash:0},0,0);c.restore();
}
