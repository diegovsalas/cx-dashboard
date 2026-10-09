const {chromium}=require('playwright');const fs=require('fs');const assert=require('assert/strict');
const path=require('node:path');const root=path.resolve(__dirname,'..');
const artifacts=process.env.CX_UI_ARTIFACTS||'/tmp/cx-ui-audit';fs.mkdirSync(artifacts,{recursive:true});
const mock=`
window.__failTickets=false;window.__queries=[];
const today=new Date().toISOString().slice(0,7);
const tickets=[
{id:1,folio:'C001',nombre:'Cliente simulado',empresa:'Sucursal norte',tipo:'Incidencia',estatus:'Escalado',prioridad:'Alta',created_at:today+'-01T06:00:00Z',servicio:'Pestex',canal_origen:'cx',telefono:'528100000001'},
{id:2,folio:'C002',nombre:'Cliente simulado 2',tipo:'Cancelación',estatus:'Nuevo',status_cancelacion:'Retenida',created_at:today+'-02T06:00:00Z',resolved_at:today+'-02T06:10:00Z',servicio:'Aromatex',canal_origen:'cx',csat:5},
{id:3,folio:'C003',nombre:'Cliente simulado 3',tipo:'Cancelación',estatus:'En proceso',created_at:today+'-03T06:00:00Z',servicio:'Pestex',canal_origen:'cx'},
{id:4,folio:'C004',nombre:'Cliente simulado 4',tipo:'Consulta',estatus:'Resuelto',created_at:today+'-04T06:00:00Z',resolved_at:today+'-04T07:00:00Z',servicio:'Pestex',canal_origen:'cx',csat:1},
{id:5,folio:'C005',nombre:'Cliente simulado 5',tipo:'Incidencia',estatus:'Nuevo',agente:'Ana',created_at:today+'-05T06:00:00Z',servicio:'Pestex',canal_origen:'aromatex'}];
const history=[0,7,9,10].map((respuesta_score,i)=>({id:i,template_name:'nps_avantex',estado:['enviado','entregado','leido','respondido'][i],respuesta_score,created_at:today+'-01T00:00:00Z',telefono:'528100000000',nombre_cliente:'Simulado'}));
class Query{constructor(table){this.table=table;this.filters=[];this.start=0;this.end=999;}select(){return this}order(){return this}range(a,b){this.start=a;this.end=b;return this}eq(k,v){this.filters.push([k,v]);return this}or(){return this}gte(){return this}lt(){return this}limit(){return this}maybeSingle(){this._single=true;return this}single(){this._single=true;return this}then(ok,bad){window.__queries.push(this.table);if(this.table==='tickets'&&window.__failTickets)return Promise.resolve({data:null,error:{message:'401 simulado'}}).then(ok,bad);let data=this.table==='tickets'?tickets:this.table==='envios_plantillas'?history:[];for(const [k,v]of this.filters)data=data.filter(r=>r[k]===v);const result={data:this._single?data[0]:data.slice(this.start,this.end+1),error:null};return new Promise(resolve=>setTimeout(()=>resolve(result),window.__slowNps&&this.table==='envios_plantillas'&&this.filters.some(([k,v])=>k==='template_name'&&v==='nps_avantex')?150:0)).then(ok,bad);}}
window.supabase={createClient:()=>({from:t=>new Query(t),schema:()=>({from:t=>new Query(t)}),auth:{getSession:async()=>({data:{session:{user:{email:'diegovelazquez@grupoavantex.com'},access_token:'simulated-session'}}}),signOut:async()=>({})}})};
`;
(async()=>{const chartScript=process.env.CX_CHART_JS?fs.readFileSync(process.env.CX_CHART_JS,'utf8'):await(await fetch('https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js')).text();const browser=await chromium.launch({headless:true});const page=await browser.newPage({viewport:{width:1440,height:1100}});const errors=[];page.on('pageerror',e=>{errors.push(e.message);console.error('UIERROR',e.message)});page.on('dialog',d=>d.dismiss());
await page.route('**/*',async route=>{let url=route.request().url();if(url==='http://localhost:8000/')return route.fulfill({contentType:'text/html',body:fs.readFileSync(root+'/index.html','utf8')});if(url.includes('chart.umd'))return route.fulfill({contentType:'application/javascript',body:chartScript});if(url.includes('supabase-js'))return route.fulfill({contentType:'application/javascript',body:mock});return route.fulfill({status:204,body:''});});
await page.goto('http://localhost:8000/');page.setDefaultTimeout(10000);await page.waitForFunction(()=>document.querySelector('#cx-load-status').textContent.startsWith('Actualizado'));
assert.equal(await page.locator('#page-dashboard').isVisible(),true);
assert.deepEqual(await page.locator('#kpis .val').allTextContents(),['5','3','1','1','2']);
await page.locator('#kpis button').nth(1).click();assert.match(await page.locator('#cx-cases .tbl-header').innerText(),/Pendientes · 3 casos/);assert.equal(await page.locator('#cx-cases th').count(),6);
await page.evaluate(()=>chartInstances.c1.options.onClick({},[{index:0}]));assert.match(await page.locator('#cx-cases .tbl-header').innerText(),/Incidencia · 2 casos/);await page.locator('#kpis button').nth(1).click();
await page.locator('#cx-cases tbody tr').first().click();assert.equal(await page.locator('#tk-modal').isVisible(),true);await page.evaluate(()=>tkCloseModal());
await page.evaluate(()=>{document.getElementById('an-f-servicio').insertAdjacentHTML('beforeend','<option value="Pestex">Pestex</option>');document.getElementById('an-f-servicio').value='Pestex';clearF();});assert.equal(await page.locator('#an-f-servicio').inputValue(),'Pestex');
await page.evaluate(()=>{goPage('campanias')});await page.waitForFunction(()=>document.querySelector('#cmp-kpis').textContent.includes('25'));assert.match(await page.locator('#cmp-kpis').innerText(),/Entrega confirmada\s*2/i);assert.match(await page.locator('#cmp-kpis').innerText(),/NPS 0–10\s*25/);
await page.evaluate(()=>{window.__slowNps=true;cmpCargarHistorial();document.getElementById('cmp-hist-template').value='ventas_satisfaccion_nuevos';cmpCargarHistorial();});await page.waitForTimeout(250);assert.match(await page.locator('#cmp-kpis').innerText(),/Satisfacción ventas/i);assert.doesNotMatch(await page.locator('#cmp-kpis').innerText(),/NPS 0–10/);
await page.evaluate(()=>{goPage('cancelaciones')});assert.match(await page.locator('#canc-metas').innerText(),/100%/);
await page.evaluate(()=>{goPage('tickets')});assert.equal(await page.locator('#tk-tbody').locator('tr').count(),5);
await page.evaluate(async()=>{goPage('dashboard');window.__failTickets=true;await loadData();_refreshVista();});assert.match(await page.locator('#cx-load-status').innerText(),/Se conservan/);assert.equal(await page.evaluate(()=>allData.length),5);
await page.screenshot({path:path.join(artifacts,'desktop.png'),fullPage:true});
await page.setViewportSize({width:390,height:844});await page.screenshot({path:path.join(artifacts,'mobile.png'),fullPage:true});
assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth+1),true);
assert.deepEqual(errors,[]);console.log('UI verificada: tarjetas, detalle, filtros aislados, campañas, cancelaciones, seis columnas, error conservando datos y móvil.');await browser.close();})().catch(e=>{console.error(e);process.exit(1)});
