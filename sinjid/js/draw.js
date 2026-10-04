'use strict';
// ================= VECTOR CHARACTER RIG (Flash-style: thick ink outline + cel gradient) =================
// Figures are drawn with feet at (0,0), facing +x, ~170 units tall at scale 1.
const OUT = '#151011';
let _flash = false; // when true every fill becomes white (hit flash)

function hexRGB(h){const c=parseInt(h.slice(1),16);return [c>>16,c>>8&255,c&255]}
function hexShade(h,a){const [r,g,b]=hexRGB(h);const f=v=>Math.max(0,Math.min(255,Math.round(a<0?v*(1+a):v+(255-v)*a)));
  return '#'+((1<<24)+(f(r)<<16)+(f(g)<<8)+f(b)).toString(16).slice(1)}
const shade=(h,a)=>_flash?'#ffffff':hexShade(h,a);
function grad(c,x1,y1,x2,y2,col){const g=c.createLinearGradient(x1,y1,x2,y2);
  g.addColorStop(0,shade(col,.3));g.addColorStop(.5,shade(col,0));g.addColorStop(1,shade(col,-.4));return g}
function ink(c,fill,lw=2.6){c.fillStyle=fill;c.fill();c.lineWidth=lw;c.strokeStyle=OUT;c.lineJoin='round';c.lineCap='round';c.stroke()}
const pt=(x,y,a,l)=>[x+Math.sin(a)*l,y+Math.cos(a)*l]; // angle 0 = straight down, + = forward
const lerp=(a,b,k)=>a+(b-a)*k;

function capsule(c,x1,y1,x2,y2,w1,w2,col,lw){
  const a=Math.atan2(y2-y1,x2-x1),p=a+Math.PI/2,cp=Math.cos(p),sp=Math.sin(p);
  c.beginPath();c.moveTo(x1+cp*w1,y1+sp*w1);c.lineTo(x2+cp*w2,y2+sp*w2);
  c.arc(x2,y2,w2,p,p-Math.PI,true);c.lineTo(x1-cp*w1,y1-sp*w1);c.arc(x1,y1,w1,p-Math.PI,p-2*Math.PI,true);c.closePath();
  const mx=(x1+x2)/2,my=(y1+y2)/2,w=Math.max(w1,w2);
  ink(c,grad(c,mx-cp*w,my-sp*w,mx+cp*w,my+sp*w,col),lw);
}
function blob(c,x,y,rx,ry,col,lw){c.beginPath();c.ellipse(x,y,rx,ry,0,0,Math.PI*2);ink(c,grad(c,x+rx,y-ry,x-rx,y+ry,col),lw)}
function ribbon(c,pts,col,w){ // outlined flowing cloth strip
  c.lineCap='round';c.lineJoin='round';
  for(const [lw,s] of [[w+3.5,OUT],[w,shade(col,0)]]){c.lineWidth=lw;c.strokeStyle=s;c.beginPath();c.moveTo(pts[0][0],pts[0][1]);
    for(let i=1;i<pts.length-1;i++){const mx=(pts[i][0]+pts[i+1][0])/2,my=(pts[i][1]+pts[i+1][1])/2;c.quadraticCurveTo(pts[i][0],pts[i][1],mx,my)}
    const l=pts[pts.length-1];c.lineTo(l[0],l[1]);c.stroke()}
}

function drawBody(c,u,sw=0,walk=0){
  _flash=u.flash>0&&Math.floor(T*30)%2===0;
  c.save();
  if(u.kind==='wolf')drawWolf(c,u.look||{fur:'#7d7d80'},sw,walk);
  else if(u.kind==='board')drawBoard(c);
  else drawFigure(c,u.look||LOOK_DEFAULT,sw,walk);
  c.restore();_flash=false;
}

