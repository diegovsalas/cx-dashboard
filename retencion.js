/* Retención (Fase 1) · árbol de retención conectado a Supabase (esquema legacy).
   Lógica portada de la maqueta aprobada. Depende de: sb, user, esc() de index.html. */
(function(){
'use strict';
var RT={cfg:{},perm:{},puedeTomar:false,casos:{},acc:{},bandeja:[],log:[],cargado:false,
  v:{sub:'bandeja',cur:null,paso:1,open:'',marca:'Aromatex',tab:'abiertos',q:''}};
window.RT=RT;
var NOMBRES={diegovelazquez:'Diego Velázquez',anakaren:'Ana Karen Torres',itzelramirez:'Itzel Ramírez',
  johanamartinez:'Johana Martínez',servicioalcliente:'Servicio al Cliente',alejandrogil:'Alejandro Gil'};
var ZONAS=['Matriz','Centro','Sur','Bajío','Noreste','Noroeste','Pacífico'];
var CANALES=['Correo','Llamada','Técnico en sitio','Vendedor','Cobranza','Señal de riesgo'];
var EST={o:'Ofrecido',a:'Aceptado',r:'No aceptó'};
var NIV={cx:'Lo decides tú',ger:'Autoriza Gerencia CX'};
var BOT=(window.CX_ENV&&window.CX_ENV.name==='staging')?(window.CX_ENV.botUrl||''):'https://avantex-bot.onrender.com';
function e(s){return esc(s==null?'':String(s));}
function nombreDe(email){var u=String(email||'').split('@')[0];return NOMBRES[u]||u;}
function primerNombre(s){return String(s||'').trim().split(/\s+/)[0]||'';}
function yo(){return user?user.email.toLowerCase():'';}
/* ---------- árbol de la marca del caso ---------- */
function arbol(d){var c=RT.cfg[d.marca];return c&&c.arbol;}
function M(d,id){var a=arbol(d);return a?a.motivos.filter(function(m){return m.id===id})[0]:null;}
function A(d,id){var a=arbol(d);return a?a.soluciones.filter(function(s){return s.id===id})[0]:null;}
function P(d){var a=arbol(d),o={};if(a)Object.keys(a.reglas.parametros).forEach(function(k){o[k]=a.reglas.parametros[k].valor});return o;}
function RESN(d,id){var a=arbol(d),r=a?a.resultados.filter(function(x){return x.id===id})[0]:null;return r?r.nombre:'';}
/* ---------- fechas (America/Monterrey; hábil = lunes a sábado) ---------- */
function hoy(){var p=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Monterrey',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date()).split('-');return new Date(+p[0],+p[1]-1,+p[2]);}
function diaLocal(ts){if(!ts)return null;var p=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Monterrey',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(ts)).split('-');return new Date(+p[0],+p[1]-1,+p[2]);}
function iso(d){return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');}
function parse(s){var p=String(s||'').slice(0,10).split('-');if(p.length!==3||!+p[0])return null;return new Date(+p[0],+p[1]-1,+p[2]);}
function habil(x,d){return d.getDay()!==0||(x&&x.sabadoHabil===false&&d.getDay()!==6&&d.getDay()!==0);}
function addBiz(d,n){var x=new Date(d);while(n>0){x.setDate(x.getDate()+1);if(x.getDay()!==0)n--}return x;}
function bizBetween(a,b){var n=0,x=new Date(a);while(x<b){x.setDate(x.getDate()+1);if(x<=b&&x.getDay()!==0)n++}return n;}
function diasCal(a,b){return Math.round((b-a)/864e5);}
function larga(d){return d?d.toLocaleDateString('es-MX',{weekday:'long',day:'numeric',month:'long'}):'';}
function corta(d){return d?d.toLocaleDateString('es-MX',{day:'2-digit',month:'short'}):'';}
function money(n){return '$'+Number(n||0).toLocaleString('es-MX',{minimumFractionDigits:2,maximumFractionDigits:2});}
function money0(n){return '$'+Math.round(n||0).toLocaleString('es-MX');}
function num(x){var n=parseFloat(x);return isFinite(n)&&n>0?n:0;}
function F(d){var p=P(d),f=diaLocal(d.inicio_plazo||d.fecha_solicitud)||hoy();return{ini:f,llam:addBiz(f,p.diasLlamada||1),cierre:addBiz(f,p.diasCierre||5)};}
/* ---------- reglas del árbol ---------- */
function vars(d){var m=num(d.mensualidad),p=P(d),f=F(d);return{contacto:primerNombre(d.contacto),empresa:d.empresa,yo:primerNombre(nombreDe(d.atiende)),
  servicio:d.marca,aroma:d.aroma,monto:m?money(m):'',tarifaApoyo:m?money(m*(1-p.descPct/100)):'',descPct:p.descPct,descMeses:p.descMeses,
  bundlePestex:p.bundlePestex,bundleOrigen:p.bundleOrigen,autoriza:'Gerencia CX',autorizaGer:'Gerencia CX',fechaLimite:larga(f.cierre),
  fechaReact:larga(parse(d.fecha_reactivacion)),fechaSeg:larga(parse(d.fecha_seguimiento)),
  nuevaMens:d.nueva_mensualidad?money(d.nueva_mensualidad):'',retiro:''};}
function fill(d,t,html){var v=vars(d),a=arbol(d),B=(a&&a.variables.texto_si_falta)||{};t=String(t||'');t=html?e(t):t;
  return t.replace(/\{(\w+)\}/g,function(_,k){var x=v[k];if(x===undefined||x==='')return html?'<span class="rt-blank">['+e(B[k]||k)+']</span>':'['+(B[k]||k)+']';return html?e(x):String(x);});}
function rama(d){return d.causa_raiz||d.motivo_inicial;}
function accDe(d,k){var b=M(d,k);if(!b)return[];if(d.situacion){var s=b.situaciones.filter(function(x){return x.id===d.situacion})[0];if(s)return s.accionables;}return b.accionables;}
function def(d,k,id){var a=A(d,id),ov=(M(d,k)&&M(d,k).ajustes_por_accionable[id])||{};return{n:a.nombre,nivel:a.nivel,ultima:a.ultima_opcion,cuando:ov.cuando||a.cuando,guion:ov.guion||a.guion,pasos:a.pasos};}
function acc(d){return RT.acc[d.folio]||{};}
function valor(d,id){var a=A(d,id);if(!a)return 0;var c=a.valor.codigo,m=num(d.mensualidad),p=P(d);
  if(c==='tarifa')return m*p.descPct/100*p.descMeses;if(c==='mes')return m;if(c==='spray')return p.valorRoomSpray;if(c==='pestex')return p.valorPestex||null;return c;}
function vTxt(d,id){var v=valor(d,id);if(v==='var')return 'Según autorización';if(v===0)return 'Sin costo';if(v===null)return 'Valor por definir';return money(v)+(A(d,id).valor.cuenta_para_tope?'':' · cortesía');}
function marc(d,es){var o=acc(d);return Object.keys(o).filter(function(id){return es.indexOf(o[id])>=0&&A(d,id)});}
function sumaTope(d){var t=0;marc(d,['o','a']).forEach(function(id){var v=valor(d,id);if(A(d,id).valor.cuenta_para_tope&&typeof v==='number')t+=v});return t;}
function cortesias(d){var t=0;marc(d,['o','a']).forEach(function(id){var v=valor(d,id);if(!A(d,id).valor.cuenta_para_tope&&typeof v==='number')t+=v});return t;}
function tope(d){return num(d.mensualidad)*(P(d).topeMeses||1);}
function menos12(d){return d.antiguedad_meses!=null&&d.antiguedad_meses!==''&&+d.antiguedad_meses<12;}
function requiereAut(d){return marc(d,['a']).some(function(id){return A(d,id).nivel!=='cx'})||(tope(d)>0&&sumaTope(d)>tope(d))||(d.resultado==='baja'&&d.tarifa_compensatoria==='condona');}
function pend(d){var b=M(d,d.causa_raiz),of=marc(d,['o','a','r']),ac=marc(d,['a']),min=b?b.minimo_ofrecidos_para_baja:2;
  var falt=[['empresa','cliente'],['contacto','contacto'],['mensualidad','mensualidad'],['antiguedad_meses','meses con nosotros'],['vendedor_original','vendedor original'],['zona','zona'],['motivo_inicial','motivo']]
    .filter(function(k){return d[k[0]]==null||!String(d[k[0]]).trim()}).map(function(k){return k[1]});
  var ll=!!d.llamada_at||d.intentos>=3,raizOk=!!d.causa_raiz&&(d.causa_raiz!=='sincontacto'||(!d.llamada_at&&d.intentos>=3)),ok,txt;
  if(d.resultado==='baja'){ok=of.length>=min;txt='Para baja: al menos '+min+' ofrecido'+(min>1?'s':'')+' (llevas '+of.length+')';}
  else if(d.resultado==='aj'||d.resultado==='pausa'){ok=ac.length>=1;txt='Al menos una solución aceptada';}else{ok=of.length>=1;txt='Al menos una solución ofrecida';}
  var L=[[!falt.length,falt.length?'Datos del caso. Falta: '+falt.join(', '):'Datos del caso completos',1],[!!d.primer_contacto_at,'Primer contacto enviado',2],
    [ll,'Llamada realizada o 3 intentos',3],[raizOk,'Causa raíz confirmada',3],[ok,txt,4],[!!d.propuesta_enviada_at,'Propuesta enviada por escrito',5],[!!d.resultado,'Resultado elegido',6]];
  if(requiereAut(d))L.push([!!d.autorizo,'Autorización de Gerencia CX',6]);
  if(d.resultado==='pausa')L.push([!!d.fecha_reactivacion,'Fecha de reactivación',6]);
  if(d.resultado&&d.resultado!=='baja')L.push([!!d.fecha_seguimiento,'Fecha de próximo seguimiento',6]);
  if(d.resultado==='baja')L.push([!!d.fecha_efectiva,'Fecha efectiva de la baja',6]);
  if(d.resultado==='baja'&&menos12(d))L.push([!!d.tarifa_compensatoria,'Tarifa compensatoria: se cobra o se condona',6]);
  if(d.resultado==='aj'&&acc(d).reconfig==='a')L.push([!!d.nueva_mensualidad,'Nueva mensualidad',6]);
  return L;}
function hecho(d,n){if(n===6)return d.estado==='cerrado';return pend(d).filter(function(p){return p[2]===n}).every(function(p){return p[0]});}
function pasoActual(d){for(var n=1;n<=6;n++)if(!hecho(d,n))return n;return 6;}
function plazo(d){var f=F(d),t=hoy();if(d.estado==='cerrado')return{c:d.resultado==='baja'?'':'ok',t:RESN(d,d.resultado)||'Cerrado'};
  if(t>f.cierre)return{c:'bad',t:'Fuera de plazo'};if(+t===+f.cierre)return{c:'warn',t:'Vence hoy'};var n=bizBetween(f.ini,t);return{c:'info',t:n===0?'Llegó hoy':'Día '+n+' de '+(P(d).diasCierre||5)};}
function alertas(){var t=hoy(),out=[];Object.keys(RT.casos).forEach(function(id){var d=RT.casos[id];if(!d.con_arbol)return;var f=F(d),nom=d.empresa||id;
  function seg(fe,campo,etq){if(!fe||d[campo])return;var n=diasCal(t,fe);if(n>7)return;out.push({sev:n<0?3:n===0?2:1,txt:etq+(n<0?' atrasado '+(-n)+' día'+(n<-1?'s':''):n===0?' hoy':' el '+larga(fe))+'.',f:fe,id:id,nom:nom,hecho:campo});}
  if(d.estado!=='cerrado'){var ll=!!d.llamada_at||d.intentos>=3,a=null;
    if(t>f.cierre)a=[3,'Fuera de plazo desde el '+larga(f.cierre)+'. Sube hoy a Gerencia CX.',f.cierre];
    else if(!ll&&t>f.llam)a=[3,'Llamada vencida. Debió hacerse a más tardar el '+larga(f.llam)+'.',f.llam];
    else if(!d.primer_contacto_at)a=[t>f.ini?3:2,'Primer contacto pendiente.',f.ini];
    else if(+t===+f.cierre)a=[2,'La decisión vence hoy.',f.cierre];
    else if(!ll)a=[2,'Llamada pendiente. A más tardar el '+larga(f.llam)+'.',f.llam];
    if(a)out.push({sev:a[0],txt:a[1],f:a[2],id:id,nom:nom});}
  if(d.resultado&&d.resultado!=='baja')seg(parse(d.fecha_seguimiento),'seguimiento_hecho','Seguimiento');
  if(d.resultado==='pausa')seg(parse(d.fecha_reactivacion),'reactivacion_hecha','Reactivación de la pausa');
  if(d.estado==='cerrado'&&d.resultado==='baja'){var c=diaLocal(d.cerrado_at);if(c){var r=new Date(c);r.setDate(r.getDate()+90);seg(r,'recontacto_hecho','Recontacto a 90 días');}}});
  return out.sort(function(a,b){return b.sev-a.sev||a.f-b.f});}
function resumen(d){var f=F(d),b=M(d,d.causa_raiz),m=num(d.mensualidad),of=marc(d,['o','a','r']),sb2='';
  if(b&&d.situacion){var s=b.situaciones.filter(function(x){return x.id===d.situacion})[0];if(s)sb2=' ('+s.nombre+')';}
  var mi=M(d,d.motivo_inicial);
  var L=['CANCELACIÓN ATENDIDA · '+d.marca.toUpperCase(),'Folio: '+d.folio+' · Cliente: '+d.empresa+' · Contacto: '+d.contacto+' · Zona: '+d.zona,
    'Mensualidad: '+money(m)+' · Antigüedad: '+d.antiguedad_meses+' meses'+(d.aroma?' · Aroma: '+d.aroma:''),'Vendedor original: '+d.vendedor_original,
    'Cuenta con menos de 12 meses: '+(menos12(d)?(d.resultado==='baja'?'SÍ. Baja antes de 12 meses, registrar cashback del vendedor.':'SÍ. Queda registrada para revisión de cashback.'):'no'),
    'Solicitud: '+iso(f.ini)+' por '+d.canal+' · Atendió: '+nombreDe(d.atiende),'Motivo inicial: '+(mi?mi.nombre:''),'Causa raíz confirmada: '+(b?b.nombre:'')+sb2,
    'Llamada: '+(d.llamada_at?'realizada':'sin respuesta, '+d.intentos+' intentos'),'Notas: '+(d.notas_llamada||'sin notas'),'Soluciones:'];
  of.forEach(function(id){var v=valor(d,id);L.push('  - '+fill(d,A(d,id).nombre,false)+(typeof v==='number'&&v>0?' ('+money(v)+')':'')+': '+EST[acc(d)[id]].toLowerCase());});
  L.push('Valor contra tope: '+money(sumaTope(d))+' de '+money(tope(d))+(sumaTope(d)>tope(d)?' (supera el tope)':''));
  if(cortesias(d))L.push('Cortesías (no suman al tope): '+money(cortesias(d)));
  L.push('Autorización: '+(d.autorizo?'autorizó '+d.autorizo:'no requerida'));L.push('Resultado: '+RESN(d,d.resultado));
  if(d.nueva_mensualidad)L.push('Nueva mensualidad: '+money(d.nueva_mensualidad));
  if(d.resultado==='pausa')L.push('Reactivación: '+d.fecha_reactivacion);
  if(d.resultado==='baja'){L.push('Fecha efectiva: '+d.fecha_efectiva);if(menos12(d))L.push('Tarifa compensatoria (2 meses): '+(d.tarifa_compensatoria==='condona'?'se condona':'se cobra'));var r=hoy();r.setDate(r.getDate()+90);L.push('Recontacto a 90 días: '+iso(r));}
  else L.push('Próximo seguimiento: '+d.fecha_seguimiento);
  var dia=bizBetween(f.ini,hoy());L.push(dia===0?'Cerrado el mismo día de la solicitud.':'Cerrado a los '+dia+' días hábiles de la solicitud (plazo: '+(P(d).diasCierre||5)+').');
  return L.join('\n');}
RT.f={e:e,nombreDe:nombreDe,primerNombre:primerNombre,yo:yo,arbol:arbol,M:M,A:A,P:P,RESN:RESN,hoy:hoy,diaLocal:diaLocal,iso:iso,parse:parse,
  larga:larga,corta:corta,money:money,money0:money0,num:num,F:F,fill:fill,rama:rama,accDe:accDe,def:def,acc:acc,valor:valor,vTxt:vTxt,marc:marc,
  sumaTope:sumaTope,cortesias:cortesias,tope:tope,menos12:menos12,requiereAut:requiereAut,pend:pend,hecho:hecho,pasoActual:pasoActual,plazo:plazo,
  alertas:alertas,resumen:resumen,bizBetween:bizBetween,ZONAS:ZONAS,CANALES:CANALES,EST:EST,NIV:NIV,BOT:BOT};
})();
/* Retención · datos y acciones contra Supabase */
(function(){
'use strict';
var RT=window.RT,f=RT.f;
function toast(t,bad){var c=document.getElementById('rt-toasts');if(!c){c=document.createElement('div');c.id='rt-toasts';document.body.appendChild(c);}
  var x=document.createElement('div');x.className='rt-toast'+(bad?' bad':'');x.textContent=t;c.appendChild(x);setTimeout(function(){x.remove()},bad?5000:2400);}
RT.toast=toast;
function err(e){return (e&&(e.message||e.error_description))||'Error inesperado';}
RT.cargar=async function(){
  var r=await Promise.all([
    sb.from('cx_retencion_config').select('*'),
    sb.from('cx_retencion_permisos').select('*').eq('email',f.yo()),
    sb.rpc('cx_ret_puede_tomar'),
    sb.from('cx_retencion_casos').select('*').order('fecha_solicitud',{ascending:false}).limit(1000),
    sb.from('cx_retencion_acciones').select('folio,accion,estado').limit(5000),
    sb.from('cx_retencion_bandeja').select('*').order('created_at',{ascending:true}),
    sb.from('cx_retencion_config_log').select('*').order('at',{ascending:false}).limit(50)]);
  var fallo=r.filter(function(x){return x.error})[0];
  if(fallo){RT.errorCarga=err(fallo.error);RT.cargado=true;return;}
  RT.errorCarga='';RT.cfg={};r[0].data.forEach(function(c){RT.cfg[c.marca]=c});
  (Object.values(RT.cfg)).forEach(function(c){if(c.arbol&&c.arbol.reglas){var pd=c.por_definir||{};c.arbol.reglas.parametros.cashback={valor:pd.cashback||''};}});
  RT.perm=r[1].data[0]||{};RT.puedeTomar=!!r[2].data;
  RT.casos={};r[3].data.forEach(function(c){RT.casos[c.folio]=c});
  RT.acc={};r[4].data.forEach(function(a){(RT.acc[a.folio]=RT.acc[a.folio]||{})[a.accion]=a.estado});
  RT.bandeja=r[5].data||[];RT.log=r[6].data||[];RT.cargado=true;};
RT.guardar=async function(folio,cambios){var d=RT.casos[folio];if(!d)return false;
  var antes={};Object.keys(cambios).forEach(function(k){antes[k]=d[k];d[k]=cambios[k]});
  var r=await sb.from('cx_retencion_casos').update(cambios).eq('folio',folio).select('*');
  if(r.error||!r.data||!r.data.length){Object.keys(antes).forEach(function(k){d[k]=antes[k]});toast(r.error?err(r.error):'No tienes permiso para cambiar este caso.',true);RT.render();return false;}
  RT.casos[folio]=r.data[0];return true;};
RT.accion=async function(folio,id,estado){var o=RT.acc[folio]=RT.acc[folio]||{},antes=o[id],r;
  if(antes===estado){delete o[id];r=await sb.from('cx_retencion_acciones').delete().eq('folio',folio).eq('accion',id);}
  else{o[id]=estado;r=await sb.from('cx_retencion_acciones').upsert({folio:folio,accion:id,estado:estado},{onConflict:'folio,accion'});}
  if(r.error){if(antes)o[id]=antes;else delete o[id];toast(err(r.error),true);}
  else RT.casos[folio].resumen_copiado_at=null;};
async function rpc(nombre,args,ok){var r=await sb.rpc(nombre,args);if(r.error){toast(err(r.error),true);return null;}if(ok)toast(ok);return r.data;}
RT.tomar=async function(folio){var c=await rpc('cx_retencion_tomar',{p_folio:folio});await RT.cargar();
  if(!c){RT.render();return;}
  if(!c.con_arbol){toast(folio+' quedó asignado a ti. '+c.marca+' todavía no tiene árbol: atiéndelo en Cancelaciones.');RT.render();return;}
  toast('Tomaste '+folio+'.');RT.abrir(folio);};
RT.registrar=async function(datos){var c=await rpc('cx_retencion_registrar',datos);if(!c)return false;await RT.cargar();
  if(c.con_arbol)RT.abrir(c.folio);else{toast('Solicitud '+c.folio+' registrada y asignada a ti.');RT.render();}return true;};
RT.autorizar=async function(folio){var c=await rpc('cx_retencion_autorizar',{p_folio:folio},'Autorizado por Diego Velázquez');if(c)RT.casos[folio]=c;RT.render();};
RT.cerrar=async function(folio){var c=await rpc('cx_retencion_cerrar',{p_folio:folio});if(!c){RT.render();return;}
  RT.casos[folio]=c;var t=await sb.from('tickets').select('status_cancelacion').eq('folio',folio).limit(1);
  toast('Caso cerrado. Status en Cancelaciones: '+((t.data&&t.data[0]&&t.data[0].status_cancelacion)||'actualizado'));RT.v.sub='casos';RT.v.cur=null;
  if(typeof window._refreshVista==='function'){try{await loadData();}catch(e){}}RT.render();};
RT.reabrir=async function(folio){var c=await rpc('cx_retencion_reabrir',{p_folio:folio},'Caso reabierto');if(c)RT.casos[folio]=c;RT.render();};
RT.editarRegla=async function(marca,campo,valor){var c=await rpc('cx_retencion_editar_regla',{p_marca:marca,p_campo:campo,p_valor:valor});if(c)return true;return false;};
RT.copiarResumen=async function(folio){var d=RT.casos[folio],txt=f.resumen(d);
  try{await navigator.clipboard.writeText(txt);}catch(e){prompt('Copia el resumen y pégalo en Operandium:',txt);}
  if(await RT.guardar(folio,{resumen_operandium:txt,resumen_copiado_at:new Date().toISOString()}))toast('Resumen copiado. Pégalo en Operandium.');RT.render();};
RT.enviarPrimerContacto=async function(folio){
  if(!f.BOT){toast('En staging no se envía WhatsApp. Usa «Ya lo envié por otro medio».',true);return;}
  var s=await sb.auth.getSession(),tk=s&&s.data&&s.data.session&&s.data.session.access_token;
  if(!tk){toast('Vuelve a iniciar sesión.',true);return;}
  var btn=document.getElementById('rt-enviar');if(btn){btn.disabled=true;btn.textContent='Enviando…';}
  try{var r=await fetch(f.BOT+'/dashboard/api/retencion/primer_contacto',{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+tk},body:JSON.stringify({folio:folio})});
    var j=await r.json().catch(function(){return{}});
    if(!r.ok||!j.ok){toast(j.error||('No se pudo enviar ('+r.status+')'),true);}
    else toast(j.via==='plantilla'?'Enviado con la plantilla de WhatsApp (la ventana de 24 h estaba cerrada).':'Enviado por WhatsApp.');}
  catch(e){toast('No se pudo conectar con el bot.',true);}
  await RT.cargar();RT.render();};
})();
/* Retención · vistas: bandeja, casos, alertas, árbol, reglas */
(function(){
'use strict';
var RT=window.RT,f=RT.f,e=f.e;
function pill(t,c){return '<span class="rt-tag '+(c||'')+'">'+t+'</span>';}
function ic(t){return '<span class="rt-ic '+(t||'')+'">'+(t==='ok'?'✓':t==='soft'?'·':'!')+'</span>';}
RT.pill=pill;RT.ic=ic;
function tabs(){var ab=Object.values(RT.casos).filter(function(d){return d.estado!=='cerrado'&&d.con_arbol}).length,
  al=f.alertas().filter(function(a){return a.sev>=2}).length,nb=RT.bandeja.length;
  return '<div class="rt-tabs">'+[['bandeja','Solicitudes nuevas',nb,nb?'hot':''],['casos','Casos',ab,''],['alertas','Alertas',al,al?'hot':''],['arbol','Árbol',0,''],['reglas','Reglas y topes',0,'']]
   .map(function(t){var on=RT.v.sub===t[0]||(RT.v.sub==='caso'&&t[0]==='casos');return '<button class="rt-tab'+(on?' on':'')+'" data-rt="sub" data-id="'+t[0]+'">'+t[1]+(t[2]?' <span class="rt-badge '+t[3]+'">'+t[2]+'</span>':'')+'</button>';}).join('')+'</div>';}
RT.tabs=tabs;
function espera(r){var ini=r.inicio_plazo||r.created_at,n=f.bizBetween(f.diaLocal(ini),f.hoy()),h=Math.floor((Date.now()-new Date(ini))/36e5);
  if(n===0)return h<2?{t:'Llegó hace '+(h?h+' h':'menos de 1 h'),c:'warn'}:{t:'Sin tomar desde hace '+h+' h',c:'bad'};
  return{t:'Sin tomar desde hace '+n+' día'+(n>1?'s':'')+' hábil'+(n>1?'es':''),c:'bad'};}
RT.vBandeja=function(){var marcas=['Aromatex','Pestex','Origen Selecto'];Object.keys(RT.cfg).forEach(function(m){if(marcas.indexOf(m)<0)marcas.push(m)});
  var L=RT.bandeja.filter(function(r){return r.marca===RT.v.marca}),cfg=RT.cfg[RT.v.marca],conArbol=!!(cfg&&cfg.activo&&cfg.arbol);
  var h='<div class="rt-head"><div><h2>Solicitudes nuevas</h2><p>Todas las cancelaciones abiertas que aún no se gestionan en Retención. Al tomarla, la ficha se llena con los datos del ticket. El plazo cuenta desde que llegó; si es anterior al proceso, desde el día en que arrancó.</p></div>'+
    (RT.puedeTomar?'<button class="rt-btn line" data-rt="registrarForm">+ Registrar solicitud de otro canal</button>':'')+'</div>';
  if(!RT.puedeTomar)h+='<div class="rt-note">Tu usuario puede ver la bandeja, pero no tomar solicitudes.</div>';
  h+='<div class="rt-card"><div class="rt-card-t"><span class="rt-toggle">'+marcas.map(function(m){var n=RT.bandeja.filter(function(r){return r.marca===m}).length;return '<button class="'+(RT.v.marca===m?'on':'')+'" data-rt="marca" data-id="'+e(m)+'">'+e(m)+' · '+n+'</button>'}).join('')+'</span></div>';
  if(!conArbol)h+='<div class="rt-note">'+e(RT.v.marca)+' todavía no tiene árbol de retención. Al tomar la solicitud queda asignada a ti y se atiende en Cancelaciones, como hoy.</div>';
  if(!L.length)h+='<p class="rt-small">No hay solicitudes pendientes de '+e(RT.v.marca)+'.</p>';
  else h+='<div class="rt-tbl"><table><thead><tr><th>Folio</th><th>Cliente</th><th>Lo que escribió</th><th>Motivo sugerido</th><th>Espera</th><th></th></tr></thead><tbody>'+L.map(function(r){
    var es=espera(r),mot=r.motivo_sugerido&&cfg&&cfg.arbol?cfg.arbol.motivos.filter(function(m){return m.id===r.motivo_sugerido})[0]:null;
    return '<tr><td><div class="rt-mono">'+e(r.folio)+'</div><div class="rt-sub">'+f.corta(f.diaLocal(r.created_at))+'</div>'+(r.anterior_al_proceso?pill('Anterior al proceso'):'')+'</td><td><div class="rt-name">'+e(r.empresa||'Sin empresa')+'</div><div class="rt-sub">'+(r.sin_contacto?pill('Sin contacto','warn'):e(r.nombre))+'</div></td>'+
      '<td class="rt-small">«'+e(String(r.mensaje||'').slice(0,140))+'»</td><td class="rt-small">'+(r.categoria?'Gemini: '+e(r.categoria)+'<br>':'')+(conArbol?(mot?pill('→ '+e(mot.nombre),'info'):pill('Elegir a mano','warn')):'')+'</td>'+
      '<td>'+pill(es.t,es.c)+(r.agente_previo?'<div class="rt-sub">Asignada antes a '+e(f.nombreDe(r.agente_previo+'@'))+'</div>':'')+(r.estatus&&r.estatus!=='Nuevo'?'<div class="rt-sub">Estatus: '+e(r.estatus)+'</div>':'')+'</td><td>'+(RT.puedeTomar?'<button class="rt-btn" data-rt="tomar" data-id="'+e(r.folio)+'">Tomar</button>':'')+'</td></tr>';}).join('')+'</tbody></table></div>';
  return h+'</div>';};
RT.vRegistrar=function(){return '<div class="rt-head"><div><h2>Registrar solicitud de otro canal</h2><p>Crea el ticket y el caso, asignados a ti.</p></div></div><div class="rt-card"><div class="rt-form">'+
  '<div><label>Servicio</label><select id="rt-r-serv">'+['Aromatex','Pestex','Origen Selecto'].map(function(s){return '<option>'+s+'</option>'}).join('')+'</select></div>'+
  '<div><label>Llegó por</label><select id="rt-r-canal">'+f.CANALES.map(function(s){return '<option>'+s+'</option>'}).join('')+'</select></div>'+
  '<div><label>Cliente</label><input id="rt-r-emp"></div><div><label>Contacto</label><input id="rt-r-nom"></div>'+
  '<div><label>Teléfono (WhatsApp)</label><input id="rt-r-tel" inputmode="tel"></div><div style="grid-column:1/-1"><label>Qué pidió</label><textarea id="rt-r-msg"></textarea></div></div>'+
  '<div class="rt-row"><button class="rt-btn line" data-rt="sub" data-id="bandeja">Cancelar</button><button class="rt-btn" data-rt="registrar">Registrar y tomar</button></div></div>';};
function tablaCasos(){var q=RT.v.q.trim().toLowerCase(),C=Object.values(RT.casos).filter(function(d){return d.con_arbol});
  var L=C.filter(function(d){if(RT.v.tab==='abiertos'&&d.estado==='cerrado')return false;if(RT.v.tab==='cerrados'&&d.estado!=='cerrado')return false;if(RT.v.tab==='mios'&&d.atiende!==f.yo())return false;
    return !q||(d.folio+' '+d.empresa+' '+d.contacto+' '+f.nombreDe(d.atiende)+' '+d.vendedor_original).toLowerCase().indexOf(q)>=0;});
  L.sort(function(a,b){if(a.estado!==b.estado)return a.estado==='cerrado'?1:-1;return a.estado==='cerrado'?String(b.cerrado_at).localeCompare(a.cerrado_at):String(a.fecha_solicitud).localeCompare(b.fecha_solicitud);});
  var a=C.filter(function(d){return d.estado!=='cerrado'}).length;
  var h='<div class="rt-card-t"><span>Casos</span><span class="rt-flex"><input class="rt-search" id="rt-q" placeholder="Buscar folio, cliente, quien atiende o vendedor" value="'+e(RT.v.q)+'"><span class="rt-toggle">'+
    [['abiertos','Abiertos · '+a],['mios','Míos'],['cerrados','Cerrados · '+(C.length-a)],['todos','Todos']].map(function(x){return '<button class="'+(RT.v.tab===x[0]?'on':'')+'" data-rt="tab" data-id="'+x[0]+'">'+x[1]+'</button>'}).join('')+'</span></span></div>';
  if(!L.length)return h+'<p class="rt-small">Ningún caso coincide.</p>';
  return h+'<div class="rt-tbl"><table><thead><tr><th>Folio</th><th>Cliente</th><th>Mensualidad</th><th>Causa</th><th>Avance</th><th>Plazo</th><th>Atiende</th></tr></thead><tbody>'+L.map(function(d){
    var p=f.plazo(d),pa=f.pasoActual(d),k=f.rama(d),m=k&&f.M(d,k),dots='';for(var n=1;n<=6;n++)dots+='<i class="'+(f.hecho(d,n)?'ok':'')+'"></i>';
    return '<tr class="rt-click" data-rt="abrir" data-id="'+e(d.folio)+'"><td class="rt-mono">'+e(d.folio)+'</td><td><div class="rt-name">'+e(d.empresa||'Sin nombre')+'</div><div class="rt-sub">'+e(d.contacto)+'</div></td>'+
      '<td>'+(f.num(d.mensualidad)?f.money0(d.mensualidad):'—')+(f.menos12(d)?' '+pill(d.resultado==='baja'?'Cashback':'< 12 meses','warn'):'')+'</td><td class="rt-small">'+e(m?m.nombre:'Sin motivo')+'</td>'+
      '<td><span class="rt-small">'+(d.estado==='cerrado'?'Cerrado '+f.corta(f.diaLocal(d.cerrado_at)):'Paso '+pa+' de 6')+'</span><span class="rt-dots">'+dots+'</span></td><td>'+pill(p.t,p.c)+'</td><td class="rt-small">'+e(f.nombreDe(d.atiende))+'</td></tr>';}).join('')+'</tbody></table></div>';}
function kpis(){var t=f.hoy(),ab=0,abM=0,fu=0,ret=0,retN=0,baj=0,bajN=0;
  Object.values(RT.casos).forEach(function(d){if(!d.con_arbol)return;var m=f.num(d.mensualidad);if(d.estado!=='cerrado'){ab++;abM+=m;if(t>f.F(d).cierre)fu++;}
    else{var c=f.diaLocal(d.cerrado_at);if(c&&c.getFullYear()===t.getFullYear()&&c.getMonth()===t.getMonth()){if(d.resultado==='baja'){baj+=m;bajN++}else{ret+=m;retN++}}}});
  function k(l,v,s,c){return '<div class="rt-kpi"><div class="l">'+l+'</div><div class="v '+(c||'')+'">'+v+'</div><div class="s">'+s+'</div></div>';}
  return '<div class="rt-kpis">'+k('Casos abiertos',ab,f.money0(abM)+' al mes en juego')+k('Fuera de plazo',fu,fu?'Suben hoy a Gerencia CX':'Todos en tiempo',fu?'red':'green')+
    k('Solicitudes sin tomar',RT.bandeja.length,'En la bandeja',RT.bandeja.length?'amber':'green')+k('Retenido este mes',f.money0(ret),retN+' caso'+(retN===1?'':'s'),'green')+k('Bajas este mes',f.money0(baj),bajN+' baja'+(bajN===1?'':'s'))+'</div>';}
RT.vCasos=function(){return '<div class="rt-head"><div><h2>Casos de retención</h2><p>'+e(f.larga(f.hoy()))+'. Plazos en días hábiles de lunes a sábado.</p></div></div>'+kpis()+'<div class="rt-card">'+tablaCasos()+'</div>';};
function alertList(){var L=f.alertas();if(!L.length)return '<p class="rt-small">Sin pendientes.</p>';
  return '<ul class="rt-alist">'+L.map(function(a){var d=RT.casos[a.id],mio=d.atiende===f.yo()||isAdmin();return '<li>'+ic(a.sev===3?'bad':a.sev===2?'':'soft')+'<div class="t"><b>'+e(a.nom)+' <span class="rt-sub">'+e(a.id)+' · '+e(f.nombreDe(d.atiende))+'</span></b><span>'+e(a.txt)+'</span></div>'+
    (a.hecho&&mio?'<button class="rt-btn line" data-rt="hecho" data-id="'+e(a.id)+'" data-v="'+a.hecho+'">Hecho</button>':'')+'<button class="rt-btn ghost" data-rt="abrir" data-id="'+e(a.id)+'">Abrir</button></li>';}).join('')+'</ul>';}
RT.vAlertas=function(){return '<div class="rt-head"><div><h2>Alertas</h2><p>Aparecen desde 7 días antes. Marca «Hecho» al cumplir.</p></div></div><div class="rt-card">'+alertList()+'</div>';};
RT.vArbol=function(){var c=RT.cfg[RT.v.marca]&&RT.cfg[RT.v.marca].arbol?RT.cfg[RT.v.marca]:RT.cfg.Aromatex;if(!c||!c.arbol)return '<div class="rt-card"><p class="rt-small">No hay árbol cargado.</p></div>';
  var d={marca:c.marca,mensualidad:0};
  return '<div class="rt-head"><div><h2>Árbol de retención · '+e(c.marca)+'</h2><p>Versión '+c.version+'. Cada motivo con su lectura, preguntas y soluciones por situación.</p></div></div>'+c.arbol.motivos.map(function(m){
    var cont='<div class="rt-lect">'+e(m.lectura)+'</div>';if(m.mensaje_primer_contacto)cont+='<p class="rt-small"><b>Primer contacto:</b> «'+e(m.mensaje_primer_contacto)+'»</p>';
    if(m.preguntas.length)cont+='<h4>Preguntas</h4><ol class="rt-qs">'+m.preguntas.map(function(q){return '<li><b>'+e(q.pregunta)+'</b><span>'+e(q.para_que)+'</span></li>'}).join('')+'</ol>';
    cont+='<h4>Soluciones</h4>'+(m.situaciones.length?'<div class="rt-tbl"><table><tbody>'+m.situaciones.map(function(s){return '<tr><td class="rt-name">'+e(s.nombre)+'</td><td>'+s.accionables.map(function(id){var a=f.A(d,id);return pill(e(f.fill(d,a.nombre,false)),a.nivel==='cx'?'':'info')}).join(' ')+'</td></tr>'}).join('')+'</tbody></table></div>'
      :(m.accionables.length?m.accionables.map(function(id){var a=f.A(d,id);return pill(e(a.nombre),a.nivel==='cx'?'':'info')}).join(' '):'<p class="rt-small">Ninguna: primero encuentra la causa real.</p>'));
    return '<details class="rt-mot"><summary>'+e(m.nombre)+' <span class="rt-sub">mínimo '+m.minimo_ofrecidos_para_baja+' para baja</span></summary><div class="in">'+cont+'</div></details>';}).join('')+
    '<p class="rt-small">'+pill('Gris')+' lo decide la ejecutiva · '+pill('Azul','info')+' autoriza Gerencia CX</p>';};
var MONTOS=[['descPct','Tarifa de apoyo: descuento máximo (%)','numero','0','100','1'],['descMeses','Tarifa de apoyo: meses','numero','1','24','1'],
  ['topeMeses','Tope de retención (mensualidades)','numero','0.5','12','0.5'],['valorRoomSpray','Valor del room spray Emerald ($)','numero','0','','1'],['valorPestex','Valor de un servicio Pestex de cortesía ($)','numero','0','','1']];
var CAMPOS=[['bundlePestex','Condiciones del paquete con Pestex','texto'],['bundleOrigen','Condiciones del paquete con Origen Selecto','texto'],
  ['cashback','Regla y monto del cashback del vendedor','texto'],['horario','Horario hábil (para las 2 horas hábiles)','texto'],['visita48','«Visita técnica en 48 horas» se cuenta en','sel']];
function pdVal(c,k){return ['bundlePestex','bundleOrigen','valorPestex','descPct','descMeses','topeMeses','valorRoomSpray'].indexOf(k)>=0?c.arbol.reglas.parametros[k].valor:(c.por_definir||{})[k];}
RT.vReglas=function(){var c=RT.cfg.Aromatex;if(!c||!c.arbol)return '<div class="rt-card"><p class="rt-small">No hay árbol cargado.</p></div>';
  var ed=!!RT.perm.puede_editar_reglas,p=c.arbol.reglas.parametros,h='<div class="rt-head"><div><h2>Reglas y topes</h2><p>Aromatex · versión '+c.version+'. Pestex y Origen Selecto todavía no tienen árbol.</p></div></div>';
  h+='<div class="rt-card"><div class="rt-card-t"><span>Montos y topes<div class="rt-sub">Los editan Diego Velázquez y Alejandro Gil. Aplican a los casos abiertos desde que se guardan; los cerrados no cambian.</div></span>'+(ed?'':pill('Solo lectura'))+'</div><div class="rt-form">'+
    MONTOS.map(function(k){var v=pdVal(c,k[0]);return '<div><label>'+k[1]+'</label><input id="rt-pd-'+k[0]+'" type="number" min="'+k[3]+'"'+(k[4]?' max="'+k[4]+'"':'')+' step="'+k[5]+'" value="'+e(v==null?'':v)+'"'+(ed?'':' disabled')+'></div>';}).join('')+'</div>'+
    (ed?'<div class="rt-row"><span class="rt-small">Ejemplo con mensualidad de $2,000: tarifa de apoyo '+f.money0(2000*p.descPct.valor/100*p.descMeses.valor)+' · tope '+f.money0(2000*p.topeMeses.valor)+'</span><button class="rt-btn" data-rt="guardarPD">Guardar cambios</button></div>':'')+'</div>';
  h+='<div class="rt-card"><div class="rt-card-t"><span>Campos por definir<div class="rt-sub">Los editan Diego Velázquez y Alejandro Gil. Editar reglas no es autorizar casos.</div></span>'+(ed?'':pill('Solo lectura'))+'</div><div class="rt-form">'+
    CAMPOS.map(function(k){var v=pdVal(c,k[0]),vac=v===''||v===0||v==null;return '<div><label>'+k[1]+' '+(vac?pill('Por definir','warn'):pill('Definido','ok'))+'</label>'+
      (k[2]==='sel'?'<select id="rt-pd-'+k[0]+'"'+(ed?'':' disabled')+'>'+[['','Sin definir'],['hábiles','Horas hábiles'],['naturales','Horas naturales']].map(function(o){return '<option value="'+o[0]+'"'+(v===o[0]?' selected':'')+'>'+o[1]+'</option>'}).join('')+'</select>'
      :'<input id="rt-pd-'+k[0]+'" type="'+(k[2]==='numero'?'number':'text')+'" value="'+e(v==null?'':v)+'"'+(ed?'':' disabled')+'>')+'</div>';}).join('')+'</div>'+
    (ed?'<div class="rt-row"><span></span><button class="rt-btn" data-rt="guardarPD">Guardar cambios</button></div>':'');
  if(RT.log.length)h+='<h4>Historial de cambios</h4><ul class="rt-lst">'+RT.log.map(function(l){return '<li>'+ic('ok')+'<span><b>'+e((MONTOS.concat(CAMPOS).filter(function(k){return k[0]===l.campo})[0]||[0,l.campo])[1])+'</b>: «'+e(l.antes==null?'vacío':JSON.parse(JSON.stringify(l.antes)))+'» → «'+e(l.despues)+'» · '+e(f.nombreDe(l.por))+' · '+e(new Date(l.at).toLocaleString('es-MX',{dateStyle:'short',timeStyle:'short'}))+'</span></li>'}).join('')+'</ul>';
  h+='</div><div class="rt-grid2"><div class="rt-card"><div class="rt-card-t">Plazos</div><div class="rt-kv"><span>Primer contacto</span><span>'+p.horasContacto.valor+' horas hábiles</span><span>Llamada</span><span>Mismo día o siguiente hábil</span><span>Decisión</span><span>'+p.diasCierre.valor+' días hábiles</span><span>Días hábiles</span><span>Lunes a sábado</span><span>Recontacto tras baja</span><span>90 días</span></div></div>'+
    '<div class="rt-card"><div class="rt-card-t">Topes y autoriza</div><div class="rt-kv"><span>Tarifa de apoyo</span><span>Hasta '+p.descPct.valor+'% por '+p.descMeses.valor+' meses</span><span>Tope de retención</span><span>'+p.topeMeses.valor+' mensualidad</span><span>Room spray Emerald</span><span>'+f.money0(p.valorRoomSpray.valor)+' (no suma)</span><span>Todo lo demás</span><span>Diego Velázquez</span></div></div></div>';
  h+='<div class="rt-card"><div class="rt-card-t">Soluciones y quién decide</div><div class="rt-tbl"><table><tbody>'+c.arbol.soluciones.map(function(s){return '<tr><td class="rt-name">'+e(f.fill({marca:'Aromatex'},s.nombre,false))+'</td><td>'+pill(f.NIV[s.nivel],s.nivel==='cx'?'ok':'info')+'</td><td class="rt-small">'+e(s.cuando)+'</td></tr>'}).join('')+'</tbody></table></div></div>';
  return h;};
RT.CAMPOS=MONTOS.concat(CAMPOS);RT.pdVal=pdVal;
})();
/* Retención · ficha del caso (6 pasos) */
(function(){
'use strict';
var RT=window.RT,f=RT.f,e=f.e,pill=RT.pill,ic=RT.ic;
var PASOS=['Abrir caso','Primer contacto','Llamada','Soluciones','Propuesta','Cierre'];
function editable(d){return d.estado!=='cerrado'&&(d.atiende===f.yo()||isAdmin());}
function inp(d,k,l,t,ed,extra){var v=d[k]==null?'':d[k];if(t==='date')v=String(v).slice(0,10);
  return '<div><label>'+l+'</label><input data-rtk="'+k+'" type="'+(t||'text')+'" value="'+e(v)+'"'+(ed?'':' disabled')+(extra||'')+'></div>';}
function sel(d,k,l,ops,ed){return '<div><label>'+l+'</label><select data-rtk="'+k+'"'+(ed?'':' disabled')+'><option value="">Elige…</option>'+ops.map(function(o){var v=Array.isArray(o)?o[0]:o,t=Array.isArray(o)?o[1]:o;return '<option value="'+e(v)+'"'+(String(d[k]||'')===v?' selected':'')+'>'+e(t)+'</option>'}).join('')+'</select></div>';}
function chip(on,a,id,txt,dis){return '<button class="rt-chip'+(on?' on':'')+'" data-rt="'+a+'" data-id="'+e(id)+'"'+(dis?' disabled':'')+'>'+txt+'</button>';}
function say(d,lbl,t){return '<div class="rt-say"><div class="st"><span>'+lbl+'</span><button class="rt-btn ghost" data-rt="copiarTxt">Copiar</button></div><p>'+f.fill(d,t,true)+'</p></div>';}
function msgPrimer(d){var a=f.arbol(d),m=f.M(d,d.motivo_inicial);if(!m)return '';
  return m.señal_de_riesgo?a.plantillas.primer_contacto['señal_de_riesgo']:a.plantillas.primer_contacto.normal.replace('{motivo.mensaje_primer_contacto}',m.mensaje_primer_contacto||'');}
function paso(d){var n=RT.v.paso,ed=editable(d),a=f.arbol(d),k=f.rama(d),b=f.M(d,k),P=f.P(d),h='<div class="rt-card">';
  h+='<h3>'+['Abre el caso','Primer contacto','Llamada para entender la causa','Soluciones','Propuesta por escrito','Cierre y registro'][n-1]+'</h3>';
  if(n===1){h+='<p class="rt-when">Datos del ticket '+e(d.folio)+'. Lo que falta se toma de Operandium.</p><div class="rt-form">'+inp(d,'empresa','Cliente / sucursal','text',ed)+inp(d,'contacto','Contacto','text',ed)+
      inp(d,'mensualidad','Mensualidad sin IVA','number',ed,' min="0" step="0.01"')+inp(d,'antiguedad_meses','Meses con nosotros','number',ed,' min="0" step="1"')+inp(d,'vendedor_original','Vendedor original','text',ed)+
      inp(d,'aroma','Aroma actual','text',ed)+sel(d,'zona','Zona',f.ZONAS,ed)+'<div><label>Llegó por</label><input value="'+e(d.canal)+'" disabled></div><div><label>Atiende</label><input value="'+e(f.nombreDe(d.atiende))+'" disabled></div></div>';
    if(d.motivo_sugerido&&d.motivo_sugerido===d.motivo_inicial)h+='<div class="rt-note info">Motivo sugerido por la clasificación de Gemini. Confírmalo o cámbialo.</div>';
    if(f.menos12(d))h+='<div class="rt-note">Cuenta con menos de 12 meses: queda registrada con su vendedor para la revisión del cashback.</div>';
    h+='<h4>¿Qué motivo da el cliente?</h4><div class="rt-chips">'+a.motivos_iniciales_orden.map(function(id){return chip(d.motivo_inicial===id,'motivo',id,e(f.M(d,id).nombre),!ed)}).join('')+'</div>';}
  else if(n===2){h+='<p class="rt-when">Hoy mismo, máximo '+P.horasContacto+' horas hábiles</p><p class="rt-hint">Un solo objetivo: conseguir la llamada. No se confirma ninguna baja por escrito antes de hablar con el cliente.</p>';
    var t=msgPrimer(d);if(!t)h+='<p class="rt-hint">Elige el motivo en el paso 1.</p>';else h+=say(d,'Mensaje (ventana de 24 h abierta)',t);
    h+='<p class="rt-small">Si pasaron más de 24 horas desde el último mensaje del cliente, o no llegó por WhatsApp, el bot manda la plantilla aprobada con los botones «Llámame ahora», «Más tarde hoy» y «Mañana».</p>';
    if(d.primer_contacto_at)h+='<div class="rt-note ok">Enviado el '+e(new Date(d.primer_contacto_at).toLocaleString('es-MX',{dateStyle:'medium',timeStyle:'short'}))+' · '+e({texto:'WhatsApp (texto)',plantilla:'WhatsApp (plantilla)',manual:'otro medio'}[d.primer_contacto_via]||'')+'</div>';
    if(!d.primer_contacto_at&&d.primer_contacto_error)h+='<div class="rt-note bad">El último envío por WhatsApp no se entregó: '+e(d.primer_contacto_error)+'. Llámale directo y márcalo como enviado por otro medio.</div>';
    else if(ed)h+='<div class="rt-row"><button class="rt-btn line" data-rt="manual">Ya lo envié por otro medio</button><button class="rt-btn" id="rt-enviar" data-rt="enviarWA"'+(t&&f.BOT?'':' disabled')+'>Enviar por WhatsApp</button></div>'+(f.BOT?'':'<p class="rt-small">En staging el envío por WhatsApp está desactivado.</p>');}
  else if(n===3){var m=f.M(d,d.motivo_inicial);h+='<p class="rt-when">Hoy mismo. A más tardar el '+e(f.larga(f.F(d).llam))+'</p><ul class="rt-tips">'+a.pasos[2].tips.map(function(t){return '<li>'+t+'</li>'}).join('')+'</ul>';
    if(m){h+='<div class="rt-lect">'+e(m.lectura)+'</div>'+say(d,'Apertura',a.plantillas.apertura_llamada);if(m.preguntas.length)h+='<h4>Preguntas para llegar a la causa</h4><ol class="rt-qs">'+m.preguntas.map(function(q){return '<li><b>'+e(q.pregunta)+'</b><span>'+e(q.para_que)+'</span></li>'}).join('')+'</ol>';h+=say(d,'Si no contesta',a.plantillas.si_no_contesta);}
    h+='<h4>¿Qué pasó con la llamada?</h4><div class="rt-chips">'+chip(!!d.llamada_at,'llamada','',(d.llamada_at?'✓ ':'')+'Llamada realizada',!ed)+[1,2,3].map(function(i){return chip(d.intentos>=i,'int',i,'Intento '+i+' sin respuesta',!ed)}).join('')+'</div>';
    h+='<h4>Causa raíz que confirmaste</h4><p class="rt-hint">Puede ser distinta del motivo. Las soluciones salen de aquí.</p><div class="rt-chips">'+a.causas_raiz_orden.map(function(id){return chip(d.causa_raiz===id,'raiz',id,e(f.M(d,id).nombre),!ed||(id==='sincontacto'&&(!!d.llamada_at||d.intentos<3)))}).join('')+'</div>';
    h+='<div style="margin-top:12px"><label>Notas de la llamada: lo que dijo el cliente, con sus palabras</label><textarea data-rtk="notas_llamada"'+(ed?'':' disabled')+'>'+e(d.notas_llamada)+'</textarea></div>';}
  else if(n===4){h+='<p class="rt-when">En la misma llamada</p>';if(!b)return h+'<p class="rt-hint">Elige la causa raíz en el paso 3.</p></div>';
    var mi=f.M(d,d.motivo_inicial);if(d.causa_raiz&&d.causa_raiz!==d.motivo_inicial&&mi&&!mi.señal_de_riesgo&&d.motivo_inicial!=='sinmotivo')h+='<div class="rt-note">El cliente dijo «'+e(mi.nombre.toLowerCase())+'», pero la causa confirmada es «'+e(b.nombre.toLowerCase())+'». Se atiende la causa.</div>';
    if(b.solo_causa_raiz)h+='<div class="rt-lect">'+e(b.lectura)+'</div>';
    if(b.situaciones.length){h+='<h4>¿Cuál es la situación?</h4><div class="rt-chips">'+b.situaciones.map(function(s){return chip(d.situacion===s.id,'sit',s.id,e(s.nombre),!ed)}).join('')+'</div>';var ss=b.situaciones.filter(function(s){return s.id===d.situacion})[0];if(ss&&ss.nota)h+='<div class="rt-note">'+e(ss.nota)+'</div>';}
    var L=f.accDe(d,k);if(!L.length)return h+'<div class="rt-note">Sin causa no hay soluciones. Termina la llamada y elige la causa raíz.</div></div>';
    h+='<p class="rt-hint">Ofrece siempre más de una opción.</p>';
    L.forEach(function(id,i){var x=f.def(d,k,id),st=f.acc(d)[id]||'',op=RT.v.open===id;
      h+='<div class="rt-acc'+(st?' st-'+st:'')+'"><button class="ah" data-rt="open" data-id="'+id+'"><span>'+f.fill(d,x.n,true)+'</span><span class="rt-flex">'+(d.situacion&&i===0?pill('Empieza aquí','info'):'')+(x.ultima?pill('Última opción'):'')+pill(f.NIV[x.nivel],x.nivel==='cx'?'ok':'info')+pill(f.vTxt(d,id))+(st?pill(f.EST[st],st==='a'?'ok':st==='r'?'bad':'warn'):'')+'</span></button>';
      if(op)h+='<div class="ab"><p class="rt-hint"><b>Cuándo usarlo.</b> '+e(x.cuando)+'</p>'+say(d,'Dilo así',x.guion)+'<ol>'+x.pasos.map(function(p){return '<li>'+f.fill(d,p,true)+'</li>'}).join('')+'</ol><div class="rt-chips">'+[['o','Lo ofrecí, está pendiente'],['a','Aceptó'],['r','No aceptó']].map(function(z){return chip(st===z[0],'est',id+'|'+z[0],z[1],!ed)}).join('')+'</div></div>';
      h+='</div>';});}
  else if(n===5){var tod=f.marc(d,['o','a']).filter(function(id){return f.A(d,id).linea_cierre}),L2=tod.filter(function(id){return f.A(d,id).nivel==='cx'||d.autorizo}),fu=tod.filter(function(id){return L2.indexOf(id)<0});
    h+='<p class="rt-when">El mismo día de la llamada</p>';
    if(fu.length)h+='<div class="rt-note">Todavía no entra al mensaje: '+fu.map(function(id){return e(f.fill(d,f.A(d,id).nombre,false).toLowerCase())}).join(', ')+'. Requiere autorización de Gerencia CX.'+(RT.perm.puede_autorizar&&d.estado!=='cerrado'?' <button class="rt-btn" data-rt="autorizar">Autorizar como Diego Velázquez</button>':' Pídela a Diego Velázquez.')+'</div>';
    if(!L2.length)h+='<p class="rt-hint">Marca en el paso 4 lo que ofreciste y aquí se arma el mensaje.</p>';else h+=say(d,'Propuesta',a.plantillas.propuesta.replace('• {linea_cierre de cada accionable}',L2.map(function(id){return '• '+f.A(d,id).linea_cierre}).join('\n')));
    h+='<div class="rt-chips">'+chip(!!d.propuesta_enviada_at,'c5','',d.propuesta_enviada_at?'✓ Enviada':'Marcar como enviada',!ed)+'</div>';}
  else{h+='<p class="rt-when">Decisión a más tardar el '+e(f.larga(f.F(d).cierre))+'</p><h4>¿Cómo terminó?</h4><div class="rt-chips">'+a.resultados.map(function(r){return chip(d.resultado===r.id,'res',r.id,e(r.nombre),!ed)}).join('')+'</div><div class="rt-form" style="margin-top:12px">';
    if(d.resultado&&d.resultado!=='baja')h+=inp(d,'fecha_seguimiento','Próximo seguimiento','date',ed);
    if(d.resultado==='pausa')h+=inp(d,'fecha_reactivacion','Fecha de reactivación','date',ed);
    if(d.resultado==='aj'&&f.acc(d).reconfig==='a')h+=inp(d,'nueva_mensualidad','Nueva mensualidad sin IVA','number',ed,' min="0" step="0.01"');
    if(d.resultado==='baja'){h+=inp(d,'fecha_efectiva','Fecha efectiva (primer mes sin cobro)','date',ed);if(f.menos12(d))h+=sel(d,'tarifa_compensatoria','Tarifa compensatoria (2 meses)',[['cobra','Se cobra'],['condona','Se condona (autoriza Gerencia CX)']],ed);}
    h+='</div>';
    if(f.requiereAut(d))h+=d.autorizo?'<div class="rt-note ok">Autorizó '+e(d.autorizo)+'.</div>':'<div class="rt-note">Requiere autorización de Gerencia CX.'+(RT.perm.puede_autorizar&&d.estado!=='cerrado'?' <button class="rt-btn" data-rt="autorizar">Autorizar como Diego Velázquez</button>':'')+'</div>';
    if(d.resultado==='baja')h+=say(d,'Mensaje de despedida',a.plantillas.despedida_baja);
    else if(d.resultado){var ac=f.marc(d,['a']).filter(function(id){return f.A(d,id).linea_cierre});h+=say(d,'Mensaje de confirmación',ac.length?a.plantillas.confirmacion_retenido.con_aceptados.replace('• {linea_cierre de cada accionable aceptado}',ac.map(function(id){return '• '+f.A(d,id).linea_cierre}).join('\n')):a.plantillas.confirmacion_retenido.sin_aceptados);}
    var fa=f.pend(d).filter(function(p){return!p[0]}).length;h+='<h4>Resumen para Operandium</h4>';
    if(d.estado==='cerrado')h+='<pre class="rt-sum">'+e(d.resumen_operandium||f.resumen(d))+'</pre>'+(d.atiende===f.yo()||isAdmin()?'<div class="rt-row"><span></span><button class="rt-btn line" data-rt="reabrir">Reabrir caso</button></div>':'');
    else if(fa)h+='<div class="rt-note bad">Faltan '+fa+' punto'+(fa>1?'s':'')+' para generar el resumen. Sin resumen en Operandium no se procesa ninguna baja ni ajuste.</div>';
    else h+='<pre class="rt-sum">'+e(f.resumen(d))+'</pre><div class="rt-row" style="justify-content:flex-start"><button class="rt-btn '+(d.resumen_copiado_at?'line':'')+'" data-rt="copy"'+(ed?'':' disabled')+'>'+(d.resumen_copiado_at?'✓ Copiado':'1. Copiar resumen')+'</button><button class="rt-btn" data-rt="cerrar"'+(d.resumen_copiado_at&&ed?'':' disabled')+'>2. Cerrar caso</button></div>';}
  h+='<div class="rt-row">'+(n>1?'<button class="rt-btn line" data-rt="ir" data-id="'+(n-1)+'">← Atrás</button>':'<span></span>')+(n<6?'<button class="rt-btn" data-rt="ir" data-id="'+(n+1)+'">Continuar: '+PASOS[n]+' →</button>':'')+'</div></div>';return h;}
function lado(d){var fx=f.F(d),t=f.hoy(),ll=!!d.llamada_at||d.intentos>=3,dia=f.bizBetween(fx.ini,t),venc=d.estado!=='cerrado'&&t>fx.cierre,P=f.P(d);
  var h='<div class="rt-card"><div class="rt-card-t">Reloj del caso</div><div class="rt-big">'+(d.estado==='cerrado'?'Cerrado':dia===0?'Llegó hoy':'Día '+dia+' de '+P.diasCierre)+'</div><ul class="rt-lst">'+
    [[!!d.primer_contacto_at,!d.primer_contacto_at&&t>fx.ini,'Primer contacto','Máx. '+P.horasContacto+' h hábiles desde la llegada'],[ll,!ll&&t>fx.llam,'Llamada','A más tardar el '+f.larga(fx.llam)],[!!d.resultado&&d.estado==='cerrado',venc,'Decisión','A más tardar el '+f.larga(fx.cierre)]]
    .map(function(i){return '<li>'+ic(i[0]?'ok':i[1]?'bad':'')+'<div><b>'+i[2]+(i[0]?': hecho':i[1]?': vencido':': pendiente')+'</b><div class="rt-sub">'+e(i[3])+'</div></div></li>'}).join('')+'</ul>'+(venc?'<div class="rt-note bad">Fuera de plazo. Sube hoy a Gerencia CX.</div>':'')+'</div>';
  var tp=f.tope(d),s=f.sumaTope(d),over=s>tp;h+='<div class="rt-card"><div class="rt-card-t">Tope de retención</div>';
  if(!tp)h+='<p class="rt-small">Captura la mensualidad para saber cuánto se le puede ofrecer.</p>';
  else{h+='<div class="rt-big">'+f.money(s)+' <span class="rt-sub">de '+f.money(tp)+'</span></div><div class="rt-track'+(over?' over':'')+'"><i style="width:'+Math.min(100,Math.round(s/tp*100))+'%"></i></div>'+(over?'<div class="rt-note bad">Supera el tope. Autoriza Gerencia CX antes de confirmarlo.</div>':'<p class="rt-small">Una mensualidad. Suma lo ofrecido pendiente y lo aceptado.</p>');if(f.cortesias(d))h+='<p class="rt-small">Cortesías (no suman): '+f.money(f.cortesias(d))+'</p>';}
  h+='</div>';var L=f.pend(d),fa=L.filter(function(p){return!p[0]}).length;
  h+='<div class="rt-card"><div class="rt-card-t">'+(d.estado==='cerrado'?'Cerrado':fa?'Falta para cerrar: '+fa:'Listo para cerrar')+'</div><ul class="rt-lst">'+L.map(function(p){return '<li class="'+(p[0]?'done':'')+'">'+ic(p[0]?'ok':'')+'<span>'+e(p[1])+'</span></li>'}).join('')+'</ul></div>';return h;}
RT.vCaso=function(){var d=RT.casos[RT.v.cur];if(!d)return '<div class="rt-card"><p class="rt-small">No se encontró el caso.</p></div>';
  var p=f.plazo(d),k=f.rama(d),m=k&&f.M(d,k),st=d.estado==='cerrado'?'':'';
  var h='<div><button class="rt-btn ghost" data-rt="sub" data-id="casos">← Casos</button></div><div class="rt-head"><div><h2>'+e(d.folio)+' · '+e(d.empresa||'Caso nuevo')+'</h2><div class="rt-flex" style="margin-top:6px">'+
    pill(p.t,p.c)+pill(e(d.marca))+(m?pill(e(m.nombre)):'')+(f.num(d.mensualidad)?pill(f.money(d.mensualidad)+' al mes'):'')+(f.menos12(d)?pill(d.resultado==='baja'?'Cashback':'Menos de 12 meses','warn'):'')+pill('Atiende: '+e(f.nombreDe(d.atiende)))+'</div></div></div>';
  if(!editable(d)&&d.estado!=='cerrado')h+='<div class="rt-note">Este caso lo atiende '+e(f.nombreDe(d.atiende))+'. Lo puedes ver, pero no cambiar.</div>';
  h+='<div class="rt-steps">'+PASOS.map(function(x,i){var n=i+1,ok=f.hecho(d,n);return '<button class="'+(ok?'ok ':'')+(RT.v.paso===n?'on':'')+'" data-rt="ir" data-id="'+n+'"><span class="sn">'+(ok?'✓':n)+'</span>'+x+'</button>'}).join('')+'</div>';
  return h+'<div class="rt-casegrid"><div>'+paso(d)+'</div><div class="rt-col">'+lado(d)+'</div></div>';};
})();
/* Retención · render, eventos y estilos */
(function(){
'use strict';
var RT=window.RT,f=RT.f;
var css=`
#page-retencion{padding:20px 24px 40px;max-width:1400px;margin:0 auto}
.rt-tabs{display:flex;gap:4px;border-bottom:1px solid var(--border);margin-bottom:16px;overflow-x:auto}
.rt-tab{background:none;border:0;border-bottom:2px solid transparent;color:var(--text2);padding:9px 12px;font:inherit;font-size:13px;cursor:pointer;white-space:nowrap}
.rt-tab.on{color:var(--text);border-bottom-color:var(--accent)}.rt-tab:hover{color:var(--text)}
.rt-badge{font-size:11px;color:var(--text3);margin-left:4px}.rt-badge.hot{background:var(--red);color:#fff;border-radius:99px;padding:0 6px}
.rt-head{display:flex;justify-content:space-between;align-items:flex-end;gap:12px;flex-wrap:wrap;margin:6px 0 14px}
.rt-head h2{font-size:20px;font-weight:600;letter-spacing:-.01em}.rt-head p{color:var(--text2);font-size:12.5px;margin-top:4px}
.rt-card{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:16px;margin-bottom:14px;min-width:0}
.rt-card-t{display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap;font-weight:600;font-size:13.5px;margin-bottom:12px}
.rt-card h3{font-size:15px;font-weight:600;margin-bottom:6px}.rt-card h4,.rt-wrap h4{font-size:13px;font-weight:600;margin:16px 0 8px}
.rt-flex{display:flex;gap:6px;flex-wrap:wrap;align-items:center}
.rt-kpis{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:10px;margin-bottom:14px}
.rt-kpi{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:12px 14px}.rt-kpi .l{font-size:11.5px;color:var(--text2)}.rt-kpi .v{font-size:22px;font-weight:700;margin:4px 0}.rt-kpi .s{font-size:11.5px;color:var(--text3)}
.rt-kpi .v.red{color:var(--red)}.rt-kpi .v.green{color:var(--green)}.rt-kpi .v.amber{color:var(--amber)}
.rt-tbl{overflow-x:auto}.rt-tbl table{width:100%;border-collapse:collapse}.rt-tbl th{text-align:left;font-weight:400;font-size:11.5px;color:var(--text2);padding:7px 8px;border-bottom:1px solid var(--border);white-space:nowrap}
.rt-tbl td{padding:9px 8px;border-bottom:1px solid var(--border);vertical-align:middle;font-size:12.5px}.rt-click{cursor:pointer}.rt-click:hover{background:var(--surface2)}
.rt-name{font-weight:500}.rt-sub{font-size:11.5px;color:var(--text3);font-weight:400}.rt-mono{font-family:ui-monospace,Menlo,monospace;font-size:12px;color:var(--text2)}.rt-small{font-size:12px;color:var(--text2);line-height:1.5}
.rt-tag{display:inline-block;font-size:11px;padding:2px 8px;border-radius:99px;background:var(--surface2);color:var(--text2);border:1px solid var(--border2);white-space:nowrap;margin:1px 0}
.rt-tag.ok{background:var(--green-bg);color:var(--green);border-color:transparent}.rt-tag.bad{background:var(--red-bg);color:var(--red);border-color:transparent}.rt-tag.warn{background:var(--amber-bg);color:var(--amber);border-color:transparent}.rt-tag.info{background:var(--blue-bg);color:var(--blue);border-color:transparent}
.rt-btn{background:var(--accent);color:var(--on-accent,#0a0a0a);border:0;border-radius:6px;padding:7px 12px;font:inherit;font-size:12.5px;font-weight:600;cursor:pointer;white-space:nowrap}.rt-btn:disabled{opacity:.4;cursor:not-allowed}
.rt-btn.line{background:transparent;color:var(--text);border:1px solid var(--border2);font-weight:500}.rt-btn.ghost{background:transparent;color:var(--text2);font-weight:500}.rt-btn.ghost:hover{color:var(--text)}
.rt-toggle{display:inline-flex;border:1px solid var(--border2);border-radius:6px;overflow:hidden}.rt-toggle button{background:none;border:0;color:var(--text2);padding:4px 10px;font:inherit;font-size:12px;cursor:pointer}.rt-toggle button+button{border-left:1px solid var(--border2)}.rt-toggle button.on{background:var(--accent);color:var(--on-accent,#0a0a0a)}
.rt-search{background:var(--surface2);border:1px solid var(--border);border-radius:6px;color:var(--text);padding:5px 10px;font:inherit;font-size:12.5px;min-width:240px}
.rt-dots{display:inline-flex;gap:3px;margin-left:6px;vertical-align:middle}.rt-dots i{width:7px;height:7px;border-radius:50%;background:var(--border2)}.rt-dots i.ok{background:var(--green)}
.rt-note{background:var(--amber-bg);color:var(--amber);padding:9px 12px;border-radius:6px;font-size:12.5px;margin:8px 0;line-height:1.45}.rt-note.bad{background:var(--red-bg);color:var(--red)}.rt-note.ok{background:var(--green-bg);color:var(--green)}.rt-note.info{background:var(--blue-bg);color:var(--text)}
.rt-form{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px}.rt-form label,.rt-card label{display:block;font-size:11.5px;color:var(--text2);margin-bottom:4px}
#page-retencion input,#page-retencion select,#page-retencion textarea{width:100%;background:var(--surface2);border:1px solid var(--border);border-radius:6px;color:var(--text);padding:7px 10px;font:inherit;font-size:13px}
#page-retencion textarea{min-height:80px;resize:vertical}#page-retencion input:disabled,#page-retencion select:disabled,#page-retencion textarea:disabled{opacity:.6}
.rt-row{display:flex;justify-content:space-between;gap:8px;margin-top:14px;flex-wrap:wrap}
.rt-alist{list-style:none;display:flex;flex-direction:column;gap:6px}.rt-alist li{display:flex;gap:10px;align-items:center;padding:9px 10px;border:1px solid var(--border);border-radius:8px}.rt-alist .t{flex:1;min-width:0}.rt-alist b{display:block;font-size:13px}.rt-alist span{font-size:12px;color:var(--text2)}
.rt-ic{width:18px;height:18px;flex:none;border-radius:50%;display:inline-grid;place-items:center;font-size:10px;font-weight:700;background:var(--amber-bg);color:var(--amber)}.rt-ic.ok{background:var(--green-bg);color:var(--green)}.rt-ic.bad{background:var(--red-bg);color:var(--red)}.rt-ic.soft{background:var(--surface2);color:var(--text3)}
.rt-steps{display:flex;gap:6px;overflow-x:auto;padding:4px 0 12px}.rt-steps button{display:flex;align-items:center;gap:7px;background:var(--surface);border:1px solid var(--border);color:var(--text2);border-radius:99px;padding:4px 12px 4px 4px;font:inherit;font-size:12.5px;cursor:pointer;white-space:nowrap}
.rt-steps .sn{width:22px;height:22px;border-radius:50%;display:grid;place-items:center;background:var(--surface2);font-size:11px;font-weight:600}.rt-steps button.ok .sn{background:var(--green-bg);color:var(--green)}.rt-steps button.on{border-color:var(--accent);color:var(--text)}.rt-steps button.on .sn{background:var(--accent);color:var(--on-accent,#0a0a0a)}
.rt-casegrid{display:grid;grid-template-columns:minmax(0,1fr) 300px;gap:14px;align-items:start}.rt-col{display:flex;flex-direction:column}
.rt-grid2{display:grid;grid-template-columns:1fr 1fr;gap:14px}
.rt-when{font-size:12px;color:var(--accent);font-weight:600;margin-bottom:10px}.rt-hint{color:var(--text2);font-size:12.5px;line-height:1.5;margin:6px 0 10px}
.rt-lect{background:var(--blue-bg);border-left:3px solid var(--blue);padding:10px 12px;border-radius:0 6px 6px 0;font-size:12.5px;line-height:1.5;margin:8px 0}
.rt-chips{display:flex;flex-wrap:wrap;gap:6px;margin:6px 0}.rt-chip{background:var(--surface2);border:1px solid var(--border2);color:var(--text2);border-radius:99px;padding:5px 12px;font:inherit;font-size:12.5px;cursor:pointer}.rt-chip.on{background:var(--accent-bg);border-color:var(--accent);color:var(--accent)}.rt-chip:disabled{opacity:.45;cursor:not-allowed}
.rt-say{border:1px solid var(--border);border-radius:8px;margin:8px 0;background:var(--surface2)}.rt-say .st{display:flex;justify-content:space-between;align-items:center;padding:4px 6px 4px 10px;border-bottom:1px solid var(--border);font-size:11px;color:var(--text2);text-transform:uppercase;letter-spacing:.05em}.rt-say p{padding:10px 12px;white-space:pre-wrap;line-height:1.55;font-size:13px}
.rt-blank{background:var(--amber-bg);color:var(--amber);border-radius:3px;padding:0 3px}
.rt-qs{padding-left:18px;display:flex;flex-direction:column;gap:8px}.rt-qs b{display:block;font-weight:500;font-size:13px}.rt-qs span{color:var(--text3);font-size:12px}.rt-tips{padding-left:16px;color:var(--text2);font-size:12.5px;line-height:1.65}
.rt-acc{border:1px solid var(--border);border-radius:8px;margin:6px 0;overflow:hidden}.rt-acc.st-a{border-color:var(--green)}.rt-acc.st-r{opacity:.6}
.rt-acc .ah{width:100%;display:flex;justify-content:space-between;gap:8px;align-items:center;background:none;border:0;color:var(--text);font:inherit;font-size:13px;font-weight:500;padding:10px 12px;cursor:pointer;text-align:left;flex-wrap:wrap}.rt-acc .ah:hover{background:var(--surface2)}
.rt-acc .ab{padding:10px 12px;border-top:1px solid var(--border)}.rt-acc .ab ol{padding-left:18px;color:var(--text2);font-size:12.5px;line-height:1.6;margin:6px 0}
.rt-big{font-size:19px;font-weight:700;margin-bottom:8px}.rt-track{height:8px;background:var(--surface2);border-radius:99px;overflow:hidden;margin:8px 0}.rt-track i{display:block;height:100%;background:var(--accent)}.rt-track.over i{background:var(--red)}
.rt-lst{list-style:none;display:flex;flex-direction:column;gap:7px;font-size:12.5px}.rt-lst li{display:flex;gap:8px;align-items:flex-start}.rt-lst li.done span{color:var(--text3);text-decoration:line-through}
.rt-sum{background:var(--surface2);border:1px solid var(--border);border-radius:8px;padding:12px;font-family:ui-monospace,Menlo,monospace;font-size:11.5px;white-space:pre-wrap;line-height:1.55}
.rt-kv{display:grid;grid-template-columns:1fr auto;gap:6px 12px;font-size:12.5px}.rt-kv span:nth-child(odd){color:var(--text2)}.rt-kv span:nth-child(even){font-weight:600;text-align:right}
.rt-mot{border:1px solid var(--border);border-radius:8px;background:var(--surface);margin-bottom:8px}.rt-mot summary{padding:11px 14px;cursor:pointer;font-weight:600}.rt-mot .in{padding:0 14px 14px}
#rt-toasts{position:fixed;bottom:20px;right:20px;z-index:2000;display:flex;flex-direction:column;gap:8px}.rt-toast{background:var(--surface);border:1px solid var(--border2);border-left:3px solid var(--green);border-radius:8px;padding:10px 14px;font-size:13px;max-width:380px;box-shadow:0 6px 20px rgba(0,0,0,.4)}.rt-toast.bad{border-left-color:var(--red)}
@media(max-width:1000px){.rt-casegrid,.rt-grid2{grid-template-columns:1fr}.rt-kpis{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:600px){#page-retencion{padding:14px 12px 32px}.rt-search{min-width:0;width:100%}}
`;
var st=document.createElement('style');st.textContent=css;document.head.appendChild(st);
function cont(){return document.getElementById('page-retencion');}
RT.render=function(){var c=cont();if(!c)return;
  if(!RT.cargado){c.innerHTML='<p class="rt-small">Cargando retención…</p>';return;}
  if(RT.errorCarga){c.innerHTML='<div class="rt-note bad">No se pudo cargar retención: '+f.e(RT.errorCarga)+'</div>';return;}
  var v=RT.v.sub,b=v==='caso'?RT.vCaso():v==='casos'?RT.vCasos():v==='alertas'?RT.vAlertas():v==='arbol'?RT.vArbol():v==='reglas'?RT.vReglas():v==='registrar'?RT.vRegistrar():RT.vBandeja();
  c.innerHTML=RT.tabs()+'<div class="rt-wrap">'+b+'</div>';};
RT.abrir=function(folio){RT.v.sub='caso';RT.v.cur=folio;RT.v.open='';var d=RT.casos[folio];RT.v.paso=d?f.pasoActual(d):1;RT.render();window.scrollTo(0,0);};
RT.mostrar=async function(){var c=cont();if(!c)return;if(!RT.cargado)RT.render();await RT.cargar();
  var m=/[?&]retencion=([^&]+)/.exec(location.search);if(m&&RT.casos[decodeURIComponent(m[1])]){RT.abrir(decodeURIComponent(m[1]));return;}RT.render();};
function cur(){return RT.v.cur&&RT.casos[RT.v.cur];}
async function guardar(campos){var d=cur();if(!d)return;if(await RT.guardar(d.folio,campos))RT.render();}
document.addEventListener('click',async function(ev){var c=cont();if(!c||!c.contains(ev.target))return;var b=ev.target.closest('[data-rt]');if(!b||b.disabled)return;
  var a=b.dataset.rt,id=b.dataset.id,d=cur(),now=new Date().toISOString();
  if(a==='sub'){RT.v.sub=id;RT.v.cur=null;RT.render();return;}
  if(a==='marca'){RT.v.marca=id;RT.render();return;}if(a==='tab'){RT.v.tab=id;RT.render();return;}
  if(a==='abrir'){RT.abrir(id);return;}if(a==='tomar'){b.disabled=true;await RT.tomar(id);return;}
  if(a==='registrarForm'){RT.v.sub='registrar';RT.render();return;}
  if(a==='registrar'){var g=function(x){return document.getElementById('rt-r-'+x).value.trim()};b.disabled=true;
    var ok=await RT.registrar({p_servicio:g('serv'),p_canal:g('canal'),p_nombre:g('nom'),p_empresa:g('emp'),p_telefono:g('tel'),p_mensaje:g('msg')});if(!ok)b.disabled=false;return;}
  if(a==='hecho'){var x={};x[b.dataset.v]=true;await RT.guardar(id,x);RT.toast('Marcado como hecho');RT.render();return;}
  if(a==='copiarTxt'){var p=b.closest('.rt-say').querySelector('p').innerText;try{await navigator.clipboard.writeText(p);RT.toast('Copiado');}catch(e){prompt('Copia el texto:',p);}return;}
  if(a==='guardarPD'){var cfg=RT.cfg.Aromatex,n=0;for(var i=0;i<RT.CAMPOS.length;i++){var k=RT.CAMPOS[i],el=document.getElementById('rt-pd-'+k[0]);if(!el)continue;
      if(k[2]==='numero'&&el.value===''&&k[0]!=='valorPestex'){RT.toast('Escribe un valor para «'+k[1]+'».',true);break;}
      var nv=k[2]==='numero'?(el.value===''?0:Number(el.value)):el.value.trim(),av=RT.pdVal(cfg,k[0]);if(String(nv)===String(av==null?'':av))continue;
      if(!(await RT.editarRegla('Aromatex',k[0],nv)))break;n++;}
    await RT.cargar();RT.toast(n?n+' campo'+(n>1?'s':'')+' actualizado'+(n>1?'s':''):'Sin cambios');RT.render();return;}
  if(!d)return;
  if(a==='ir'){RT.v.paso=+id;RT.v.open='';RT.render();window.scrollTo(0,0);return;}
  if(a==='open'){RT.v.open=RT.v.open===id?'':id;RT.render();return;}
  if(a==='motivo'){await guardar({motivo_inicial:d.motivo_inicial===id?null:id});return;}
  if(a==='manual'){await guardar({primer_contacto_at:now,primer_contacto_via:'manual'});return;}
  if(a==='enviarWA'){await RT.enviarPrimerContacto(d.folio);return;}
  if(a==='llamada'){var ch={llamada_at:d.llamada_at?null:now};if(!d.llamada_at&&d.causa_raiz==='sincontacto'){ch.causa_raiz=null;ch.situacion=null;}await guardar(ch);return;}
  if(a==='int'){var nI=d.intentos===+id?+id-1:+id,ci={intentos:nI};if(nI<3&&d.causa_raiz==='sincontacto'){ci.causa_raiz=null;ci.situacion=null;}await guardar(ci);return;}
  if(a==='raiz'){RT.v.open='';await guardar({causa_raiz:d.causa_raiz===id?null:id,situacion:null});return;}
  if(a==='sit'){RT.v.open='';await guardar({situacion:d.situacion===id?null:id});return;}
  if(a==='est'){var pp=id.split('|');await RT.accion(d.folio,pp[0],pp[1]);RT.render();return;}
  if(a==='c5'){await guardar({propuesta_enviada_at:d.propuesta_enviada_at?null:now});return;}
  if(a==='res'){await guardar({resultado:d.resultado===id?null:id});return;}
  if(a==='autorizar'){await RT.autorizar(d.folio);return;}
  if(a==='copy'){await RT.copiarResumen(d.folio);return;}
  if(a==='cerrar'){b.disabled=true;await RT.cerrar(d.folio);return;}
  if(a==='reabrir'){if(confirm('¿Reabrir el caso? El ticket vuelve a «En proceso».'))await RT.reabrir(d.folio);return;}
});
document.addEventListener('change',async function(ev){var c=cont();if(!c||!c.contains(ev.target))return;var el=ev.target,k=el.dataset&&el.dataset.rtk,d=cur();if(!k||!d)return;
  var v=el.value.trim(),x={};if(el.type==='number')x[k]=v===''?null:Number(v);else x[k]=v===''?null:v;
  if(k==='fecha_seguimiento')x.seguimiento_hecho=false;if(k==='fecha_reactivacion')x.reactivacion_hecha=false;await guardar(x);});
document.addEventListener('input',function(ev){if(ev.target.id!=='rt-q')return;RT.v.q=ev.target.value;var p=ev.target.selectionStart;RT.render();var n=document.getElementById('rt-q');if(n){n.focus();n.setSelectionRange(p,p);}});
})();
/* Retención · panel lateral de Casos y Cancelaciones: una sola forma de gestionar */
(function(){
'use strict';
var RT=window.RT,f=RT.f,e=f.e;
RT.panelCancelacion=async function(r){
  var folio=r.folio_ticket||r.folio,abierto=!/cerrad|resuelt|cancelad/i.test(String(r.status||r.estatus||''));
  if(!folio||r._source!=='whatsapp')return;
  if(!RT.cargado)await RT.cargar();
  var marca=String(r.tipo_de_servicio||r.servicio||'');marca=/aromatex/i.test(marca)?'Aromatex':/pestex/i.test(marca)?'Pestex':/origen|caf/i.test(marca)?'Origen Selecto':marca;
  var cfg=RT.cfg[marca],d=RT.casos[folio];
  if(!cfg||!cfg.activo||!cfg.arbol)return;            // marca sin árbol: se gestiona como hoy
  if(!d&&!abierto)return;                              // histórico cerrado sin caso: se consulta como antes
  var body=document.getElementById('tk-modal-body');if(!body||body.dataset.rtFolio===folio&&body.querySelector('.rt-panel'))return;
  body.dataset.rtFolio=folio;
  ['cancel-stage','reg-zona-sel','reg-stcanc-sel','cancel-motivo'].forEach(function(id){var el=document.getElementById(id);var it=el&&el.closest('.detail-item');if(it)it.style.display='none';else if(el)el.style.display='none';});
  var cc=document.getElementById('cancel-close-confirm');if(cc)cc.remove();
  var help=body.querySelector('.cancel-help');if(help)help.textContent='La gestión de esta cancelación vive en Retención. Aquí solo quedan los comentarios de seguimiento y el escalamiento.';
  body.querySelectorAll('details.cancel-section').forEach(function(x){var t=(x.querySelector('summary')||{}).textContent||'';if(/Retención · diagnóstico|Facturación y primer mes/.test(t))x.style.display='none';});
  var h='<section class="cancel-section rt-panel"><h3>Retención</h3>';
  if(d){var p=f.plazo(d),pa=f.pasoActual(d);
    h+='<p style="margin:6px 0"><span class="rt-tag '+p.c+'">'+e(p.t)+'</span> <span class="rt-tag">'+(d.estado==='cerrado'?'Cerrado · '+e(f.RESN(d,d.resultado)):'Paso '+pa+' de 6')+'</span> <span class="rt-tag">Atiende: '+e(f.nombreDe(d.atiende))+'</span></p>'+
      '<button class="btn-save-comment" data-rt-panel="abrir">Abrir en Retención</button>';}
  else h+='<p class="cancel-help" style="margin:6px 0">Nadie ha tomado esta cancelación. Se gestiona con el árbol de retención.</p>'+
      (RT.puedeTomar?'<button class="btn-save-comment" data-rt-panel="tomar">Tomar y abrir en Retención</button>':'<p class="cancel-help">Tu usuario no puede tomar solicitudes.</p>');
  h+='</section>';
  var sum=body.querySelector('.cancel-section');if(sum)sum.insertAdjacentHTML('afterend',h);else body.insertAdjacentHTML('afterbegin',h);
  body.querySelector('[data-rt-panel]')&&body.querySelector('[data-rt-panel]').addEventListener('click',async function(ev){
    var b=ev.currentTarget;b.disabled=true;
    if(b.dataset.rtPanel==='tomar'){var c=await (await sb.rpc('cx_retencion_tomar',{p_folio:folio}));if(c.error){RT.toast(c.error.message,true);b.disabled=false;return;}await RT.cargar();}
    tkCloseModal();goPage('retencion');RT.abrir(folio);});
};
})();
