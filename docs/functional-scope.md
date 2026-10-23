# Alcance funcional vigente

## Propósito y fuente de verdad

Este documento resume el comportamiento del producto LumioMoney implementado
en este repositorio Flutter y sus límites conocidos. El código y las pruebas
son la evidencia de implementación; las decisiones de datos y backend se
documentan en [modelo canónico](canonical-data-model.md),
[presupuestos](budget-commands.md), [coach](coach.md),
[deudas](debts.md) e [importación asistida](email-imports.md). Los diseños
orientan la interfaz, pero no prueban que una capacidad esté desplegada.

## Funcionalidad implementada

### Identidad, onboarding y navegación

- Autenticación Firebase, recuperación de sesión y rutas protegidas.
- Onboarding localizado con datos regionales y selección inicial de cuentas y
  categorías.
- Cinco secciones persistentes: Inicio, Actividad, Cuentas, Plan y Coach.
  Configuración reúne preferencias y gestión global; los enlaces antiguos a
  Más redirigen a Configuración.
- Cuentas organiza dinero, tarjetas y préstamos en subsecciones. Coach ofrece
  un centro para cierre diario, revisión semanal e historial, separado de la
  configuración de recordatorios.
- Pantallas de tarea y consulta conservan navegación contextual y estado de
  sección según el contrato de UX.

Evidencia: `lib/features/auth/`, `lib/core/routing/` y
`docs/ux-implementation-contract.md`.

### Cuentas, movimientos y sincronización

- Cuentas monetarias con moneda, saldo inicial, saldo derivado y preferencia
  para incluirlas en el saldo de Inicio.
- Ingresos, gastos y transferencias con importes en unidades menores. Las
  transferencias tienen dos entradas contables y no se cuentan como ingresos ni
  gastos.
- Ajuste auditable de saldos mediante callable autenticada; los movimientos
  pendientes locales que afecten las cuentas seleccionadas bloquean el ajuste.
- Outbox local para comandos financieros compatibles y estados pendiente,
  sincronizando, confirmado o rechazado. Las callables de presupuestos y deuda
  no se convierten en escrituras offline optimistas.
- Inicio consolida por moneda y respeta selección de cuentas, privacidad y
  preferencias de widgets.

Evidencia: `lib/features/finance/`, `lib/core/offline/`,
`functions/src/balance_adjustments.ts` y
`docs/canonical-data-model.md`.

### Categorías y presupuestos

- Categorías por tipo con selección de color y valores predeterminados
  compatibles con perfiles antiguos.
- Presupuestos por mes, categoría, tipo y moneda, compuestos por elementos.
  La callable `mutateBudget` recalcula total y conteo en la misma transacción.
- Seguimiento compara importes planeados y reales; el Home muestra todas las
  tarjetas de presupuesto visibles, incluyendo el estado de exceso con estilo de
  alerta.

Evidencia: `lib/features/finance/domain/`,
`lib/features/finance/presentation/screens/`,
`functions/src/budget_commands.ts` y `docs/budget-commands.md`.

### Actividad e informes

- Lista paginada con filtros de periodo, cuenta y tipo para ingresos, gastos,
  transferencias y ajustes de saldo.
- Resumen por moneda con Ingresos, Egresos y Resultado; transferencias y
  ajustes no participan en esos totales.
- Revisión previa de CSV con acciones nativas para guardar y compartir. La
  selección se exporta completa, no solo la página cargada; pendientes se
  excluyen por defecto y pueden incluirse explícitamente.

Evidencia: `lib/features/finance/domain/entities/activity_report.dart`,
`lib/features/finance/presentation/screens/canonical_activity_screen.dart`,
`lib/features/finance/presentation/utils/activity_csv_exporter.dart` y
`test/features/finance/presentation/`.

### Coach financiero

- Cierre diario, revisión de la última semana calendario completa y tarjeta
  opcional «Tu siguiente paso» en Inicio.
- Preferencias de horarios/días se sincronizan con Firestore. Los permisos,
  pausa y programación de recordatorios son locales por dispositivo.
- Android/iOS usan notificaciones locales; en web hay interfaz del coach, pero
  no notificaciones web.
- Los informes separan monedas, excluyen transferencias y ajustes de los
  totales y distinguen datos pendientes o posiblemente incompletos.

Evidencia: `lib/features/coach/` y [contrato y verificación](coach.md).

### Cuentas de deuda

El checkout incluye tarjetas de crédito, préstamos/créditos recibidos,
desembolsos, pagos, cargos, devoluciones, ajustes y correcciones auditables.
La implementación está detrás de controles de activación; no convierte cuentas
antiguas y no admite amortización o intereses automáticos. La revisión de la
callable en Cloud Run está lista; una llamada no autenticada fue rechazada como
se espera. No se ha probado un comando financiero autenticado, por lo que la
creación de deuda debe seguir deshabilitada hasta cualificar el cliente. Véase
[estado y límites](debts.md).

### Importación asistida de correo

Solo existe una base parcial de backend: extractores deterministas limitados,
candidatos revisables y comandos de aprobación protegidos. No hay cliente OAuth,
búsqueda Gmail ni pantallas móviles de importación; no debe presentarse como
una integración disponible. Véase [gates restantes](email-imports.md).

## Persistencia y permisos

Firestore organiza los datos financieros bajo `users/{uid}`. Las operaciones y
entradas del ledger son la fuente de verdad; saldos, resúmenes y uso del
presupuesto son proyecciones reconciliables. Las reglas limitan el acceso a los
datos del propietario y reservan las escrituras sensibles para las callables
correspondientes. Los cambios de reglas y Functions se validan separadamente
con Firebase Emulator y con evidencia del proyecto remoto.

Evidencia: `firestore.rules`, `functions/src/projection_store.ts`,
`functions/src/projection_audit.ts` y `docs/projection-audit.md`.

## Límites conocidos y estado de release

- No hay configuración de Firebase staging verificada; la configuración local
  de desarrollo apunta a `lumiomoney`. Las pruebas automatizadas deben usar
  `demo-clearbudget`.
- El Android debug y los flujos Emulator se cualifican por separado del APK
  firmado. El build release requiere un `storeFile`/keystore que no está
  configurado.
- La entrega de notificaciones se verificó en dispositivos para el flujo
  probado; los toques reales con app cerrada, la revisión completa de
  accesibilidad y la aceptación visual de todas las pantallas continúan siendo
  gates distintos.
- Gmail requiere aún OAuth, permisos y recursos de infraestructura; no hay
  importación real habilitada.
- La función de deuda sigue desactivada hasta validar el cliente actualizado;
  Cloud Run presenta una revisión lista.

El estado detallado y las últimas verificaciones se mantienen en
[backlog](implementation-backlog.md), [cualificación de tiendas](store-readiness-audit.md)
y las guías enlazadas arriba. Los diseños orientan la interfaz, pero no son
evidencia de implementación o despliegue.