function drawFigure(c,L,sw,walk){
  const bulk=L.bulk||1,sc=L.scale||1,moving=!!walk,w=walk||0;
  c.scale(sc,sc);
  if(L.ghost)c.globalAlpha*=.72;
  // ---- legs (relative to hip) ----
  const s1=Math.sin(w),lift=k=>Math.max(0,Math.sin(w+1.6+k));
  const fA=moving?.5*s1:.22, bA=moving?-.5*s1:-.17;
  const fBend=moving?.12+.5*lift(0):.1, bBend=moving?.12+.5*lift(Math.PI):.16;
  const TH=40*(L.leg||1),SH=40*(L.leg||1);
  const leg=(a,b)=>{const k=pt(0,0,a,TH);return {k,f:pt(k[0],k[1],a-b,SH)}};
  const LF=leg(fA,fBend),LB=leg(bA,bBend);
  const hy=-Math.max(LF.f[1],LB.f[1])-6+(moving?-Math.abs(s1)*2:Math.sin(T*2.2)*1.2), hx=0;
  const lean=(moving?.08:.03)+.18*sw+(L.lean||0);
  const R=(x,y)=>[hx+x*Math.cos(lean)-y*Math.sin(lean),hy+x*Math.sin(lean)+y*Math.cos(lean)];
  const sh=R(2,-50*(L.torso||1)), neck=R(3,-57*(L.torso||1));
  const head=R(5,-70*(L.torso||1));
  // ---- arm poses ----
  const hasW=L.weapon&&L.weapon!=='none';
  const fu=hasW?lerp(.32+Math.sin(T*2)*.04,1.8,sw):lerp(.12,1.7,sw), ff=hasW?lerp(1.3,1.72,sw):lerp(.35,1.6,sw);
  const bu=-.28+(moving?-.45*s1:0), bf=bu+.5;
  const UA=27,FA=25;
  // ---- back layer: wings, long hair, scarf, back arm, back leg ----
  if(L.wings)drawWings(c,sh,L.wings);
  if(L.scarf)ribbon(c,[neck,[neck[0]-16,neck[1]+4+Math.sin(T*6)*3],[neck[0]-34,neck[1]+(moving?0:10)+Math.sin(T*6+1)*6],[neck[0]-46,neck[1]+(moving?-2:18)+Math.sin(T*6+2)*8]],L.scarf,5);
  const limbLeg=(Lg,dark)=>{
    const pc=dark?hexShade(L.pants,-.25):L.pants, bc=dark?hexShade(L.boots,-.25):L.boots;
    const K=[hx+Lg.k[0],hy+Lg.k[1]],F=[hx+Lg.f[0],hy+Lg.f[1]];
    capsule(c,hx,hy,K[0],K[1],9.5*bulk,6.6*bulk,pc);
    capsule(c,K[0],K[1],F[0],F[1]-3,6.6*bulk,4.6*bulk,L.wraps?(dark?hexShade(L.wraps,-.25):L.wraps):pc);
    c.beginPath();c.moveTo(F[0]-6,F[1]-9);c.lineTo(F[0]+5,F[1]-8);c.quadraticCurveTo(F[0]+15,F[1]-4,F[0]+14,F[1]+3);c.lineTo(F[0]-7,F[1]+3);c.closePath();
    ink(c,grad(c,F[0],F[1]-9,F[0],F[1]+3,bc));
  };
  const arm=(u,f,dark,front)=>{
    const E=pt(sh[0],sh[1],u,UA),H=pt(E[0],E[1],f,FA);
    const sl=dark?hexShade(L.sleeve||L.top,-.25):(L.sleeve||L.top), fo=L.forearm||L.sleeve||L.top;
    capsule(c,sh[0],sh[1],E[0],E[1],6.2*bulk,5*bulk,sl);
    if(front&&hasW)drawWeapon(c,L,H,lerp(L.wIdle||2.55,L.wSwing||1.35,sw));
    capsule(c,E[0],E[1],H[0],H[1],5*bulk,4.2*bulk,dark?hexShade(fo,-.25):fo);
    blob(c,H[0]+1,H[1]+1,4.6*bulk,4.6*bulk,L.glove||L.skin);
    if(front&&L.armor){c.save();c.translate(sh[0],sh[1]);c.rotate(-u);c.beginPath();c.ellipse(0,7,11*bulk,10,0,0,7);
      ink(c,grad(c,-10,0,10,14,L.armor));c.restore()}
  };
  arm(bu,bf,true,false);
  if(L.robe)limbLeg(LB,true),limbLeg(LF,false);else limbLeg(LB,true);
  // ---- torso ----
  c.save();c.translate(hx,hy);c.rotate(lean);
  const b=bulk,tl=L.torso||1;
  c.beginPath();c.moveTo(-11*b,3);c.quadraticCurveTo(-16*b,-26*tl,-14*b,-50*tl);c.quadraticCurveTo(-4,-59*tl,6,-58*tl);
  c.quadraticCurveTo(18*b,-55*tl,17*b,-40*tl);c.quadraticCurveTo(15*b,-14,11*b,3);c.closePath();
  ink(c,grad(c,17*b,-30,-16*b,-30,L.top));
  c.save();c.clip();
  if(L.chest){c.beginPath();c.moveTo(-2,-56*tl);c.quadraticCurveTo(14*b,-40*tl,4,-14);c.lineTo(20,-14);c.lineTo(20,-60);c.closePath();c.fillStyle=shade(L.chest,0);c.fill()}
  if(L.sash){c.beginPath();c.moveTo(-15*b,-50*tl);c.lineTo(-7*b,-56*tl);c.lineTo(16*b,-4);c.lineTo(7*b,2);c.closePath();ink(c,grad(c,0,-50,0,0,L.sash),1.8)}
  if(L.armor){for(let i=0;i<3;i++){c.beginPath();c.rect(-14*b,-40*tl+i*9,32*b,8);ink(c,grad(c,0,-40+i*9,0,-32+i*9,L.armor),1.6)}}
  c.restore();
  if(L.belt){c.beginPath();c.rect(-12.5*b,-13,26*b,8);ink(c,grad(c,0,-13,0,-5,L.belt),2);if(L.beltTail){c.beginPath();c.rect(-14*b,-9,5,16);ink(c,grad(c,0,-9,0,7,L.belt),1.8)}}
  if(L.robe){const rl=L.robeLen||62;c.beginPath();c.moveTo(-12*b,-12);c.quadraticCurveTo(-20*b,rl*.5,-21*b,rl);c.lineTo(19*b,rl);c.quadraticCurveTo(17*b,rl*.4,12*b,-12);c.closePath();
    ink(c,grad(c,18*b,0,-20*b,0,L.robe));if(L.trim){c.beginPath();c.rect(-21*b,rl-6,40*b,6);ink(c,shade(L.trim,0),1.6)}}
  if(L.beads){for(let i=0;i<7;i++)blob(c,-10*b+i*3.4*b,-52*tl+i*5,3,3,'#5a3a1a',1.2)}
  c.restore();
  if(!L.robe)limbLeg(LF,false);
  // ---- head ----
  capsule(c,neck[0]-1,neck[1]+4,head[0]-1,head[1]+6,5*b,5*b,L.hood||L.skin);
  drawHead(c,L,head[0],head[1],moving);
  // ---- front arm + weapon ----
  arm(fu,ff,false,true);
  if(sw>.2&&sw<.95&&hasW){c.strokeStyle=`rgba(255,255,255,${sw*.75})`;c.lineWidth=4;c.beginPath();c.arc(sh[0]+8,sh[1]+10,90,-1.4,.7);c.stroke()}
}

