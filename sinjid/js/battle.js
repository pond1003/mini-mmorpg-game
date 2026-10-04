'use strict';
// ================= TURN-BASED BATTLE =================
const GROUND = 440;
const fx = [], texts = [];
let shake = 0, lastTab = 'katana';

function startBattle(stage, src){
  const def=ENEMIES[stage], st=enemyStats(stage);
  fixPlayer();
  B={stage,src,theme:MAPS[P.map].theme,busy:false,over:false,tab:lastTab,chakra:0,
    p:{side:'p',name:P.name,hp:P.hp,max:maxHP(),mp:P.mp,maxmp:maxMP(),st:{},x:230,y:GROUND,ox:0,flash:0,kind:'player',look:playerLook()},
    e:{side:'e',name:def.name,hp:st.hp,max:st.hp,mp:0,maxmp:0,st:{},x:730,y:GROUND,ox:0,flash:0,kind:def.kind,look:def.look,boss:def.boss,...st,moves:def.moves}};
  fx.length=0;texts.length=0;
  $('#log').innerHTML='';
  log(`⚔ ${def.name} (แนะนำ Lv ${st.rec}) ขวางทางคุณ!`,'s');
  log('คีย์ลัด: 1-8 ใช้สกิล · Q/E เปลี่ยนหมวด · R ใช้โอกิ','s');
  sfx('start');
  setState('battle');
  renderActions();
}

function log(msg,cls=''){const d=document.createElement('div');d.className=cls;d.textContent=msg;const l=$('#log');l.appendChild(d);l.scrollTop=l.scrollHeight}

const ACT_TABS=['katana','shuriken','ninjutsu','item'];
function renderActions(){
  if(!B)return;
  $('#act-tabs').innerHTML=ACT_TABS.map(t=>`<button class="${B.tab===t?'on':''}" onclick="setTab('${t}')">${TREES[t]}</button>`).join('');
  const dis=B.busy||B.over;
  let h='';
  if(B.tab==='item'){
    for(const [id,it] of Object.entries(ITEMS)){const n=P.inv[id]||0;if(!n)continue;
      h+=`<button ${dis?'disabled':''} onclick="useItem('${id}')">${it.name} ×${n}<small>${it.desc}</small></button>`;}
    h+=`<button ${dis?'disabled':''} onclick="flee()">🏃 หลบหนี<small>โอกาส ${B.e.boss?25:50}%</small></button>`;
  } else {
    for(const [id,s] of Object.entries(SKILLS)){ if(s.tree!==B.tab)continue; const lv=P.skills[id]; if(!lv)continue;
      h+=`<button ${dis||B.p.mp<s.mp?'disabled':''} onclick="useSkill('${id}')" title="${s.desc(lv)}">${s.name} <span class="small">Lv${lv}</span><small>MP ${s.mp} · ${s.desc(lv)}</small></button>`;}
    if(!h)h='<span class="small">ยังไม่มีสกิลสายนี้ — เรียนได้จากอาจารย์ไรเดนในหมู่บ้าน หรือเมนู (I)</span>';
  }
  $('#skillbtns').innerHTML=h;
  const full=B.chakra>=100;
  $('#ult').innerHTML=`<div class="chakra"><i style="width:${Math.floor(B.chakra)}%"></i></div>
    <button class="ult ${full?'ready':''}" ${dis||!full?'disabled':''} onclick="useUlt()">💥 โอกิ: ผนึกพันเงา <span class="small">จักระ ${Math.floor(B.chakra)}%</span></button>`;
}
function setTab(t){B.tab=lastTab=t;sfx('ui');renderActions()}

async function playerTurn(action){
  if(!B||B.busy||B.over)return;
  B.busy=true;renderActions();
  await action();
  if(await checkEnd())return;
  await sleep(250);
  await tickStatus(B.e);
  if(await checkEnd())return;
  await enemyTurn();
  if(await checkEnd())return;
  await tickStatus(B.p);
  if(await checkEnd())return;
  mpUnit(B.p,Math.round(B.p.maxmp*.04),true);
  B.busy=false;renderActions();
}
function useSkill(id){const s=SKILLS[id];if(!B||!P.skills[id]||B.p.mp<s.mp)return;
  playerTurn(async()=>{B.p.mp-=s.mp;log(`${P.name} ใช้ ${s.name}!`,'p');await s.run(P.skills[id])})}
