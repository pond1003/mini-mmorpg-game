'use strict';
// ================= OVERWORLD (WASD) =================
const W = {id:null,t:null,w:0,h:0,img:null,mini:null,npcs:[],chests:[],boss:null,enemies:[],exits:[],spawnTiles:[],
  keys:{},inv:0,dir:1,walk:0,moving:false,cam:{x:0,y:0},regenT:0,near:null,gateT:0};
const GEN = {}; // generated map cache

// ---------- map generation ----------
function genMap(id){
  if(GEN[id])return GEN[id];
  const z=MAPS[id],th=THEMES[z.theme],R=mulberry32(z.seed),w=z.w,h=z.h;
  const t=[];for(let y=0;y<h;y++){t.push([]);for(let x=0;x<w;x++)t[y].push(x===0||y===0||x===w-1||y===h-1?th.solids[0]:th.ground)}
  const ri=(a,b)=>a+Math.floor(R()*(b-a+1));
  for(let i=0;i<th.clumps;i++){const cx=ri(1,w-2),cy=ri(1,h-2),r=1+R()*2.6,s=th.solids[ri(0,th.solids.length-1)];
    for(let y=Math.floor(cy-r);y<=cy+r;y++)for(let x=Math.floor(cx-r);x<=cx+r;x++)
      if(x>0&&y>0&&x<w-1&&y<h-1&&Math.hypot(x-cx,y-cy)<r&&R()<.8)t[y][x]=s;}
  for(let i=0;i<th.water;i++){const cx=ri(6,w-7),cy=ri(4,h-5),rx=2+R()*3,ry=1.5+R()*2;
    for(let y=1;y<h-1;y++)for(let x=1;x<w-1;x++)if(((x-cx)/rx)**2+((y-cy)/ry)**2<1)t[y][x]='~';}
  for(let y=1;y<h-1;y++)for(let x=1;x<w-1;x++)if(t[y][x]===th.ground&&R()<.05&&th.deco!==th.ground)t[y][x]=th.deco;
  // main path with waypoints
  const entry={x:0,y:ri(4,h-5)}, exit={x:w-1,y:ri(4,h-5)};
  const pts=[{x:1,y:entry.y},{x:6,y:entry.y},{x:Math.floor(w*.3),y:ri(3,h-4)},{x:Math.floor(w*.55),y:ri(3,h-4)},{x:Math.floor(w*.78),y:ri(3,h-4)},
    {x:w-10,y:exit.y},{x:w-2,y:exit.y}]; // last leg is a straight corridor through the boss
  const carve=(x,y)=>{for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const X=x+dx,Y=y+dy;
    if(X>0&&Y>0&&X<w-1&&Y<h-1)t[Y][X]=(dx===0&&dy===0)||R()<.35?th.path:th.ground}};
  const walkTo=(a,b)=>{let x=a.x,y=a.y;while(x!==b.x||y!==b.y){carve(x,y);
    if(x!==b.x&&(y===b.y||R()<.6))x+=Math.sign(b.x-x);else y+=Math.sign(b.y-y);}carve(x,y)};
  for(let i=0;i<pts.length-1;i++)walkTo(pts[i],pts[i+1]);
  // side branches (chests live at their ends)
  const branchEnds=[];
  for(let i=0;i<z.chestLoot.length;i++){const from=pts[ri(1,pts.length-2)],to={x:ri(3,w-4),y:R()<.5?ri(2,5):ri(h-6,h-3)};
    walkTo(from,to);branchEnds.push(to);}
  t[entry.y][0]=th.path;t[exit.y][w-1]=z.next?th.path:th.solids[0];
  t[entry.y][1]=th.path;t[exit.y][w-2]=th.path;
  // flood fill: make unreachable tiles solid
  const seen=t.map(r=>r.map(()=>0)),q=[[1,entry.y]];seen[entry.y][1]=1;
  while(q.length){const [x,y]=q.pop();for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){const X=x+dx,Y=y+dy;
    if(X>=0&&Y>=0&&X<w&&Y<h&&!seen[Y][X]&&!SOLID.has(t[Y][X])){seen[Y][X]=1;q.push([X,Y])}}}
  const spawnTiles=[];
  for(let y=1;y<h-1;y++)for(let x=1;x<w-1;x++){if(!SOLID.has(t[y][x])&&!seen[y][x])t[y][x]=th.solids[0];
    else if(seen[y][x]&&x>6&&x<w-6)spawnTiles.push({x,y});}
  const chests=branchEnds.map((p,i)=>({id:id+'_c'+i,x:p.x,y:p.y,loot:z.chestLoot[i]}));
  return GEN[id]={t,entry,exit,chests,spawnTiles,boss:{x:w-5,y:exit.y}};
}

