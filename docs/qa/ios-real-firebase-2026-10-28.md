# QA integral en iPhone — Firebase real

**Fecha:** 28 de octubre de 2026
**Entorno:** iPhone físico, cliente Flutter Debug/Flutter Driver, Firebase de producción `lumiomoney`
**Identidad:** cuenta QA principal ya autorizada (se omiten correo y UID)
**Resultado:** recorrido parcial; se encontraron un bloqueo financiero y un resultado incompleto en el registro de instalaciones.

## Seguridad y alcance de esta ejecución

- El usuario autorizó reiniciar los datos de la cuenta QA principal. El reinicio se hizo desde la aplicación, aumentó la generación de datos de 0 a 1, conservó la identidad de Firebase Auth y llevó al onboarding. Los datos anteriores bajo ese UID fueron eliminados por el flujo de reinicio.
- Se completó el onboarding con español, Colombia, COP y zona horaria de Bogotá. El saldo de apertura se trató como saldo, no como ingreso ni movimiento.
- Después del reinicio se crearon únicamente cuentas, presupuestos y movimientos sintéticos dentro de LumioMoney. No se hicieron pagos bancarios reales ni escrituras manuales desde Firebase Console.
- Los importes de abajo sí están persistidos en Firebase real, pero son datos de prueba de la cuenta QA. Se conservaron al final como pidió el usuario.
- No se desplegó Firebase ni se modificó código durante el recorrido. Las únicas adiciones locales son este informe y sus capturas.

## Resultados comprobados

| Flujo | Resultado |
|---|---|
| Reinicio y onboarding | **Aprobado.** Auth se conservó; se verificó la nueva generación. La cuenta inicial no generó ingreso. |
| Cuentas | **Aprobado parcialmente.** Se crearon cuentas sintéticas en COP; se verificaron saldos y separación entre dinero y deuda. No se probó otra moneda. |
| Gasto, ingreso y transferencia | **Aprobado parcialmente.** Gasto COP 10.000, ingreso COP 200.000 y transferencia COP 30.000. La transferencia movió dinero entre cuentas sin sumarse a ingresos o gastos. El ingreso se editó dos veces y quedó una sola operación vigente. |
| Presupuesto de gasto | **Aprobado.** Presupuesto de COP 100.000; tras el gasto normal y la compra con tarjeta, Inicio muestra COP 60.000 ejecutados (60 %). |
| Tarjeta | **Aprobado para compra y pago.** Se configuraron corte y pago el día 15. Compra sintética de COP 50.000: aumentó el gasto y la deuda. Pago desde el banco por COP 50.000: la tarjeta volvió a cero, el banco bajó una vez y el pago no repitió el gasto. |
| Crédito y compromiso | **Parcial.** Se registró una deuda existente de COP 20.000.000 sin mover el banco y un compromiso mensual de COP 2.400.000, con vencimiento 15 de noviembre de 2026. |
| Pago sin desglose | **Parcial / bloqueo.** Se registró COP 2.400.000 desde el banco. El banco se debitó una sola vez; la cuota aparece pagada, mientras el capital conserva COP 20.000.000 y el pago permanece identificado como pendiente de desglose. La app muestra esta tarea en Inicio y Coach. |
| Coach | **Aprobado parcialmente.** Recomendación de conciliación visible y coherente. “¿Por qué lo veo?” explicó el motivo sin realizar cambios. Se observó un solo engranaje de Configuración y el control independiente de privacidad de importes. |
| Apariencia | **Aprobado parcialmente.** Se cambió a modo oscuro y paleta Océano; luego se restauraron Lumio y modo Sistema. Ambos guardados mostraron sincronización. |
| Actividad y CSV | **Aprobado parcialmente.** Actividad mostró seis movimientos y el resumen correcto: ingresos COP 200.000, egresos COP 60.000, Resultado COP 140.000; transferencias excluidas. La vista previa incluyó los seis confirmados y los filtros del periodo. iOS abrió el panel nativo con un CSV de 1 KB; se cerró sin elegir destino ni compartir. No se inspeccionó el contenido del archivo. |
| Inicio y proyecciones | **Aprobado para los registros probados.** Inicio muestra COP 2.740.000 disponibles (banco COP 2.710.000 + ahorro COP 30.000), COP 200.000 de ingresos, COP 60.000 de gastos, 60 % de ejecución del presupuesto y deuda de COP 20.000.000. La posición neta mostrada es COP -17.260.000, consistente con esas cuentas seleccionadas. |

