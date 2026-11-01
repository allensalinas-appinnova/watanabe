import {useEffect, useState, useRef, type FormEvent} from 'react';
import {httpsCallable} from 'firebase/functions';
import {functions} from './firebase';

type Summary = {dailyUsed:number; monthlyUsed:number; attachmentBytes:number; temporaryBytes:number; attachmentFiles:number;
  updatedAt:string|null; inventoryAt:string|null; policy:{dailyAnalyses:number;monthlyAnalyses:number;attachmentBytes:number};
  monthly:Record<string,number>|null; coverage:Record<string,string>; cost:{quality:string;amountUsd:number|null;knownSubtotalUsd?:number|null;coverage?:number|null}};
type Row = {uid:string;summary:Summary};
type Response = {users?:Row[];uid?:string;summary?:Summary;nextCursor?:string|null;billing?:{available:boolean;issue?:string;services?:Array<{day:string;service:string;currency:string;netCost:number;knownSubtotalUsd:number|null;unattributedDifferenceUsd:number|null}>}};
const mb=(n:number)=>new Intl.NumberFormat('es-CO',{maximumFractionDigits:1}).format(n/1000000)+' MB';
const money=(n:number|null|undefined)=>n==null?'Pendiente de confirmar':new Intl.NumberFormat('es-CO',{style:'currency',currency:'USD',maximumFractionDigits:6}).format(n);

export function ResourceUsagePage() {
  const [rows,setRows]=useState<Row[]>([]),[cursor,setCursor]=useState<string|null>(null),[query,setQuery]=useState('');
  const [busy,setBusy]=useState(false),[error,setError]=useState(''),[billing,setBilling]=useState<boolean|null>(null),[selected,setSelected]=useState<Row|null>(null);
  const dialog=useRef<HTMLDialogElement>(null);
  const [services,setServices]=useState<NonNullable<Response['billing']>['services']>([]);
  useEffect(()=>{if(!selected)return;const previous=document.activeElement;dialog.current?.showModal();return()=>{dialog.current?.close();if(previous instanceof HTMLElement)previous.focus();};},[selected]);
  async function load(uid?:string,after?:string) {
    setBusy(true);setError('');
    try {
      const {data}=await httpsCallable<Record<string,string>,Response>(functions,'adminResourceUsage')({...uid?{uid}:{},...after?{cursor:after}:{}});
      if(data.summary&&data.uid) {setSelected({uid:data.uid,summary:data.summary});}
      else {setRows(after?prev=>[...prev,...data.users??[]]:data.users??[]);setCursor(data.nextCursor??null);setBilling(data.billing?.available??false);setServices(data.billing?.services??[]);}
    } catch {setError('No se pudo consultar el consumo. Reintenta.');} finally {setBusy(false);}
  }
  useEffect(()=>{void load();},[]);
  const search=(e:FormEvent)=>{e.preventDefault();if(query.trim())void load(query.trim());};
  return <section className="resource-usage"><div className="page-heading"><div><p className="eyebrow">RECURSOS Y COSTES</p><h1>Consumo por usuario</h1>
    <p>Mes UTC actual. Los límites se comparten entre dispositivos y se conservan después de reiniciar datos.</p></div>
    <button className="secondary" onClick={()=>void load()} disabled={busy}>Actualizar</button></div>
    {error&&<div className="error-banner" role="alert">{error}</div>}
    {billing===false&&<div className="empty-state">Conciliación con facturación pendiente. Los costes conocidos son estimaciones; los datos ausentes no equivalen a cero.</div>}
    <form onSubmit={search} className="search-form"><input aria-label="UID exacto" placeholder="UID exacto" value={query} onChange={e=>setQuery(e.target.value)}/><button disabled={busy} className="primary">Consultar</button></form>
    {busy&&<p aria-live="polite">Consultando…</p>}
    {!busy&&!rows.length&&<p>No hay consumo registrado.</p>}
    <div className="table-wrap"><table><thead><tr><th>Usuario</th><th>Análisis hoy / mes</th><th>Adjuntos</th><th>Temporales</th><th>Coste mensual</th><th>Cobertura</th></tr></thead><tbody>{rows.map(row=><tr key={row.uid}>
      <td><button className="text-button" onClick={()=>setSelected(row)}>{row.uid}</button></td>
      <td>{row.summary.dailyUsed}/{row.summary.policy.dailyAnalyses} · {row.summary.monthlyUsed}/{row.summary.policy.monthlyAnalyses}</td>
      <td>{mb(row.summary.attachmentBytes)} / {mb(row.summary.policy.attachmentBytes)} · {row.summary.attachmentFiles} archivos</td>
      <td>{mb(row.summary.temporaryBytes)}</td><td>{money(row.summary.cost.amountUsd)}</td><td>{row.summary.cost.quality==='pending'?'Incompleta':'Estimado'}</td>
    </tr>)}</tbody></table></div>
    {cursor&&<button className="secondary" disabled={busy} onClick={()=>void load(undefined,cursor)}>Cargar más</button>}
    {!!services?.length&&<div className="panel"><h2>Conciliación por servicio</h2><p>Costes del proyecto LumioMoney. Las diferencias incluyen infraestructura compartida y mediciones todavía incompletas; no se reparten entre usuarios.</p><div className="table-wrap"><table><thead><tr><th>Día</th><th>Servicio</th><th>Proveedor</th><th>Subtotal de usuarios (USD)</th><th>Diferencia sin atribuir (USD)</th></tr></thead><tbody>{services.map(s=><tr key={`${s.day}:${s.service}:${s.currency}`}><td>{s.day}</td><td>{s.service}</td><td>{s.netCost.toFixed(6)} {s.currency}</td><td>{money(s.knownSubtotalUsd)}</td><td>{money(s.unattributedDifferenceUsd)}</td></tr>)}</tbody></table></div></div>}
    {selected&&<dialog ref={dialog} className="resource-detail" onCancel={()=>setSelected(null)} aria-label="Detalle de consumo">
      <button className="secondary" onClick={()=>setSelected(null)}>Cerrar</button><h2>Consumo de {selected.uid}</h2>
      <p>Última actualización: {selected.summary.updatedAt??'No disponible'}</p><p>Último inventario: {selected.summary.inventoryAt??'Pendiente'}</p>
      <p>Coste estimado: {money(selected.summary.cost.amountUsd)} · Subtotal conocido: {money(selected.summary.cost.knownSubtotalUsd)}</p>
      <h3>Cobertura por servicio</h3><dl>{Object.entries(selected.summary.coverage).map(([key,value])=><div key={key}><dt>{key}</dt><dd>{value}</dd></div>)}</dl>
      <h3>Unidades técnicas del mes</h3><dl>{Object.entries(selected.summary.monthly??{}).filter(([,v])=>typeof v==='number').map(([key,value])=><div key={key}><dt>{key}</dt><dd>{new Intl.NumberFormat('es-CO').format(value)}</dd></div>)}</dl>
      <p>Las observaciones de lecturas del cliente son estimadas y no controlan cuotas. El coste de infraestructura compartida no se atribuye automáticamente a un usuario.</p>
    </dialog>}
  </section>;
}
