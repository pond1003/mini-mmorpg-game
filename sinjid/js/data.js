'use strict';
// ================= GAME DATA =================
const TS = 32; // tile size (px)

const TREES = {katana:'⚔ คาตานะ', shuriken:'✴ ดาวกระจาย', ninjutsu:'🔥 นินจุตสึ', item:'🎒 ไอเทม'};

const SKILLS = {
  // --- Katana (STR) ---
  slash:   {tree:'katana',name:'ฟันดาบ',mp:0,req:1,max:5,desc:l=>`ฟัน ${pct(1+.15*l)} ของพลังดาบ`,
            run:async(l)=>{await meleeHits(1,1+.15*l)}},
  cross:   {tree:'katana',name:'ฟันกากบาท',mp:8,req:3,max:5,desc:l=>`ฟัน 2 ครั้ง ครั้งละ ${pct(.75+.1*l)}`,
            run:async(l)=>{await meleeHits(2,.75+.1*l)}},
  iai:     {tree:'katana',name:'ไออิ ชักดาบสายฟ้าแลบ',mp:15,req:6,max:5,desc:l=>`ฟันหนัก ${pct(2+.3*l)} คริติคอล +30%`,
            run:async(l)=>{await meleeHits(1,2+.3*l,{crit:30})}},
  storm:   {tree:'katana',name:'พายุใบมีด',mp:30,req:12,max:5,desc:l=>`ฟันรัว 5 ครั้ง ครั้งละ ${pct(.6+.08*l)}`,
            run:async(l)=>{await meleeHits(5,.6+.08*l)}},
  // --- Shuriken (AGI) ---
  star:    {tree:'shuriken',name:'ปาดาวกระจาย',mp:0,req:1,max:5,desc:l=>`ปาดาว ${pct(.9+.15*l)} ของพลังปา`,
            run:async(l)=>{await rangedHits(1,.9+.15*l)}},
  kunai:   {tree:'shuriken',name:'คุไนอาบพิษ',mp:8,req:4,max:5,desc:l=>`ปา ${pct(.6)} + พิษ 3 เทิร์น (${pct(.5+.1*l)}/เทิร์น)`,
            run:async(l)=>{const hit=await rangedHits(1,.6,{proj:'kunai'});
              if(hit) addStatus(B.e,'poison',3,Math.round(rangedPow()*(.5+.1*l)))}},
  barrage: {tree:'shuriken',name:'ฝนดาวกระจาย',mp:18,req:8,max:5,desc:l=>`ปา 4 ครั้ง ครั้งละ ${pct(.55+.08*l)}`,
            run:async(l)=>{await rangedHits(4,.55+.08*l)}},
  bind:    {tree:'shuriken',name:'ด้ายเงาตรึงร่าง',mp:20,req:10,max:5,desc:l=>`ปา ${pct(.8)} โอกาสสตั้น ${50+6*l}%`,
            run:async(l)=>{const hit=await rangedHits(1,.8,{proj:'kunai'});
              if(hit && Math.random()*100<50+6*l) addStatus(B.e,'stun',1)}},
  // --- Ninjutsu (INT) ---
  fire:    {tree:'ninjutsu',name:'คาถาลูกไฟ',mp:10,req:2,max:5,desc:l=>`เวท ${pct(1.1+.18*l)} + ไหม้ 2 เทิร์น`,
            run:async(l)=>{await magicHit(1.1+.18*l,'fire');addStatus(B.e,'burn',2,Math.round(magicPow()*.35))}},
  heal:    {tree:'ninjutsu',name:'คาถาฟื้นฟู',mp:14,req:3,max:5,desc:l=>`ฟื้น HP ${Math.round((1+.2*l)*10)/10}× (INT×4+25)`,
            run:async(l)=>{await healFx(B.p);healUnit(B.p,Math.round((P.int*4+25)*(1+.2*l)))}},
  clone:   {tree:'ninjutsu',name:'แยกเงาพันร่าง',mp:16,req:5,max:5,desc:l=>`หลบการโจมตี ${2+Math.floor(l/2)} ครั้งถัดไป`,
            run:async(l)=>{await buffFx(B.p,'#9b8cff');addStatus(B.p,'clone',2+Math.floor(l/2));log('เงาแยกร่างล้อมรอบตัวคุณ!','p')}},
  thunder: {tree:'ninjutsu',name:'สายฟ้าพิโรธ',mp:25,req:9,max:5,desc:l=>`เวท ${pct(2+.3*l)} โอกาสสตั้น 25%`,
            run:async(l)=>{await magicHit(2+.3*l,'thunder');if(B.e.hp>0&&Math.random()<.25)addStatus(B.e,'stun',1)}},
  dragon:  {tree:'ninjutsu',name:'มังกรอัคคีทมิฬ',mp:45,req:15,max:5,desc:l=>`เวทมหาศาล ${pct(3.5+.4*l)} + ไหม้ 3 เทิร์น`,
            run:async(l)=>{await magicHit(3.5+.4*l,'dragon');addStatus(B.e,'burn',3,Math.round(magicPow()*.5))}},
};

