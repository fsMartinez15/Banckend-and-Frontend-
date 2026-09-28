import { mkdir, writeFile } from 'node:fs/promises';
const out='output/entrega_angular_spring/figma'; await mkdir(out,{recursive:true});
const C={blue:'#1957ED',ink:'#17243B',muted:'#738098',border:'#E7ECF3',orange:'#FF7A45',background:'#F5F7FB'};
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
const rect=(x,y,w,h,fill='white',r=12,stroke='none')=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}" stroke="${stroke}"/>`;
const text=(x,y,s,size=14,color=C.ink,weight=400)=>`<text x="${x}" y="${y}" font-family="Arial, sans-serif" font-size="${size}" font-weight="${weight}" fill="${color}">${esc(s)}</text>`;
const brand=(x,y)=>rect(x,y,37,37,C.blue,12)+text(x+8,y+28,'↗',28,'white',700)+text(x+47,y+28,'ridemove.',26,C.ink,700);
const button=(x,y,w,label,fill=C.blue)=>rect(x,y,w,49,fill)+text(x+18,y+30,label,13,'white',700)+text(x+w-32,y+31,'↗',20,'white');
const input=(x,y,w,label,placeholder)=>text(x,y,label,12,C.ink,700)+rect(x,y+11,w,49,'white',10,C.border)+text(x+14,y+41,placeholder,13,'#96A1B3');
function map(x,y,scale=1) {
  let result=`<g transform="translate(${x},${y}) scale(${scale})">`;
  for(let row=0;row<5;row++) for(let col=0;col<6;col++) result+=rect(col*77,row*67,62,52,'#D9E2F4',9);
  result+='<path d="M-20 290 C130 140 80 200 220 210 S290 130 475 90" fill="none" stroke="#BDDCD9" stroke-width="20"/>';
  result+='<path d="M50 260 L130 210 L113 144 L280 95 L329 160" fill="none" stroke="white" stroke-width="17" stroke-linejoin="round"/>';
  result+=`<path d="M50 260 L130 210 L113 144 L280 95 L329 160" fill="none" stroke="${C.blue}" stroke-width="8" stroke-linejoin="round"/><circle cx="50" cy="260" r="13" fill="${C.blue}" stroke="white" stroke-width="5"/><circle cx="329" cy="160" r="16" fill="${C.orange}" stroke="white" stroke-width="5"/></g>`; return result;
}
const svg=(name,w,h,body)=>`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><title>${name}</title>${rect(0,0,w,h,C.background,0)}${body}</svg>`;
function auth(register=false) {
  let b=rect(0,0,1440,900,'white',0)+rect(0,0,720,900,'#EAF0FF',0)+brand(60,48)+text(60,212,'CADA VIAJE, UNA NUEVA HISTORIA',11,C.ink,700);
  b+=text(60,294,'Tu ciudad.',62,C.ink,700)+text(60,368,'Tu ritmo.',62,C.ink,700)+text(60,442,'Tu próximo viaje.',62,C.blue,700)+text(60,498,'Conecta con tu destino y disfruta el camino.',16,C.muted)+text(60,525,'Todo comienza con RideMove.',16,C.muted)+map(198,556,.9);
  b+=text(60,853,'Hecho para movernos juntos',12,C.muted)+text(650,853,'01 / 03',10,C.muted);
  const x=878,w=390,y=register?140:204;
  b+=text(x,y,register?'EL CAMINO EMPIEZA AQUÍ':'BIENVENIDO DE NUEVO',10,C.blue,700)+text(x,y+46,register?'Vamos a conectar.':'Qué bueno verte.',34,C.ink,700)+text(x,y+80,register?'Crea tu cuenta y haz parte de RideMove.':'Ingresa a tu cuenta y elige tu próximo destino.',13,C.muted);
  let top=y+126;
  if(register){b+=input(x,top,w,'Nombre completo','¿Cómo te llamas?');top+=90;}
  b+=input(x,top,w,'Correo electrónico','tucorreo@ejemplo.com');top+=90;
  b+=input(x,top,w,'Contraseña',register?'Mínimo 8 caracteres':'Tu contraseña');top+=90;
  if(register){b+=input(x,top,w,'¿Cómo quieres moverte?','Quiero viajar · Pasajero');top+=90;}
  b+=button(x,top,w,register?'Crear mi cuenta':'Iniciar sesión')+text(x+50,top+84,register?'¿Ya tienes cuenta? Inicia sesión':'¿Es tu primer viaje? Crea tu cuenta',13,C.blue,700);
  if(!register) b+=rect(x,top+130,w,48,'#F5F7FB',12,C.border)+text(x+90,top+160,'Explorar demostración →',13,C.ink,700)+text(x+78,top+204,'Datos de ejemplo, sin crear una cuenta.',11,C.muted);
  b+=text(x+95,852,'RideMove · Movilidad que conecta',11,C.muted);return svg(register?'Registro':'Login',1440,900,b);
}
function dashboard() {
  let b=rect(0,0,233,1024,'white',0)+brand(24,35)+text(37,160,'MI ESPACIO',10,C.muted)+rect(24,181,185,49,'#EDF2FF',10)+text(43,211,'▦   Mi dashboard',13,C.blue,700)+text(43,266,'↗   Mis viajes',13,C.muted)+text(43,959,'⇥   Cerrar sesión',13,C.muted);
  b+=text(275,51,'Mi espacio  /  Dashboard',12,C.muted)+text(1230,51,'Alex Rivera',12,C.ink)+rect(275,101,1123,37,'#FFF5E9',9)+text(290,125,'DEMO  ·  Datos de ejemplo. Los cambios no se guardan en la base de datos.',12,'#936327');
  b+=text(275,179,'TU DÍA, EN MOVIMIENTO',10,C.blue,700)+text(275,223,'Hola, Alex.',36,C.ink,700)+text(275,251,'Cada destino empieza con un buen plan.',13,C.muted);
  b+=rect(275,281,687,350,'#E9EFFD',18)+map(550,297,.81)+text(306,321,'ENCUENTRA TU PRÓXIMO DESTINO',9,'#58719B',700)+text(306,379,'¿A dónde',41,C.ink,700)+text(306,427,'vamos hoy?',41,C.ink,700)+text(306,472,'La ciudad te espera.',13,C.muted)+text(306,495,'Nosotros te conectamos.',13,C.muted)+text(306,592,'Ilustración de recorrido',10,C.muted);
  b+=rect(984,281,414,350,'white',18,C.border)+text(1011,315,'EMPIEZA AQUÍ',9,C.blue,700)+text(1011,350,'Un nuevo viaje',25,C.ink,700)+input(1011,383,360,'Punto de partida','¿Dónde te recogemos?')+input(1011,467,360,'Tu destino','¿A dónde vamos?')+button(1011,553,360,'Solicitar viaje',C.ink);
  [['Total de viajes','3'],['Viajes finalizados','2'],['Viajes activos','0']].forEach(([label,val],i)=>{const x=275+i*381;b+=rect(x,654,361,92,'white',13,C.border)+text(x+23,684,label,12,C.muted)+text(x+23,722,val,29,C.ink,700);});
  b+=rect(275,773,1123,220,'white',16,C.border)+text(301,812,'Mis viajes',21,C.ink,700)+text(301,837,'Tu actividad, en un solo lugar.',11,C.muted)+text(1130,817,'Todos  ·  Activos  ·  Finalizados',11,C.blue);
  b+=text(315,882,'↗   Plaza Mayor, Fusagasugá',14,C.ink,700)+text(342,906,'Desde Universidad de Cundinamarca',12,C.muted)+text(1110,892,'Finalizado',11,'#248568')+text(1250,892,'Pagar · demo ↗',12,C.blue,700);
  b+=text(315,947,'↗   Terminal de transportes',14,C.ink,700)+text(342,971,'Desde Centro comercial La Querencia',12,C.muted)+text(1110,955,'Finalizado',11,'#248568')+text(1250,955,'Pagar · demo ↗',12,C.blue,700);return svg('Dashboard de demostración',1440,1024,b);
}
function payment(){let b=rect(0,0,720,640,'#E8EDF6',0)+rect(130,70,460,500,'white',20)+text(537,112,'×',26,C.muted)+rect(163,108,58,58,'#EDF2FF',18)+text(180,150,'↗',36,C.blue)+text(163,207,'PAGO · DEMOSTRACIÓN',10,C.blue,700)+text(163,252,'Tu viaje, a un paso.',29,C.ink,700)+text(163,290,'Universidad de Cundinamarca → Plaza Mayor',12,C.muted)+rect(163,327,394,121,'#F5F7FB',12)+text(180,355,'Este botón es una demostración.',13,C.ink,700)+text(180,383,'La tarifa y la pasarela aún no están conectadas.',12,C.muted)+text(180,405,'No se piden tarjetas ni se cobra dinero.',12,C.muted)+button(163,478,394,'Probar confirmación');return svg('Pago demo',720,640,b);}
function mobile(){let b=rect(0,0,390,1510,C.background,0)+rect(0,0,390,74,'white',0)+brand(20,19)+text(345,48,'⇥',24,C.muted)+text(20,109,'Mi espacio / Dashboard',11,C.muted)+text(289,109,'Alex Rivera',11,C.ink)+rect(20,135,350,62,'#FFF5E9',9)+text(31,159,'DEMO · Datos de ejemplo',11,'#936327',700)+text(31,179,'Los cambios no se guardan en la base de datos.',10,'#936327')+text(20,236,'TU DÍA, EN MOVIMIENTO',9,C.blue,700)+text(20,278,'Hola, Alex.',34,C.ink,700)+text(20,307,'Cada destino empieza con un buen plan.',12,C.muted)+rect(20,331,350,288,'#E9EFFD',18)+map(179,438,.39)+text(43,365,'TU PRÓXIMO DESTINO',9,C.muted,700)+text(43,412,'¿A dónde',34,C.ink,700)+text(43,454,'vamos hoy?',34,C.ink,700)+text(43,496,'La ciudad te espera.',12,C.muted)+text(43,516,'Nosotros te conectamos.',12,C.muted)+text(43,590,'Ilustración de recorrido',9,C.muted);
  b+=rect(20,637,350,358,'white',15,C.border)+text(45,672,'EMPIEZA AQUÍ',9,C.blue,700)+text(45,706,'Un nuevo viaje',25,C.ink,700)+input(45,743,300,'Punto de partida','¿Dónde te recogemos?')+input(45,831,300,'Tu destino','¿A dónde vamos?')+button(45,917,300,'Solicitar viaje',C.ink);
  [['Total de viajes','3'],['Finalizados','2'],['Activos','0']].forEach(([label,value],i)=>{const x=20+i*119;b+=rect(x,1016,112,88,'white',12,C.border)+text(x+11,1043,label,10,C.muted)+text(x+11,1080,value,29,C.ink,700);});
  b+=rect(20,1126,350,304,'white',16,C.border)+text(41,1164,'Mis viajes',22,C.ink,700)+text(41,1190,'Tu actividad, en un solo lugar.',11,C.muted)+rect(41,1208,308,35,'#F5F7FB',8)+text(53,1230,'Todos       Activos       Finalizados',11,C.blue)+text(41,1280,'↗   Plaza Mayor, Fusagasugá',13,C.ink,700)+text(65,1305,'Desde Universidad de Cundinamarca',11,C.muted)+text(65,1330,'25 sept 2026 · 14:00',10,C.muted)+text(65,1375,'Finalizado',11,'#248568')+text(250,1375,'Pagar · demo ↗',11,C.blue,700)+text(20,1470,'RideMove · Movilidad que conecta',10,C.muted);return svg('Dashboard móvil web',390,1510,b);}
for(const [file,body] of [['01-login.svg',auth()],['02-registro.svg',auth(true)],['03-dashboard.svg',dashboard()],['04-pago-demo.svg',payment()],['05-dashboard-movil.svg',mobile()]]) await writeFile(`${out}/${file}`,body);
await writeFile(`${out}/tokens.json`,JSON.stringify({colors:C,fonts:{heading:'Manrope',body:'DM Sans',svgFallback:'Arial'},spacing:[4,8,12,16,20,24,32,40,48],radius:{input:10,button:12,card:18},breakpoints:{mobile:600,tablet:850,desktop:1100},frames:{desktopAuth:[1440,900],desktopDashboard:[1440,1024],mobileDashboard:[390,1510]}},null,2));
console.log('5 pantallas SVG y tokens generados para importar en Figma.');