// ---------- tiles ----------
function groundFill(c,ch,x,y,h){
  const S=TS;
  const col={'.':'#3e6b34',',':'#3e6b34','=':'#86683f','s':'#dfe7ee','p':'#aebdcc','f':'#352a31','c':'#5e1520'}[ch]||'#3e6b34';
  c.fillStyle=col;c.fillRect(x,y,S,S);
  if(ch==='.'||ch===','){c.fillStyle='#355e2d';for(let i=0;i<4;i++){const a=hash2(x+i,y),b=hash2(y+i,x);c.fillRect(x+a*28,y+b*28,2,4)}
    if(ch===','){const cs=['#f2d16b','#e86f9a','#fff'];for(let i=0;i<3;i++){c.fillStyle=cs[i];c.beginPath();c.arc(x+6+hash2(x,y+i)*20,y+6+hash2(y,x+i)*20,2.5,0,7);c.fill()}}}
  else if(ch==='='){c.fillStyle='#735733';for(let i=0;i<3;i++)c.fillRect(x+hash2(x+i,y)*28,y+hash2(x,y+i)*28,4,3)}
  else if(ch==='s'||ch==='p'){c.fillStyle=ch==='s'?'#c9d6e2':'#98a9bb';for(let i=0;i<3;i++)c.fillRect(x+hash2(x+i,y)*28,y+hash2(x,y+i)*28,3,2)}
  else if(ch==='f'){c.strokeStyle='#2a2127';c.lineWidth=1;c.strokeRect(x+.5,y+.5,S-1,S-1);c.beginPath();c.moveTo(x,y+16);c.lineTo(x+S,y+16);c.stroke()}
  else if(ch==='c'){c.fillStyle='#d4af37';c.fillRect(x,y+2,S,2);c.fillRect(x,y+S-4,S,2)}
}
function drawTile(c,ch,x,y,theme,above){
  const S=TS,gch=THEMES[theme].ground,h=hash2(x,y);
  if(!SOLID.has(ch)){groundFill(c,ch,x,y);return}
  if(ch!=='~')groundFill(c,gch,x,y);
  switch(ch){
    case 'T':c.strokeStyle=OUT;c.lineWidth=1.6;c.fillStyle='#5a3a22';c.fillRect(x+13,y+18,6,14);c.strokeRect(x+13,y+18,6,14);
      {const g=c.createRadialGradient(x+11,y+8,2,x+16,y+14,15);g.addColorStop(0,'#4f8a3a');g.addColorStop(1,'#1d4220');c.fillStyle=g;}
      c.beginPath();c.arc(x+16,y+14,14,0,7);c.fill();c.stroke();c.fillStyle='rgba(255,255,255,.12)';c.beginPath();c.arc(x+11,y+9,5,0,7);c.fill();break;
    case 'B':c.strokeStyle='rgba(10,25,8,.85)';c.lineWidth=1.3;for(let i=0;i<3;i++){const bx=x+4+i*9+h*3;c.fillStyle=i%2?'#6aa846':'#558f36';c.fillRect(bx,y,6,S);c.strokeRect(bx,y,6,S);
        c.beginPath();c.moveTo(bx-1,y+8+i*6);c.lineTo(bx+7,y+8+i*6);c.stroke();}
      c.fillStyle='#6fb048';c.beginPath();c.ellipse(x+20,y+6,8,3,-.5,0,7);c.fill();break;
    case '~':{const dark=theme==='castle';c.fillStyle=dark?'#24122c':'#2a5d8a';c.fillRect(x,y,S,S);c.strokeStyle=dark?'#4a2a5c':'#5d93c4';c.lineWidth=2;
      c.beginPath();c.moveTo(x+4,y+10+h*8);c.quadraticCurveTo(x+10,y+6+h*8,x+16,y+10+h*8);c.stroke();break;}
    case 'H':if(above==='H'){c.fillStyle='#6b4a2e';c.fillRect(x,y,S,S);c.fillStyle='#5a3d24';for(let i=0;i<S;i+=8)c.fillRect(x+i,y,1,S);
        c.fillStyle='#f0e2c0';c.fillRect(x+9,y+8,14,12);c.fillStyle='#6b4a2e';c.fillRect(x+15,y+8,2,12);c.fillRect(x+9,y+13,14,2);}
      else{c.fillStyle='#7a1f1f';c.fillRect(x,y,S,S);c.fillStyle='#5a1515';for(let i=0;i<S;i+=8)c.fillRect(x,y+i+4,S,2);c.fillStyle='#3a0d0d';c.fillRect(x,y+S-4,S,4);}
      break;
    case 'D':c.fillStyle='#6b4a2e';c.fillRect(x,y,S,S);c.fillStyle='#2a1a10';c.fillRect(x+7,y+6,18,26);
      c.fillStyle='#e3b04b';c.fillRect(x+20,y+22,3,3);break;
    case 'L':c.fillStyle='#777';c.fillRect(x+11,y+20,10,12);c.fillRect(x+8,y+8,16,12);c.fillStyle='#ffcf6b';c.fillRect(x+12,y+11,8,6);
      c.fillStyle='#666';c.beginPath();c.moveTo(x+4,y+9);c.lineTo(x+28,y+9);c.lineTo(x+16,y+1);c.fill();break;
    case 'x':c.fillStyle='#7b5533';c.fillRect(x,y+12,S,4);c.fillRect(x,y+22,S,4);c.fillRect(x+4,y+8,4,22);c.fillRect(x+24,y+8,4,22);break;
    case 'S':c.strokeStyle=OUT;c.lineWidth=1.5;c.fillStyle='#4a3020';c.fillRect(x+14,y+24,5,8);c.strokeRect(x+14,y+24,5,8);
      {const g=c.createLinearGradient(x+3,0,x+29,0);g.addColorStop(0,'#3a6a58');g.addColorStop(1,'#16382c');c.fillStyle=g;}
      c.beginPath();c.moveTo(x+16,y+1);c.lineTo(x+29,y+26);c.lineTo(x+3,y+26);c.closePath();c.fill();c.stroke();
      c.fillStyle='#f4f8fb';c.beginPath();c.moveTo(x+16,y+1);c.lineTo(x+22,y+12);c.lineTo(x+16,y+10);c.lineTo(x+10,y+12);c.closePath();c.fill();c.stroke();break;
    case 'r':{const g=c.createLinearGradient(x,y+8,x+20,y+30);g.addColorStop(0,'#9a9aa0');g.addColorStop(1,'#55555c');c.fillStyle=g;}
      c.strokeStyle=OUT;c.lineWidth=1.6;c.beginPath();c.ellipse(x+16,y+19,14,11,0,0,7);c.fill();c.stroke();c.fillStyle='#8d8d93';c.beginPath();c.ellipse(x+12,y+15,6,4,0,0,7);c.fill();
      if(theme==='mountain'){c.fillStyle='#fff';c.beginPath();c.ellipse(x+16,y+10,10,4,0,0,7);c.fill()}break;
    case 'W':c.fillStyle='#0d080b';c.fillRect(x,y,S,S);c.fillStyle='#3d2e37';c.fillRect(x+1,y+1,14,9);c.fillRect(x+17,y+1,14,9);c.fillRect(x+1,y+12,30,9);
      c.fillStyle='#1c1419';c.fillRect(x,y+23,S,9);c.fillStyle='#8a1f2c';c.fillRect(x,y+21,S,2);break;
  }
}
function prerender(){
  const z=MAPS[W.id],img=document.createElement('canvas');img.width=W.w*TS;img.height=W.h*TS;
  const c=img.getContext('2d');
  for(let y=0;y<W.h;y++)for(let x=0;x<W.w;x++)drawTile(c,W.t[y][x],x*TS,y*TS,z.theme,y?W.t[y-1][x]:null);
  W.img=img;
  const m=document.createElement('canvas');m.width=W.w*3;m.height=W.h*3;const mc=m.getContext('2d');
  for(let y=0;y<W.h;y++)for(let x=0;x<W.w;x++){const ch=W.t[y][x];
    mc.fillStyle=ch==='~'?'#2a5d8a':SOLID.has(ch)?'#111':['=','p','c'].includes(ch)?'#a58a5c':z.theme==='mountain'?'#c9d6e2':z.theme==='castle'?'#4a3a42':'#3e6b34';
    mc.fillRect(x*3,y*3,3,3)}
  W.mini=m;
}