function useItem(id){if(!B||!(P.inv[id]>0))return;
  playerTurn(async()=>{
    P.inv[id]--;const it=ITEMS[id];log(`${P.name} ใช้ ${it.name}`,'p');
    if(id==='bomb'){await projectile(B.p,B.e,'fire');dealDamage(B.e,50+P.lvl*8,{canCrit:false,raw:true});addStatus(B.e,'burn',2,10+P.lvl*2)}
    else if(id==='smoke'){await buffFx(B.p,'#aaa');log('ปุ้ง! คุณหายตัวไปในกลุ่มควัน','s');B.over=true;await sleep(400);endBattle('flee')}
    else{await healFx(B.p);if(it.hp)healUnit(B.p,it.hp);if(it.mp)mpUnit(B.p,it.mp)}
  })}
function flee(){playerTurn(async()=>{
  if(Math.random()<(B.e.boss?.25:.5)){log('หนีสำเร็จ!','s');B.over=true;await sleep(400);endBattle('flee')}
  else log('หนีไม่พ้น!','e')})}
function useUlt(){if(!B||B.chakra<100)return;
  playerTurn(async()=>{
    B.chakra=0;B.ult=true;log(`${P.name} ปลดปล่อยโอกิ: ผนึกพันเงา!!`,'p');
    B.dark=1;await buffFx(B.p,'#ff3d3d');
    const pow=(meleePow()+rangedPow()+magicPow())/3;
    for(let i=0;i<6&&B.e.hp>0;i++){
      B.p.ox=(B.e.x-B.p.x)*(i%2?-0.15:0.85);B.p.swing=1;sfx('hit');
      dealDamage(B.e,pow*1.05,{critChance:critChance()+10});
      await anim(110,k=>{B.p.swing=1-k});
    }
    await anim(250,k=>{B.p.ox*=1-k});B.p.ox=0;B.dark=0;B.ult=false;
  })}

// ---- damage core ----
function dealDamage(target,raw,opt={}){
  const def=target.side==='e'?target.def:pDef();
  let dmg=opt.raw?raw*rnd(.9,1.1):raw*rnd(.9,1.1)*60/(60+def*2);
  let crit=false;
  if(opt.canCrit!==false && Math.random()*100<(opt.critChance||0)){dmg*=1.7;crit=true}
  dmg=Math.max(1,Math.round(dmg));
  target.hp=Math.max(0,target.hp-dmg);
  target.flash=1;
  if(!B.ult)B.chakra=Math.min(100,B.chakra+(target.side==='e'?dmg/target.max*70:dmg/target.max*110));
  floatText(target,(crit?'CRIT! ':'')+dmg,crit?'#ffd34d':'#fff',crit?30:24);
  for(let i=0;i<(crit?14:7);i++)spark(target.x+target.ox,target.y-(target.kind==='wolf'?70:140),crit?'#ffd34d':'#ff5a4a');
  shake=crit?10:5;sfx(crit?'crit':'hit');
  return dmg;
}
function tryDodge(target){
  if(target.st.clone){target.st.clone.t--;if(target.st.clone.t<=0)delete target.st.clone;
    floatText(target,'เงาหลบ!','#b9a8ff',22);sfx('miss');return true}
  const atkAgi=target.side==='p'?B.e.agi:P.agi, defAgi=target.side==='p'?P.agi:B.e.agi;
  const ch=clamp(4+(defAgi-atkAgi)*.8,2,30);
  if(Math.random()*100<ch){floatText(target,'หลบ!','#9fd3ff',22);sfx('miss');return true}
  return false;
}
async function meleeHits(n,mult,opt={}){
  const a=B.p,t=B.e;
  await anim(220,k=>{a.ox=(t.x-a.x-120)*ease(k)});
  for(let i=0;i<n;i++){
    a.swing=1;
    if(!tryDodge(t)) dealDamage(t,meleePow()*mult,{critChance:critChance()+(opt.crit||0)});
    await anim(n>1?130:200,k=>{a.swing=1-k});
    if(t.hp<=0)break;
  }
  await anim(220,k=>{a.ox=(t.x-a.x-120)*(1-ease(k))});
}
async function rangedHits(n,mult,opt={}){
  let anyHit=false;
  for(let i=0;i<n;i++){
    await projectile(B.p,B.e,opt.proj||'star');
    if(!tryDodge(B.e)){dealDamage(B.e,rangedPow()*mult,{critChance:critChance()+5});anyHit=true}
    if(B.e.hp<=0)break;
  }
  return anyHit;
}
async function magicHit(mult,type){
  sfx('magic');
  if(type==='fire'||type==='dragon') await projectile(B.p,B.e,type);
  else await lightning(B.e);
  dealDamage(B.e,magicPow()*mult,{canCrit:false});
}
function healUnit(u,n){const before=u.hp;u.hp=Math.min(u.max,u.hp+n);const d=u.hp-before;
  if(d>0){floatText(u,'+'+d,'#7dff8a',24);log(`${u.name} ฟื้น HP ${d}`,u.side==='p'?'p':'e');sfx('heal')}}
