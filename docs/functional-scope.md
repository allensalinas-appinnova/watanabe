# Alcance funcional inicial

## Propósito

Este documento define el alcance inicial de la aplicación Flutter de finanzas personales, tomando como baseline funcional la versión web `studio` en el commit `8847693` (`Order Unbudgeted Expenses by value desc`). Describe comportamiento observado en el repositorio; las decisiones específicas de UX, arquitectura móvil y operación offline quedan como propuestas o preguntas abiertas.

## Objetivo del producto

Permitir que una persona registre y consulte sus ingresos, gastos, cuentas y presupuestos, y que obtenga una vista rápida de su situación financiera mediante un dashboard, seguimiento presupuestario y reportes.

## Alcance funcional confirmado en la versión web

### 1. Acceso y configuración inicial

- Crear cuenta con email y contraseña; la contraseña exige mínimo ocho caracteres.
- Iniciar sesión con email y contraseña.
- Iniciar sesión con Google.
- Iniciar sesión como invitado mediante autenticación anónima.
- Crear el perfil inicial del usuario en Firestore.
- Ejecutar onboarding después del registro para elegir idioma y seleccionar categorías y cuentas predeterminadas.
- Proteger las pantallas principales para usuarios autenticados.

Evidencia: `studio/src/app/login/page.tsx:43-185`, `studio/src/app/onboarding/page.tsx:92-157`, `studio/src/components/auth/ProtectedRoutes.tsx`.

### 2. Dashboard

Mostrar un resumen del mes actual basado en las cuentas marcadas para aparecer en el dashboard:

- gasto total;
- ingreso total;
- presupuesto de gastos;
- presupuesto neto —ingresos presupuestados menos gastos presupuestados—;
- porcentaje de cumplimiento del presupuesto de gastos;
- distribución y actividad reciente según los componentes del dashboard.

Las transferencias internas se excluyen de los totales de ingresos y gastos. El usuario puede controlar qué cuentas aparecen en el dashboard.

Evidencia: `studio/src/app/page.tsx:16-109`, `studio/src/lib/actions.ts:32-88`, `studio/src/components/dashboard/`.

### 3. Cuentas financieras

Permitir:

- crear, editar y eliminar cuentas;
- configurar tipo de cuenta: wallet, savings, checking, credit card, revolving credit o loan;
- definir saldo inicial y fecha del saldo inicial;
- mostrar u ocultar la cuenta en el dashboard;
- mostrar u ocultar el saldo de la cuenta en selectores y filtros;
- ordenar manualmente las cuentas;
- recalcular el saldo de una cuenta a partir de sus movimientos.

Al eliminar una cuenta, también se eliminan sus ingresos y gastos asociados.

Evidencia: `studio/src/app/accounts/page.tsx:18-109`, `studio/src/lib/types.ts:17-29`, `studio/src/lib/actions.ts:303-430`.

### 4. Movimientos, ingresos y gastos

El dominio usa un movimiento de caja (`Cashflow`) con tipo `in` o `out`, descripción, monto, fecha, cuenta, categoría opcional y saldo resultante.

Permitir:

- registrar ingresos;
- registrar gastos;
- editar movimientos;
- eliminar movimientos;
- asignar cuenta y categoría;
- consultar ingresos y gastos por separado;
- consultar todos los movimientos;
- filtrar por cuenta, categoría y rango de fechas;
- exportar los movimientos filtrados a CSV;
- confirmar explícitamente operaciones retroactivas cuando la fecha del movimiento puede alterar saldos posteriores.

Al agregar o editar un movimiento, se recalculan los saldos de la cuenta y de los movimientos posteriores. La edición de un movimiento no permite cambiarlo de cuenta; la implementación actual indica eliminarlo y crearlo nuevamente.

Evidencia: `studio/src/app/expenses/page.tsx:18-151`, `studio/src/app/incomes/page.tsx:18-146`, `studio/src/app/transactions/page.tsx:18-204`, `studio/src/lib/actions.ts:95-299`.

### 5. Transferencias entre cuentas

Permitir transferir dinero entre dos cuentas. La transferencia se representa como un movimiento de salida en la cuenta origen y uno de entrada en la cuenta destino, con categorías internas de transferencia para excluirla de los totales ordinarios.

Evidencia: `studio/src/app/transfers/page.tsx:13-58`, `studio/src/lib/actions.ts:719-781`.

### 6. Categorías

Permitir:

- listar categorías;
- crear, editar y eliminar categorías;
- definir nombre, icono y tipo —ingreso o gasto—;
- usar categorías diferentes para ingresos y gastos;
- seleccionar categorías predeterminadas durante el onboarding.

Al eliminar una categoría, los movimientos relacionados quedan sin categoría y los presupuestos asociados se eliminan.

Evidencia: `studio/src/app/categories/page.tsx:12-58`, `studio/src/lib/types.ts:57-66`, `studio/src/lib/actions.ts:432-501`, `studio/src/lib/default-categories.ts`.

### 7. Presupuestos

Permitir definir un presupuesto por categoría y agregar elementos de presupuesto con descripción, monto y día del mes. Los elementos modifican el total del presupuesto de su categoría y pueden servir como base para crear un ingreso o gasto desde el planificador.