// ---------- loading / transitions ----------
function loadMap(id){
  const z=MAPS[id];W.id=id;W.enemies=[];W.boss=null;W.exits=[];
  if(z.rows){
    W.t=z.rows.map(r=>r.padEnd(40,'T').slice(0,40).split(''));W.h=W.t.length;W.w=W.t[0].length;
    W.chests=z.chests.map(c=>({...c}));
    W.exits=z.exits.map(e=>({...e,kind:'next'}));
    W.npcs=z.npcs.map(n=>({...n,px:(n.x+.5)*TS,py:(n.y+.5)*TS,st:{},flash:0,noWeapon:true}));
  } else {
    const g=genMap(id);
    W.t=g.t.map(r=>r.slice());W.w=z.w;W.h=z.h;W.chests=g.chests.map(c=>({...c}));W.npcs=[];W.spawnTiles=g.spawnTiles;
    W.exits=[{x:0,y:g.entry.y,to:z.prev,kind:'prev'}];
    if(z.next)W.exits.push({x:z.w-1,y:g.exit.y,to:z.next,kind:'next'});
    if(!P.flags['boss'+z.boss]){const e=ENEMIES[z.boss];
      W.boss={stage:z.boss,px:(g.boss.x+.5)*TS,py:(g.boss.y+.5)*TS,kind:e.kind,look:e.look,boss:1,st:{},flash:0};}
    for(let i=0;i<z.count;i++)W.enemies.push(spawnEnemy(z.enemies[i%z.enemies.length],true));
  }
  for(const c of W.chests){c.px=(c.x+.5)*TS;c.py=(c.y+.5)*TS}
  prerender();
}
function spawnEnemy(stage,initial){
  const e={stage,kind:ENEMIES[stage].kind,look:ENEMIES[stage].look,st:{},flash:0,alive:true,t:0,vx:0,vy:0,walk:0,dir:1};
  placeEnemy(e,initial);return e;
}
function placeEnemy(e){
  for(let i=0;i<60;i++){const s=W.spawnTiles[Math.floor(Math.random()*W.spawnTiles.length)];
    const x=(s.x+.5)*TS,y=(s.y+.5)*TS;
    if(Math.hypot(x-P.x,y-P.y)>TS*8){e.x=x;e.y=y;return}}
  e.x=W.w*TS/2;e.y=W.h*TS/2;
}
function goMap(to,fromKind){
  const prevId=W.id;P.map=to;loadMap(to);
  const z=MAPS[to];
  if(z.rows){const s=z.fromNext;P.x=(s.x+.5)*TS;P.y=(s.y+.5)*TS}
  else{const g=GEN[to];
    if(fromKind==='next'){P.x=1.6*TS;P.y=(g.entry.y+.5)*TS;W.dir=1}
    else{P.x=(z.w-1.6)*TS;P.y=(g.exit.y+.5)*TS;W.dir=-1}}
  W.inv=1.5;save();
  toast(`📍 ${z.name}`,'#e3b04b');
  if(prevId)updateHUD(true);
}
function worldEnemyDefeated(src){
  if(src==='boss'){W.boss=null;return}
  src.alive=false;src.respawn=performance.now()+30000;
}

