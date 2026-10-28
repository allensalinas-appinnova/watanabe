import {useCallback, useEffect, useMemo, useState, type FormEvent, type ReactNode} from 'react';
import {GoogleAuthProvider, onAuthStateChanged, signInWithPopup, signOut, type User} from 'firebase/auth';
import {httpsCallable} from 'firebase/functions';
import {Activity, ArrowDown, BadgeCheck, ChevronRight, CircleAlert, ExternalLink, FileClock, Laptop, LayoutDashboard, LoaderCircle, LogOut, RefreshCw, Search, Shield, Smartphone, Users, X} from 'lucide-react';
import {auth, configurationReady, functions} from './firebase';

type Page = 'overview' | 'users' | 'versions' | 'audit';
type Metrics = {authUserCount: number; profileCount: number; onboardingCompleteCount: number; activeDeviceCount: number; devicesByPlatform: Record<string, number>; devicesByAppVersion: Record<string, number>};
type UserRow = {uid: string; email: string | null; emailVerified: boolean; disabled: boolean; providers: string[]; createdAt: string | null; lastSignInAt: string | null; hasProfile: boolean; onboardingStatus: string | null; resetStatus: string | null};
type Installation = {id: string; platform: string; appVersion: string | null; buildNumber: string | null; createdAt: string | null; lastSeenAt: string | null; active: boolean};
type UserDetail = {user: Omit<UserRow, 'hasProfile' | 'onboardingStatus' | 'resetStatus'>; profile: {exists: boolean; onboardingStatus: string | null; resetStatus: string | null; dataGeneration: number}; devices: Installation[]; activeDeviceCount: number};
type AuditEvent = {id: string; actorUid: string; actorRole: string; action: string; targetUid: string | null; createdAt: string | null};
type OverviewResponse = {available: boolean; generatedAt?: string | null; metrics?: Metrics | null};
type UsersResponse = {users: UserRow[]; nextPageToken: string | null};
type AuditResponse = {events: AuditEvent[]; nextPageToken: string | null};

const callable = <I, O>(name: string) => httpsCallable<I, O>(functions, name);
const fmtDate = (value: string | null | undefined) => value ? new Intl.DateTimeFormat('es-CO', {dateStyle: 'medium', timeStyle: 'short'}).format(new Date(value)) : 'Sin actividad';
const count = (value: number | undefined) => new Intl.NumberFormat('es-CO').format(value ?? 0);

