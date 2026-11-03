import {useEffect, useState, useRef, type FormEvent} from 'react';
import {httpsCallable} from 'firebase/functions';
import {functions} from './firebase';
import {costReasonLabel} from './resource_cost_labels';
import {resourceMoneyUsd as money} from './resource_cost_format';

type Summary = {dailyUsed:number; monthlyUsed:number; attachmentBytes:number; temporaryBytes:number; attachmentFiles:number;
  updatedAt:string|null; inventoryAt:string|null; capacityObservedAt?:string|null; policy:{dailyAnalyses:number;monthlyAnalyses:number;attachmentBytes:number};
  monthly:Record<string,number>|null; coverage:Record<string,string>; cost:{quality:string;amountUsd:number|null;knownSubtotalUsd?:number|null;coverage?:number|null;componentCoverage?:number|null;updatedAtIso?:string|null;pendingReasons?:Record<string,number>;byService?:Record<string,number>;tariffVersions?:string[]}};
type Row = {uid:string;summary:Summary};
type Response = {tariffs?:{state:string;nextExpiryIso:string|null;expired:string[];expiring:string[]};users?:Row[];uid?:string;summary?:Summary;nextCursor?:string|null;billing?:{available:boolean;issue?:string;updatedAtIso?:string|null;lastSuccessfulAtIso?:string|null;services?:Array<{day:string;service:string;currency:string;netCost:number;netCostUsd?:number|null;knownSubtotalUsd:number|null;unattributedDifferenceUsd:number|null}>}};
const mb=(n:number)=>new Intl.NumberFormat('es-CO',{maximumFractionDigits:1}).format(n/1000000)+' MB';

