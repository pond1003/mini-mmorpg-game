'use strict';
// ================= HELPERS / PLAYER / SAVE / SOUND =================
const $ = s => document.querySelector(s);
const pct = x => Math.round(x*100)+'%';
const rnd = (a,b) => a+Math.random()*(b-a);
const clamp = (v,a,b) => Math.max(a,Math.min(b,v));
const ease = k => 1-Math.pow(1-k,3);
let SPEED = 1; // animation speed multiplier (used by automated tests)
const sleep = ms => new Promise(r=>setTimeout(r,ms/SPEED));
function anim(ms,fn){
  ms=Math.max(1,ms/SPEED);
  return new Promise(r=>{const s=performance.now();
    (function step(now){const k=Math.min(1,(now-s)/ms);fn(k);if(k<1)requestAnimationFrame(step);else r()})(s)});
}
function mulberry32(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);
  t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
const hash2 = (x,y) => { let h=(x*374761393+y*668265263)|0; h=Math.imul(h^(h>>>13),1274126177); return ((h^(h>>>16))>>>0)/4294967296; };

const cv = document.getElementById('cv'), ctx = cv.getContext('2d');
let T = 0;           // global time (s)
let P = null;        // player save data
let B = null;        // battle state
let STATE = 'title'; // title | world | battle

const SAVE_KEY = 'shadowninja_save_v2';
const expNeed = l => Math.floor(30*Math.pow(l,1.5));

function newPlayer(name,cls='balanced'){
  const s = MAPS.village.spawn, C = CLASSES[cls];
  return {ver:2,name,cls,lvl:1,exp:0,gold:60,...C.base,sp:0,skp:1,
    skills:{...C.skills}, inv:{potion:3,ether:1}, mats:{}, up:{},
    owned:['wood_katana','iron_star','paper_charm','cloth'],
    eq:{weapon:'wood_katana',throw:'iron_star',charm:'paper_charm',armor:'cloth'},
    hp:null, mp:null, map:'village', x:(s.x+.5)*TS, y:(s.y+.5)*TS,
    kills:{}, flags:{}, opened:{}, quest:{i:0,active:false,base:{}}, bounties:[],
    sound:true, minimap:true, wins:0};
}

// gear stats including forge upgrades (+1 .. +10)
function gstat(id){
  const g=GEAR[id], u=P.up[id]||0;
  return {atk:g.atk?Math.round(g.atk*(1+.12*u)+u):0, def:g.def?Math.round(g.def*(1+.12*u)+u):0,
    hp:(g.hp||0)+(g.slot==='armor'?8*u:0), mp:(g.mp||0)+(g.slot==='charm'?4*u:0)};
}
const gname = id => GEAR[id].name+((P.up[id]||0)?` +${P.up[id]}`:'');
const gear = s => gstat(P.eq[s]);
const CLS = () => CLASSES[P.cls]||CLASSES.balanced;
const maxHP = () => Math.round((60+P.vit*10+P.lvl*8+gear('armor').hp)*CLS().hpMul);
const maxMP = () => Math.round((25+P.int*5+P.lvl*2+gear('charm').mp)*CLS().mpMul);
const pDef = () => Math.round(P.vit*.8+gear('armor').def*2);
const meleePow = () => P.str*2+gear('weapon').atk*1.5+P.lvl;
const rangedPow = () => P.agi*1.8+gear('throw').atk*1.5+P.lvl;
const magicPow = () => P.int*2.3+gear('charm').atk*1.5+P.lvl;
const critChance = () => 5+P.agi*.4+CLS().crit;
// class look, dressed in the currently equipped gear
const GEAR_LOOK = {
  leather:{top:'#8a5a32',sleeve:'#7a4e2a'}, chain:{armor:'#9a9aa2',sleeve:'#7a7a82'},
  shadow_garb:{top:'#26263a',sash:'#c8382c',belt:'#c8382c'}, oni_armor:{armor:'#8b1a1a',top:'#5a1414',sash:'#d4af37',belt:'#d4af37'},
  kage_blade:{glow:'#7a8cff'}, dragon_fang:{glow:'#ff9d2e'}, muramasa:{glow:'#ff2020',wLen:92},
};
const playerLook = () => {const L={...CLS().look};for(const s of ['armor','weapon'])Object.assign(L,GEAR_LOOK[P.eq[s]]||{});return L};
function fixPlayer(){
  if(P.hp==null||P.hp>maxHP())P.hp=maxHP();
  if(P.mp==null||P.mp>maxMP())P.mp=maxMP();
}