export function AdminPortal() {
  const [user, setUser] = useState<User | null>(null);
  const [authorized, setAuthorized] = useState<boolean | null>(null);
  const [page, setPage] = useState<Page>('overview');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [overview, setOverview] = useState<OverviewResponse | null>(null);
  const [users, setUsers] = useState<UserRow[]>([]);
  const [usersToken, setUsersToken] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  const [detail, setDetail] = useState<UserDetail | null>(null);
  const [audits, setAudits] = useState<AuditEvent[]>([]);
  const [auditToken, setAuditToken] = useState<string | null>(null);

  useEffect(() => onAuthStateChanged(auth, (nextUser) => { setUser(nextUser); setAuthorized(null); }), []);

  const run = useCallback(async <T,>(work: () => Promise<T>) => {
    setBusy(true); setError('');
    try { return await work(); }
    catch (cause) {
      const code = typeof cause === 'object' && cause && 'code' in cause ? String((cause as {code: unknown}).code) : '';
      const message = typeof cause === 'object' && cause && 'message' in cause ? String((cause as {message: unknown}).message) : 'Ocurrió un problema inesperado.';
      setError(code.includes('permission-denied') ? 'Tu cuenta no tiene acceso administrativo.' : code.includes('not-found') ? 'No se encontró una coincidencia exacta.' : message);
      return undefined;
    } finally { setBusy(false); }
  }, []);

  const loadOverview = useCallback(async () => {
    const result = await run(async () => (await callable<Record<string, never>, OverviewResponse>('adminOverview')({})).data);
    if (result) setOverview(result);
  }, [run]);
  const loadUsers = useCallback(async (token?: string | null, append = false) => {
    const result = await run(async () => (await callable<{pageToken?: string}, UsersResponse>('adminListUsers')(token ? {pageToken: token} : {})).data);
    if (result) { setUsers((current) => append ? [...current, ...result.users] : result.users); setUsersToken(result.nextPageToken); }
  }, [run]);
  const loadAudit = useCallback(async (token?: string | null, append = false) => {
    const result = await run(async () => (await callable<{pageToken?: string}, AuditResponse>('adminListAudit')(token ? {pageToken: token} : {})).data);
    if (result) { setAudits((current) => append ? [...current, ...result.events] : result.events); setAuditToken(result.nextPageToken); }
  }, [run]);

  useEffect(() => {
    if (!user) return;
    void run(async () => {
      await callable<Record<string, never>, {role: string}>('bootstrapAdmin')({});
      return true;
    }).then((allowed) => { setAuthorized(allowed === true); if (allowed) void loadOverview(); });
  }, [user, run, loadOverview]);

  useEffect(() => { if (page === 'users' && users.length === 0) void loadUsers(); }, [page, users.length, loadUsers]);
  useEffect(() => { if (page === 'audit' && audits.length === 0) void loadAudit(); }, [page, audits.length, loadAudit]);

  const versionEntries = useMemo(() => Object.entries(overview?.metrics?.devicesByAppVersion ?? {}).sort((a, b) => b[1] - a[1]), [overview]);
  const login = async () => {
    setError('');
    try { await signInWithPopup(auth, new GoogleAuthProvider()); }
    catch { setError('No se pudo iniciar sesión con Google. Inténtalo de nuevo.'); }
  };
  const search = async (event: FormEvent) => {
    event.preventDefault();
    const result = await run(async () => (await callable<{query: string}, UserDetail>('adminLookupUser')({query: query.trim()})).data);
    if (result) setDetail(result);
  };
  const selectPage = (next: Page) => { setError(''); setPage(next); };

  if (!configurationReady) return <div className="config-error"><Shield size={36}/><h1>Configura el portal</h1><p>Completa las variables de Firebase en <code>admin_portal/.env.local</code> a partir de <code>.env.example</code>.</p></div>;
  if (!user) return <main className="login-page"><div className="login-card"><div className="brand-mark">L</div><p className="eyebrow">LUMIOMONEY · INTERNO</p><h1>Centro de administración</h1><p>Monitoreo operativo de usuarios, instalaciones y versiones. Sin acceso a movimientos financieros.</p><button className="primary" onClick={() => void login()}>Continuar con Google</button><small>Acceso restringido a operadores autorizados.</small></div></main>;
  if (authorized === false) return <main className="login-page"><div className="login-card"><div className="brand-mark">L</div><p className="eyebrow">ACCESO RESTRINGIDO</p><h1>No tienes acceso a este portal</h1><p>La sesión se inició, pero esta cuenta no está autorizada como operador de LumioMoney.</p><button className="secondary" onClick={() => void signOut(auth)}>Cerrar sesión</button></div></main>;
  if (authorized === null) return <main className="login-page"><div className="login-card"><LoaderCircle className="spin-icon" size={26}/><p>Verificando acceso…</p></div></main>;

  const nav = [
    {id: 'overview' as const, label: 'Resumen', icon: LayoutDashboard},
    {id: 'users' as const, label: 'Usuarios e instalaciones', icon: Users},
    {id: 'versions' as const, label: 'Versiones', icon: Smartphone},
    {id: 'audit' as const, label: 'Auditoría', icon: FileClock},
  ];

  return <div className="app-shell">
    <aside className="sidebar">
      <div className="brand"><div className="brand-mark small">L</div><div><b>LumioMoney</b><span>Administración</span></div></div>
      <div className="side-label">OPERACIÓN</div>
      <nav>{nav.map(({id, label, icon: Icon}) => <button key={id} className={page === id ? 'nav-item active' : 'nav-item'} onClick={() => selectPage(id)}><Icon size={19}/><span>{label}</span>{page === id && <ChevronRight size={16}/>}</button>)}</nav>
      <div className="side-bottom"><div className="secure-note"><Shield size={17}/><span>Solo consulta<br/>Sin datos financieros</span></div><button className="profile-button" onClick={() => void signOut(auth)}><div className="avatar">{user.displayName?.slice(0, 1) ?? 'A'}</div><span><b>{user.displayName ?? user.email}</b><small>Cerrar sesión</small></span><LogOut size={17}/></button></div>
    </aside>
    <main className="main-area">
      <header className="topbar"><div><span className="crumb">LumioMoney /</span> {nav.find((item) => item.id === page)?.label}</div><div className="top-actions"><span className="role-pill"><BadgeCheck size={15}/> Operador autorizado</span><button className="icon-button" title="Actualizar" onClick={() => page === 'overview' ? void loadOverview() : page === 'users' ? void loadUsers() : page === 'audit' ? void loadAudit() : void loadOverview()}><RefreshCw size={18}/></button></div></header>
      <div className="content">
        {error && <div className="error-banner"><CircleAlert size={18}/><span>{error}</span><button onClick={() => setError('')} aria-label="Cerrar"><X size={17}/></button></div>}
        {busy && <div className="busy-line"><LoaderCircle size={16}/> Actualizando datos…</div>}
        {page === 'overview' && <section>
          <div className="page-heading"><div><p className="eyebrow">PANEL OPERATIVO</p><h1>Resumen</h1><p>Una lectura diaria de la salud operativa de LumioMoney.</p></div><a className="external-link" href="https://console.firebase.google.com/project/lumiomoney/overview" target="_blank" rel="noreferrer">Abrir Firebase <ExternalLink size={15}/></a></div>
          {!overview?.available ? <div className="empty-state"><Activity size={28}/><h2>Métricas en preparación</h2><p>El primer resumen estará disponible después de ejecutarse la actualización diaria. Una lectura no disponible no se muestra como cero.</p><button className="secondary" onClick={() => void loadOverview()}>Reintentar</button></div> : <>
            <div className="freshness"><span className="fresh-dot"/> Actualizado {fmtDate(overview.generatedAt)} <span>·</span> métricas diarias, no en tiempo real</div>
            <div className="metric-grid">
              <Metric label="Usuarios autenticados" value={overview.metrics?.authUserCount} icon={<Users/>} note="Operadores y UID de prueba excluidos"/>
              <Metric label="Perfiles creados" value={overview.metrics?.profileCount} icon={<LayoutDashboard/>} note="Datos de perfil, sin movimientos"/>
              <Metric label="Onboarding completo" value={overview.metrics?.onboardingCompleteCount} icon={<BadgeCheck/>} note="Perfiles que finalizaron la configuración"/>
              <Metric label="Instalaciones activas" value={overview.metrics?.activeDeviceCount} icon={<Smartphone/>} note="Actividad en los últimos 90 días"/>
            </div>
            <div className="panel-grid"><div className="panel"><div className="panel-title"><h2>Plataformas</h2><span>Instalaciones activas</span></div><Distribution data={overview.metrics?.devicesByPlatform ?? {}}/></div><div className="panel"><div className="panel-title"><h2>Estado de incorporación</h2><span>Perfiles</span></div><div className="progress-row"><div><span>Completado</span><b>{count(overview.metrics?.onboardingCompleteCount)}</b></div><Progress value={overview.metrics?.onboardingCompleteCount ?? 0} max={overview.metrics?.profileCount ?? 0}/></div><div className="progress-row muted-progress"><div><span>Sin completar</span><b>{count(Math.max(0, (overview.metrics?.profileCount ?? 0) - (overview.metrics?.onboardingCompleteCount ?? 0)))}</b></div><Progress value={Math.max(0, (overview.metrics?.profileCount ?? 0) - (overview.metrics?.onboardingCompleteCount ?? 0))} max={overview.metrics?.profileCount ?? 0}/></div></div></div>
            <div className="provider-links"><span>Detalle en proveedores</span><a href="https://console.firebase.google.com/project/lumiomoney/authentication/users" target="_blank" rel="noreferrer">Firebase Auth <ExternalLink size={14}/></a><a href="https://appstoreconnect.apple.com/" target="_blank" rel="noreferrer">App Store Connect <ExternalLink size={14}/></a><a href="https://play.google.com/console/" target="_blank" rel="noreferrer">Google Play Console <ExternalLink size={14}/></a></div>
          </>}
        </section>}
        {page === 'users' && <section>
          <div className="page-heading"><div><p className="eyebrow">DIAGNÓSTICO</p><h1>Usuarios e instalaciones</h1><p>Solo metadatos de Auth, onboarding y dispositivos. No se consultan finanzas.</p></div></div>
          <form className="search-bar" onSubmit={(event) => void search(event)}><Search size={19}/><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Buscar correo exacto o UID" aria-label="Correo exacto o UID"/><button className="primary compact" disabled={busy || query.trim().length < 3}>Buscar usuario</button></form>
          {detail && <div className="panel user-detail"><div className="detail-heading"><div><p className="eyebrow">DETALLE DE USUARIO</p><h2>{detail.user.email ?? detail.user.uid}</h2><span className="subtle">UID: {detail.user.uid}</span></div><button className="icon-button" onClick={() => setDetail(null)} aria-label="Cerrar detalle"><X size={18}/></button></div><div className="detail-stats"><span><b>{detail.profile.exists ? 'Perfil creado' : 'Sin perfil'}</b><small>{detail.profile.onboardingStatus === 'complete' ? 'Configuración terminada' : detail.profile.onboardingStatus ?? 'Onboarding no disponible'}</small></span><span><b>{detail.activeDeviceCount} activas</b><small>{detail.devices.length} instalaciones registradas</small></span><span><b>{detail.user.disabled ? 'Deshabilitado' : 'Habilitado'}</b><small>Auth · creado {fmtDate(detail.user.createdAt)}</small></span></div><h3>Instalaciones</h3>{detail.devices.length === 0 ? <p className="subtle">No hay instalaciones registradas.</p> : <div className="table-wrap"><table><thead><tr><th>Plataforma</th><th>Versión</th><th>Build</th><th>Última actividad</th><th>Estado</th></tr></thead><tbody>{detail.devices.map((device) => <tr key={device.id}><td><Platform value={device.platform}/></td><td>{device.appVersion ?? 'Desconocida'}</td><td>{device.buildNumber ?? '—'}</td><td>{fmtDate(device.lastSeenAt)}</td><td><span className={device.active ? 'status good' : 'status'}>{device.active ? 'Activa' : 'Expirada'}</span></td></tr>)}</tbody></table></div>}</div>}
          <div className="panel"><div className="panel-title"><h2>Usuarios recientes</h2><span>Metadatos de Auth y perfil</span></div><div className="table-wrap"><table><thead><tr><th>Correo / UID</th><th>Estado</th><th>Onboarding</th><th>Último acceso</th><th></th></tr></thead><tbody>{users.map((row) => <tr key={row.uid}><td><b>{row.email ?? 'Sin correo'}</b><small className="table-sub">{row.uid}</small></td><td><span className={row.disabled ? 'status bad' : 'status good'}>{row.disabled ? 'Deshabilitado' : row.emailVerified ? 'Verificado' : 'Activo'}</span></td><td>{row.onboardingStatus === 'complete' ? 'Completo' : row.onboardingStatus ?? 'Sin perfil'}</td><td>{fmtDate(row.lastSignInAt)}</td><td><button className="text-button" onClick={() => {setQuery(row.email ?? row.uid); void run(async () => (await callable<{query: string}, UserDetail>('adminLookupUser')({query: row.email ?? row.uid})).data).then((value) => {if(value) setDetail(value);});}}>Ver detalle <ChevronRight size={15}/></button></td></tr>)}</tbody></table></div>{users.length === 0 && !busy && <p className="table-empty">No hay usuarios para mostrar.</p>}{usersToken && <button className="secondary load-more" disabled={busy} onClick={() => void loadUsers(usersToken, true)}>Cargar más usuarios <ArrowDown size={15}/></button>}</div>
        </section>}
        {page === 'versions' && <section><div className="page-heading"><div><p className="eyebrow">DISTRIBUCIÓN DE CLIENTES</p><h1>Versiones</h1><p>Versión reportada por instalación. No se usa para limitar acceso ni monetización.</p></div><a className="external-link" href="https://play.google.com/console/" target="_blank" rel="noreferrer">Play Console <ExternalLink size={15}/></a></div><div className="panel"><div className="panel-title"><h2>Instalaciones activas por versión</h2><span>Últimos 90 días · {fmtDate(overview?.generatedAt)}</span></div>{versionEntries.length ? <div className="version-list">{versionEntries.map(([version, amount]) => <div className="version-row" key={version}><div className="version-icon"><Smartphone size={18}/></div><div className="version-copy"><b>{versionLabel(version)}</b><span>{amount} instalaciones</span></div><div className="version-bar"><i style={{width: `${Math.max(3, amount / Math.max(1, overview?.metrics?.activeDeviceCount ?? amount) * 100)}%`}}/></div><span className="version-count">{amount}</span></div>)}</div> : <div className="empty-inline"><Smartphone size={25}/><span>No hay datos de versión disponibles aún. Las instalaciones antiguas aparecerán como desconocidas hasta que actualicen la app.</span></div>}</div><div className="notice"><CircleAlert size={18}/><p>La versión se recopila al registrar o actualizar una instalación. Dispositivos no usados en este periodo y clientes antiguos pueden no aparecer.</p></div></section>}
        {page === 'audit' && <section><div className="page-heading"><div><p className="eyebrow">TRAZABILIDAD</p><h1>Auditoría</h1><p>Consultas administrativas realizadas a través del portal. Retención propuesta: 180 días.</p></div></div><div className="panel"><div className="panel-title"><h2>Eventos recientes</h2><span>Las consultas de auditoría también quedan registradas</span></div><div className="table-wrap"><table><thead><tr><th>Fecha</th><th>Operación</th><th>Operador UID</th><th>Usuario consultado</th><th>Rol</th></tr></thead><tbody>{audits.map((event) => <tr key={event.id}><td>{fmtDate(event.createdAt)}</td><td><span className="event-tag">{event.action}</span></td><td className="mono">{event.actorUid}</td><td className="mono">{event.targetUid ?? '—'}</td><td>{event.actorRole}</td></tr>)}</tbody></table></div>{audits.length === 0 && !busy && <p className="table-empty">Aún no hay eventos registrados.</p>}{auditToken && <button className="secondary load-more" disabled={busy} onClick={() => void loadAudit(auditToken, true)}>Eventos anteriores <ArrowDown size={15}/></button>}</div><div className="notice"><Shield size={18}/><p>Esta bitácora registra accesos de soporte, no acciones sobre cuentas. El portal no permite modificar ni suspender usuarios.</p></div></section>}
      </div>
      <footer className="footer"><span>© {new Date().getFullYear()} LumioMoney</span><span>Centro operativo interno · Solo lectura</span></footer>
    </main>
  </div>;
}

