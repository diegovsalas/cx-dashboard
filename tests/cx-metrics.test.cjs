const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const html=fs.readFileSync(require('node:path').join(__dirname,'../index.html'),'utf8');
const code=html.split('// CX_METRICS_START')[1].split('// CX_METRICS_END')[0];
const context={};vm.createContext(context);vm.runInContext(code.slice(code.indexOf('\n')),context);
const M=context.CXMetrics;
const same=(actual,expected)=>assert.deepEqual(JSON.parse(JSON.stringify(actual)),expected);
const row=(status,extra={})=>({status,tipo_de_solicitud:'Incidencia / Queja',_source:'whatsapp',...extra});
test('mediana par y sin registros',()=>{assert.equal(M.median([0,1,2,100]),1.5);assert.equal(M.median([]),null);});
test('resolución conserva minutos; nunca confunde falta de fecha con cero',()=>{assert.equal(M.days({_tk:{created_at:'2026-10-01T00:00:00Z',resolved_at:'2026-10-01T00:10:00Z'}}),10/1440);assert.equal(M.days({_tk:{created_at:'2026-10-01'}}),null);assert.equal(M.days({tiempo_de_respuesta:''}),null);});
test('CSAT solo usa enteros 1–5 válidos',()=>{same(M.csat([null,'',true,false,0,1,5,6,1.5].map(_csat=>({_csat}))),{total:2,average:3,satisfied:1});});
test('NPS incluye cero y pasivos; no mezcla ventas con NPS',()=>{const rows=[0,7,9,10].map(respuesta_score=>({template_name:'nps_avantex',respuesta_score}));rows.push({template_name:'ventas_satisfaccion_nuevos',respuesta_score:1});same(M.nps(rows),{total:4,promoters:2,detractors:1,value:25});assert.equal(M.nps([]).value,null);});
test('octubre de distintos años mantiene cohortes distintas',()=>same(M.months([{fecha_de_la_solicitud:'2025-10-01'},{fecha_de_la_solicitud:'2026-10-01'}]),[['2025-10',1],['2026-10',1]]));
test('escalados y cancelaciones con tareas pendientes conservan gestión abierta',()=>{assert.equal(M.isPending(row('Escalado')),true);const terminal=row('En proceso',{tipo_de_solicitud:'Solicitud de Cancelación',status_cancelacion:'Retenida'});assert.equal(M.isPending(terminal),true);assert.equal(M.group([terminal],'closed').length,0);});
test('tarjetas y detalle usan idénticos grupos, incluido sin responsable',()=>{const rows=[row('Escalado'),row('Nuevo',{ejecutivo_asignado:'Ana'}),row('Resuelto')];assert.equal(M.group(rows,'pending').length,2);assert.equal(M.group(rows,'unassigned').length,1);assert.equal(M.group(rows,'closed').length,1);});
test('consulta conserva su clasificación',()=>{assert.equal(M.category('Consulta'),'Consulta');assert.equal(M.category('Cancelación'),'Solicitud de Cancelación');});
test('retención solo divide resultados terminales',()=>{const rows=['Retenida','Cancelada','En proceso'].map(status_cancelacion=>row(status_cancelacion==='En proceso'?'En proceso':'Cerrado',{tipo_de_solicitud:'Solicitud de Cancelación',status_cancelacion}));same(M.retention(rows),{kept:1,lost:1,open:1,rate:50});assert.equal(M.retention([rows[2]]).rate,null);});
test('histórico y bot se filtran sin deduplicar coincidencias ambiguas',()=>{const rows=[row('Nuevo',{_tk:{id:1}}),row('Nuevo',{_tk:{id:1}}),row('Nuevo',{_source:'base_general',id:1})];assert.equal(M.dedup(rows).length,2);assert.equal(M.matches(rows[0],{origen:'base_general'}),false);assert.equal(M.matches(rows[2],{origen:'base_general'}),true);});
test('frontend no publica secreto administrativo',()=>{assert.equal(/BOT_TOKEN|admin_token\s*:/.test(html),false);assert.match(html,/headers:await botAuthHeaders\(\)/);});

test('cierre exige resultado y confirmación; se guardan ambos campos juntos',()=>{assert.throws(()=>M.cancelWorkflow('Cerrado','',true),/resultado/);assert.throws(()=>M.cancelWorkflow('Cerrado','Cancelada',false),/pendientes/);same(M.cancelWorkflow('Cerrado','Retenida',true),{status:'Cerrado',status_cancelacion:'Retenida'});same(M.cancelWorkflow('En proceso','',false),{status:'En proceso',status_cancelacion:null});});
test('esperar respuesta mantiene la gestión pendiente',()=>assert.equal(M.isPending(row('Esperando respuesta')),true));

test('negociación es etapa y no un resultado final',()=>assert.throws(()=>M.cancelWorkflow('Cerrado','Negociacion',true),/resultado válido/));