const GEAR = {
  wood_katana:{slot:'weapon',name:'ดาบไม้ฝึกหัด',atk:2,price:0},
  steel_katana:{slot:'weapon',name:'คาตานะเหล็กกล้า',atk:6,price:120},
  kage_blade:{slot:'weapon',name:'ดาบเงาจันทรา',atk:12,price:450},
  dragon_fang:{slot:'weapon',name:'เขี้ยวมังกร',atk:20,price:1200},
  muramasa:{slot:'weapon',name:'มุรามาสะต้องสาป',atk:32,price:3000},
  iron_star:{slot:'throw',name:'ดาวกระจายเหล็ก',atk:2,price:0},
  steel_kunai:{slot:'throw',name:'คุไนเหล็กกล้า',atk:6,price:150},
  venom_star:{slot:'throw',name:'ดาวพิษงูเห่า',atk:11,price:500},
  phoenix_star:{slot:'throw',name:'ดาวกระจายหงส์ไฟ',atk:19,price:1400},
  paper_charm:{slot:'charm',name:'ยันต์กระดาษ',atk:1,mp:0,price:0},
  jade_charm:{slot:'charm',name:'ลูกปัดหยก',atk:5,mp:15,price:180},
  spirit_scroll:{slot:'charm',name:'คัมภีร์วิญญาณ',atk:11,mp:35,price:600},
  dragon_orb:{slot:'charm',name:'ลูกแก้วมังกร',atk:20,mp:60,price:1600},
  cloth:{slot:'armor',name:'ชุดผ้าดำ',def:1,hp:0,price:0},
  leather:{slot:'armor',name:'เกราะหนัง',def:3,hp:20,price:100},
  chain:{slot:'armor',name:'เสื้อโซ่ถัก',def:6,hp:45,price:400},
  shadow_garb:{slot:'armor',name:'ชุดนินจาเงา',def:10,hp:80,price:1100},
  oni_armor:{slot:'armor',name:'เกราะปีศาจโอนิ',def:15,hp:140,price:2800},
};
const SLOTNAME = {weapon:'ดาบ',throw:'อาวุธปา',charm:'เครื่องราง',armor:'ชุดเกราะ'};

// hp/mp: restore amount · battle: only usable in battle
const ITEMS = {
  potion:{name:'ยาสมุนไพร',desc:'ฟื้น HP 60',price:20,hp:60},
  hipotion:{name:'ยาโสมทอง',desc:'ฟื้น HP 200',price:65,hp:200},
  ether:{name:'ชาเขียวจิต',desc:'ฟื้น MP 40',price:30,mp:40},
  elixir:{name:'น้ำอมฤต',desc:'ฟื้น HP/MP เต็ม',price:250,hp:99999,mp:99999},
  bomb:{name:'ระเบิดเพลิง',desc:'ความเสียหาย 50+Lv×8 + ไหม้ (ในการต่อสู้)',price:45,battle:true},
  smoke:{name:'ระเบิดควัน',desc:'หนีการต่อสู้ได้แน่นอน (ในการต่อสู้)',price:35,battle:true},
};