function mpUnit(u,n,quiet){const before=u.mp;u.mp=Math.min(u.maxmp,u.mp+n);const d=u.mp-before;
  if(d>0&&!quiet)floatText(u,'+'+d+' MP','#7fb6ff',22)}

const STATUS_INFO={poison:['พิษ','#7bd35a'],burn:['ไหม้','#ff8a3d'],stun:['มึนงง','#ffd34d'],clone:['เงาแยกร่าง','#b9a8ff']};
function addStatus(u,k,turns,val=0){
  if(u.hp<=0)return;
  u.st[k]={t:turns,v:val};
  floatText(u,STATUS_INFO[k][0]+'!',STATUS_INFO[k][1],20);
  log(`${u.name} ติดสถานะ ${STATUS_INFO[k][0]}`,'s');
}
async function tickStatus(u){
  for(const k of ['poison','burn']){
    const s=u.st[k]; if(!s)continue;
    u.hp=Math.max(0,u.hp-s.v);u.flash=.6;
    floatText(u,'-'+s.v,STATUS_INFO[k][1],22);
    log(`${u.name} เสีย HP ${s.v} จาก${STATUS_INFO[k][0]}`,u.side==='p'?'e':'p');
    if(--s.t<=0)delete u.st[k];
    await sleep(350);
  }
}

// ---- enemy AI ----
async function enemyTurn(){
  const e=B.e,p=B.p;
  if(e.st.stun){delete e.st.stun;log(`${e.name} มึนงง ขยับไม่ได้!`,'s');floatText(e,'Zzz','#ffd34d',22);await sleep(500);return}
  let mv='hit';
  const specials=e.moves.filter(m=>m!=='hit'&&m!=='heal');
  if(e.moves.includes('heal')&&e.hp<e.max*.3&&Math.random()<.45&&(e.healed||0)<2){mv='heal';e.healed=(e.healed||0)+1}
  else if(specials.length&&(!e.moves.includes('hit')||Math.random()<(e.boss?.45:.32)))mv=specials[Math.floor(Math.random()*specials.length)];
  const melee=async(mult,name)=>{
    log(`${e.name} ${name}!`,'e');
    await anim(220,k=>{e.ox=-(e.x-p.x-120)*ease(k)});
    e.swing=1;
    if(!tryDodge(p)) dealDamage(p,e.atk*mult,{critChance:e.boss?8:4});
    await anim(200,k=>{e.swing=1-k});
    await anim(220,k=>{e.ox=-(e.x-p.x-120)*(1-ease(k))});
  };
  switch(mv){
    case 'hit': await melee(1,'โจมตี');break;
    case 'bite': await melee(1.3,'กัดอย่างดุร้าย');break;
    case 'heavy': await melee(1.6,'ใช้ท่าโจมตีหนัก');break;
    case 'star': log(`${e.name} ปาอาวุธลับ!`,'e');
      for(let i=0;i<2;i++){await projectile(e,p,'star');if(!tryDodge(p))dealDamage(p,e.atk*.65,{critChance:4})}break;
    case 'poison': log(`${e.name} ปาเข็มพิษ!`,'e');await projectile(e,p,'kunai');
      if(!tryDodge(p)){dealDamage(p,e.atk*.6,{canCrit:false});addStatus(p,'poison',3,Math.round(e.mag*.45))}break;
    case 'fire': log(`${e.name} ร่ายคาถาไฟ!`,'e');sfx('magic');await projectile(e,p,'fire');
      dealDamage(p,e.mag*1.5,{canCrit:false});addStatus(p,'burn',2,Math.round(e.mag*.35));break;
    case 'stun': log(`${e.name} ทุบพื้นสะเทือน!`,'e');shake=12;await sleep(250);
      if(!tryDodge(p)){dealDamage(p,e.atk*.9,{canCrit:false});if(Math.random()<.5)addStatus(p,'stun',1)}break;
    case 'drain': log(`${e.name} ดูดพลังชีวิต!`,'e');await lightning(p,'#b04bff');
      {const d=dealDamage(p,e.mag*1.3,{canCrit:false});healUnit(e,Math.round(d*.6))}break;
    case 'heal': log(`${e.name} ฟื้นฟูตัวเอง`,'e');await healFx(e);healUnit(e,Math.round(e.max*.22));break;
  }
  if(p.st.stun&&p.hp>0){
    delete p.st.stun;await sleep(400);log(`${P.name} มึนงง เสียเทิร์น!`,'s');
    await tickStatus(B.e); if(B.e.hp<=0||p.hp<=0)return;
    await enemyTurn();
  }
}