export function ResourceUsagePage() {
  const [rows,setRows]=useState<Row[]>([]),[cursor,setCursor]=useState<string|null>(null),[query,setQuery]=useState('');
  const [busy,setBusy]=useState(false),[error,setError]=useState(''),[billing,setBilling]=useState<Response['billing']|null>(null),[selected,setSelected]=useState<Row|null>(null);
  const dialog=useRef<HTMLDialogElement>(null);
  const [tariffs,setTariffs]=useState<Response['tariffs']>();
  const [services,setServices]=useState<NonNullable<Response['billing']>['services']>([]);
  useEffect(()=>{if(!selected)return;const previous=document.activeElement;dialog.current?.showModal();return()=>{dialog.current?.close();if(previous instanceof HTMLElement)previous.focus();};},[selected]);
  async function load(uid?:string,after?:string) {
    setBusy(true);setError('');
    try {
      const {data}=await httpsCallable<Record<string,string>,Response>(functions,'adminResourceUsage')({...uid?{uid}:{},...after?{cursor:after}:{}});
      setTariffs(data.tariffs);
      if(data.summary&&data.uid) {setSelected({uid:data.uid,summary:data.summary});}
      else {setRows(after?prev=>[...prev,...data.users??[]]:data.users??[]);setCursor(data.nextCursor??null);setBilling(data.billing??{available:false});setServices(data.billing?.available?data.billing.services??[]:[]);}
    } catch {setError('No se pudo consultar el consumo. Reintenta.');} finally {setBusy(false);}
  }
  useEffect(()=>{void load();},[]);
  const search=(e:FormEvent)=>{e.preventDefault();if(query.trim())void load(query.trim());};
  return <section className="resource-usage"><div className="page-heading"><div><p className="eyebrow">RECURSOS Y COSTES</p><h1>Consumo por usuario</h1>
    <p>Mes UTC actual. Los límites se comparten entre dispositivos y se conservan después de reiniciar datos.</p></div>
    <button className="secondary" onClick={()=>void load()} disabled={busy}>Actualizar</button></div>
    {tariffs&&tariffs.state!=='ready'&&<div className="error-banner" role="status">{tariffs.state==='unknown'?'No hay tarifas verificadas disponibles.':tariffs.state==='expired'?'Hay tarifas vencidas; los costes afectados siguen pendientes.':'Hay tarifas que vencen en los próximos 30 días.'} {tariffs.nextExpiryIso&&`Próximo vencimiento: ${tariffs.nextExpiryIso.slice(0,10)}`}</div>}
    {error&&<div className="error-banner" role="alert">{error}</div>}
    {billing?.available===false&&<div className="empty-state">{costReasonLabel(billing.issue??'billing-query-unavailable')}. Los costes conocidos son estimaciones; los datos ausentes no equivalen a cero.{billing.lastSuccessfulAtIso&&<p>Última consulta correcta: {billing.lastSuccessfulAtIso}</p>}</div>}
    <form onSubmit={search} className="search-form"><input aria-label="UID exacto" placeholder="UID exacto" value={query} onChange={e=>setQuery(e.target.value)}/><button disabled={busy} className="primary">Consultar</button></form>
    {busy&&<p aria-live="polite">Consultando…</p>}
    {!busy&&!rows.length&&<p>No hay consumo registrado.</p>}
    <div className="table-wrap"><table><thead><tr><th>Usuario</th><th>Análisis hoy / mes</th><th>Adjuntos</th><th>Temporales</th><th>Coste mensual</th><th>Cobertura</th></tr></thead><tbody>{rows.map(row=><tr key={row.uid}>
      <td><button className="text-button" onClick={()=>setSelected(row)}>{row.uid}</button></td>
      <td>{row.summary.dailyUsed}/{row.summary.policy.dailyAnalyses} · {row.summary.monthlyUsed}/{row.summary.policy.monthlyAnalyses}</td>
      <td>{mb(row.summary.attachmentBytes)} / {mb(row.summary.policy.attachmentBytes)} · {row.summary.attachmentFiles} archivos</td>
      <td>{mb(row.summary.temporaryBytes)}</td><td>{money(row.summary.cost.amountUsd)}{row.summary.cost.amountUsd==null&&<small className="muted"> · Subtotal conocido: {money(row.summary.cost.knownSubtotalUsd)}</small>}</td><td>{row.summary.cost.quality==='pending'?'Incompleta':'Estimado'}</td>
    </tr>)}</tbody></table></div>
    {cursor&&<button className="secondary" disabled={busy} onClick={()=>void load(undefined,cursor)}>Cargar más</button>}
    {!!services?.length&&<div className="panel"><h2>Conciliación por servicio</h2><p>Consultado: {billing?.updatedAtIso??'Pendiente'}. Los datos del proveedor pueden llegar con retraso.</p><p>Costes del proyecto LumioMoney. La conversión a USD usa exclusivamente las tasas del export de Google. Las diferencias incluyen infraestructura compartida y mediciones incompletas; no se reparten entre usuarios.</p><div className="table-wrap"><table><thead><tr><th>Día</th><th>Servicio</th><th>Proveedor</th><th>Proveedor (USD)</th><th>Subtotal de usuarios (USD)</th><th>Diferencia sin atribuir (USD)</th></tr></thead><tbody>{services.map(s=><tr key={`${s.day}:${s.service}:${s.currency}`}><td>{s.day}</td><td>{s.service}</td><td>{s.netCost.toFixed(6)} {s.currency}</td><td>{money(s.netCostUsd)}</td><td>{money(s.knownSubtotalUsd)}</td><td>{money(s.unattributedDifferenceUsd)}</td></tr>)}</tbody></table></div></div>}
    {selected&&<dialog ref={dialog} className="resource-detail" onCancel={()=>setSelected(null)} aria-label="Detalle de consumo">
      <button className="secondary" onClick={()=>setSelected(null)}>Cerrar</button><h2>Consumo de {selected.uid}</h2>
      <p>Última actualización: {selected.summary.updatedAt??'No disponible'}</p><p>Último inventario: {selected.summary.inventoryAt??'Pendiente'}</p>
      <p>Última observación de capacidad: {selected.summary.capacityObservedAt??'Pendiente'}</p>
      <p>Coste estimado: {money(selected.summary.cost.amountUsd)} · Subtotal conocido: {money(selected.summary.cost.knownSubtotalUsd)}</p>
      <p>Estimación actualizada: {selected.summary.cost.updatedAtIso??'Pendiente'} · Componentes valorados: {selected.summary.cost.componentCoverage==null?'Sin medición':new Intl.NumberFormat('es-CO',{style:'percent',maximumFractionDigits:1}).format(selected.summary.cost.componentCoverage)}. Esta cobertura no representa el porcentaje de la factura total.</p>
      <h3>Subtotal conocido por servicio (USD)</h3><dl>{Object.entries(selected.summary.cost.byService??{}).map(([service,value])=><div key={service}><dt>{service}</dt><dd>{money(value)}</dd></div>)}</dl>
      {!!Object.keys(selected.summary.cost.pendingReasons??{}).length&&<><h3>Pendientes de valoración</h3><ul>{Object.entries(selected.summary.cost.pendingReasons??{}).map(([reason,count])=><li key={reason}>{costReasonLabel(reason)} · {count} eventos</li>)}</ul></>}
      <p>Versiones de tarifa utilizadas: {selected.summary.cost.tariffVersions?.join(', ')||'Ninguna disponible'}</p>
      <h3>Cobertura por servicio</h3><dl>{Object.entries(selected.summary.coverage).map(([key,value])=><div key={key}><dt>{key}</dt><dd>{value}</dd></div>)}</dl>
      <h3>Unidades técnicas del mes</h3><dl>{Object.entries(selected.summary.monthly??{}).filter(([,v])=>typeof v==='number').map(([key,value])=><div key={key}><dt>{key}</dt><dd>{new Intl.NumberFormat('es-CO').format(value)}</dd></div>)}</dl>
      <p>Las observaciones de lecturas del cliente son estimadas y no controlan cuotas. El coste de infraestructura compartida no se atribuye automáticamente a un usuario.</p>
      <p>El tiempo clasificado y sin clasificar son desgloses del almacenamiento observado; no se suman de nuevo al contador general.</p>
    </dialog>}
  </section>;
}