const MATS = {
  herb:{name:'สมุนไพรป่า',icon:'🌿',price:6},
  scrap_iron:{name:'เศษเหล็ก',icon:'⚙',price:8},
  wolf_pelt:{name:'หนังหมาป่า',icon:'🐺',price:10},
  tengu_feather:{name:'ขนนกเท็งงุ',icon:'🪶',price:25},
  shadow_shard:{name:'ผลึกเงา',icon:'🔮',price:35},
  oni_horn:{name:'เขาโอนิ',icon:'🦴',price:45},
};

// kind: ninja|ronin|wolf|oni|monk|puppet|tengu|shogun
const ENEMIES = [
  null,
  {name:'โจรป่า',kind:'ronin',color:'#7a5a3a',moves:['hit'],drops:[{m:'herb',c:.5}]},
  {name:'หมาป่าสีเทา',kind:'wolf',color:'#8a8a8a',moves:['hit','bite'],drops:[{m:'wolf_pelt',c:.6}]},
  {name:'ซามูไรพเนจร',kind:'ronin',color:'#3d5a80',moves:['hit','heavy'],drops:[{m:'scrap_iron',c:.55}]},
  {name:'นินจาฝึกหัด',kind:'ninja',color:'#556b2f',moves:['hit','star'],drops:[{m:'scrap_iron',c:.3},{m:'herb',c:.3}]},
  {name:'ราชาโจร โกโร่',kind:'ronin',color:'#a0522d',boss:1,moves:['hit','heavy','heal'],drops:[{m:'scrap_iron',c:1,n:3}]},
  {name:'นินจาเงา',kind:'ninja',color:'#333',moves:['hit','star','poison'],drops:[{m:'shadow_shard',c:.3},{m:'scrap_iron',c:.3}]},
  {name:'พระนักรบ',kind:'monk',color:'#d98b2b',moves:['hit','heavy','heal'],drops:[{m:'herb',c:.6}]},
  {name:'หุ่นเชิดกลไก',kind:'puppet',color:'#9c7b52',moves:['hit','heavy','stun'],drops:[{m:'scrap_iron',c:.7}]},
  {name:'ปีศาจเท็งงุ',kind:'tengu',color:'#b22222',moves:['hit','fire','star'],drops:[{m:'tengu_feather',c:.5}]},
  {name:'โอนิแดง',kind:'oni',color:'#c0392b',boss:1,moves:['hit','heavy','stun','heal'],drops:[{m:'oni_horn',c:1,n:2}]},
  {name:'นักฆ่าแมงป่อง',kind:'ninja',color:'#6b3fa0',moves:['hit','poison','star'],drops:[{m:'shadow_shard',c:.45}]},
  {name:'ซามูไรวิญญาณ',kind:'ronin',color:'#5f9ea0',moves:['hit','heavy','drain'],drops:[{m:'scrap_iron',c:.5},{m:'shadow_shard',c:.25}]},
  {name:'จอมเวทอสรพิษ',kind:'monk',color:'#2e8b57',moves:['fire','poison','heal'],drops:[{m:'herb',c:.6},{m:'tengu_feather',c:.2}]},
  {name:'โอนิน้ำเงิน',kind:'oni',color:'#2f5fb3',moves:['hit','heavy','stun','fire'],drops:[{m:'oni_horn',c:.35}]},
  {name:'โชกุนเงา คาเงะโมริ',kind:'shogun',color:'#1a1a1a',boss:1,moves:['hit','heavy','fire','drain','stun','heal'],drops:[{m:'shadow_shard',c:1,n:5}]},
];