function drawHead(c,L,cx,cy,moving){
  const hr=L.big?13:11,vr=L.big?14:13;
  if(L.longHair)capsule(c,cx-6,cy-4,cx-11,cy+20,8,6,L.hair);
  if(L.bun)blob(c,cx-12,cy-6,6,6,L.hair);
  if(L.topknot)capsule(c,cx-6,cy-12,cx-11,cy-17,3.5,3,L.hair,2);
  c.beginPath();c.ellipse(cx,cy,hr,vr,0,0,7);
  if(L.boxHead){c.beginPath();c.rect(cx-12,cy-13,25,26)}
  ink(c,grad(c,cx+hr,cy-vr,cx-hr,cy+vr,L.hood||L.skin));
  c.save();c.clip();
  if(L.hood){ // eye slit
    c.fillStyle=shade(L.skin,0);c.fillRect(cx+1,cy-5,14,6.5);c.strokeStyle=OUT;c.lineWidth=1.4;c.strokeRect(cx+1,cy-5,14,6.5);
  } else if(L.hair&&!L.bald){
    c.beginPath();c.ellipse(cx-4,cy-6,hr+2,vr-3,-.25,0,7);c.fillStyle=shade(L.hair,0);c.fill();
    c.beginPath();c.moveTo(cx-hr,cy+4);c.quadraticCurveTo(cx-2,cy-12,cx+hr+2,cy-7);c.lineWidth=1.4;c.strokeStyle=OUT;c.stroke();
  }
  if(L.mask){c.beginPath();c.moveTo(cx-hr,cy+1);c.lineTo(cx+hr+2,cy);c.lineTo(cx+hr+2,cy+vr);c.lineTo(cx-hr,cy+vr);c.closePath();ink(c,shade(L.mask,0),1.6)}
  if(L.band){c.fillStyle=shade(L.band,0);c.fillRect(cx-hr-2,cy-10,hr*2+4,5);c.strokeStyle=OUT;c.lineWidth=1.4;c.strokeRect(cx-hr-2,cy-10,hr*2+4,5)}
  c.restore();
  c.beginPath();c.ellipse(cx,cy,hr,vr,0,0,7);if(L.boxHead){c.beginPath();c.rect(cx-12,cy-13,25,26)}c.lineWidth=2.6;c.strokeStyle=OUT;c.stroke();
  // face
  const eyeC=L.eye||'#1a1010';
  if(!L.noFace){
    c.fillStyle=_flash?'#fff':eyeC;c.beginPath();c.ellipse(cx+6,cy-2,1.7,2.3,0,0,7);c.fill();
    c.strokeStyle=OUT;c.lineWidth=1.8;c.beginPath();c.moveTo(cx+2,cy-6.5);c.lineTo(cx+10,cy-5.5);c.stroke();
    if(!L.hood&&!L.mask){c.lineWidth=1.3;c.beginPath();c.moveTo(cx+hr-1,cy+1);c.lineTo(cx+hr+1,cy+4);c.lineTo(cx+hr-2,cy+5);c.stroke();
      c.beginPath();c.moveTo(cx+4,cy+8);c.lineTo(cx+8,cy+8);c.stroke();
      c.beginPath();c.ellipse(cx-2,cy+1,2.6,3.6,0,0,7);ink(c,shade(L.skin,-.1),1.3)}
  }
  if(L.beard){c.beginPath();c.moveTo(cx-4,cy+5);c.quadraticCurveTo(cx+12,cy+6,cx+10,cy+10);c.quadraticCurveTo(cx+6,cy+28,cx-2,cy+22);c.quadraticCurveTo(cx-6,cy+12,cx-4,cy+5);
    ink(c,grad(c,cx,cy,cx,cy+24,L.beard),2)}
  if(L.tusks){c.beginPath();c.moveTo(cx+5,cy+8);c.lineTo(cx+7,cy+1);c.lineTo(cx+9,cy+8);ink(c,shade('#f3ead2',0),1.4)}
  if(L.nose){c.beginPath();c.moveTo(cx+hr-2,cy-4);c.quadraticCurveTo(cx+26,cy-6,cx+32,cy+1);c.quadraticCurveTo(cx+20,cy+3,cx+hr-2,cy+4);ink(c,grad(c,cx,cy-4,cx,cy+4,L.skin),2)}
  if(L.band){const t=T*6;ribbon(c,[[cx-hr,cy-7],[cx-hr-12,cy-8+Math.sin(t)*3],[cx-hr-24,cy-4+Math.sin(t+1)*5],[cx-hr-30,cy+(moving?-6:2)+Math.sin(t+2)*6]],L.band,2.6)}
  if(L.horns){for(const [x0,x1] of [[-6,-14],[5,12]]){c.beginPath();c.moveTo(cx+x0-3,cy-vr+3);c.quadraticCurveTo(cx+x1-2,cy-vr-6,cx+x1,cy-vr-20);c.quadraticCurveTo(cx+x1+3,cy-vr-4,cx+x0+5,cy-vr+3);c.closePath();
    ink(c,grad(c,cx,cy-vr-20,cx,cy-vr,'#efe2c2'),2)}}
  if(L.kasa){c.beginPath();c.moveTo(cx-29,cy-3);c.quadraticCurveTo(cx+2,cy-30,cx+31,cy-3);c.quadraticCurveTo(cx+1,cy-8,cx-29,cy-3);ink(c,grad(c,cx,cy-26,cx,cy-3,L.kasa));
    c.strokeStyle=_flash?'#fff':'rgba(0,0,0,.3)';c.lineWidth=1;for(let i=-3;i<=3;i++){c.beginPath();c.moveTo(cx+1,cy-19);c.lineTo(cx+i*8,cy-5);c.stroke()}}
  if(L.helmet){c.beginPath();c.arc(cx-1,cy-2,hr+4,Math.PI*1.02,Math.PI*1.98);c.lineTo(cx+hr+8,cy-1);c.lineTo(cx-hr-8,cy-1);c.closePath();ink(c,grad(c,cx,cy-hr-6,cx,cy,L.helmet));
    if(L.crest){c.beginPath();c.moveTo(cx+2,cy-hr-2);c.quadraticCurveTo(cx-10,cy-hr-14,cx-14,cy-hr-30);c.quadraticCurveTo(cx-4,cy-hr-16,cx+4,cy-hr-6);
      c.quadraticCurveTo(cx+14,cy-hr-16,cx+20,cy-hr-30);c.quadraticCurveTo(cx+14,cy-hr-12,cx+6,cy-hr-1);c.closePath();ink(c,grad(c,cx,cy-hr-30,cx,cy-hr,L.crest),2)}}
}