// ---------- collision ----------
function solidTile(tx,ty){if(tx<0||ty<0||tx>=W.w||ty>=W.h)return true;return SOLID.has(W.t[ty][tx])}
function blocked(px,py,ignoreNpc){
  const hw=9,hh=6;
  for(const [cx,cy] of [[px-hw,py-hh],[px+hw,py-hh],[px-hw,py+hh],[px+hw,py+hh]])
    if(solidTile(Math.floor(cx/TS),Math.floor(cy/TS)))return true;
  if(!ignoreNpc){
    for(const n of W.npcs)if(Math.abs(px-n.px)<20&&Math.abs(py-n.py)<12)return true;
    for(const c of W.chests)if(Math.abs(px-c.px)<20&&Math.abs(py-c.py)<12)return true;
  }
  return false;
}
function moveEnt(e,dx,dy,ignoreNpc){
  if(dx&&!blocked(e.x+dx,e.y,ignoreNpc))e.x+=dx;
  if(dy&&!blocked(e.x,e.y+dy,ignoreNpc))e.y+=dy;
}

// ---------- update ----------
function worldPaused(){return modalOpen()||menuOpen()||dialogOpen()}
function updateWorld(dt){
  if(W.inv>0)W.inv-=dt;
  if(W.gateT>0)W.gateT-=dt;
  if(worldPaused()){W.moving=false;return}
  const k=W.keys;
  let dx=(k.d||k.arrowright?1:0)-(k.a||k.arrowleft?1:0), dy=(k.s||k.arrowdown?1:0)-(k.w||k.arrowup?1:0);
  W.moving=!!(dx||dy);
  if(W.moving){
    const l=Math.hypot(dx,dy),sp=(k.shift?240:150)*dt;
    const pe={x:P.x,y:P.y};moveEnt(pe,dx/l*sp,dy/l*sp);P.x=pe.x;P.y=pe.y;
    W.walk+=dt*(k.shift?16:11);if(dx)W.dir=dx>0?1:-1;
  }
  // exits
  const tx=Math.floor(P.x/TS),ty=Math.floor(P.y/TS);
  for(const ex of W.exits){
    if(ex.x===tx&&ex.y===ty){
      const z=MAPS[W.id];
      if(ex.kind==='next'&&z.boss&&!P.flags['boss'+z.boss]){
        P.x-=TS*.6;if(W.gateT<=0){toast(`🔒 ทางถูกผนึก — ต้องปราบ ${ENEMIES[z.boss].name} ก่อน`,'#ff8f80');W.gateT=2}
      } else {goMap(ex.to,ex.kind);return}
    }
  }
  // regen
  W.regenT+=dt;
  if(W.regenT>=1){W.regenT=0;fixPlayer();
    const r=MAPS[W.id].safe?3:1;
    P.hp=Math.min(maxHP(),P.hp+Math.ceil(maxHP()*.005*r));P.mp=Math.min(maxMP(),P.mp+Math.ceil(maxMP()*.01*r));}
  // enemies
  const now=performance.now();
  for(const e of W.enemies){
    if(!e.alive){if(now>e.respawn){placeEnemy(e);e.alive=true}continue}
    const d=Math.hypot(P.x-e.x,P.y-e.y);
    let vx=0,vy=0;
    if(d<TS*5&&W.inv<=0){vx=(P.x-e.x)/d*80;vy=(P.y-e.y)/d*80;e.chase=true}
    else{e.chase=false;e.t-=dt;if(e.t<=0){e.t=rnd(1,2.6);if(Math.random()<.35){e.vx=e.vy=0}else{const a=Math.random()*7;e.vx=Math.cos(a)*42;e.vy=Math.sin(a)*42}}
      vx=e.vx;vy=e.vy;}
    if(vx||vy){moveEnt(e,vx*dt,vy*dt,true);e.walk+=dt*9;if(vx)e.dir=vx>0?1:-1}
    if(d<24&&W.inv<=0){startBattle(e.stage,e);return}
  }
  if(W.boss&&W.inv<=0){
    const d=Math.hypot(P.x-W.boss.px,P.y-W.boss.py);
    if(d<40){const s=W.boss.stage,st=enemyStats(s);W.inv=1.2;
      modal(`<h3 style="color:var(--red)">👹 ${ENEMIES[s].name}</h3><p>"เจ้าผ่านทางนี้ไปไม่ได้!"</p>
        <p class="small">HP ${st.hp} · ATK ${st.atk} · แนะนำ Lv ${st.rec} (คุณ Lv ${P.lvl})</p>
        <button class="primary" onclick="closeModal();startBattle(${s},'boss')">ท้าสู้!</button> <button onclick="closeModal();W.inv=2.5">ถอยก่อน</button>`);}
  }
  // nearest interactable
  W.near=null;let best=46;
  for(const o of [...W.npcs,...W.chests]){if(o.loot&&P.opened[o.id])continue;const d=Math.hypot(P.x-o.px,P.y-o.py);if(d<best){best=d;W.near=o}}
}

