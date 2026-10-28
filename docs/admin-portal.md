# Portal administrativo interno

## Alcance inicial

`admin_portal/` es una SPA React/TypeScript publicada en un sitio dedicado de
Firebase Hosting (`lumiomoney-admin`). Su panel incluye resumen operativo,
usuarios e instalaciones, distribución de versiones y auditoría. Las pantallas
son solo de consulta: no ofrecen bloqueo de cuentas, revocación de sesiones ni
acceso a movimientos o datos financieros.

El inicio de sesión usa Google. El primer operador se provisiona al llamar
`bootstrapAdmin`: la Function comprueba en servidor que la identidad sea Google,
el correo esté verificado y coincida con `ADMIN_OWNER_EMAIL`. El UID nunca se
acepta desde el navegador. Después, cada llamada consulta
`adminOperators/{uid}` y verifica estado/rol. Para incorporar personal en una
entrega futura se definirán herramientas de gestión de roles, MFA y aprobación;
no se habilita autoasignación desde el portal.

## Variables locales

Copiar `admin_portal/.env.example` a `.env.local` y configurar el Firebase Web
App del proyecto `lumiomoney`. Las variables Vite solo contienen configuración
cliente pública de Firebase; no colocar secretos, claves de service account ni
tokens. Firebase Auth debe tener Google habilitado y el hostname de Hosting en
sus dominios autorizados (`lumiomoney-admin.web.app`).

Para funciones, definir `ADMIN_OWNER_EMAIL` con el correo aprobado y
`ADMIN_EXCLUDED_TEST_UIDS_JSON` con una lista JSON de UIDs sintéticos, por
ejemplo `[]`, y `ADMIN_AUTH_READER_SERVICE_ACCOUNT` con la cuenta de servicio
dedicada a las dos consultas que leen Firebase Auth. Estos parámetros no
contienen credenciales. La configuración de despliegue de Functions se mantiene
en `functions/.env.<project>` (ignorado por Git), para que Firebase CLI cargue
esos parámetros al publicar.
`functions/.env.<project>.local` se reserva para el emulador y no sustituye la
configuración de despliegue.

```sh
cd admin_portal
npm ci
npm run dev
npm run build
```

Para el navegador local, las llamadas reales requieren el mismo proyecto
Firebase configurado. Solo se deben usar datos sintéticos en `demo-clearbudget`
al cualificar. No cambiar el `.firebaserc` predeterminado.

## Datos y límites

- El resumen diario consulta Auth, documentos de perfil y las instalaciones
  activas; no recorre subcolecciones financieras.
- El listado usa páginas de hasta 50 usuarios. La búsqueda es por correo exacto
  o UID exacto; no se permite búsqueda parcial.
- El detalle muestra únicamente datos de Auth, estado de onboarding/reinicio y
  plataforma/versión/fechas de instalaciones.
- Cada listado, consulta individual, lectura de resumen y página de auditoría
  genera un evento de auditoría. La bitácora omite correo y datos de sesión,
  conservando UID actor/objetivo y acción durante 180 días.
- Las instalaciones antiguas no tienen versión; se presentan como desconocidas
  hasta que un cliente nuevo reporte `appVersion` y `buildNumber`.
- El trabajo diario corre a las 03:00 `America/Bogota`. La vista indica la hora
  de generación y trata la ausencia de datos como “no disponible”, no cero.
- Los UID de operadores y los UIDs de prueba configurados se excluyen de los
  agregados. El resumen incluye cuentas registradas, no sesiones anónimas.

## Funciones y permisos

- `bootstrapAdmin`: alta idempotente restringida al correo dueño configurado.
- `adminOverview`, `adminListUsers`, `adminLookupUser`, `adminListAudit`: solo
  operadores activos y Google verificado.
- `refreshAdminDailyMetrics`: agregación programada sin escrituras financieras.
- `manageDevice`: amplía metadatos opcionales de instalación con versión/build.
- `adminOperators`, `adminDailyMetrics` y `adminAudit` rechazan acceso directo
  de clientes en Firestore. Las lecturas administrativas pasan por callables.
- `adminListUsers` y `adminLookupUser` usan una cuenta de servicio exclusiva
  con `roles/firebaseauth.viewer` y `roles/datastore.user`. No otorgar el rol de
  Auth Viewer a la cuenta de servicio general de las demás Functions.
- Las cinco callables de acceso (`bootstrapAdmin`, `adminOverview`,
  `adminListUsers`, `adminLookupUser`, `adminListAudit`) necesitan invocación
  HTTP pública en Cloud Run para que Firebase Auth pueda entregar el token al
  código de la Function. En `lumiomoney`, una excepción a la política de
  organización permite `allUsers` únicamente a servicios con la etiqueta
  organizacional `allUsersIngress=True`. La Function sigue exigiendo Firebase
  Auth y verifica Google y el rol de operador; la excepción no autoriza el
  acceso a los datos por sí sola. No aplicar esa etiqueta a otros servicios.

El registro de auditoría expira con TTL a 180 días y los agregados a 400 días;
la eliminación TTL es eventual. Para producción, revisar retención, MFA y
política de acceso del equipo antes de añadir operadores.

## Cualificación

Ejecutar Functions y reglas en `demo-clearbudget`. Probar propietario autorizado,
usuario app normal, sesión sin autenticación, aislamiento UID, paginación,
busqueda exacta, DTO sin datos financieros y ausencia de acceso Firestore
directo. Las métricas solo están disponibles tras ejecutar el job programado o
invocar su lógica de prueba en el emulador. La publicación del Hosting por sí
sola no demuestra que Google Auth, roles, Scheduler, TTL ni callables estén
configurados correctamente en el proyecto.
