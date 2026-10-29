# Diagnóstico financiero personal

## Producto y alcance

Coach abre `Diagnóstico financiero` sin añadir una sección de navegación.
El diagnóstico es personal; dependientes y gastos compartidos aportan contexto,
pero no consolidan cuentas de otras personas. Los formularios guardan secciones
independientes para permitir completar la información progresivamente. Guardar
requiere conexión; un error conserva los campos mientras el formulario siga
abierto. Las lecturas usan la caché de Firestore y la señalan como provisional.

Las tres áreas del plan están representadas: liquidez y sostenibilidad; deuda,
reservas, metas y provisiones; patrimonio, inversiones, coberturas, impuestos y
retiro. No hay puntuación global, IA, selección de productos, conexión bancaria,
conversión de moneda, intereses automáticos ni proyección actuarial.

## Datos y persistencia

Los movimientos y saldos existentes conservan su autoridad. Se agregan:

- `users/{uid}/diagnosticRecords/{recordId}`: `kind`, `values`, `revision`,
  `dataGeneration`, `updatedAt`, `paymentBaselineMinor` (solo servidor). Tipos: context, account, classification, plan,
  reserve, goal, debt, asset y coverage.
- `diagnosticRecords/{recordId}/valuations/{requestId}`: valoraciones explícitas
  de activos con su fecha de referencia, revisión y fecha de registro.
- `users/{uid}/diagnosticCommands/{requestId}`: recibos privados del servidor.

`mutateDiagnostic` recibe `action=save|delete`, `recordId`, `kind`, `values`,
`expectedGeneration`, `revision` y `requestId`. UID procede de Firebase Auth.
Los comandos son idempotentes; una revisión concurrente exige volver a cargar.
El servidor valida campos permitidos, tipos, tamaños, fechas, monedas y
referencias dentro del propietario. Importes son enteros en unidades menores;
la UI captura tasas en porcentaje y las persiste en puntos básicos enteros.
El máximo por registro se deriva de campos de hasta 500 caracteres y los límites
monetarios existentes. Hay un máximo de 2.000 registros complementarios.

Los activos externos pueden destinarse a una meta, incluida la de retiro. No se
permite asignar además una cuenta vinculada o una obligación al mismo recurso.
Las cuentas archivadas se mantienen en el histórico; su saldo no se trata como
efectivo disponible.

Los clientes solo leen sus registros y valoraciones. No pueden escribirlos ni
consultar recibos directamente. No se amplían las reglas de cuentas, operaciones
ni presupuestos. Las nuevas reglas son un prototipo sujeto a revisión antes de
una distribución amplia; las pruebas Emulator comprueban aislamiento y denegación
de escrituras directas. El reinicio existente enumera y elimina recursivamente
las subcolecciones del usuario: incluye datos nuevos, valoraciones y recibos.
No se registra contenido financiero en Analytics ni en mensajes de error.

## Metodología 1

Cada indicador contiene moneda, valor o ausencia de valor, unidad, fuentes,
periodo, información faltante y suficiencia (`sufficient`, `partial`,
`notCalculable`). La pantalla explica su fórmula, supuestos y metodología.
Los resultados son observaciones de los datos registrados, no certificaciones
de información externa.

- **Resultado del mes:** ingreso reconocido menos gasto neto reconocido;
  devoluciones y reversos conservan sus signos.
- **Flujo de efectivo:** suma de entradas del ledger en cuentas monetarias,
  excluyendo ajustes. Incluye financiación y pagos de capital; no equivale a
  ahorro. Transferencias entre cuentas incluidas se compensan.
- **Dinero libre:** saldos de disponibilidad inmediata menos reservas en esas
  cuentas. No usa cupos ni saldos a favor de tarjetas como efectivo.
- **Cobertura de emergencia:** reserva líquida dedicada a emergencia dividida
  por gasto esencial promedio de meses completos. Sin base positiva o sin
  clasificación, no es calculable. Objetivo inicial de referencia: tres meses;
  el usuario puede cambiarlo.
- **Histórico:** últimos tres meses consecutivos completos anteriores al mes
  actual; el selector permite hasta doce. Se detiene al primer mes sin
  confirmación. Menos de tres meses se presenta como provisional.
- **Margen recurrente:** ingreso recurrente mensual promedio menos gastos netos
  mensuales promedio; es anterior a capital de deuda y metas.