function Metric({label, value, icon, note}: {label: string; value?: number; icon: ReactNode; note: string}) { return <div className="metric-card"><div className="metric-top"><span>{label}</span><i>{icon}</i></div><strong>{count(value)}</strong><small>{note}</small></div>; }
function Progress({value, max}: {value: number; max: number}) { return <div className="progress-track"><i style={{width: `${max ? Math.min(100, value / max * 100) : 0}%`}}/></div>; }
function Distribution({data}: {data: Record<string, number>}) { const total = Object.values(data).reduce((sum, value) => sum + value, 0); const colors: Record<string, string> = {ios: 'var(--blue)', android: 'var(--green)', web: 'var(--gold)'}; return <>{Object.entries(data).sort((a, b) => b[1] - a[1]).map(([key, value]) => <div className="distribution-row" key={key}><span><i style={{background: colors[key] ?? 'var(--ink-muted)'}}/>{key === 'ios' ? 'iOS' : key === 'android' ? 'Android' : key === 'web' ? 'Web' : key}</span><div><b>{count(value)}</b><small>{total ? Math.round(value / total * 100) : 0}%</small></div></div>)}{total === 0 && <div className="empty-inline">Aún no hay instalaciones activas.</div>}</>; }
function Platform({value}: {value: string}) { const Icon = value === 'web' ? Laptop : Smartphone; return <span className="platform"><Icon size={15}/>{value === 'ios' ? 'iOS' : value === 'android' ? 'Android' : value === 'web' ? 'Web' : 'Otra'}</span>; }
function versionLabel(value: string) { const [version, build] = value.split('|'); if (version === 'unknown') return 'Versión desconocida'; return build && build !== 'unknown' ? `v${version} · build ${build}` : `v${version}`; }
