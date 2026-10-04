'use strict';
// ================= STATE / LOOP / INPUT =================
function setState(s){
  STATE=s;
  document.body.dataset.state=s;
  document.querySelectorAll('.screen').forEach(el=>el.classList.toggle('on',el.id===(s==='title'?'title-screen':'game')));
  if(s==='world'){W.keys={};updateHUD(true)}
  renderHeader();
}
function backToWorld(reload){
  B=null;
  if(reload||W.id!==P.map)loadMap(P.map);
  W.inv=2;setState('world');
}
function enterGame(){
  fixPlayer();ensureBounties();loadMap(P.map);
  if(blocked(P.x,P.y)){const s=MAPS.village.spawn;P.map='village';loadMap('village');P.x=(s.x+.5)*TS;P.y=(s.y+.5)*TS}
  W.inv=1;setState('world');
}

let last=performance.now();
function frame(now){
  const dt=Math.min(.05,(now-last)/1000);last=now;T=now/1000;
  if(STATE==='world'&&W.t){updateWorld(dt);if(STATE==='world'){renderWorld();updateHUD();if(menuOpen()&&menuTab==='bag')drawDoll()}}
  else if(STATE==='battle'&&B)renderBattle();
  else if(STATE==='title'&&$('#title-screen').classList.contains('picking'))drawClassCards();
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

const GAME_KEYS=new Set(['w','a','s','d','arrowup','arrowdown','arrowleft','arrowright',' ','tab']);
addEventListener('keydown',e=>{
  if(e.target.tagName==='INPUT')return;
  const k=e.key.toLowerCase();
  if(STATE!=='title'&&GAME_KEYS.has(k))e.preventDefault();
  if(k==='escape'){if(modalOpen()&&STATE==='world')closeModal();else if(menuOpen())closeMenu();return}
  if(STATE==='world'){
    if(dialogOpen()){if(k==='e'||k===' '||k==='enter')advanceDialog();return}
    if(modalOpen())return;
    if(k==='i'||k==='tab'){menuOpen()?closeMenu():openMenu();return}
    if(menuOpen())return;
    if(k==='m'){P.minimap=!P.minimap;return}
    if(k==='e'||k===' '||k==='enter'){interact();return}
    W.keys[k]=true;if(e.shiftKey)W.keys.shift=true;
  } else if(STATE==='battle'&&B&&!modalOpen()){
    if(/^[1-9]$/.test(k)){const b=[...document.querySelectorAll('#skillbtns button')][+k-1];if(b&&!b.disabled)b.click()}
    else if(k==='q'||k==='e'){const i=ACT_TABS.indexOf(B.tab);setTab(ACT_TABS[(i+(k==='e'?1:3))%4])}
    else if(k==='r')useUlt();
  }
});
addEventListener('keyup',e=>{const k=e.key.toLowerCase();W.keys[k]=false;if(k==='shift')W.keys.shift=false});
addEventListener('blur',()=>{W.keys={}});
$('#dialog').addEventListener('click',advanceDialog);

// on-screen d-pad for touch devices
document.querySelectorAll('#pad [data-k]').forEach(b=>{
  const k=b.dataset.k,on=ev=>{ev.preventDefault();if(k==='e')interact();else if(k==='i')openMenu();else W.keys[k]=true},off=()=>{W.keys[k]=false};
  b.addEventListener('pointerdown',on);b.addEventListener('pointerup',off);b.addEventListener('pointerleave',off);
});

// ================= TITLE =================
let pickCls=null;
const STAT_TH={str:'STR',agi:'AGI',int:'INT',vit:'VIT'};
$('#btn-new').onclick=()=>{
  $('#title-screen').classList.add('picking');pickCls=null;$('#btn-start').disabled=true;
  $('#class-cards').innerHTML=Object.entries(CLASSES).map(([id,C])=>`<div class="ccard" data-c="${id}"><canvas width="200" height="250"></canvas>
    <h4>${C.name}</h4><div class="en">${C.en}</div><p>${C.desc}</p>
    <div class="st">${Object.entries(C.base).map(([k,v])=>`<span>${STAT_TH[k]} <b>${v}</b></span>`).join('')}
    <span>HP ×${C.hpMul}</span><span>MP ×${C.mpMul}</span></div>
    <p class="small">เลเวลอัป: ${Object.entries(C.grow).map(([k,n])=>STAT_TH[k]+' +'+n).join(', ')}<br>สกิลเริ่ม: ${Object.keys(C.skills).map(s=>SKILLS[s].name).join(', ')}</p></div>`).join('');
  document.querySelectorAll('.ccard').forEach(el=>el.onclick=()=>{pickCls=el.dataset.c;sfx('ui');
    document.querySelectorAll('.ccard').forEach(x=>x.classList.toggle('on',x===el));$('#btn-start').disabled=false});
};
$('#btn-back').onclick=()=>$('#title-screen').classList.remove('picking');
function drawClassCards(){
  document.querySelectorAll('.ccard').forEach(el=>{const c=el.querySelector('canvas').getContext('2d'),on=el.classList.contains('on');
    c.clearRect(0,0,200,250);c.save();c.translate(92,236);c.fillStyle='rgba(0,0,0,.4)';c.beginPath();c.ellipse(0,2,40,7,0,0,7);c.fill();
    c.scale(1.18,1.18);drawBody(c,{look:CLASSES[el.dataset.c].look,flash:0},on?Math.max(0,Math.sin(T*3))*.0:0,0);c.restore()});
}
$('#btn-start').onclick=()=>{
  if(!pickCls)return;
  if(load()&&!confirm('มีเซฟเก่าอยู่ เริ่มใหม่จะทับเซฟเดิม ตกลงไหม?'))return;
  P=newPlayer(($('#pname').value||'ซินจิด').trim(),pickCls);save();
  $('#title-screen').classList.remove('picking');
  enterGame();
  showDialog('อาจารย์นินจา ไรเดน',[
    `ตื่นแล้วหรือ ${P.name}... เจ้าเลือกเดินบนวิถีแห่ง${CLS().name}`,
    'หมู่บ้านใบไม้กำลังตกอยู่ในอันตราย กองทัพของโชกุนเงา คาเงะโมริ ส่งสมุนมาคุกคามทุกทิศทาง',
    'ไปพบผู้ใหญ่บ้านฮิโรชิ (บ้านด้านบนขวา) เพื่อรับภารกิจแรก',
    'ใช้ WASD เดิน · E คุย · I เปิดเมนู · ทางออกไปป่าไผ่อยู่ทางขวาของหมู่บ้าน'],()=>{});
};
$('#btn-continue').onclick=()=>{const s=load();if(!s){modal('<h3>ไม่พบเซฟ</h3><button class=primary onclick=closeModal()>ตกลง</button>');return}
  P=migrate(s);enterGame()};
if(!load())$('#btn-continue').disabled=true;
setState('title');