// ---- vector looks (see draw.js) ----
const SKIN='#e8b892';
const ENEMY_LOOKS = [
  null,
  {skin:SKIN,hair:'#4a3020',top:'#55703c',sash:'#8a6a3a',pants:'#6b4a2e',boots:'#3e2c1e',wraps:'#9a8a70',belt:'#3e2c1e',mask:'#7a5a3a',weapon:'dagger'},
  {fur:'#80838a'},
  {skin:SKIN,hair:'#1e1a18',topknot:1,kasa:'#c9a86a',top:'#3d5a80',chest:'#e6dfcf',pants:'#283548',boots:'#2a221c',belt:'#1e1e24',weapon:'katana'},
  {skin:SKIN,hood:'#55673a',top:'#55673a',pants:'#45552e',boots:'#2e3520',wraps:'#7d7d6e',belt:'#2e3520',weapon:'dagger'},
  {skin:SKIN,hair:'#1e1a18',topknot:1,beard:'#2a2420',big:1,bulk:1.3,scale:1.08,top:'#9a4e28',armor:'#6e6a64',pants:'#4e3424',boots:'#2e2018',belt:'#2e2018',beltTail:1,weapon:'club'},
  {skin:SKIN,hood:'#25252b',band:'#8a8a90',top:'#25252b',pants:'#202024',boots:'#18181c',wraps:'#4a4a50',belt:'#4a4a50',weapon:'katana'},
  {skin:SKIN,bald:1,top:'#d98b2b',robe:'#d98b2b',trim:'#7a3a12',pants:'#d98b2b',boots:'#4a3020',beads:1,belt:'#7a3a12',weapon:'staff'},
  {skin:'#a8865a',boxHead:1,noFace:0,eye:'#000000',top:'#9c7b52',pants:'#8a6a44',boots:'#5e4630',forearm:'#9c7b52',glove:'#a8865a',belt:'#5e4630',weapon:'katana',wLen:62},
  {skin:'#c23a2c',hair:'#e8e4dc',longHair:1,nose:1,wings:'#26262c',top:'#efe8d6',sash:'#b22222',pants:'#2a2a2e',boots:'#1e1e22',belt:'#b22222',weapon:'staff',wTip:'#e6c35a'},
  {skin:'#c23a2c',hair:'#1a1210',longHair:1,horns:1,tusks:1,big:1,bulk:1.5,scale:1.15,top:'#c23a2c',chest:'#a82e22',pants:'#d4a017',boots:'#5a3a20',belt:'#5a3a20',beltTail:1,eye:'#ffde59',weapon:'club',wLen:90},
  {skin:SKIN,hood:'#5e3590',top:'#5e3590',sash:'#2a1a40',pants:'#3e2460',boots:'#22142e',wraps:'#7a5aa0',belt:'#2a1a40',weapon:'dagger',glow:'#b56cff'},
  {skin:'#b8d8d8',ghost:1,hair:'#2a3a3a',top:'#5f9ea0',armor:'#3e6e70',helmet:'#2e4e50',pants:'#2e4e50',boots:'#1e2e30',belt:'#1e2e30',eye:'#d0ffff',weapon:'katana'},
  {skin:'#c8d8a8',hair:'#1e3a22',longHair:1,top:'#2e8b57',robe:'#2e8b57',trim:'#d4af37',pants:'#2e8b57',boots:'#1e3a22',belt:'#d4af37',eye:'#ffde00',weapon:'staff',wTip:'#7bd35a'},
  {skin:'#2f5fb3',hair:'#e8e4dc',longHair:1,horns:1,tusks:1,big:1,bulk:1.45,scale:1.12,top:'#2f5fb3',chest:'#244c94',pants:'#8a8a90',boots:'#3a3a40',belt:'#3a3a40',beltTail:1,eye:'#ffde59',weapon:'club',wLen:88},
  {skin:'#d0c0b0',hood:'#1a1a1e',helmet:'#1c1c20',crest:'#d4af37',wings:'#2a2a30',bulk:1.2,scale:1.1,top:'#1c1c20',armor:'#8b1a1a',sash:'#d4af37',pants:'#18181c',boots:'#101012',belt:'#d4af37',eye:'#ff3030',weapon:'katana',wLen:95},
];
ENEMIES.forEach((e,i)=>{if(e)e.look=ENEMY_LOOKS[i]});