function drawWeapon(c,L,H,a){
  const d=[Math.sin(a),Math.cos(a)],P=k=>[H[0]+d[0]*k,H[1]+d[1]*k];
  const t=L.weapon;
  if(t==='katana'||t==='dagger'){
    const len=t==='katana'?(L.wLen||80):32;
    if(L.glow&&!_flash){c.save();c.shadowColor=L.glow;c.shadowBlur=16}
    const b0=P(9),b1=P(len),n=[-d[1],d[0]];
    c.beginPath();c.moveTo(b0[0]+n[0]*2.8,b0[1]+n[1]*2.8);c.quadraticCurveTo((b0[0]+b1[0])/2+n[0]*4.5,(b0[1]+b1[1])/2+n[1]*4.5,b1[0],b1[1]);
    c.lineTo(b0[0]-n[0]*1.6,b0[1]-n[1]*1.6);c.closePath();ink(c,grad(c,b0[0],b0[1],b1[0],b1[1],L.glow?'#bfe6ff':'#dde2ea'),2);
    if(L.glow&&!_flash)c.restore();
    const g0=P(-12),g1=P(6);capsule(c,g0[0],g0[1],g1[0],g1[1],2.6,2.6,L.hilt||'#2a1c1c',1.8);
    const g=P(7.5);c.save();c.translate(g[0],g[1]);c.rotate(-a);c.beginPath();c.ellipse(0,0,6,2.2,0,0,7);ink(c,shade('#c9a227',0),1.6);c.restore();
  } else if(t==='staff'){const a0=P(-48),a1=P(64);capsule(c,a0[0],a0[1],a1[0],a1[1],2.8,2.8,L.wCol||'#6b4a2a',2);
    if(L.wTip){blob(c,a1[0],a1[1],5,5,L.wTip,1.8)}}
  else if(t==='club'){const a0=P(-10),a1=P(L.wLen||74);capsule(c,a0[0],a0[1],a1[0],a1[1],3,8.5,'#4a3020',2.2);
    for(let i=1;i<5;i++){const s=P(16+i*13);blob(c,s[0],s[1],2.4,2.4,'#b8b8b8',1.2)}}
  else if(t==='hammer'){const a0=P(-6),a1=P(40);capsule(c,a0[0],a0[1],a1[0],a1[1],2.4,2.4,'#6b4a2a',1.8);
    c.save();c.translate(a1[0],a1[1]);c.rotate(-a);c.beginPath();c.rect(-10,-3,20,12);ink(c,grad(c,0,-3,0,9,'#7a7a80'),2);c.restore()}
}