function enemyStats(s){
  const b=ENEMIES[s].boss?1:0;
  return {hp:Math.round((40+32*s+5.5*s*s)*(b?1.8:1)), atk:Math.round((9+4*s+.12*s*s)*(b?1.2:1)),
    def:Math.round(1+1.6*s), agi:3+s, mag:Math.round((8+4*s)*(b?1.2:1)),
    exp:Math.round((22+14*s+1.4*s*s)*(b?2.5:1)), gold:Math.round((14+11*s)*(b?2.5:1)),
    rec:Math.max(1,Math.round(s*1.45))};
}

function addLoot(l){ // returns list of text lines
  const out=[];
  if(l.gold){P.gold+=l.gold;out.push(`💰 ${l.gold} ทอง`)}
  for(const [k,n] of Object.entries(l.items||{})){P.inv[k]=(P.inv[k]||0)+n;out.push(`${ITEMS[k].name} ×${n}`)}
  for(const [k,n] of Object.entries(l.mats||{})){P.mats[k]=(P.mats[k]||0)+n;out.push(`${MATS[k].icon} ${MATS[k].name} ×${n}`)}
  if(l.gear){
    if(P.owned.includes(l.gear)){const g=Math.round(GEAR[l.gear].price/2);P.gold+=g;out.push(`💰 ${g} ทอง (มี ${GEAR[l.gear].name} แล้ว)`)}
    else{P.owned.push(l.gear);out.push(`⭐ ${GEAR[l.gear].name}`)}
  }
  return out;
}

function gainExp(n){ // returns number of levels gained
  P.exp+=n;let up=0;
  while(P.exp>=expNeed(P.lvl)){P.exp-=expNeed(P.lvl);P.lvl++;for(const [k,n] of Object.entries(CLS().grow))P[k]+=n;P.sp+=1;P.skp+=1;up++}
  if(up){P.hp=maxHP();P.mp=maxMP();sfx('level')}
  return up;
}

function save(){try{localStorage.setItem(SAVE_KEY,JSON.stringify(P))}catch(e){}}
function load(){try{const s=localStorage.getItem(SAVE_KEY);return s?JSON.parse(s):null}catch(e){return null}}
function migrate(s){
  const p=Object.assign(newPlayer(s.name,CLASSES[s.cls]?s.cls:'balanced'),s);
  if(!CLASSES[p.cls])p.cls='balanced';
  for(const k of ['kills','flags','opened','mats','up','inv'])p[k]=p[k]||{};
  p.quest=Object.assign({i:0,active:false,base:{}},p.quest||{});
  if(!MAPS[p.map])p.map='village';
  return p;
}

// ---- tiny WebAudio synth ----
let AC=null;
function tone(f,dur,type='square',vol=.04,f2=null,delay=0){
  const t0=AC.currentTime+delay,o=AC.createOscillator(),g=AC.createGain();
  o.type=type;o.frequency.setValueAtTime(f,t0);if(f2)o.frequency.exponentialRampToValueAtTime(f2,t0+dur);
  g.gain.setValueAtTime(vol,t0);g.gain.exponentialRampToValueAtTime(.0001,t0+dur);
  o.connect(g).connect(AC.destination);o.start(t0);o.stop(t0+dur+.02);
}
function sfx(t){
  if(!P||!P.sound||SPEED>1)return;
  try{
    AC=AC||new (window.AudioContext||window.webkitAudioContext)();
    switch(t){
      case 'hit':tone(220,.09,'sawtooth',.05,80);break;
      case 'crit':tone(320,.08,'square',.05);tone(640,.12,'square',.05,null,.07);break;
      case 'miss':tone(900,.08,'sine',.03,1400);break;
      case 'throw':tone(1200,.07,'triangle',.03,600);break;
      case 'magic':tone(400,.3,'sine',.05,1200);break;
      case 'heal':tone(600,.15,'sine',.04,900);tone(900,.2,'sine',.04,1300,.12);break;
      case 'level':[523,659,784,1047].forEach((f,i)=>tone(f,.16,'square',.04,null,i*.1));break;
      case 'coin':tone(988,.07,'square',.03);tone(1319,.15,'square',.03,null,.07);break;
      case 'start':tone(150,.25,'sawtooth',.05,60);tone(300,.2,'square',.03,null,.15);break;
      case 'ui':tone(660,.05,'triangle',.03);break;
      case 'win':[392,523,659,784].forEach((f,i)=>tone(f,.18,'triangle',.05,null,i*.12));break;
      case 'lose':[392,330,262].forEach((f,i)=>tone(f,.3,'triangle',.05,null,i*.25));break;
    }
  }catch(e){}
}