Evidencia: `studio/src/app/budgets/page.tsx:14-93`, `studio/src/lib/types.ts:43-55`, `studio/src/lib/actions.ts:503-640`, `studio/src/components/budgets/`.

### 8. Seguimiento presupuestario

Comparar, por categoría y mes, el gasto real contra el presupuesto definido. Mostrar también los gastos que pertenecen a categorías sin presupuesto, sus movimientos relacionados y el total no presupuestado.

Evidencia: `studio/src/app/budget-tracker/page.tsx:34-190`, `studio/src/components/budget-tracker/`.

### 9. Reportes

Mostrar un reporte visual que compara presupuesto y gasto por categoría mediante un gráfico de barras.

Evidencia: `studio/src/app/reports/page.tsx:14-70`, `studio/src/components/reports/BudgetComparisonChart.tsx:16-84`.

### 10. Importación y categorización asistida

El producto web contiene dos flujos de importación:

- revisión de transacciones extraídas de emails, con confirmación, rechazo y selección de cuenta/categoría;
- carga de CSV, procesamiento de filas, sugerencia de categoría y revisión antes de confirmar.

También existe categorización asistida para gastos a partir de descripción o imagen de comprobante.

Estado: estas capacidades deben considerarse parte del alcance funcional de referencia, pero requieren validación adicional antes de convertirlas en una promesa de MVP móvil. La integración Gmail visible en el perfil declara explícitamente que aún no está implementada y el flujo CSV contiene comportamiento de demostración.

Evidencia: `studio/src/app/import/page.tsx:15-88`, `studio/src/components/import/`, `studio/src/ai/flows/`, `studio/src/components/profile/ConnectGmailButton.tsx:8-25`.

### 11. Perfil y preferencias

Permitir consultar y editar datos del perfil, cambiar idioma entre español e inglés y conservar preferencias como última cuenta usada para ingresos/gastos. La interfaz ofrece un selector de idioma global.

Evidencia: `studio/src/app/profile/page.tsx:16-66`, `studio/src/components/profile/`, `studio/src/components/i18n/`, `studio/src/lib/types.ts:5-15`.

## Modelo de información de referencia

El modelo por usuario se organiza en Firestore bajo `users/{userId}`:

- perfil de usuario;
- `accounts`;
- `cashflow`;
- `categories`;
- `budgets` con elementos hijos `items`;
- `email_transactions`;
- `email_integrations`;
- entidades de importación CSV y transacciones importadas.

Los tipos principales están definidos en `studio/src/lib/types.ts:5-133`. Las reglas de acceso actuales restringen el árbol de datos del usuario autenticado a su propio `userId`, con excepciones explícitas para transacciones e integraciones de email en `studio/firestore.rules:1-20`.

## Prioridad propuesta para el MVP Flutter

### P0 — núcleo financiero

1. autenticación y onboarding;
2. perfil e idioma;
3. cuentas y saldos;
4. categorías;
5. registro, edición y eliminación de ingresos/gastos;
6. transferencias;
7. dashboard mensual;
8. sincronización remota con Firestore.

### P1 — control presupuestario

1. presupuestos por categoría;
2. elementos de presupuesto;
3. seguimiento de gasto real vs. presupuesto;
4. gastos no presupuestados;
5. reportes básicos;
6. exportación CSV.

### P2 — automatización e importaciones

1. importación CSV robusta;
2. revisión y confirmación de filas importadas;
3. categorización asistida por descripción o imagen;
4. integración Gmail y extracción de transacciones.

## Fuera del alcance confirmado

- No hay evidencia suficiente en el repositorio para confirmar modo offline, sincronización diferida, notificaciones, múltiples monedas, cuentas compartidas, roles, metas de ahorro, pagos recurrentes, inversiones, deudas detalladas o integración bancaria directa.

## Preguntas abiertas para Flutter

1. ¿El MVP debe funcionar offline? Si la respuesta es sí, hay que definir persistencia local, conflictos y política de sincronización.
2. ¿Se mantiene Firebase Authentication/Firestore como backend móvil?
3. ¿La importación CSV y Gmail entran en P0/P1 o se posponen a P2?
4. ¿La edición debe permitir mover un movimiento entre cuentas, o se conserva la restricción web?
5. ¿Qué moneda, zona horaria y formato regional deben ser configurables?
6. ¿Los saldos y movimientos deben soportar múltiples monedas?
7. ¿Qué proveedores de autenticación se habilitarán en producción: email, Google e invitado?
8. ¿La aplicación móvil debe conservar las mismas rutas conceptuales de la web o reorganizarlas en una navegación móvil?

## Evidencia y verificación

Baseline revisado: commit `8847693` del repositorio `studio`.

Comandos de inspección ejecutados:

- `find src/app -maxdepth 3 -type f -print | sort`
- búsquedas `rg` sobre rutas, componentes, tipos, acciones, flujos AI y colecciones Firestore;
- lectura de `src/lib/types.ts`, `src/lib/actions.ts`, `firestore.rules`, `src/app/*/page.tsx` y componentes relacionados.

Este documento describe el estado encontrado en el código; no implica que las capacidades marcadas como parciales estén listas para producción móvil.