test('cola de calidad distingue resultado, fecha y causa faltantes',()=>{
 const r=row('Cerrado',{tipo_de_solicitud:'Solicitud de Cancelación',_tk:{estatus:'Cerrado',status_cancelacion:null,categoria:'Cancelación de servicio'}});
 same(M.qualityIssues(r),['Cierre sin resultado definitivo','Falta causa específica']);
 r._tk.status_cancelacion='Cancelada';same(M.qualityIssues(r),['Falta fecha efectiva de baja','Falta causa específica']);
 r._tk.fecha_efectiva_cancelacion='2026-10-15';r._tk.causa_raiz_cancelacion='Cierre de sucursal';same(M.qualityIssues(r),[]);
 assert.throws(()=>M.validateCancelDate('Cerrado','Cancelada',''),/fecha efectiva/);
 M.validateCancelDate('Cerrado','Retenida','');M.validateCancelDate('En proceso','Cancelada','');
});

test('H2: fecha rellenada o faltante no entra a la mediana; la recuperada sí',()=>{
 M.setResolutionQuality([
  {fuente:'tickets',registro:'A1',estado:'sintetica',fecha_original:'2026-04-02T10:00:00+00:00'},
  {fuente:'tickets',registro:'A2',estado:'recuperada',fecha_original:null,fecha_recuperada:'2026-06-01T12:00:00+00:00'},
  {fuente:'base_general',registro:'7',estado:'sin_fecha',fecha_original:null}]);
 const tk=(folio,resolved_at)=>row('Cerrado',{_tk:{folio,created_at:'2026-04-01T10:00:00Z',resolved_at}});
 assert.equal(M.days(tk('A1','2026-04-02T10:00:00Z')),null);
 assert.equal(M.days(tk('A2',null)),61.083333333333336);
 assert.equal(M.days({status:'Resuelta',_source:'base_general',id:7,fecha_de_la_solicitud:'2025-06-01',tiempo_de_respuesta:'12'}),null);
 assert.equal(M.days(tk('A3','2026-04-01T22:00:00Z')),0.5);
 same(M.resolutionStats([tk('A1','2026-04-02T10:00:00Z'),tk('A2',null),tk('A3','2026-04-01T22:00:00Z'),tk('A4',null),row('Nuevo')]),{median:30.791666666666668,n:2,closed:4,excluded:2,motivos:{sin_fecha:0,sintetica:1,inconsistente:0,otro:1},coverage:0.5,measurable:false,minCoverage:0.8});
});
test('H2: un cierre nuevo deja sin efecto la marca anterior',()=>{
 M.setResolutionQuality([{fuente:'tickets',registro:'A1',estado:'sin_fecha',fecha_original:null}]);
 assert.equal(M.days(row('Cerrado',{_tk:{folio:'A1',created_at:'2026-11-01T00:00:00Z',resolved_at:'2026-11-02T00:00:00Z'}})),1);
 M.setResolutionQuality([]);
});

test('KPI tiempo de cierre: medible solo con 80% de cobertura; serie por mes',()=>{
 M.setResolutionQuality([]);
 const tk=(m,i,res)=>row('Cerrado',{fecha_de_la_solicitud:`2026-${m}-01`,_tk:{folio:m+i,created_at:`2026-${m}-01T00:00:00Z`,resolved_at:res?`2026-${m}-0${res}T00:00:00Z`:null}});
 const sep=[1,2,3,4,5].map(i=>tk('09',i,2)), jul=[tk('07',1,3),...[2,3,4,5].map(i=>tk('07',i,null))];
 const s1=M.resolutionStats(sep);assert.equal(s1.measurable,true);assert.equal(s1.median,1);assert.equal(s1.coverage,1);
 const s2=M.resolutionStats(jul);assert.equal(s2.measurable,false);assert.equal(s2.coverage,0.2);
 same(M.resolutionByMonth([...jul,...sep]).map(m=>[m.month,m.measurable,m.coverage]),[['2026-07',false,0.2],['2026-09',true,1]]);
 assert.equal(M.group([...jul,...sep],'res_missing').length,4);assert.equal(M.group([...jul,...sep],'res_ok').length,6);
 assert.equal(M.fmtDays(0.5),'12.0 h');assert.equal(M.fmtDays(6.04),'6.0 d');
});

test('H4: cada cancelación cae en un solo grupo y los grupos suman el total',()=>{
 const c=(status,status_cancelacion)=>row(status,{tipo_de_solicitud:'Solicitud de Cancelación',status_cancelacion});
 const rows=[c('Cerrado','Cancelada'),c('Resuelta','Retenida'),c('Cerrado','Downgrade'),c('Cerrado','Migración'),c('Sin atender','Cancelada'),c('En proceso',''),c('Cerrado','Negociacion'),c('Cerrado',''),row('Nuevo')];
 same(rows.map(M.cancelBucket),['cancelada','retenida','downgrade','migracion','abierta_con_resultado','en_gestion','cerrada_sin_resultado','cerrada_sin_resultado',null]);
 const s=M.cancelSummary(rows);
 assert.equal(s.total,8);
 assert.equal(s.cancelada+s.retenidas_total+s.abiertas+s.cerrada_sin_resultado,s.total);
 const r=M.retention(rows);assert.equal(r.lost,s.cancelada);assert.equal(r.kept,s.retenidas_total);assert.equal(r.open,s.abiertas+s.cerrada_sin_resultado);
});