async function checkEnd(){
  if(!B||B.over)return true;
  if(B.e.hp<=0){B.over=true;B.e.dead=1;log(`${B.e.name} พ่ายแพ้!`,'s');await sleep(900);endBattle('win');return true}
  if(B.p.hp<=0){B.over=true;B.p.dead=1;log(`${P.name} ล้มลง...`,'e');await sleep(900);endBattle('lose');return true}
  return false;
}

function endBattle(res){
  P.hp=B.p.hp;P.mp=B.p.mp;
  const stage=B.stage,def=ENEMIES[stage],src=B.src;
  if(res==='win'){
    const st=enemyStats(stage);
    P.kills[stage]=(P.kills[stage]||0)+1;P.wins++;
    const firstBoss=def.boss&&!P.flags['boss'+stage];
    if(def.boss)P.flags['boss'+stage]=1;
    const loot={gold:st.gold,mats:{},items:{}};
    for(const d of def.drops)if(Math.random()<d.c)loot.mats[d.m]=(loot.mats[d.m]||0)+(d.n||1);
    if(Math.random()<.25){const k=Math.random()<.55?'potion':Math.random()<.6?'ether':Math.random()<.5?'hipotion':'bomb';loot.items[k]=1}
    const lines=addLoot(loot);
    const lv=gainExp(st.exp);
    if(src)worldEnemyDefeated(src);
    const qNote=questNotes();
    let ending='';
    if(firstBoss){
      const z=Object.values(MAPS).find(m=>m.boss===stage);
      ending=z&&z.next?`<p class="gold">🔓 ทางไปยัง ${MAPS[z.next].name} เปิดแล้ว!</p>`
        :`<p class="gold">🏆 คุณปราบโชกุนเงาได้แล้ว! หมู่บ้านใบไม้กลับมาสงบสุข<br>คุณคือนินจาผู้ยิ่งใหญ่ที่สุด</p><p class="small">เกมยังเล่นต่อได้ — ล่าค่าหัวและตีอาวุธ +10 ให้ครบ!</p>`;
    }
    save();sfx('win');
    modal(`<h3 style="color:var(--gold)">ชัยชนะ!</h3><p>EXP +${st.exp}</p><p>${lines.join('<br>')}</p>
      ${lv?`<p class="gold">⬆ เลเวลอัป! Lv ${P.lvl} (+${lv*3} แต้มสถานะ, +${lv} แต้มสกิล) · HP/MP ฟื้นเต็ม</p>`:''}${qNote}${ending}
      <button class="primary" onclick="closeModal();backToWorld()">ไปต่อ</button>`);
  } else if(res==='lose'){
    const lost=Math.floor(P.gold*.1);P.gold-=lost;
    P.hp=maxHP();P.mp=maxMP();
    const inn=MAPS.village.inn;P.map='village';P.x=(inn.x+.5)*TS;P.y=(inn.y+.5)*TS;
    save();sfx('lose');
    modal(`<h3 style="color:var(--red)">พ่ายแพ้...</h3><p>คุณฟื้นขึ้นที่โรงเตี๊ยมในหมู่บ้าน เสียทอง ${lost}</p>
      <p class="small">ลองอัปสถานะ เรียนสกิล ตีอาวุธ หรือซื้ออุปกรณ์ใหม่</p><button class="primary" onclick="closeModal();backToWorld(true)">ตกลง</button>`);
  } else { save(); backToWorld(); }
}

// ================= BATTLE RENDERING =================
function floatText(u,txt,color,size){texts.push({x:u.x+u.ox+rnd(-20,20),y:u.y-(u.kind==='wolf'?150:270),txt,color,size,life:1})}
function spark(x,y,color){fx.push({type:'p',x,y,vx:rnd(-4,4),vy:rnd(-5,1),color,life:1,r:rnd(2,4)})}