// ---- character classes (from the original: Balanced / Warrior / Spellcaster / Ninja) ----
const CLASSES = {
  balanced:{name:'สมดุล',en:'Balanced',desc:'รอบด้าน ใช้ได้ทั้งดาบ ดาวกระจาย และคาถา',
    base:{str:7,agi:6,int:6,vit:6},grow:{str:1,agi:1,int:1},hpMul:1,mpMul:1,crit:0,skills:{slash:1,star:1},
    look:{skin:SKIN,hair:'#4a2e1c',top:'#2a2a2e',pants:'#28282c',boots:'#3a3a3e',wraps:'#6a6a70',belt:'#6a6a70',beltTail:1,weapon:'katana'}},
  warrior:{name:'นักรบ',en:'Warrior',desc:'HP และพลังดาบสูง ทนทาน แต่ MP น้อย',
    base:{str:10,agi:4,int:3,vit:8},grow:{str:2,vit:1},hpMul:1.15,mpMul:.8,crit:0,skills:{slash:2,star:1},
    look:{skin:SKIN,hair:'#1e1a18',topknot:1,bulk:1.15,top:'#8a8478',armor:'#9a9488',pants:'#4e5270',boots:'#5a4030',wraps:'#a89a80',belt:'#5a3a2a',sash:'#5a3a2a',weapon:'katana',wLen:88}},
  caster:{name:'จอมเวท',en:'Spellcaster',desc:'พลังเวทและ MP สูงมาก แต่ร่างกายบอบบาง',
    base:{str:3,agi:5,int:10,vit:5},grow:{int:2,agi:1},hpMul:.9,mpMul:1.3,crit:0,skills:{slash:1,fire:1},
    look:{skin:SKIN,hair:'#5a3a22',longHair:1,top:'#34346e',robe:'#34346e',trim:'#d4af37',pants:'#34346e',boots:'#2a2a40',belt:'#d4af37',weapon:'dagger',glow:'#66ccff'}},
  ninja:{name:'นินจา',en:'Ninja',desc:'ว่องไว คริติคอลและหลบหลีกสูง เชี่ยวชาญอาวุธปา',
    base:{str:6,agi:10,int:4,vit:5},grow:{agi:2,str:1},hpMul:1,mpMul:1,crit:5,skills:{slash:1,star:2},
    look:{skin:SKIN,hood:'#1c1c22',band:'#c8382c',scarf:'#c8382c',top:'#1c1c22',pants:'#1a1a1e',boots:'#2a2a2e',wraps:'#4a4a50',belt:'#c8382c',weapon:'katana'}},
};