La lectura de solo consulta de Firestore corroboró seis operaciones confirmadas: un gasto de COP 10.000, un ingreso de COP 200.000, una transferencia ordinaria de COP 30.000, el pago provisional de COP 2.400.000, la compra con tarjeta de COP 50.000 y el pago de tarjeta de COP 50.000. Hay dos registros de pago de deuda: uno provisional y uno de tarjeta ya asignado. No se observó doble débito en las cuentas.

## Bloqueos y hallazgos

### Bloqueante: completar el desglose de un pago provisional

Al distribuir el pago del crédito como COP 2.000.000 a capital y COP 400.000 a cargos nuevos, la revisión fue correcta, pero guardar devolvió el error genérico. El formulario conservó los valores. La lectura posterior confirmó que **no se aplicó ninguna parte del desglose**: el banco continúa en COP 2.710.000, el crédito en COP 20.000.000 y el registro sigue `unallocated`; no se creó el gasto de COP 400.000.

La inspección del código local identifica la causa probable y concreta: la ruta entrega los componentes iniciales para `allocatePayment` ([debt_detail_screen.dart](/Users/allensalinas/dev/allendev/watanabe/finance_flutter/lib/features/debts/presentation/debt_detail_screen.dart:200)), pero el guardado convierte cualquier formulario con esos componentes en acción `correct`, independientemente de la acción solicitada ([debt_form_screen.dart](/Users/allensalinas/dev/allendev/watanabe/finance_flutter/lib/features/debts/presentation/debt_form_screen.dart:832)). La callable recibe un comando incompatible y lo rechaza. **No reintentar ni corregir mediante escrituras directas.** El pago está contabilizado en caja, pero la deuda y los gastos requieren conciliación; conservar este estado visible hasta corregir el cliente y repetir la prueba con datos QA.

### Incompleto: Mis dispositivos

Después del reinicio, Configuración mostró cero instalaciones activas y la subcolección correspondiente estaba vacía. El reinicio borra esa subcolección; es posible que el ciclo de vida del cliente todavía tuviera en caché el UID y no volviera a registrarlo inmediatamente. Esta explicación es una hipótesis: el registro tras reanudación debe volver a comprobarse. No se insertó ningún documento manualmente.

### Artefactos sintéticos

La cuenta QA tiene dos cuentas llamadas “QA Ahorro”: una activa con COP 30.000 y otra archivada con saldo cero. También quedó archivada “Mi billetera” con saldo cero. No afectan el total mostrado; se dejan documentadas para evitar confusión al inspeccionar Cuentas.

## No ejecutado en esta sesión

- Conversión invitado → cuenta registrada con la segunda identidad persistente; requiere que la contraseña se introduzca directamente en el iPhone. No se creó la identidad ni se manejó contraseña.
- Sincronización offline y reconexión; múltiples monedas; reembolso de compra; desembolso y pago de capital; pago mixto conciliado; vinculación de pago existente; anulación/ajuste de movimientos.
- Inspección del contenido del archivo CSV; cierre diario y revisión semanal guardados; activación de rutinas y recepción real de notificaciones; Google Sign-In; cambio de idioma; lectores de pantalla y texto ampliado.
- La interfaz de Actividad y el resumen se inspeccionaron; no se recorrieron todos los filtros con los nuevos movimientos. El panel nativo de compartir se cerró sin transmitir el archivo.
- Gmail/importaciones no tiene un flujo móvil disponible y quedó fuera del recorrido.

Estos puntos son **no probados**, no aprobados. Las pruebas de Emulator/CI no se ejecutaron contra Firebase real.

## Estado final

- App dejada en **Inicio**, en la sesión de la cuenta QA principal.
- Datos sintéticos conservados; reiniciar de nuevo los borraría.
- Tarjeta en COP 0; crédito con COP 20.000.000 registrados y un pago de COP 2.400.000 pendiente de desglose.
- Banco en COP 2.710.000; ahorro activo en COP 30.000.
- Sin despliegue ni commit.

## Evidencia visual

La captura guardada muestra Inicio después de la compra y el pago de tarjeta: saldo disponible, ingresos/gastos y ejecución presupuestal del 60 %.

![Inicio QA: saldo, resumen y presupuesto](/Users/allensalinas/dev/allendev/watanabe/finance_flutter/docs/qa/evidence/home-financial-summary.png)

![Actividad QA: resumen y movimientos del periodo](/Users/allensalinas/dev/allendev/watanabe/finance_flutter/docs/qa/evidence/activity-summary.png)