async function projectile(from,to,type){
  if(type==='star'||type==='kunai')sfx('throw');
  const sx=from.x+(from.side==='p'?50:-50),sy=from.y-150,tx=to.x,ty=to.y-(to.kind==='wolf'?80:140);
  const p={type,x:sx,y:sy,rot:0};fx.push(p);
  const dur=type==='dragon'?650:type==='fire'?450:280;
  await anim(dur,k=>{p.x=sx+(tx-sx)*k;p.y=sy+(ty-sy)*k-Math.sin(k*Math.PI)*(type==='star'?18:30);p.rot+=.5;
    if(type!=='star'&&type!=='kunai')for(let i=0;i<(type==='dragon'?4:2);i++)fx.push({type:'p',x:p.x,y:p.y,vx:rnd(-1,1)-(tx>sx?2:-2),vy:rnd(-1.5,1),
      color:type==='dragon'?(Math.random()<.5?'#a020f0':'#ff3d00'):(Math.random()<.5?'#ffb347':'#ff4500'),life:.8,r:rnd(3,7)})});
  p.dead=1;
  if(type==='fire'||type==='dragon')for(let i=0;i<(type==='dragon'?40:18);i++)spark(tx,ty,i%2?'#ff7a00':'#ffd000');
}
async function lightning(to,color='#bfe3ff'){
  const b={type:'bolt',x:to.x,y:to.y-130,color,life:1};fx.push(b);shake=8;
  await anim(380,k=>{b.life=1-k});b.dead=1;
}
async function healFx(u){for(let i=0;i<20;i++)fx.push({type:'p',x:u.x+rnd(-40,40),y:u.y-rnd(0,240),vx:0,vy:-rnd(1,2.5),color:'#7dff8a',life:1,r:rnd(2,4)});await sleep(450)}
async function buffFx(u,c){for(let i=0;i<26;i++)fx.push({type:'p',x:u.x+rnd(-55,55),y:u.y-rnd(0,250),vx:rnd(-.5,.5),vy:-rnd(.3,1.2),color:c,life:1,r:rnd(2,5)});await sleep(450)}

// ---- Flash-style painted backgrounds (prerendered once per theme) ----
const BG_CACHE={};
function bgHills(c,base,amp,seed,col,step=90){
  const R=mulberry32(seed),pts=[];for(let x=-step;x<=960+step;x+=step)pts.push([x,base-R()*amp]);
  c.beginPath();c.moveTo(-10,540);c.lineTo(pts[0][0],pts[0][1]);
  for(let i=1;i<pts.length-1;i++){const mx=(pts[i][0]+pts[i+1][0])/2,my=(pts[i][1]+pts[i+1][1])/2;c.quadraticCurveTo(pts[i][0],pts[i][1],mx,my)}
  c.lineTo(970,540);c.closePath();
  const g=c.createLinearGradient(0,base-amp,0,base+120);g.addColorStop(0,hexShade(col,.12));g.addColorStop(1,hexShade(col,-.3));
  c.fillStyle=g;c.fill();c.strokeStyle='rgba(0,0,0,.45)';c.lineWidth=2.2;c.stroke();
}
function bgSky(c,stops){const g=c.createLinearGradient(0,0,0,400);stops.forEach((s,i)=>g.addColorStop(i/(stops.length-1),s));c.fillStyle=g;c.fillRect(0,0,960,540)}
function bgGlow(c,x,y,r,col,core){const g=c.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,col);g.addColorStop(1,'rgba(0,0,0,0)');c.fillStyle=g;c.fillRect(0,0,960,540);
  if(core){c.fillStyle=core;c.beginPath();c.arc(x,y,r*.16,0,7);c.fill()}}