- **Gasto fijo:** gasto neto clasificado fijo dividido por gasto neto histórico.
  La clasificación del elemento prevalece sobre la de su categoría.
- **Presión de deuda:** cuota contractual o mínimo vigente por cuenta dividido
  por ingreso neto recurrente promedio. Si faltan condiciones se usa el plan
  mensual como aproximación y se marca parcial. DTI bruto usa exclusivamente
  el ingreso bruto declarado y se muestra aparte. Un denominador cero no da 0%.
- **Tarjetas:** saldo de deuda dividido por cupo. Tasas efectivas mensuales se
  convierten mediante `(1 + tasa)^12 - 1` para compararlas con efectivas anuales.
  La comparación es parcial: no supone costos, tasas variables futuras ni ahorro
  por refinanciación. Capital y cargos muestran componentes registrados.
- **Metas, provisiones, impuestos y retiro:** reservas asignadas divididas por
  objetivo. Aporte requerido: faltante dividido por meses calendario disponibles,
  incluyendo el actual; una meta vencida muestra el faltante y requiere revisión.
  No se presume rendimiento. El mismo dinero solo tiene una finalidad.
- **Patrimonio registrado:** saldos monetarios y deuda más activos externos
  atribuibles menos obligaciones externas. Activos vinculados a una cuenta no
  vuelven a sumarla. Propiedad se aplica sobre el valor total informado. Las
  valoraciones históricas son observaciones, no rentabilidades ni estimaciones
  reconstruidas del pasado.
- **Inversiones:** participación del valor atribuible en el inventario de renta
  variable y renta fija. No representa inversiones omitidas ni prescribe una
  asignación. Contexto permite declarar capacidad y tolerancia al riesgo.
- **Protección:** necesidad declarada menos cobertura vigente, con mínimo cero.
  Sin necesidad declarada no se concluye suficiencia; un seguro vencido no
  contribuye cobertura. Deducibles y beneficiarios quedan en el inventario.

Ausencia de datos significa desconocido. Confirmaciones de saldos de más de 30
días, condiciones de deuda de más de 90 días y valoraciones de más de 365 días
limitan las conclusiones. Son reglas de vigencia del producto, no umbrales
universales de salud financiera.

## Proyección y recomendaciones

El horizonte incluye hoy y los siguientes 89 días calendario locales. Usa saldos
actuales y únicamente importes pendientes de los elementos existentes. No repite
presupuestos. Compromisos mensuales de deuda respetan periodos, pausas,
omisiones, pagos enlazados y versiones por mes efectivo.

Cada elemento de presupuesto debe identificar cuenta y efecto: cobro/pago,
compra con tarjeta o sin efecto monetario. Compras con tarjeta no salen del banco;
el compromiso de pago de tarjeta sí. Un movimiento sin vínculo se ofrece para
asociación explícita con un elemento compatible; nunca se empareja por similitud.
Pagos pasados sin confirmar se señalan y no se mueven a otra fecha.

Pagos preceden cobros del mismo día. No se asumen transferencias entre cuentas.
Se muestran pasos y mínimos por cuenta y por moneda. Una salida libera solo su
reserva vinculada, directa o mediante una provisión/meta fiscal enlazada al mismo
elemento. El dinero reservado no se descuenta dos veces. Las reservas guardan el importe pagado al momento de asignarlas; los pagos
posteriores consumen su respaldo derivado, incluso al consultar elementos
archivados. Editar una reserva vuelve a establecer esa referencia. No se puede
cambiar el compromiso de una provisión mientras tenga reservas asignadas.
Los escenarios reducen
ingresos y aumentan gastos entre 0 y 100%, inicialmente cero, sin modificar datos.
Cuotas de capital no aumentan por simular inflación del gasto.

La prioridad es faltante de efectivo, pagos pasados o uso de reservas,
información incompleta y brechas frente a metas. No se afirma mora bancaria
por ausencia de pago registrado. Un mes sin plan confirmado nunca se presenta
como un mes sin compromisos.

## Validación y publicación

Pruebas específicas:

```sh
flutter test test/features/diagnostics
npm --prefix functions run build
FIRESTORE_EMULATOR_HOST=127.0.0.1:59180 GCLOUD_PROJECT=demo-clearbudget \
  node --test functions/test/diagnostic_records_test.mjs
node --test functions/test/firestore_rules_test.mjs
flutter test integration_test/diagnostic_flow_test.dart -d emulator-5554 \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

El recorrido de integración usa identidad y datos sintéticos en `demo-clearbudget`:
crea un plan, configura disponibilidad y reserva, completa contexto desde la UI,
registra un pago y comprueba que el diagnóstico se actualiza sin volver a
proyectar ese pago. No autoriza ni crea movimientos reales.

Publicar únicamente `functions:mutateDiagnostic` y las reglas compatibles antes
del cliente. Verificar la callable sin sesión (401) y conservar por separado la
evidencia de build, pruebas automatizadas, Android, iOS y despliegue real. El
estado observado de esta entrega se registra al terminar las validaciones.

### Evidencia de esta entrega (2026-10-29)

- `flutter pub get`, generación de modelos y traducciones completados. La
  generación no introdujo cambios adicionales de modelos existentes.
- `flutter analyze`: sin incidencias. `flutter test`: **454 pruebas pasadas**,
  incluyendo **32** del diagnóstico.
- Backend: **7 pruebas** de comandos con identidades distintas por ejecución;
  reglas de Firestore: **26 pruebas**. Se comprobó respaldo concurrente de
  reservas, idempotencia, aislamiento, reinicio, historia de valoraciones,
  monedas y consumo de reservas después de pagos parciales.
- Recorrido iPhone 17 Simulator + Auth/Firestore/Functions Emulator: **pasó**.
  Completa contexto desde la UI y valida pago y actualización contra Firebase
  sintético, incluida liberación de la reserva del pago. El pago se registra
  mediante callable; esto no certifica cada formulario financiero de la app.
- Compilaciones web y APK Android debug: completadas. Advertencias existentes
  sobre Kotlin Gradle Plugin, fuentes Cupertino y versión de analyzer del
  generador se mantienen separadas de errores de esta funcionalidad.
- Recarga en caliente de la app activa: completada. El recorrido Android quedó
  pendiente porque `emulator-5554` no respondió a comandos de shell y la
  instalación quedó bloqueada; se detuvieron solo los procesos de esta prueba.
- Las reglas nuevas fueron publicadas en `lumiomoney`. Se preservó previamente
  una copia local ignorada y se comprobó que la versión remota coincidía con
  la base del repositorio antes de publicar.
- La creación inicial de `mutateDiagnostic` encontró una restricción IAM al
  asignar invocación pública. La revisión automática rechazó desactivar la
  comprobación IAM de Cloud Run sin autorización explícita. El código declara
  `invoker: private` para evitar permisos IAM `allUsers`. Posteriormente el
  usuario autorizó explícitamente desactivar solo la comprobación IAM de
  invocación en este servicio; véase la verificación posterior.
- No se crearon operaciones financieras reales ni se publicó una versión en
  tiendas. Los cambios del cliente permanecen en el checkout.

Antes de aplicar la autorización, `mutateDiagnostic` se actualizó mediante
Firebase CLI, conservando IAM. Cloud Run confirmó `CONDITION_SUCCEEDED` en
`mutatediagnostic-00002-nul`, con `invokerIamDisabled=false`. La comprobación
externa sin credenciales devolvió entonces HTTP 403 de IAM.


### Activación autorizada y verificada (2026-10-29)

Tras la autorización explícita del usuario se modificó únicamente el servicio
Cloud Run `projects/lumiomoney/locations/us-central1/services/mutatediagnostic`:
`invokerIamDisabled=true`. Se generó una revisión nueva conservando el código,
la imagen, las variables y las verificaciones del handler. Cloud Run confirmó
`CONDITION_SUCCEEDED` en `mutatediagnostic-00003-2sh`.

La URL callable devolvió HTTP 401 `UNAUTHENTICATED` con
`diagnostic-session-expired` al recibir una petición sin sesión. La URL directa
de Cloud Run también devolvió HTTP 401 `UNAUTHENTICATED` con un token
intencionalmente inválido. Esto verifica que las peticiones llegan a Firebase
y que la autenticación continúa obligatoria. El UID sigue procediendo de Auth
y el acceso a datos se limita a `users/{uid}`. No se modificaron otros servicios,
reglas ni movimientos financieros durante esta activación. La prueba de acceso
autenticado y persistencia permanece respaldada por Emulator; no se creó ningún
registro real como prueba.