const MAIN_QUESTS = [
  {title:'โจรป่าลอบปล้น',need:{1:3},reward:{gold:80,exp:60,items:{potion:2}},
   talk:['ช่วงนี้โจรป่าออกปล้นชาวบ้านที่ผ่านป่าไผ่ทางตะวันออก','เจ้าช่วยไปจัดการโจรป่าสัก 3 คนได้ไหม?']},
  {title:'เขี้ยวในพงไผ่',need:{2:3,3:1},reward:{gold:120,exp:120,items:{ether:2}},
   talk:['หมาป่าในป่าเริ่มดุร้ายผิดปกติ และมีซามูไรพเนจรเดินเตร็ดเตร่','กำจัดหมาป่า 3 ตัวและซามูไรพเนจร 1 คน']},
  {title:'ศิษย์ทรยศ',need:{4:3},reward:{gold:150,exp:200,items:{hipotion:1,bomb:2}},
   talk:['นินจาฝึกหัดบางคนแปรพักตร์ไปเข้ากับโจร','นำพวกมันกลับมาสู่ความสงบ... ด้วยดาบของเจ้า']},
  {title:'ราชาโจร โกโร่',need:{5:1},reward:{gold:300,exp:350,items:{elixir:1}},
   talk:['หัวหน้าของพวกโจรคือโกโร่ มันขวางทางขึ้นภูเขาอยู่ท้ายป่า','ปราบมันแล้วทางสู่ยอดเขาหิมะจะเปิด']},
  {title:'วัดบนยอดเขา',need:{6:2,7:2},reward:{gold:400,exp:500,items:{hipotion:2}},
   talk:['ข่าวลือว่าวัดบนเขาถูกนินจาเงายึดไปแล้ว','ปราบนินจาเงา 2 คน และพระนักรบที่ถูกสะกดจิต 2 รูป']},
  {title:'กลไกและปีศาจ',need:{8:2,9:2},reward:{gold:550,exp:700,items:{elixir:1}},
   talk:['หุ่นเชิดกลไกและเท็งงุบุกลงมาจากยอดเขา','ทำลายหุ่นเชิด 2 ตัว และเท็งงุ 2 ตน']},
  {title:'โอนิแดงแห่งภูเขา',need:{10:1},reward:{gold:900,exp:1000,items:{elixir:2}},
   talk:['โอนิแดงเฝ้าประตูสู่ปราสาทเงาอยู่บนยอดเขา','มันแข็งแกร่งมาก เตรียมตัวให้พร้อมก่อนไป']},
  {title:'เงาในปราสาท',need:{11:2,12:2},reward:{gold:1000,exp:1400,items:{hipotion:3}},
   talk:['ปราสาทเงาเต็มไปด้วยนักฆ่าและวิญญาณซามูไร','ปราบนักฆ่าแมงป่อง 2 และซามูไรวิญญาณ 2']},
  {title:'ปีศาจสุดท้าย',need:{13:2,14:2},reward:{gold:1300,exp:1800,items:{elixir:2}},
   talk:['ผู้รับใช้คนสนิทของโชกุนคือจอมเวทอสรพิษและโอนิน้ำเงิน','ปราบให้สิ้นซาก ก่อนเผชิญหน้ากับนาย']},
  {title:'โชกุนเงา',need:{15:1},reward:{gold:3000,exp:3000,items:{elixir:3}},
   talk:['ถึงเวลาแล้ว... โชกุนเงา คาเงะโมริ รออยู่ในห้องบัลลังก์','ชะตากรรมของหมู่บ้านอยู่ในมือเจ้า']},
];

// ================= MAPS =================
const VILLAGE_ROWS = [
  'TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT',
  'T......,.......TT...........,........TTT',
  'T..HHHHH.......TT....HHHHHH..........TTT',
  'T..HHHHH..,..........HHHHHH....,......TT',
  'T..HHDHH.............HHHDHH...........TT',
  'T....=..................=.............TT',
  'T....=..................=......~~~~...TT',
  'T....====================......~~~~...TT',
  'T..,..........=.........,......~~~~...TT',
  'T.............=..........,......~~....TT',
  'T..HHHHH......=.....L......L..........TT',
  'T..HHHHH......=.......................TT',
  'T..HHDHH......==========================',
  'T....=........=........................T',
  'T....==========.......HHHHHH...........T',
  'T.............=.......HHHHHH......,....T',
  'T...,.........=.......HHHDHH...........T',
  'T.............=..........=.............T',
  'T......xxxxx..=..........=......TT.....T',
  'T......x...x..============......TTT....T',
  'T......x.,.x..........,..........T.....T',
  'T......xx.xx...................,......TT',
  'T.........................TT..........TT',
  'T...,..............................,..TT',
  'TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT',
];