function bgGround(c,top,col,seed,cracks){
  const g=c.createLinearGradient(0,top,0,540);g.addColorStop(0,hexShade(col,.1));g.addColorStop(1,hexShade(col,-.35));
  c.fillStyle=g;c.beginPath();c.moveTo(0,top);c.quadraticCurveTo(480,top-10,960,top);c.lineTo(960,540);c.lineTo(0,540);c.fill();
  c.strokeStyle='rgba(0,0,0,.45)';c.lineWidth=2;c.beginPath();c.moveTo(0,top);c.quadraticCurveTo(480,top-10,960,top);c.stroke();
  const R=mulberry32(seed);
  if(cracks){c.strokeStyle='rgba(0,0,0,.22)';c.lineWidth=1.4;
    for(let i=0;i<34;i++){let x=R()*960,y=top+8+R()*(540-top);const sc=.4+(y-top)/(540-top);c.beginPath();c.moveTo(x,y);
      for(let k=0;k<4;k++){x+=(R()-.5)*60*sc;y+=(R()-.5)*12*sc;c.lineTo(x,y)}c.stroke()}}
  else{c.strokeStyle=hexShade(col,-.25);c.lineWidth=1.5;
    for(let i=0;i<120;i++){const x=R()*960,y=top+6+R()*(540-top),h=3+(y-top)*.05;c.beginPath();c.moveTo(x,y);c.lineTo(x-2,y-h);c.moveTo(x,y);c.lineTo(x+3,y-h);c.stroke()}}
}
function bgBamboo(c,seed,x0,count,col,dark){
  const R=mulberry32(seed);
  for(let i=0;i<count;i++){const x=x0+i*(960/count)+R()*30,w=9+R()*6,top=-20;
    const g=c.createLinearGradient(x,0,x+w,0);g.addColorStop(0,hexShade(col,.15));g.addColorStop(1,hexShade(col,-.3));
    c.fillStyle=g;c.fillRect(x,top,w,420);c.strokeStyle=dark;c.lineWidth=2;c.strokeRect(x,top,w,420);
    for(let y=20+R()*40;y<400;y+=60+R()*20){c.beginPath();c.moveTo(x-1,y);c.lineTo(x+w+1,y);c.lineWidth=2.5;c.stroke()}
    c.fillStyle=hexShade(col,-.1);for(let k=0;k<3;k++){const ly=40+R()*300;c.beginPath();c.ellipse(x+w+14,ly,16,4,-.4,0,7);c.fill();c.lineWidth=1.2;c.stroke()}}
}
function bgPagoda(c,x,base,s,col){
  c.fillStyle=col;c.strokeStyle='rgba(0,0,0,.6)';c.lineWidth=2;
  for(let i=0;i<4;i++){const w=(70-i*12)*s,y=base-i*34*s;c.fillRect(x-w/2+8*s,y-26*s,w-16*s,26*s);
    c.beginPath();c.moveTo(x-w/2-14*s,y-24*s);c.quadraticCurveTo(x,y-40*s,x+w/2+14*s,y-24*s);c.lineTo(x+w/2-4*s,y-34*s);c.lineTo(x-w/2+4*s,y-34*s);c.closePath();c.fill();c.stroke()}
  c.fillRect(x-2*s,base-4*34*s-30*s,4*s,30*s);
}
function makeBG(theme){
  const cv2=document.createElement('canvas');cv2.width=960;cv2.height=540;const c=cv2.getContext('2d');
  const top=GROUND-70;
  if(theme==='forest'){
    bgSky(c,['#2c3a30','#6f7d52','#d9b36a']);bgGlow(c,700,250,260,'rgba(255,214,140,.55)','#ffe9b8');
    bgHills(c,260,60,11,'#5b6a48');bgHills(c,310,50,12,'#465839');
    bgBamboo(c,3,-10,9,'#5b8a3a','rgba(10,25,8,.8)');
    bgGround(c,top,'#6b7a42',5,false);
  } else if(theme==='mountain'){
    bgSky(c,['#0e0d18','#3e3a56','#8d97ab']);
    const R=mulberry32(9);c.fillStyle='#fff';for(let i=0;i<70;i++){c.globalAlpha=.3+R()*.6;c.fillRect(R()*960,R()*200,1.6,1.6)}c.globalAlpha=1;
    bgGlow(c,180,90,120,'rgba(220,230,255,.5)','#f4f6ff');
    c.fillStyle='#6d7890';c.strokeStyle='rgba(0,0,0,.45)';c.lineWidth=2;c.beginPath();c.moveTo(-10,330);
    for(const [x,y] of [[120,180],[230,280],[360,150],[500,300],[640,170],[790,290],[960,200],[970,330]])c.lineTo(x,y);c.closePath();c.fill();c.stroke();
    c.fillStyle='#eef3f8';c.beginPath();for(const [x,y] of [[120,180],[360,150],[640,170],[960,200]]){c.moveTo(x,y);c.lineTo(x-34,y+40);c.lineTo(x-8,y+30);c.lineTo(x+6,y+44);c.lineTo(x+30,y+36);c.closePath()}c.fill();c.stroke();
    bgHills(c,330,50,21,'#9fb3c4',120);bgHills(c,360,40,22,'#c4d4df',120);
    bgGround(c,top,'#dfe8ee',7,false);
  } else if(theme==='castle'){
    bgSky(c,['#1e0e0c','#7a2c18','#e07a2a','#f6c650']);bgGlow(c,560,330,300,'rgba(255,200,90,.7)','#fff2c0');
    bgHills(c,300,70,31,'#4a2826',110);
    bgPagoda(c,250,330,1.3,'#241212');bgPagoda(c,770,320,.9,'#2e1716');
    bgHills(c,345,25,33,'#3a1e1c',140);
    bgGround(c,top,'#8a5a3a',13,true);
  } else {
    bgSky(c,['#151b28','#2e3646','#5a6272']);
    const R=mulberry32(4);c.fillStyle='#fff';for(let i=0;i<80;i++){c.globalAlpha=.3+R()*.7;c.fillRect(R()*960,R()*220,1.6,1.6)}c.globalAlpha=1;
    bgGlow(c,190,80,110,'rgba(255,255,240,.55)','#fffef0');
    bgHills(c,290,60,41,'#4e5048');bgHills(c,330,40,42,'#6b6a5c');
    bgGround(c,top,'#77705c',15,true);
  }
  return cv2;
}
function drawBattleBG(){
  if(!BG_CACHE[B.theme])BG_CACHE[B.theme]=makeBG(B.theme);
  ctx.drawImage(BG_CACHE[B.theme],0,0);
  if(B.theme==='mountain'){ctx.fillStyle='rgba(255,255,255,.8)';for(let i=0;i<50;i++)ctx.fillRect((i*137+T*30*(1+i%3))%960,(i*91+T*40*(1+i%2))%540,2.5,2.5)}
  if(B.theme==='forest'){ctx.fillStyle='rgba(120,170,60,.6)';for(let i=0;i<10;i++){const x=(i*211+T*25)%980-10,y=(i*67+T*18+Math.sin(T+i)*20)%420;ctx.beginPath();ctx.ellipse(x,y,6,2,T+i,0,7);ctx.fill()}}
  if(B.theme==='castle'){ctx.fillStyle='rgba(255,170,80,.7)';for(let i=0;i<16;i++)ctx.fillRect((i*157+Math.sin(T+i)*30)%960,540-((i*83+T*40)%540),2,2)}
}