function drawWings(c,sh,col){
  const f=Math.sin(T*2.5)*.08;
  for(const [dx,dk,rot] of [[6,-.25,-.15],[0,0,.05]]){
    c.save();c.translate(sh[0]+dx,sh[1]+4);c.rotate(rot+f);
    c.beginPath();c.moveTo(0,0);c.quadraticCurveTo(-30,-60,-95,-78);c.quadraticCurveTo(-130,-80,-150,-60);
    for(let i=0;i<6;i++){const x=-150+i*22,y=-60+i*11;c.quadraticCurveTo(x+4,y+22,x+18,y+14)}
    c.quadraticCurveTo(-30,8,0,0);c.closePath();ink(c,grad(c,0,-80,-60,20,dk?hexShade(col,dk):col),2.4);
    c.strokeStyle=_flash?'#fff':'rgba(255,255,255,.12)';c.lineWidth=1.2;
    for(let i=0;i<5;i++){c.beginPath();c.moveTo(-10-i*6,-4-i*4);c.quadraticCurveTo(-60-i*10,-40-i*4,-110-i*6,-50+i*8);c.stroke()}
    c.restore();
  }
}

function drawWolf(c,L,sw,walk){
  c.scale(1.3,1.3);
  const fur=L.fur,s=Math.sin(walk||0)*.5,bob=walk?Math.abs(Math.sin(walk))*-2:Math.sin(T*3)*1;
  c.translate(0,bob);
  const legs=[[-30,-34,s,true],[16,-36,-s,true],[-22,-34,-s,false],[24,-36,s,false]];
  for(const [x,y,a,back] of legs){if(!back)continue;const k=pt(x,y,a,18),f=pt(k[0],k[1],a-.3,18);
    capsule(c,x,y,k[0],k[1],6,4.5,hexShade(fur,-.3));capsule(c,k[0],k[1],f[0],f[1]-2,4.5,3.5,hexShade(fur,-.3));}
  // tail
  c.beginPath();c.moveTo(-40,-50);c.quadraticCurveTo(-62,-58+Math.sin(T*5)*4,-74,-40);c.quadraticCurveTo(-58,-46,-40,-40);c.closePath();ink(c,grad(c,-74,-58,-40,-40,fur));
  // body
  c.beginPath();c.moveTo(-42,-52);c.quadraticCurveTo(-10,-66,26,-60);c.quadraticCurveTo(40,-52,36,-36);c.quadraticCurveTo(0,-26,-38,-34);c.quadraticCurveTo(-48,-42,-42,-52);c.closePath();
  ink(c,grad(c,0,-66,0,-28,fur));
  c.beginPath();c.moveTo(-30,-40);c.quadraticCurveTo(0,-30,30,-40);c.lineWidth=1.2;c.strokeStyle=_flash?'#fff':'rgba(0,0,0,.25)';c.stroke();
  for(const [x,y,a,back] of legs){if(back)continue;const k=pt(x,y,a,18),f=pt(k[0],k[1],a-.3,18);
    capsule(c,x,y,k[0],k[1],6.5,5,fur);capsule(c,k[0],k[1],f[0],f[1]-2,5,3.8,fur);
    c.beginPath();c.ellipse(f[0]+3,f[1]-1,6,3.5,0,0,7);ink(c,shade(hexShade(fur,-.2),0),1.8)}
  // head
  const hx=36+sw*14,hy=-62;
  c.beginPath();c.moveTo(hx-14,hy-6);c.lineTo(hx-10,hy-24);c.lineTo(hx-2,hy-10);c.closePath();ink(c,grad(c,hx,hy-24,hx,hy-6,fur),2);
  c.beginPath();c.moveTo(hx-16,hy+6);c.quadraticCurveTo(hx-14,hy-12,hx,hy-12);c.quadraticCurveTo(hx+10,hy-10,hx+28,hy-2);
  c.quadraticCurveTo(hx+30,hy+5,hx+22,hy+8);c.quadraticCurveTo(hx+4,hy+14,hx-16,hy+6);c.closePath();ink(c,grad(c,hx,hy-12,hx,hy+12,fur));
  c.fillStyle=_flash?'#fff':'#111';c.beginPath();c.ellipse(hx+27,hy-2,2.5,2,0,0,7);c.fill();
  c.fillStyle=_flash?'#fff':'#ffd23f';c.beginPath();c.ellipse(hx+6,hy-4,2.4,1.6,-.3,0,7);c.fill();
  c.strokeStyle=OUT;c.lineWidth=1.5;c.beginPath();c.moveTo(hx+10,hy+6);c.lineTo(hx+24,hy+5);c.stroke();
  c.beginPath();c.moveTo(hx-4,hy-6);c.lineTo(hx+2,hy-14);c.lineTo(hx+6,hy-5);c.closePath();ink(c,grad(c,hx,hy-14,hx,hy-4,fur),2);
}

function drawBoard(c){
  capsule(c,-34,-70,-34,0,3.5,3.5,'#5a3b22');capsule(c,32,-70,32,0,3.5,3.5,'#5a3b22');
  c.beginPath();c.rect(-46,-100,92,54);ink(c,grad(c,0,-100,0,-46,'#8b5e34'),3);
  for(const [x,y,w,h] of [[-38,-93,24,32],[-8,-90,22,28],[20,-94,20,36]]){c.beginPath();c.rect(x,y,w,h);ink(c,shade('#efe2c4',0),1.5);
    c.fillStyle=shade('#c8382c',0);c.fillRect(x+6,y+8,w-12,3);c.fillStyle='rgba(0,0,0,.4)';c.fillRect(x+4,y+15,w-8,2);c.fillRect(x+4,y+20,w-10,2)}
}

// ================= LOOKS =================
const LOOK_DEFAULT={skin:'#e8b892',hair:'#3a2a1e',top:'#2a2a2e',pants:'#26262a',boots:'#3a3a3e',weapon:'katana'};