const MAPS = {
  village:{name:'หมู่บ้านใบไม้',theme:'village',rows:VILLAGE_ROWS,safe:true,
    spawn:{x:20,y:12}, inn:{x:26,y:18}, fromNext:{x:38,y:12},
    exits:[{x:39,y:12,to:'forest'}],
    npcs:[
      {id:'merchant',name:'พ่อค้า โทคิจิ',x:6,y:5,look:{skin:SKIN,hair:'#1e1a18',topknot:1,top:'#8a5a2b',chest:'#e6dfcf',sash:'#4a6a3a',pants:'#5a4632',boots:'#3a2a1e',belt:'#4a6a3a',weapon:'none'}},
      {id:'elder',name:'ผู้ใหญ่บ้าน ฮิโรชิ',x:25,y:5,look:{skin:SKIN,bald:1,beard:'#f0f0ec',top:'#e8e4dc',robe:'#e8e4dc',trim:'#9a9488',pants:'#e8e4dc',boots:'#7a6a50',belt:'#9a9488',weapon:'staff',wIdle:3.0}},
      {id:'smith',name:'ช่างตีดาบ กันเท็ตสึ',x:6,y:13,look:{skin:'#c8946a',hair:'#2a2a2a',band:'#e8e4dc',bulk:1.3,top:'#c8946a',chest:'#5a3e28',pants:'#4a4a50',boots:'#2a221c',belt:'#5a3e28',weapon:'hammer',wIdle:2.2}},
      {id:'inn',name:'โรงเตี๊ยม โอฮานะ',x:26,y:17,look:{skin:'#f0c8a8',hair:'#1e1a18',bun:1,top:'#d77fa1',robe:'#d77fa1',trim:'#7a2a4a',pants:'#d77fa1',boots:'#7a2a4a',belt:'#f2d16b',weapon:'none'}},
      {id:'master',name:'อาจารย์นินจา ไรเดน',x:9,y:20,look:{skin:SKIN,hood:'#2a2a3a',mask:'#2a2a3a',band:'#d4af37',beard:'#d8d8d8',top:'#2a2a3a',pants:'#22222e',boots:'#18181e',wraps:'#5a5a6a',belt:'#d4af37',weapon:'katana'}},
      {id:'board',name:'กระดานค่าหัว',x:17,y:9,kind:'board'},
    ],
    chests:[{id:'v1',x:36,y:22,loot:{gold:40,items:{potion:1}}},{id:'v2',x:35,y:1,loot:{items:{ether:1,smoke:1}}}],
  },
  forest:{name:'ป่าไผ่มรณะ',theme:'forest',seed:1337,w:50,h:30,enemies:[1,2,3,4],count:10,boss:5,prev:'village',next:'mountain',
    chestLoot:[{gold:80},{items:{potion:3}},{gear:'steel_kunai'},{items:{ether:2},mats:{herb:2}},{items:{bomb:2}}]},
  mountain:{name:'ยอดเขาหิมะ',theme:'mountain',seed:777,w:54,h:32,enemies:[6,7,8,9],count:11,boss:10,prev:'forest',next:'castle',
    chestLoot:[{gold:250},{gear:'jade_charm'},{items:{hipotion:2}},{mats:{tengu_feather:2},items:{bomb:2}},{gear:'chain'}]},
  castle:{name:'ปราสาทเงา',theme:'castle',seed:4242,w:56,h:32,enemies:[11,12,13,14],count:12,boss:15,prev:'mountain',next:null,
    chestLoot:[{gold:600},{gear:'shadow_garb'},{items:{elixir:1}},{mats:{shadow_shard:3,oni_horn:1}},{gear:'venom_star'}]},
};

const THEMES = {
  village:{ground:'.'},
  forest:{ground:'.',path:'=',solids:['B','B','T'],deco:',',water:2,clumps:70},
  mountain:{ground:'s',path:'p',solids:['S','S','r'],deco:'s',water:1,clumps:75},
  castle:{ground:'f',path:'c',solids:['W','W','W','W','L'],deco:'f',water:3,clumps:65},
};
const SOLID = new Set(['T','B','~','H','D','L','x','S','r','W']);