function drawFighter(u){
  if(u.dead){u.deadT=(u.deadT||0)+.04;if(u.deadT>1)return;ctx.globalAlpha=1-u.deadT}
  const dir=u.side==='p'?1:-1;
  const bob=Math.sin(T*3+(u.side==='p'?0:1.5))*2;
  const sc=1.45;
  ctx.save();ctx.translate(u.x+u.ox,u.y+bob);ctx.scale(dir*sc,sc);
  ctx.fillStyle='rgba(0,0,0,.35)';ctx.beginPath();ctx.ellipse(0,2/sc,(u.look&&u.look.bulk||1)*30*(u.look&&u.look.scale||1),6,0,0,7);ctx.fill();
  if(u.st.clone){const a=ctx.globalAlpha;ctx.globalAlpha=a*.3;ctx.save();ctx.translate(-30,0);drawBody(ctx,u,u.swing||0);ctx.restore();
    ctx.save();ctx.translate(30,0);drawBody(ctx,u,u.swing||0);ctx.restore();ctx.globalAlpha=a}
  drawBody(ctx,u,u.swing||0);
  ctx.restore();ctx.globalAlpha=1;
  if(u.flash>0)u.flash=Math.max(0,u.flash-.06);
}

function drawFX(){
  for(const f of fx){
    if(f.type==='p'){f.x+=f.vx;f.y+=f.vy;f.vy+=.08;f.life-=.025;ctx.globalAlpha=Math.max(0,f.life);ctx.fillStyle=f.color;ctx.beginPath();ctx.arc(f.x,f.y,f.r,0,7);ctx.fill()}
    else if(f.type==='star'||f.type==='kunai'){
      ctx.save();ctx.translate(f.x,f.y);ctx.rotate(f.type==='star'?f.rot:0);ctx.fillStyle='#dfe6ee';
      if(f.type==='star'){ctx.beginPath();for(let i=0;i<8;i++){const r=i%2?4:13,a=i*Math.PI/4;ctx.lineTo(Math.cos(a)*r,Math.sin(a)*r)}ctx.fill()}
      else{ctx.beginPath();ctx.moveTo(18,0);ctx.lineTo(-4,-4);ctx.lineTo(-4,4);ctx.fill();ctx.fillStyle='#7bd35a';ctx.fillRect(-14,-2,10,4)}
      ctx.restore();
    }
    else if(f.type==='fire'||f.type==='dragon'){
      const r=f.type==='dragon'?26:15;const g=ctx.createRadialGradient(f.x,f.y,2,f.x,f.y,r);
      g.addColorStop(0,'#fff6c0');g.addColorStop(.4,f.type==='dragon'?'#ff3d00':'#ff9a00');g.addColorStop(1,'rgba(160,0,200,0)');
      ctx.fillStyle=g;ctx.beginPath();ctx.arc(f.x,f.y,r,0,7);ctx.fill();
    }
    else if(f.type==='bolt'){
      ctx.globalAlpha=f.life;ctx.strokeStyle=f.color;ctx.lineWidth=4;ctx.shadowColor=f.color;ctx.shadowBlur=20;
      ctx.beginPath();let x=f.x,y=0;ctx.moveTo(x,y);while(y<f.y+60){y+=25;x=f.x+rnd(-22,22);ctx.lineTo(x,y)}ctx.stroke();ctx.shadowBlur=0;
      ctx.fillStyle=`rgba(200,230,255,${f.life*.15})`;ctx.fillRect(0,0,960,540);
    }
    ctx.globalAlpha=1;
  }
  for(let i=fx.length-1;i>=0;i--)if(fx[i].dead||(fx[i].type==='p'&&fx[i].life<=0))fx.splice(i,1);
  for(const t of texts){t.y-=.8;t.life-=.014;ctx.globalAlpha=Math.max(0,t.life);ctx.font=`600 ${t.size}px Mitr, sans-serif`;
    ctx.textAlign='center';ctx.lineWidth=4;ctx.strokeStyle='#000';ctx.strokeText(t.txt,t.x,t.y);ctx.fillStyle=t.color;ctx.fillText(t.txt,t.x,t.y)}
  ctx.globalAlpha=1;
  for(let i=texts.length-1;i>=0;i--)if(texts[i].life<=0)texts.splice(i,1);
}