function interact(){
  const o=W.near;if(!o||worldPaused())return;
  if(o.loot){
    P.opened[o.id]=1;const lines=addLoot(o.loot);sfx('coin');save();
    toast('📦 เปิดหีบสมบัติ: '+lines.join(', '),'#e3b04b');return;
  }
  npcAction(o.id);
}

// ---------- render ----------
function renderWorld(){
  const cw=960,ch=540,mw=W.w*TS,mh=W.h*TS;
  W.cam.x=clamp(P.x-cw/2,0,Math.max(0,mw-cw));W.cam.y=clamp(P.y-ch/2,0,Math.max(0,mh-ch));
  const cx=Math.round(W.cam.x),cy=Math.round(W.cam.y);
  ctx.fillStyle='#000';ctx.fillRect(0,0,cw,ch);
  ctx.drawImage(W.img,cx,cy,Math.min(cw,mw),Math.min(ch,mh),0,0,Math.min(cw,mw),Math.min(ch,mh));
  // exit markers
  for(const ex of W.exits){
    const x=(ex.x+.5)*TS-cx,y=(ex.y+.5)*TS-cy,z=MAPS[W.id];
    const locked=ex.kind==='next'&&z.boss&&!P.flags['boss'+z.boss];
    ctx.fillStyle=locked?'rgba(200,56,44,.5)':`rgba(227,176,75,${.35+Math.sin(T*4)*.2})`;
    ctx.beginPath();ctx.arc(x,y,14,0,7);ctx.fill();
    ctx.fillStyle='#fff';ctx.font='600 14px Mitr';ctx.textAlign='center';ctx.fillText(locked?'🔒':(ex.x===0?'◀':'▶'),x,y+5);
    ctx.font='400 11px Mitr';ctx.fillText(MAPS[ex.to].name,x+(ex.x===0?40:-40),y-16);
  }
  // entities sorted by y
  const list=[];
  for(const n of W.npcs)list.push({y:n.py,f:()=>drawEnt(n,n.px,n.py,1,0,n.name)});
  for(const c of W.chests)list.push({y:c.py,f:()=>drawChest(c)});
  for(const e of W.enemies)if(e.alive)list.push({y:e.y,f:()=>drawEnt(e,e.x,e.y,e.dir,e.walk,null,e)});
  if(W.boss)list.push({y:W.boss.py,f:()=>drawEnt(W.boss,W.boss.px,W.boss.py,-1,0,'👹 '+ENEMIES[W.boss.stage].name)});
  list.push({y:P.y,f:()=>{if(W.inv>0&&Math.floor(T*12)%2)return;
    drawEnt({kind:'player',look:playerLook(),st:{},flash:0},P.x,P.y,W.dir,W.moving?W.walk:0)}});
  list.sort((a,b)=>a.y-b.y).forEach(o=>o.f());
  // night tint for castle
  if(MAPS[W.id].theme==='castle'){const g=ctx.createRadialGradient(P.x-cx,P.y-cy,80,P.x-cx,P.y-cy,520);
    g.addColorStop(0,'rgba(0,0,0,0)');g.addColorStop(1,'rgba(10,0,8,.7)');ctx.fillStyle=g;ctx.fillRect(0,0,cw,ch)}
  if(MAPS[W.id].theme==='mountain'){ctx.fillStyle='rgba(255,255,255,.7)';for(let i=0;i<50;i++)ctx.fillRect((i*137+T*25*(1+i%3))%960,(i*91+T*45*(1+i%2))%540,2,2)}
  // interact prompt
  if(W.near&&!worldPaused()){const o=W.near;ctx.font='400 13px Mitr';ctx.textAlign='center';
    const label=o.loot?'[E] เปิดหีบ':`[E] ${o.kind==='board'?'ดู':'คุยกับ'} ${o.name}`;
    const x=o.px-cx,y=o.py-cy-62,w=ctx.measureText(label).width+16;
    ctx.fillStyle='rgba(0,0,0,.75)';ctx.fillRect(x-w/2,y-16,w,22);ctx.fillStyle='#ffe9b0';ctx.fillText(label,x,y)}
  if(P.minimap)drawMinimap();
}
function drawEnt(u,x,y,dir,walk,label,enemy){
  const cx=W.cam.x,cy=W.cam.y,sx=x-cx,sy=y-cy;
  if(sx<-60||sy<-80||sx>1020||sy>600)return;
  const sc=u.boss?.36:u.kind==='board'?.45:u.kind==='wolf'?.33:.31;
  ctx.fillStyle='rgba(0,0,0,.35)';ctx.beginPath();ctx.ellipse(sx,sy+8,13*sc/.31,5,0,0,7);ctx.fill();
  ctx.save();ctx.translate(sx,sy+8-(walk?Math.abs(Math.sin(walk))*2:0));ctx.scale(dir*sc,sc);drawBody(ctx,u,0,walk);ctx.restore();
  if(label){ctx.font='400 11px Mitr';ctx.textAlign='center';ctx.fillStyle='rgba(0,0,0,.6)';const w=ctx.measureText(label).width+10;
    ctx.fillRect(sx-w/2,sy-(u.boss?84:62),w,15);ctx.fillStyle=u.boss?'#ff8f80':'#fff';ctx.fillText(label,sx,sy-(u.boss?73:51))}
  if(u.id==='elder'||u.id==='board'){const m=npcMarker(u.id);if(m){ctx.font='600 18px Mitr';ctx.fillStyle='#ffd34d';ctx.textAlign='center';ctx.fillText(m,sx,sy-68+Math.sin(T*5)*3)}}
  if(enemy){const st=enemyStats(enemy.stage),diff=st.rec-P.lvl;
    ctx.font='600 10px Mitr';ctx.textAlign='center';ctx.fillStyle=diff>=3?'#ff5a4a':diff>=1?'#ffb347':'#9be37a';
    ctx.fillText((enemy.chase?'! ':'')+'Lv'+st.rec,sx,sy-52)}
}
function drawChest(c){
  const x=c.px-W.cam.x,y=c.py-W.cam.y,open=P.opened[c.id];
  ctx.fillStyle='rgba(0,0,0,.35)';ctx.beginPath();ctx.ellipse(x,y+9,14,4,0,0,7);ctx.fill();
  ctx.fillStyle='#7a4a22';ctx.fillRect(x-12,y-6,24,15);ctx.fillStyle='#d4af37';ctx.fillRect(x-12,y-6,24,2);ctx.fillRect(x-2,y-2,4,5);
  if(open){ctx.fillStyle='#5a3416';ctx.fillRect(x-12,y-16,24,8)}
  else{ctx.fillStyle='#8b5a2b';ctx.fillRect(x-12,y-12,24,7);ctx.fillStyle=`rgba(255,220,120,${.3+Math.sin(T*4)*.2})`;ctx.beginPath();ctx.arc(x,y-4,18,0,7);ctx.fill()}
}
function drawMinimap(){
  const m=W.mini,sc=W.w>45?2:2.4,w=W.w*sc,h=W.h*sc,x0=960-w-10,y0=10;
  ctx.globalAlpha=.85;ctx.fillStyle='#000';ctx.fillRect(x0-3,y0-3,w+6,h+6);ctx.drawImage(m,x0,y0,w,h);ctx.globalAlpha=1;
  const dot=(x,y,c,r=2.5)=>{ctx.fillStyle=c;ctx.beginPath();ctx.arc(x0+x/TS*sc,y0+y/TS*sc,r,0,7);ctx.fill()};
  for(const e of W.enemies)if(e.alive)dot(e.x,e.y,'#ff5a4a',1.8);
  for(const c of W.chests)if(!P.opened[c.id])dot(c.px,c.py,'#ffd34d',2);
  for(const n of W.npcs)dot(n.px,n.py,'#7fb6ff',2);
  for(const ex of W.exits)dot((ex.x+.5)*TS,(ex.y+.5)*TS,'#e3b04b',3);
  if(W.boss)dot(W.boss.px,W.boss.py,'#ff2020',4);
  dot(P.x,P.y,'#fff',3);
}