function drawBars(u,x,alignRight){
  const w=300;const bx=alignRight?x-w:x;
  ctx.font='400 16px Mitr, sans-serif';ctx.textAlign=alignRight?'right':'left';ctx.fillStyle='#fff';
  ctx.fillText((u.boss?'👹 ':'')+u.name+(u.side==='p'?`  Lv ${P.lvl}`:''),x,26);
  const bar=(y,v,m,c,h)=>{ctx.fillStyle='#000';ctx.fillRect(bx,y,w,h);ctx.fillStyle=c;ctx.fillRect(alignRight?bx+w-w*clamp(v/m,0,1):bx,y,w*clamp(v/m,0,1),h);
    ctx.strokeStyle='#555';ctx.lineWidth=1;ctx.strokeRect(bx,y,w,h)};
  bar(34,u.hp,u.max,'#d9443a',14);
  ctx.font='400 11px Mitr, sans-serif';ctx.fillStyle='#fff';ctx.fillText(`HP ${u.hp}/${u.max}`,alignRight?x-4:x+4,45);
  let sy;
  if(u.maxmp){bar(52,u.mp,u.maxmp,'#3b82d9',9);ctx.fillText(`MP ${u.mp}/${u.maxmp}`,alignRight?x-4:x+4,74);sy=80}
  else sy=64;
  let sx=0;
  for(const [k,s] of Object.entries(u.st)){const [n,c]=STATUS_INFO[k];ctx.fillStyle=c;const label=`${n}(${s.t})`;
    ctx.font='400 12px Mitr, sans-serif';ctx.fillText(label,alignRight?x-sx:x+sx,sy+8);sx+=ctx.measureText(label).width+10}
}

function renderBattle(){
  ctx.save();
  if(shake>0){ctx.translate(rnd(-shake,shake),rnd(-shake,shake));shake*=.85;if(shake<.5)shake=0}
  drawBattleBG();
  if(B.dark){ctx.fillStyle='rgba(40,0,0,.55)';ctx.fillRect(-20,-20,1000,580)}
  drawFighter(B.e);drawFighter(B.p);
  drawFX();
  ctx.restore();
  drawBars(B.p,20,false);drawBars(B.e,940,true);
  ctx.font='400 13px Mitr';ctx.textAlign='center';ctx.fillStyle='rgba(255,255,255,.55)';ctx.fillText(MAPS[P.map].name,480,26);
}
